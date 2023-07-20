unit ServiceConsole;

interface

{$APPTYPE CONSOLE}


uses
  Winapi.Windows, Winapi.ShellApi,
  System.IniFiles, System.StrUtils, System.SysUtils, System.DateUtils,
  System.IOUtils;

type
  Exception = System.SysUtils.Exception;

type
  TConsoleFontColor = (ccDefault, ccBlue, ccCyan, ccWhite, ccGreen, ccYellow,
    ccMagenta, ccRed);

const
{$J+}
  YEAR: string = '2022';
{$J-}
  VER          = '2.0';
  APP_BITS     = {$IFDEF WIN32} '32' {$ELSE} '64' {$ENDIF};
  Version      = VER + APP_BITS + 'bits';
  PATH: string = 'Path';

  CONSOLE_COLOR: array [TConsoleFontColor] of Word = (
    { Default } 0,
    { Blue } FOREGROUND_BLUE,
    { Cyan } FOREGROUND_GREEN or FOREGROUND_BLUE,
    { White } FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE,
    { Green } FOREGROUND_GREEN,
    { Yellow } FOREGROUND_RED or FOREGROUND_GREEN,
    { Magenta } FOREGROUND_RED or FOREGROUND_BLUE,
    { Red } FOREGROUND_RED);

function ConsoleCodePage(wCodePageID: UINT = 65001): boolean;
procedure ConsoleDebugString(lpOutputString: LPCWSTR);

procedure FontColor(Color: TConsoleFontColor);
procedure FontColorReset;

function AppNameAtLastNodeFolder: string;

function DateTimeFromFile(aFilename: string): TDateTime;
function YearDateFromFile(aFilename: string): string;

procedure DeleteFiles(aFilename: string; aExtensions: TArray<string>);
procedure Br(aRepeat: byte = 1);
procedure die(const aError: string);
procedure echo(const aText: string; aColor: TConsoleFontColor = ccDefault);

procedure head(aColor: TConsoleFontColor);
procedure line(aValue: string; aColor: TConsoleFontColor; aMarker: string = '');
procedure rowo(aColor: TConsoleFontColor);
procedure rows(aColor: TConsoleFontColor);
procedure rowc(aColor: TConsoleFontColor);
procedure rowe(aColor: TConsoleFontColor);

procedure AwaitCommand(aCommand: string; aParameters: string);
procedure AwaitShellExecute(const aFilename: string);

function RemoveDir(aDir: string): boolean;
function DeleteFile(aFilename: string): boolean;
function ChangeFileExt(const FileName, Extension: string): string;

function FileExists(aFilename: string): boolean;

function ExtractFilePath(aFilename: string): string;
function ExtractFileName(const aFilename: string): string;
function ExtractFileExt(const aFilename: string): string;

function UpperCase(const aValue: string): string;

function LineCount(aValue: string; aLineSize: integer): integer;
function SplitError(aValue: string; aLineSize: integer; aMarker: string = ' • ')
  : TArray<string>;

const
  SECTION = 'DEPLOY';

function ReadDeployConfig(aDeployConfigFileName: string; aPropertie: string;
  aValue: string; aSection: string = SECTION): string;

implementation

var
  LConsoleInfo      : TConsoleScreenBufferInfo;
  LConsoleInfoLoaded: boolean;

function ReadDeployConfig(aDeployConfigFileName: string; aPropertie: string;
  aValue: string; aSection: string = SECTION): string;
var
  LConfigName: string;
begin
  LConfigName := ChangeFileExt(aDeployConfigFileName, '.Deploy');
  with TIniFile.Create(LConfigName) do
    try
      if not ValueExists(aSection, aPropertie) then
        WriteString(aSection, aPropertie, aValue);

      Result := ReadString(aSection, aPropertie, aValue);
    finally
      UpdateFile;
      DisposeOf;
    end;
end;

procedure LoadConsoleInfoDefault(aConsoleInfo: TConsoleScreenBufferInfo);
begin
  if not LConsoleInfoLoaded then
    LConsoleInfo := aConsoleInfo;

  LConsoleInfoLoaded := true;
end;

procedure FontColorReset;
var
  ConsoleHandle: THandle;
begin
  ConsoleHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  SetConsoleTextAttribute(ConsoleHandle, LConsoleInfo.wAttributes);
end;

procedure FontColor(Color: TConsoleFontColor);
var
  ConsoleHandle: THandle;
  ConsoleInfo  : TConsoleScreenBufferInfo;
begin
  ConsoleHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if GetConsoleScreenBufferInfo(ConsoleHandle, ConsoleInfo) then
  begin
    LoadConsoleInfoDefault(ConsoleInfo);
    ConsoleInfo.wAttributes := CONSOLE_COLOR[Color];
    SetConsoleTextAttribute(ConsoleHandle, ConsoleInfo.wAttributes);
  end;
end;

function ConsoleCodePage(wCodePageID: UINT = 65001): boolean;
begin
  Result := Winapi.Windows.SetConsoleOutputCP(wCodePageID) and
    Winapi.Windows.SetConsoleCP(wCodePageID);
end;

procedure ConsoleDebugString(lpOutputString: LPCWSTR);
begin
  Winapi.Windows.OutputDebugString(lpOutputString);
end;

function FileExists(aFilename: string): boolean;
begin
  Result := System.SysUtils.FileExists(aFilename);
end;

function RemoveDir(aDir: string): boolean;
begin
  Result := System.SysUtils.RemoveDir(aDir);
end;

function DeleteFile(aFilename: string): boolean;
begin
  Result := System.SysUtils.DeleteFile(aFilename);
end;

function ExtractFilePath(aFilename: string): string;
begin
  Result := System.SysUtils.ExtractFilePath(aFilename);
end;

function ExtractFileName(const aFilename: string): string;
begin
  Result := System.SysUtils.ExtractFileName(aFilename);
end;

function ExtractFileExt(const aFilename: string): string;
begin
  Result := System.SysUtils.ExtractFileExt(aFilename);
end;

function ChangeFileExt(const FileName, Extension: string): string;
begin
  Result := System.SysUtils.ChangeFileExt(FileName, Extension);
end;

function UpperCase(const aValue: string): string;
begin
  Result := System.SysUtils.UpperCase(aValue);
end;

function AppNameAtLastNodeFolder: string;
var
  LParts: TArray<string>;
begin
  Result := System.SysUtils.ExtractFilePath(ParamStr(0));
  if not DirectoryExists(Result) then
    exit(ExtractFileName(ParamStr(0)));

  LParts := Result.Split([PathDelim]);
  Result := LParts[Length(LParts) - 1];

  if not FileExists(System.SysUtils.ExtractFilePath(ParamStr(0)) + Result + '.EXE') then
    Result := ChangeFileExt(ExtractFileName(ParamStr(0)), EmptyStr);
end;

function DateTimeFromFile(aFilename: string): TDateTime;
begin
  if not FileAge(aFilename, Result) then
    Result := 0;
end;

function YearDateFromFile(aFilename: string): string;
var
  LProgramBuildDateTime: TDateTime;
begin
  if FileAge(aFilename, LProgramBuildDateTime) then
    Result := YearOf(LProgramBuildDateTime).ToString;
end;

procedure DeleteFiles(aFilename: string; aExtensions: TArray<string>);
var
  LFileName  : PWideChar;
  LExtension : string;
  LExtensions: TArray<string>;
begin
  try
    if Length(aExtensions) > 0 then
    begin
      SetLength(LExtensions, Length(aExtensions));
      LExtensions := aExtensions;
      exit;
    end;

    SetLength(LExtensions, 6);
    LExtensions := ['upx', '000', '001', 'drc', 'exe.bak', 'ex~'];
  finally
    for LExtension in LExtensions do
    begin
      LFileName := PWideChar(ChangeFileExt(aFilename,
        IFThen(LExtension[1] = '.', '', '.') + LExtension));
      if FileExists(LFileName) then
        try
          TFile.Delete(LFileName);
        except
          on E: Exception do
        end;
      // AwaitCommand('rm -Rf', LFileName);
    end;
  end;
end;

procedure Br(aRepeat: UInt8 = 1);
begin
  repeat
    System.Writeln(EmptyStr);
    dec(aRepeat);
  until (aRepeat <= 0);
end;

procedure die(const aError: string);
begin
  echo(aError, ccRed);
  echo('Pressione a tecla ENTER para sair');
  ReadLn;
  Abort;
end;

procedure echo(const aText: string; aColor: TConsoleFontColor = ccDefault);
var
  LText: string;
begin
  LText := aText;

  if aColor = ccDefault then
  begin
    FontColorReset;
    System.Writeln(' ' + LText);
    exit;
  end;

  FontColor(aColor);
  System.Writeln(' ' + LText);
  FontColorReset;
end;

procedure head(aColor: TConsoleFontColor);
begin
  echo(' ┌─────────────┬────────┬──────────────────────┬───────────────────────────────┐',
    aColor);
  echo(' │ Deploy v0.0 │ 00bits │ Copyright© 1995-0000 │ Luis Nt, https://app.qbits.pl │'.
    Replace('0000', ServiceConsole.YEAR).Replace('00', APP_BITS).Replace('0.0',
    VER), aColor);
  echo(' ├─────────────┴────────┴──────────────────────┴───────────────────────────────┤',
    aColor);
end;

function LineCount(aValue: string; aLineSize: integer): integer;
begin
  Result := aValue.Length div aLineSize;
  if (aValue.Length mod aLineSize) <> 0 then
    Inc(Result);
end;

function SplitError(aValue: string; aLineSize: integer; aMarker: string = ' • ')
  : TArray<string>;
var
  LIndex     : integer;
  LLineCount : integer;
  LLineSize  : integer;
  LSep, LSep2: string;
begin
  LLineSize  := aLineSize - aMarker.Length;
  LLineCount := LineCount(aValue, LLineSize);
  SetLength(Result, LLineCount);

  LSep := aMarker;

  LSep2 := EmptyStr;
  if LSep.Length > 0 then
    LSep2 := string('').PadLeft(aMarker.Length, ' ');

  for LIndex := 0 to Pred(LLineCount) do
  begin
    Result[LIndex] := LSep + Copy(aValue, LIndex * LLineSize, LLineSize)
      .PadRight(LLineSize, ' ');
    LSep := LSep2;
  end;
end;

procedure line(aValue: string; aColor: TConsoleFontColor; aMarker: string = '');
const
  LINE_SPACE =
    'L00000000000000000000000000000000000000000000000000000000000000000000000000';
var
  LValue: string;
begin
  for LValue in SplitError(aValue, LINE_SPACE.Length, aMarker) do
    echo(' │ ' + LINE_SPACE.Replace(LINE_SPACE, LValue) + ' │', aColor);
end;

procedure rowo(aColor: TConsoleFontColor);
const
  LINE_DATA =
    ' ┌─────────────────────────────────────────────────────────────────────────────┐';
begin
  echo(LINE_DATA, aColor);
end;

procedure rows(aColor: TConsoleFontColor);
const
  LINE_DATA =
    ' ├─────────────────────────────────────────────────────────────────────────────┤';
begin
  echo(LINE_DATA, aColor);
end;

procedure rowc(aColor: TConsoleFontColor);
begin
  echo(' └─────────────────────────────────────────────────────────────────────────────┘',
    aColor);
end;

procedure rowe(aColor: TConsoleFontColor);
begin
  rows(aColor);
  echo(' │                                                       Press ENTER to close! │',
    aColor);
  rowc(aColor);
  ReadLn;
end;

procedure AwaitCommand(aCommand: string; aParameters: string);
const
  ERROR_COMUNICATION: string   = 'Erro ao criar pipe de comunicação';
  ERROR_MAKING_PROCESS: string = 'Erro ao criar processo';
  ReadBuffer                   = 1024;
var
  LSecurityAttr         : TSecurityAttributes;
  LReadPipe, LWritePipe : THandle;
  LStartupInfo          : TStartupInfo;
  LProcessInfo          : TProcessInformation;
  LBuffer               : PAnsiChar;
  LBytesRead, LBytesLeft: DWORD;
  LAppRunning           : BOOL;
begin
  LSecurityAttr.nLength              := SizeOf(TSecurityAttributes);
  LSecurityAttr.bInheritHandle       := true;
  LSecurityAttr.lpSecurityDescriptor := nil;
  if not CreatePipe(LReadPipe, LWritePipe, @LSecurityAttr, 0) then
    raise Exception.Create(ERROR_COMUNICATION);

  try
    LBuffer := AllocMem(ReadBuffer + 1);
    FillChar(LStartupInfo, SizeOf(TStartupInfo), 0);
    LStartupInfo.cb          := SizeOf(TStartupInfo);
    LStartupInfo.hStdInput   := LReadPipe;
    LStartupInfo.hStdOutput  := GetStdHandle(STD_OUTPUT_HANDLE);
    LStartupInfo.hStdError   := GetStdHandle(STD_ERROR_HANDLE);
    LStartupInfo.dwFlags     := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    LStartupInfo.wShowWindow := SW_HIDE;

    if not CreateProcess(nil, PChar(aCommand + ' ' + aParameters), nil, nil,
      true, 0, nil, nil, LStartupInfo, LProcessInfo) then
      raise Exception.Create(ERROR_MAKING_PROCESS + #10 + aCommand + ' ' +
        aParameters);

    CloseHandle(LReadPipe);
    // LAppRunning := True;

    repeat
      LBytesLeft := 0;
      PeekNamedPipe(LWritePipe, nil, 0, nil, @LBytesRead, @LBytesLeft);
      if LBytesRead > 0 then
      begin
        ZeroMemory(LBuffer, ReadBuffer + 1);
        if not string(LBuffer).IsEmpty then
          echo(string(LBuffer));
        ReadFile(LWritePipe, LBuffer, LBytesRead, LBytesRead, nil);
      end;
      LAppRunning := WaitForSingleObject(LProcessInfo.hProcess, 100)
        = WAIT_TIMEOUT;
    until not LAppRunning;

    ZeroMemory(LBuffer, ReadBuffer + 1);
    repeat
      LBytesLeft := 0;
      PeekNamedPipe(LWritePipe, nil, 0, nil, @LBytesRead, @LBytesLeft);
      if LBytesRead > 0 then
      begin
        if not string(LBuffer).IsEmpty then
          echo(string(LBuffer));
        ReadFile(LWritePipe, LBuffer, LBytesRead, LBytesRead, nil);
      end;
    until LBytesRead = 0;
  finally
    FreeMem(LBuffer);
    CloseHandle(LWritePipe);
    CloseHandle(LProcessInfo.hProcess);
    CloseHandle(LProcessInfo.hThread);
  end;
end;

procedure AwaitShellExecute(const aFilename: string);
var
  Info: TShellExecuteInfo;
begin
  ZeroMemory(@Info, SizeOf(Info));
  Info.cbSize       := SizeOf(Info);
  Info.fMask        := SEE_MASK_NOCLOSEPROCESS;
  Info.lpVerb       := 'open';
  Info.lpFile       := PChar(aFilename);
  Info.lpParameters := PChar('');
  Info.nShow        := SW_HIDE;

  if ShellExecuteEx(@Info) then
  begin
    WaitForSingleObject(Info.hProcess, INFINITE);
    CloseHandle(Info.hProcess);
  end;
end;

initialization

begin
  ServiceConsole.YEAR := YearDateFromFile(ParamStr(0));
  LConsoleInfoLoaded  := false;
end;

finalization


end.
