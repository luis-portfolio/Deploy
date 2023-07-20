unit ServiceAssociation;

interface

uses
   Winapi.Windows, Winapi.ShlObj, Winapi.ShellAPI,
   System.Hash, System.Classes, System.SysUtils, System.Win.Registry
     ;

type
   iAssociation            = interface;
   iAssociationExtension   = interface;
   iAssociationActions     = interface;
   iAssociationFileType    = interface;
   iAssociationDescription = interface;
   iAssociationIcoName     = interface;
   iAssociationIcoIndex    = interface;

   iAssociationActions = interface
      ['{C9B6F8E5-0F7D-4E4C-8C0E-9F1A0B7B2E9C}']
      function isAssociate: boolean;

      function Associate: boolean;
      function Disassociate: boolean;
   end;

   iAssociation = interface
      ['{DE6A93DB-6E48-40D4-9E52-FC6E5489DA55}']
      function ExeName(const Value: string): iAssociationExtension;
   end;

   iAssociationExtension = interface
      ['{B9B6F8E5-0F7D-4E4C-8C0E-9F1A0B7B2E9B}']
      function Extension(const Value: string): iAssociationFileType;
   end;

   iAssociationFileType = interface(iAssociationActions)
      ['{D71090A1-B489-4342-9E8D-9D41D22E6706}']
      function FileType(const Value: string): iAssociationDescription;
   end;

   iAssociationDescription = interface(iAssociationActions)
      ['{F9055329-4384-4DA7-BDE1-BF46B508056F}']
      function Description(const Value: string): iAssociationIcoName;
   end;

   iAssociationIcoName = interface(iAssociationActions)
      ['{3074D590-DFD7-4935-A3CF-6805614DBDFE}']
      function IcoName(const Value: string): iAssociationIcoIndex;
   end;

   iAssociationIcoIndex = interface
      ['{0EFEFE32-02FC-4C40-BD14-F94D572B4D1A}']
      function IcoIndex(const Value: integer): iAssociationActions;
   end;

type
   TAssociation = class(TInterfacedObject, iAssociation, iAssociationExtension, iAssociationFileType, iAssociationDescription, iAssociationIcoName, iAssociationIcoIndex, iAssociationActions)
      constructor Create;
      destructor Destroy; override;
   strict private
      FExeName    : string;
      FExtension  : string;
      FFileType   : string;
      FDescription: string;
      FIcoName    : string;
      FIcoIndex   : integer;

   private
      function CopyKey(const aSourceKey, aDestinationKey: string; aOverwrite: boolean): boolean;
      function Backup: boolean;
      function Restore: boolean;
   public
      { iAssociation }
      function ExeName(const Value: string): iAssociationExtension;

      { iAssociationExtension }
      function Extension(const Value: string): iAssociationFileType;

      { iAssociationFileType }
      function FileType(const Value: string): iAssociationDescription;

      { iAssociationDescription }
      function Description(const Value: string): iAssociationIcoName;

      { iAssociationIcoName }
      function IcoName(const Value: string): iAssociationIcoIndex;

      { iAssociationIcoIndex }
      function IcoIndex(const Value: integer): iAssociationActions;

      { iAssociationActions }
      function isAssociate: boolean;
      function Associate: boolean;
      function Disassociate: boolean;
   end;

function Association: iAssociation;

implementation

function Association: iAssociation;
begin
   Result := TAssociation.Create;
end;

{ TAssociation }

constructor TAssociation.Create;
begin
   FExeName     := ParamStr(0);
   FExtension   := ChangeFileExt(ExtractFileName(ParamStr(0)), EmptyStr);
   FFileType    := FExtension + 'File';
   FDescription := ' Description generics of ' + FExtension;
   FIcoName     := ParamStr(0);
   FIcoIndex    := 0;
end;

destructor TAssociation.Destroy;
begin

   inherited;
end;

function TAssociation.ExeName(const Value: string): iAssociationExtension;
begin
   FExeName := Value;
   Result   := Self;
end;

function TAssociation.Extension(const Value: string): iAssociationFileType;
begin
   FExtension := Value;
   Result     := Self;
end;

function TAssociation.FileType(const Value: string): iAssociationDescription;
begin
   FFileType := Value;
   Result    := Self;
end;

function TAssociation.Description(const Value: string): iAssociationIcoName;
begin
   FDescription := Value;
   Result       := Self;
end;

function TAssociation.IcoName(const Value: string): iAssociationIcoIndex;
begin
   FIcoName := Value;
   Result   := Self;
end;

function TAssociation.IcoIndex(const Value: integer): iAssociationActions;
begin
   FIcoIndex := Value;
   Result    := Self;
end;

function TAssociation.isAssociate: boolean;
var
   LBackupKey: String;
begin
   with TRegistry.Create do
      try
         RootKey := HKEY_CURRENT_USER;
         if not OpenKeyReadOnly('\Software\Classes\' + FExtension) then
            Exit(False);

         LBackupKey := ReadString('') + '_Backup';
         CloseKey;

         if not KeyExists('\Software\Classes\' + LBackupKey) then
            Exit(False);

         if not OpenKeyReadOnly('\Software\Classes\' + LBackupKey) then
            Exit(False);

         if ReadString('') <> FFileType then
            Exit(False);

         CloseKey;

         if not OpenKeyReadOnly('\Software\Classes\' + FFileType) then
            Exit(False);

         if ReadString('') <> FDescription then
            Exit(False);

         CloseKey;

         if not OpenKeyReadOnly('\Software\Classes\' + FFileType + '\DefaultIcon') then
            Exit(False);

         if ReadString('') <> FIcoName + ',' + IntToStr(FIcoIndex) then
            Exit(False);

         CloseKey;

         if not OpenKeyReadOnly('\Software\Classes\' + FFileType + '\Shell\Open\Command') then
            Exit(False);

         if ReadString('') <> '"' + FExeName + '" "%1"' then
            Exit(False);

         CloseKey;

         Exit(True);
      finally
         Free;
      end;
end;

function TAssociation.CopyKey(const aSourceKey, aDestinationKey: string; aOverwrite: boolean): boolean;
var
   LSourceRegistry      : TRegistry;
   LDestinationRegistry : TRegistry;
   LSourceKeyExists     : boolean;
   LDestinationKeyExists: boolean;
   LValueNames          : TStringList;
   LIndex               : integer;
   LValueName           : string;
   LValueType           : TRegDataType;
   LValueData           : array of Byte;
   LValueSize           : integer;
begin
   Result := False;

   LSourceRegistry      := TRegistry.Create;
   LDestinationRegistry := TRegistry.Create;
   LValueNames          := TStringList.Create;
   try
      LSourceRegistry.RootKey      := HKEY_CURRENT_USER;
      LDestinationRegistry.RootKey := HKEY_CURRENT_USER;

      LSourceKeyExists      := LSourceRegistry.KeyExists(aSourceKey);
      LDestinationKeyExists := LDestinationRegistry.KeyExists(aDestinationKey);

      if not LSourceKeyExists then
         Exit;

      if LDestinationKeyExists and not aOverwrite then
         Exit;

      if not LDestinationRegistry.OpenKey(aDestinationKey, True) then
         Exit;

      if not LSourceRegistry.OpenKeyReadOnly(aSourceKey) then
         Exit;

      LSourceRegistry.GetValueNames(LValueNames);

      for LIndex := 0 to LValueNames.Count - 1 do
      begin
         LValueName := LValueNames[LIndex];
         LValueType := LSourceRegistry.GetDataType(LValueName);

         case LValueType of
            rdString, rdExpandString:
               begin
                  LDestinationRegistry.WriteString(LValueName, LSourceRegistry.ReadString(LValueName));
               end;
            rdInteger:
               begin
                  LDestinationRegistry.WriteInteger(LValueName, LSourceRegistry.ReadInteger(LValueName));
               end;
            rdBinary:
               begin
                  LValueSize := LSourceRegistry.GetDataSize(LValueName);
                  SetLength(LValueData, LValueSize);
                  LSourceRegistry.ReadBinaryData(LValueName, LValueData[0], LValueSize);
                  LDestinationRegistry.WriteBinaryData(LValueName, LValueData[0], LValueSize);
               end;
         end;
      end;

      Result := True;
   finally
      LSourceRegistry.Free;
      LDestinationRegistry.Free;
      LValueNames.Free;
   end;
end;

function TAssociation.Backup: boolean;
var
   LBackupKey: string;
begin
   if not isAssociate then
      Exit(True);

   With TRegistry.Create do
      try
         RootKey := HKEY_CURRENT_USER;
         if not OpenKeyReadOnly('\Software\Classes\' + FExtension) then
            Exit(False);

         LBackupKey := ReadString('') + '_Backup';
         CloseKey;

         if KeyExists('\Software\Classes\' + LBackupKey) then
            Exit(True);

         CopyKey('\Software\Classes\' + FExtension, '\Software\Classes\' + LBackupKey, True);
         Exit(True);
      finally
         Free;
      end;
end;

function TAssociation.Restore: boolean;
var
   LBackupKey: string;
begin
   if not isAssociate then
      Exit(False);

   with TRegistry.Create do
      try
         RootKey := HKEY_CURRENT_USER;
         if not OpenKeyReadOnly('\Software\Classes\' + FExtension) then
            Exit(False);

         LBackupKey := ReadString(FExtension) + '_Backup';
         CloseKey;

         if not KeyExists('\Software\Classes\' + LBackupKey) then
            Exit(False);

         if not DeleteKey('\Software\Classes\' + FExtension) then
            Exit(False);

         if not CopyKey('\Software\Classes\' + LBackupKey, '\Software\Classes\' + FExtension, True) then
            Exit(False);

         if not DeleteKey('\Software\Classes\' + LBackupKey) then
            Exit(False);

         Exit(True);
      finally
         Free;
      end;
end;

function TAssociation.Associate: boolean;
begin
   if isAssociate then
      Exit(True);

   if not Backup then
      Exit(False);

   with TRegistry.Create do
      try
         RootKey := HKEY_CURRENT_USER;

         if not OpenKey('\Software\Classes\' + FExtension, True) then
            Exit(False);

         WriteString('', FFileType);
         CloseKey;
         if not OpenKey('\Software\Classes\' + FFileType, True) then
            Exit(False);

         WriteString('', FDescription);
         CloseKey;
         if not OpenKey('\Software\Classes\' + FFileType + '\DefaultIcon', True) then
            Exit(False);

         WriteString('', FIcoName + ',' + IntToStr(FIcoIndex));
         CloseKey;
         if not OpenKey('\Software\Classes\' + FFileType + '\Shell\Open\Command', True) then
            Exit(False);

         WriteString('', '"' + FExeName + '" "%1"');
         CloseKey;
         Exit(True);
      finally
         Free;
      end;
end;

function TAssociation.Disassociate: boolean;

begin
   if not isAssociate then
      Exit(True);

   if not Restore then
      Exit(False);

   Result := True;
end;

function RegisterDeployProgram: boolean;
var
   LReg: TRegistry;
begin
   LReg := TRegistry.Create;
   try
      LReg.RootKey := HKEY_CLASSES_ROOT;

      if not LReg.OpenKey('\exefile', True) then
         Exit(False);

      if not LReg.OpenKey('\exefile\shell', True) then
         Exit(False);

      if not LReg.OpenKey('\exefile\shell\New Deploy File', True) then
         Exit(False);

      if not LReg.OpenKey('\exefile\shell\New Deploy File\command', True) then
         Exit(False);

      LReg.WriteString('', '"' + ParamStr(0) + '" "%1" ');

      if LReg.OpenKey('\exefile\shell\New Deploy File\Icon', True) then
         LReg.WriteString('', ParamStr(0));

      Result := True;

   finally
      LReg.Free;
   end;
end;

initialization

// To enable the functionality to create .deploy files in the context menu of executable files in windows,
// the Deploy.exe program must be executed with privileges for this or this functionality will be ignored.

RegisterDeployProgram;

end.
