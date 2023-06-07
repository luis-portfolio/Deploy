unit ServiceExtract;

interface

uses
  System.Classes, System.SysUtils, System.Types;

type
  iExtractFileName = interface;
  iExtractSave     = interface;

  iExtract = interface
    ['{8F3A8AB4-6988-413C-9915-528834CF6F30}']
    function Exists(aIdentifier: string): boolean;
    function Resource(aIdentifier: string): iExtractFileName;
  end;

  iExtractFileName = interface
    ['{CA59FA3F-FB75-45F9-A91E-2F94828D7BF1}']
    function FileName(aValue: string): iExtractSave;
  end;

  iExtractSave = interface
    ['{D580BAC9-B1D4-4BBF-B8F1-706B7EC7EC71}']
    function Save(aOverride: boolean = false): boolean;
  end;

type
  TExtract = class(TInterfacedObject, iExtract, iExtractFileName, iExtractSave)
    constructor Create;
    destructor Destroy; override;
  strict private
    FResource: string;
    FError   : string;
    FFilename: string;

  private
    { iExtract }
    function Exists(aIdentifier: string): boolean;
    function Resource(aIdentifier: string): iExtractFileName;

    { iExtractFileName }
    function FileName(aValue: string): iExtractSave;

    { iExtractSave }
    function Save(aOverride: boolean = false): boolean;
  public

  end;

function Extract: iExtract;

implementation

const
  RESOURCE_FILE_HAS_EXISTS_USER             = 'Arquivo já existe na pasta de fontes do usuário.';
  RESOURCE_FILE_HAS_EXISTS_WINDOWS          = 'Arquivo já existe na pasta de fontes do windows.';
  RESOURCE_FILE_HAS_EXISTS_APP              = 'Arquivo já existe na pasta do usuário.';
  RESOURCE_FILE_HAS_EXISTS                  = 'Arquivo já existe! E não foi sobrescrito.';
  RESOURCE_DENY_PERMISSION_TO_CREATE_FOLTER = 'Permissão negada ao tentar criar a pasta ';
  RESOURCE_DENY_PERMISSION_TO_CREATE_FILE   = 'Permissão negada ao tentar criar o arquivo ';
  RESOURCE_IDENTIFY_NOT_EMPTY               = 'O Identificador do recurso não foi informado.';
  RESOURCE_IDENTIFY_NOT_FOUND               = 'O Identificador %s não foi encontrado nos recursos da applicação.';

function Extract: iExtract;
begin
  Result := TExtract.Create;
end;

constructor TExtract.Create;
begin

end;

destructor TExtract.Destroy;
begin

  inherited;
end;

function TExtract.Exists(aIdentifier: string): boolean;
begin
  if SameStr(aIdentifier, EmptyStr) then
  begin
    FError := RESOURCE_IDENTIFY_NOT_EMPTY;
    Exit(false);
  end;

  if not(FindResource(hInstance, PChar(aIdentifier), RT_RCDATA) <> 0) then
  begin
    FError := Format(RESOURCE_IDENTIFY_NOT_FOUND, [aIdentifier]);
    Exit(false);
  end;

  Result := true;
end;

function TExtract.Resource(aIdentifier: string): iExtractFileName;
begin
  FResource := aIdentifier;
  Result    := Self;
end;

function TExtract.FileName(aValue: string): iExtractSave;
var
  LFilePath: string;
begin
  if not Exists(FResource) then
    Exit(Self);

  FFilename := aValue;

  LFilePath := ExtractFilePath(aValue);
  if not ForceDirectories(LFilePath) then
  begin
    FError := RESOURCE_DENY_PERMISSION_TO_CREATE_FOLTER + LFilePath;
    Exit(Self);
  end;

  Result := Self;
end;

function TExtract.Save(aOverride: boolean = false): boolean;
begin
  if FileExists(FFilename) then
    if not aOverride then
      Exit(true);

  if not FError.IsEmpty then
    Exit(false);

  with TResourceStream.Create(hInstance, FResource, RT_RCDATA) do
    try
      try
        Position := 0;
        SaveToFile(FFilename);
        Exit(true);
      except
        on E: Exception do
        begin
          FError := RESOURCE_DENY_PERMISSION_TO_CREATE_FILE + #10 + FFilename;
          Exit(false);
        end;
      end;
    finally
      Free;
    end;
end;

end.
