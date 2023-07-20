unit ServiceDeploy;

interface

uses
   System.SysUtils, System.IOUtils;

type
   iDeploy = interface
      ['{27BCE45D-3C83-4129-92FC-5D9783D6A09F}']
      procedure Execute;
   end;

type
   TDeploy = class(TInterfacedObject, iDeploy)
      constructor Create;
      destructor Destroy; override;

   private
      FIsNewDeployFile        : Boolean;
      FIsRunDeployFile        : Boolean;
      FDeployFileName         : string;
      FDeployConfigFileName   : string;
      FAppName                : string;
      FParamFileExt           : string;
      FParamFilePath          : string;
      FUpxAppName             : string;
      FInnoSetupScriptFileName: string;
      FInnoSetupScriptExists  : Boolean;
      FParamFileName          : string;
      FProgramFileTemp        : string;
      FFileExtsTemp           : TArray<string>;

      procedure DieParamCountZero;
      procedure DieDependenciesUpxError;

      procedure LoadParams(const aParamFileName: string);
      procedure LoadDeployFile(const aDeployConfigFileName: string);

      procedure NewDeployFile;

      procedure RunDeleteTempFiles;
      procedure RunOptimizeResources;
      procedure RunCompressProgram;
      procedure RunInnoSetupScript;

      procedure RunDeployFile;
      procedure DieParamCountOneAndNoDeploy;
      procedure DeleteTempFolders(aFolderName: string);

   public
      procedure Execute;
   end;

function Deploy: iDeploy;

implementation

uses ServiceConsole, ServiceAssociation, ServiceStripReloc, ServiceExtract;

function Deploy: iDeploy;
begin
   Result := TDeploy.Create;
end;

{ TDeploy }

constructor TDeploy.Create;
begin
   FIsNewDeployFile := false;
   FIsRunDeployFile := false;
end;

destructor TDeploy.Destroy;
begin

   inherited;
end;

procedure TDeploy.DieParamCountZero;
const
   COLOR: TConsoleFontColor = ccCyan;
begin
   if not(ParamCount = 0) then
      exit;

   head(COLOR);
   line('Deploy cannot continue, because of the dependencies below', COLOR);
   rows(COLOR);
   line('No Deploy file was informed for runner!', COLOR, ' • ');
   line('No program was informed for the Delpoy file to be created.',
     COLOR, ' • ');
   rows(COLOR);
   line('MOUSE USES SAMPLE', COLOR);
   rows(COLOR);
   line('Drag and drop App.exe on top of the Deploy to create the file App.Deploy',
     COLOR, ' • ');
   line('Double-click a file with the App.Deploy to run the Deploy',
     COLOR, ' • ');
   rows(COLOR);
   line('COMMAND PROMPT USES SAMPLE', COLOR);
   rows(COLOR);
   line('Deploy App.exe To create App.deploy file from App.exe', COLOR, ' • ');
   line('Deploy App.Deploy To run the App.Deploy file from the App.exe',
     COLOR, ' • ');
   rowe(COLOR);
   Halt(0);
end;

procedure TDeploy.DieParamCountOneAndNoDeploy;
const
   COLOR: TConsoleFontColor = ccWhite;
begin
   if FIsRunDeployFile then
      exit;
   head(COLOR);
   line('Deploy cannot continue, because of the dependencies below', COLOR);
   rows(COLOR);
   line('No Deploy file was informed for runner!', COLOR, ' • ');
   line('No program was informed for the Delpoy file to be created.',
     COLOR, ' • ');
   rows(COLOR);
   line('MOUSE USES SAMPLE', COLOR);
   rows(COLOR);
   line('Drag and drop App.exe on top of the Deploy to create the file App.Deploy',
     COLOR, ' • ');
   line('Double-click a file with the App.Deploy to run the Deploy',
     COLOR, ' • ');
   rows(COLOR);
   line('COMMAND PROMPT USES SAMPLE', COLOR);
   rows(COLOR);
   line('Deploy App.exe To create App.deploy file from App.exe', COLOR, ' • ');
   line('Deploy App.Deploy To run the App.Deploy file from the App.exe',
     COLOR, ' • ');
   rowe(COLOR);
   Halt(0);
end;

procedure TDeploy.DieDependenciesUpxError;
const
   COLOR: TConsoleFontColor = ccYellow;
begin
   head(COLOR);
   line('Deploy cannot continue, because of the dependencies below', COLOR);
   rows(COLOR);
   line('UPX file not found!', COLOR, ' • ');
   line('No! I can`t compress the program.', COLOR, ' • ');
   rows(COLOR);
   line('Resolve dependencies to continue.', COLOR);
   rowe(COLOR);
   Halt(0);
end;

procedure TDeploy.LoadDeployFile(const aDeployConfigFileName: string);
begin
   FAppName                 := ReadDeployConfig(aDeployConfigFileName, 'APP', FAppName, PATH);
   FUpxAppName              := ReadDeployConfig(aDeployConfigFileName, 'UPX', 'upx.exe', PATH);
   FFileExtsTemp            := ReadDeployConfig(aDeployConfigFileName, 'TMP', 'upx,000,001,drc,exe.bak,ex~,rsm', 'EXTENSIONS').Split([',']);
   FInnoSetupScriptFileName := ReadDeployConfig(aDeployConfigFileName, 'InnoSetupScript', 'Instalador.lnk', PATH);

   if not FileExists(FInnoSetupScriptFileName) then
      FInnoSetupScriptFileName := ExtractFilePath(ParamStr(1)) + ExtractFileName(FInnoSetupScriptFileName);

   FInnoSetupScriptExists := FileExists(FInnoSetupScriptFileName);
end;

procedure TDeploy.Execute;
begin
   ConsoleCodePage(65001);

   FDeployFileName := ParamStr(0);

   ServiceAssociation.Association.ExeName(FDeployFileName).Extension('.deploy')
     .FileType('deployFile').Description('Configuration file to deploy')
     .IcoName(FDeployFileName).IcoIndex(0).Associate;

   if ParamCount = 0 then
   begin
      LoadParams(ParamStr(0));
      NewDeployFile;
   end;

   LoadParams(ParamStr(1));
   NewDeployFile;

   FIsRunDeployFile := SameStr('.DEPLOY', Uppercase(FParamFileExt));
   RunDeployFile;
end;

procedure TDeploy.LoadParams(const aParamFileName: string);
begin
   FParamFileName := aParamFileName;
   FParamFilePath := ExtractFilePath(FParamFileName);
   if FParamFilePath.IsEmpty then
   begin
      FParamFileName := ChangeFilePath(FParamFileName, GetCurrentDir);
      FParamFilePath := ExtractFilePath(FParamFileName);
   end;
   FAppName              := ExtractFileName(FParamFileName);
   FParamFileExt         := ExtractFileExt(FParamFileName);
   FProgramFileTemp      := ChangeFileExt(FParamFileName, '.tmp');
   FDeployConfigFileName := ChangeFileExt(FParamFileName, '.Deploy');
   ChDir(FParamFilePath);
   FIsNewDeployFile := SameStr('.EXE', Uppercase(FParamFileExt)) and
     FileExists(FParamFileName);
end;

procedure TDeploy.NewDeployFile;
begin
   if not FIsNewDeployFile then
      exit;

   if FileExists(FDeployConfigFileName) then
      TFile.Delete(FDeployConfigFileName);

   try
      LoadDeployFile(FDeployConfigFileName);

      DieParamCountZero;

      head(ccCyan);
      line('Deployment file has been created successfully', ccCyan);
      line('Now double-click this file to run Deploy', ccCyan);
      rows(ccCyan);
      line(FDeployConfigFileName, ccCyan, ' • ');
      rowe(ccCyan);

   except
      on E: Exception do
      begin
         head(ccRed);
         line('Deploy cannot continue, because of the dependencies below', ccRed);
         rows(ccRed);
         line(E.Message, ccRed, ' • ');
         rows(ccRed);
         line('Resolva as dependências para continuar.', ccRed);
         rowe(ccRed);
      end;
   end;
   Halt(2);
end;

procedure TDeploy.DeleteTempFolders(aFolderName: string);
begin
   if not TDirectory.Exists('.\' + aFolderName) then
      exit;

   line('Removendo folder ' + aFolderName + '...', ccCyan, ' • ');
   TDirectory.Delete('.\' + aFolderName, true);
   // AwaitCommand('rm -Rf ', '.\cache');
end;

procedure TDeploy.RunDeleteTempFiles;
begin
   line('Removing temp folders and files', ccCyan);
   rows(ccCyan);
   DeleteTempFolders('cache');
   DeleteTempFolders('debug');
   DeleteTempFolders('release');
   DeleteTempFolders('log');
   line('Removing temp files...', ccCyan, ' • ');
   DeleteFiles(FProgramFileTemp, FFileExtsTemp);
   rows(ccCyan);
end;

procedure TDeploy.RunOptimizeResources;
const
   P: string = 'P0000000000000000000000000000000000000000000000000000000000000';
   B: string = 'B0000000000000000000000000000000000000000';
   A: string = 'A0000000000000000000000000000000000000000';
   D: string = 'D0000000000000000000000000000000000000000';
var
   Lb   : string;
   La   : string;
   Ld   : string;
   Lbits: string;
begin
   Lbits := ServiceStripReloc.StripReloc.FileName(FAppName).Bits;
   line('Reloc Resources for program 00bits'.Replace('00', Lbits), ccCyan);

   with ServiceStripReloc.StripReloc.FileName(FAppName).Execute do
   begin
      if SameStr(Error, EmptyStr) then
      begin
         Lb := FormatFloat('#,##0', Values.Before).PadLeft(B.Length, ' ');
         La := FormatFloat('#,##0', Values.After).PadLeft(A.Length, ' ');
         Ld := FormatFloat('#,##0', Values.Difference).PadLeft(D.Length, ' ');
         echo(' ├────────────┬────────────────────────────────────────────────────────────────┤',
           ccCyan);
         echo(' │ PROGRAM    │ P0000000000000000000000000000000000000000000000000000000000000 │'.
           Replace(P, FAppName.PadRight(P.Length, ' ')), ccCyan);
         echo(' ├────────────┼────────────────────────────────────────────────────────────────┤',
           ccCyan);
         echo(' │ SIZE       │                B0000000000000000000000000000000000000000 bytes │'.
           Replace(B, Lb), ccCyan);
         echo(' ├────────────┼────────────────────────────────────────────────────────────────┤',
           ccCyan);
         echo(' │ SIZE AFTER │                A0000000000000000000000000000000000000000 bytes │'.
           Replace(A, La), ccCyan);
         echo(' ├────────────┼────────────────────────────────────────────────────────────────┤',
           ccCyan);
         echo(' │ DIFFERENCE │                D0000000000000000000000000000000000000000 bytes │'.
           Replace(D, Ld), ccCyan);
         echo(' └────────────┴────────────────────────────────────────────────────────────────┘',
           ccCyan);
      end
      else
      begin
         echo(' ├────────────┬────────────────────────────────────────────────────────────────┤',
           ccCyan);
         echo(' │ APP        │ P0000000000000000000000000000000000000000000000000000000000000 │'.
           Replace(P, FAppName.PadRight(P.Length, ' ')), ccCyan);
         echo(' ├────────────┴────────────────────────────────────────────────────────────────┤',
           ccCyan);
         line(Error.Replace(' (1)', EmptyStr), ccCyan);
         rowc(ccCyan);
      end;
   end;
   Br;
end;

procedure TDeploy.RunCompressProgram;
begin
   if not ServiceExtract.Extract.Resource('upx')
     .FileName(FParamFilePath + 'upx.exe').Save then
      DieDependenciesUpxError;

   AwaitCommand(FUpxAppName, '"' + ExtractFileName(FAppName) + '" -f -k --all-methods');

   if FileExists('upx.exe') then
      try
         TFile.Delete('upx.exe');
      except
         on E: Exception do
      end;
   rowo(ccCyan);
   line('Removing temp files...', ccCyan);
   DeleteFiles(FProgramFileTemp, FFileExtsTemp);
   rows(ccCyan);
end;

procedure TDeploy.RunInnoSetupScript;
begin
   if FInnoSetupScriptExists then
   begin
      line('Starting to build and publish the installer...', ccCyan);
      rows(ccCyan);
      AwaitShellExecute(FInnoSetupScriptFileName);
      exit;
   end;
end;

procedure TDeploy.RunDeployFile;
begin
   DieParamCountZero;
   DieParamCountOneAndNoDeploy;
   try
      LoadDeployFile(FDeployConfigFileName);

      head(ccCyan);
      line('Startting deployment file has been called below', ccCyan);
      rows(ccCyan);
      line(FDeployConfigFileName, ccCyan, ' • ');
      rows(ccCyan);

      RunDeleteTempFiles;
      RunOptimizeResources;
      RunCompressProgram;
      RunInnoSetupScript;

      line('Deploy it`s Completed.', ccCyan);
      rowe(ccCyan);

   except
      on E: Exception do
      begin
         head(ccRed);
         line('Deployment program returned exception below', ccRed);
         rows(ccRed);
         line(E.Message, ccRed, ' • ');

         rowe(ccRed);
      end;
   end;

end;

end.
