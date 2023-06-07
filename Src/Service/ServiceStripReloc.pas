unit ServiceStripReloc;

interface

uses
  Windows, Classes, SysUtils, IOUtils;

type
  iStripRelocExecute      = interface;
  iStripRelocResult       = interface;
  iStripRelocResultValues = interface;

  iStripReloc = interface
    ['{A2427540-B167-4DAD-851C-ADFCA6BF894F}']
    function Filename: string; overload;
    function Filename(aValue: string): iStripRelocExecute; overload;
  end;

  iStripRelocExecute = interface
    ['{727A85CF-A309-4003-85BA-C66AE19AC47F}']
    function Bits: string;
    function Execute: iStripRelocResult;
  end;

  iStripRelocResult = interface
    ['{D1FCCB6F-4C13-4563-B3B5-402BBC15EB9E}']
    function Values: iStripRelocResultValues;
    function Error: string;
  end;

  iStripRelocResultValues = interface
    ['{DDC5A497-98BD-4B95-8F0E-0B9488166E6B}']
    function Before: Cardinal;
    function After: Cardinal;
    function Difference: Cardinal;
  end;

type
  TStripReloc = class(TInterfacedObject, iStripReloc, iStripRelocExecute, iStripRelocResult, iStripRelocResultValues)
    constructor Create;
    destructor Destroy; override;
  strict private
  type
    TBits = (x32, x64);
  private
    FFilename: string;
    FBits    : TBits;

    FBefore    : Cardinal;
    FAfter     : Cardinal;
    FDifference: Cardinal;

    FError: string;

    FKeepBackups      : boolean;
    FWantValidChecksum: boolean;
    FForceStrip       : boolean;

    function CalcChecksum(const aFileHandle: THandle; aBits: TBits): DWORD;

    procedure Strip;

  public
    { iStripReloc }
    function Filename: string; overload;
    function Filename(aValue: string): iStripRelocExecute; overload;

    { iStripRelocExecute }
    function Bits: string;
    function Execute: iStripRelocResult;

    { iStripRelocResult }

    function Values: iStripRelocResultValues;
    function Error: string;

    { iStripRelocResultValues }
    function Before: Cardinal;
    function After: Cardinal;
    function Difference: Cardinal;
  end;

function StripReloc: iStripReloc;

implementation

const
  Version = {$IFDEF WIN32} '1.13 32 bits' {$ELSE} '1.13 64 bits' {$ENDIF};

var

  CheckSumMappedFile: function(BaseAddress: Pointer; FileLength: DWORD; var HeaderSum: DWORD; var CheckSum: DWORD): PImageNtHeaders; stdcall;

function StripReloc: iStripReloc;
begin
  Result := TStripReloc.Create;
end;

{ TStripReloc }

constructor TStripReloc.Create;
begin
  FKeepBackups       := true;
  FWantValidChecksum := False;
  FForceStrip        := False;
  FError             := EmptyStr;
end;

destructor TStripReloc.Destroy;
begin

  inherited;
end;

function TStripReloc.CalcChecksum(const aFileHandle: THandle; aBits: TBits): DWORD;
var
  Size    : DWORD;
  H       : THandle;
  M       : Pointer;
  OldSum  : DWORD;
  CheckSum: Cardinal;
begin
  Size := GetFileSize(aFileHandle, nil);
  H    := CreateFileMapping(aFileHandle, nil, PAGE_READONLY, 0, Size, nil);
  if H = 0 then
    RaiseLastOSError;
  try
    M := MapViewOfFile(H, FILE_MAP_READ, 0, 0, Size);
    if M = nil then
      RaiseLastOSError;
    try
      if CheckSumMappedFile(M, Size, OldSum, CheckSum) = nil then
        RaiseLastOSError;
      Result := DWORD(CheckSum);
    finally
      UnmapViewOfFile(M);
    end;
  finally
    CloseHandle(H);
  end;
end;

function TStripReloc.Bits: string;
begin
  case FBits of
    x32:
      Exit('32');
    x64:
      Exit('64');
  end;
  Result := '00';
end;

procedure TStripReloc.Strip;
type
  PPESectionHeaderArray = ^TPESectionHeaderArray;
  TPESectionHeaderArray = array [0 .. $7FFFFFFF div sizeof(TImageSectionHeader) - 1] of TImageSectionHeader;
var
  LFilename            : String;
  BackupFilename       : String;
  F, F2                : File;
  EXESig               : Word;
  PEHeaderOffset, PESig: Cardinal;
  PEHeader             : TImageFileHeader;

  PEOptHeader32: TImageOptionalHeader32;
  PEOptHeader64: TImageOptionalHeader64;

  PESectionHeaders: PPESectionHeaderArray;
  BytesLeft, Bytes: Cardinal;
  Buf             : array [0 .. 8191] of Byte;
  I               : Integer;
  RelocVirtualAddr: Cardinal;
  RelocPhysOffset : Cardinal;
  RelocPhysSize   : Cardinal;
  OldSize, NewSize: Cardinal;
  TimeStamp       : TFileTime;
begin
  FBefore          := 0;
  FAfter           := 0;
  FDifference      := 0;
  FError           := EmptyStr;
  PESectionHeaders := nil;
  LFilename        := Filename;
  try
    RelocPhysOffset := 0;
    RelocPhysSize   := 0;
    BackupFilename  := LFilename + '.bak';

    AssignFile(F, LFilename);
    FileMode := fmOpenRead or fmShareDenyWrite;
    Reset(F, 1);
    try
      OldSize := FileSize(F);
      GetFileTime(TFileRec(F).Handle, nil, nil, @TimeStamp);

      BlockRead(F, EXESig, sizeof(EXESig));
      if EXESig <> $5A4D { 'MZ' } then
      begin
        FError := 'File isn''t an EXE file (1).';
        Exit;
      end;
      Seek(F, $3C);
      BlockRead(F, PEHeaderOffset, sizeof(PEHeaderOffset));
      if PEHeaderOffset = 0 then
      begin
        FError := 'File isn''t a PE file (1).';
        Exit;
      end;
      Seek(F, PEHeaderOffset);
      BlockRead(F, PESig, sizeof(PESig));
      if PESig <> $00004550 { 'PE'#0#0 } then
      begin
        FError := 'File isn''t a PE file (2).';
        Exit;
      end;
      BlockRead(F, PEHeader, sizeof(PEHeader));
      if not FForceStrip and (PEHeader.Characteristics and IMAGE_FILE_DLL <> 0) then
      begin
        FError := 'Skipping; can''t strip a DLL.';
        Exit;
      end;
      if PEHeader.Characteristics and IMAGE_FILE_RELOCS_STRIPPED <> 0 then
      begin
        FError := 'Relocations already stripped from file (1).';
        Exit;
      end;
      PEHeader.Characteristics := PEHeader.Characteristics or IMAGE_FILE_RELOCS_STRIPPED;

      case FBits of
        x32:
          begin
            if PEHeader.SizeOfOptionalHeader <> sizeof(PEOptHeader32) then
            begin
              FError := 'File isn''t a 32-bit image (1).';
              Exit;
            end;

            BlockRead(F, PEOptHeader32, sizeof(PEOptHeader32));

            if (PEOptHeader32.Magic <> IMAGE_NT_OPTIONAL_HDR32_MAGIC) then
            begin
              FError := 'File isn''t a valid 32-bit image (2).';
              Exit;
            end;
            if (PEOptHeader32.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress = 0) or (PEOptHeader32.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size = 0) then
            begin
              FError := 'Relocations already stripped from file (2).';
              Exit;
            end;
            RelocVirtualAddr := PEOptHeader32.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress;
            PEOptHeader32.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress := 0;
            PEOptHeader32.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size := 0;
            if not FWantValidChecksum then
              PEOptHeader32.CheckSum := 0;
          end;
      else
        begin
          if PEHeader.SizeOfOptionalHeader <> sizeof(PEOptHeader64) then
          begin
            FError := 'File isn''t a 64-bit image (1).';
            Exit;
          end;

          BlockRead(F, PEOptHeader64, sizeof(PEOptHeader64));

          if (PEOptHeader64.Magic <> IMAGE_NT_OPTIONAL_HDR64_MAGIC) then
          begin
            FError := 'File isn''t a valid 64-bit image (2).';
            Exit;
          end;
          if (PEOptHeader64.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress = 0) or (PEOptHeader64.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size = 0) then
          begin
            FError := 'Relocations already stripped from file (2).';
            Exit;
          end;
          RelocVirtualAddr := PEOptHeader64.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress;
          PEOptHeader64.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress := 0;
          PEOptHeader64.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size := 0;
          if not FWantValidChecksum then
            PEOptHeader64.CheckSum := 0;
        end;
      end;

      GetMem(PESectionHeaders, PEHeader.NumberOfSections * sizeof(TImageSectionHeader));
      BlockRead(F, PESectionHeaders^, PEHeader.NumberOfSections * sizeof(TImageSectionHeader));
      for I := 0 to PEHeader.NumberOfSections - 1 do
        with PESectionHeaders[I] do
          if (VirtualAddress = RelocVirtualAddr) and (SizeOfRawData <> 0) then
          begin
            RelocPhysOffset := PointerToRawData;
            RelocPhysSize   := SizeOfRawData;
            SizeOfRawData   := 0;
            Break;
          end;
      if RelocPhysOffset = 0 then
      begin
        FError := 'Relocations already stripped from file (3).';
        Exit;
      end;
      if RelocPhysSize = 0 then
      begin
        FError := 'Relocations already stripped from file (4).';
        Exit;
      end;
      for I := 0 to PEHeader.NumberOfSections - 1 do
        with PESectionHeaders[I] do
        begin
          if PointerToRawData > RelocPhysOffset then
            Dec(PointerToRawData, RelocPhysSize);
          if PointerToLinenumbers > RelocPhysOffset then
            Dec(PointerToLinenumbers, RelocPhysSize);
          if PointerToRelocations <> 0 then
          begin
            { ^ I don't think this field is ever used in the PE format. StripRlc doesn't handle it. }
            FError := 'Cannot handle this file (1).';
            Exit;
          end;
        end;

      case FBits of
        x32:
          if PEOptHeader32.ImageBase < $400000 then
          begin
            FError := 'Cannot handle this file -- the image base address is less than 0x400000.';
            Exit;
          end;
      else
        if PEOptHeader64.ImageBase < $400000 then
        begin
          FError := 'Cannot handle this file -- the image base address is less than 0x400000.';
          Exit;
        end;
      end;

    finally
      CloseFile(F);
    end;

    if TFile.Exists(BackupFilename) then
      TFile.Delete(BackupFilename);

    Rename(F, BackupFilename);
    try
      FileMode := fmOpenRead or fmShareDenyWrite;
      Reset(F, 1);
      try
        AssignFile(F2, LFilename);
        FileMode := fmOpenWrite or fmShareExclusive;
        Rewrite(F2, 1);
        try
          BytesLeft := RelocPhysOffset;
          while BytesLeft <> 0 do
          begin
            Bytes := BytesLeft;
            if Bytes > sizeof(Buf) then
              Bytes := sizeof(Buf);
            BlockRead(F, Buf, Bytes);
            BlockWrite(F2, Buf, Bytes);
            Dec(BytesLeft, Bytes);
          end;
          Seek(F, Cardinal(FilePos(F)) + RelocPhysSize);
          BytesLeft := FileSize(F) - FilePos(F);
          while BytesLeft <> 0 do
          begin
            Bytes := BytesLeft;
            if Bytes > sizeof(Buf) then
              Bytes := sizeof(Buf);
            BlockRead(F, Buf, Bytes);
            BlockWrite(F2, Buf, Bytes);
            Dec(BytesLeft, Bytes);
          end;
          Seek(F2, PEHeaderOffset + sizeof(PESig));
          BlockWrite(F2, PEHeader, sizeof(PEHeader));
          case FBits of
            x32:
              begin
                BlockWrite(F2, PEOptHeader32, sizeof(PEOptHeader32));
                BlockWrite(F2, PESectionHeaders^, PEHeader.NumberOfSections * sizeof(TImageSectionHeader));
                if FWantValidChecksum then
                begin
                  PEOptHeader32.CheckSum := CalcChecksum(TFileRec(F2).Handle, FBits);
                  { go back and rewrite opt. header with new checksum }
                  Seek(F2, PEHeaderOffset + sizeof(PESig) + sizeof(PEHeader));
                  BlockWrite(F2, PEOptHeader32, sizeof(PEOptHeader32));
                end;
              end;
            x64:
              begin
                BlockWrite(F2, PEOptHeader64, sizeof(PEOptHeader64));
                BlockWrite(F2, PESectionHeaders^, PEHeader.NumberOfSections * sizeof(TImageSectionHeader));
                if FWantValidChecksum then
                begin
                  PEOptHeader64.CheckSum := CalcChecksum(TFileRec(F2).Handle, FBits);
                  { go back and rewrite opt. header with new checksum }
                  Seek(F2, PEHeaderOffset + sizeof(PESig) + sizeof(PEHeader));
                  BlockWrite(F2, PEOptHeader64, sizeof(PEOptHeader64));
                end;
              end;
          end;

          NewSize := FileSize(F2);
          SetFileTime(TFileRec(F2).Handle, nil, nil, @TimeStamp);
        finally
          CloseFile(F2);
        end;
      finally
        CloseFile(F);
      end;
    except
      DeleteFile(LFilename);
      AssignFile(F, BackupFilename);
      Rename(F, LFilename);
      raise;
    end;

    FBefore     := OldSize;
    FAfter      := NewSize;
    FDifference := OldSize - NewSize;

    if not FKeepBackups then
      if not DeleteFile(BackupFilename) then
        FError := 'Warning: Couldn''t delete backup file ' + BackupFilename;
  finally
    FreeMem(PESectionHeaders);
  end;
end;

function TStripReloc.Filename(aValue: string): iStripRelocExecute;

  procedure setBits(const aFilename: string);
  var
    LSignatureOffset: Cardinal;
    LSignature      : Word;
  begin
    with TFileStream.Create(aFilename, fmOpenRead or fmShareDenyNone) do
      try
        Seek($3C, soBeginning);
        Read(LSignatureOffset, sizeof(LSignatureOffset));
        Seek(LSignatureOffset + $18, soBeginning);
        Read(LSignature, sizeof(LSignature));
        case LSignature of
          $010B:
            FBits := TBits.x32;
          $020B:
            FBits := TBits.x64;
        else
          RaiseLastOSError;
        end;
      finally
        Free;
      end;
  end;

begin
  FFilename := aValue;
  if FileExists(FFilename) then
    setBits(FFilename);

  FBefore     := 0;
  FAfter      := 0;
  FDifference := 0;
  FError      := EmptyStr;
  Result      := Self;
end;

function TStripReloc.Execute: iStripRelocResult;
begin
  Result := Self;
  try
    Strip;
  except
    on E: Exception do
    begin
      FError := E.Message;
    end;
  end;
end;

function TStripReloc.Filename: string;
begin
  Result := FFilename;
end;

function TStripReloc.Values: iStripRelocResultValues;
begin
  Result := Self;
end;

function TStripReloc.After: Cardinal;
begin
  Result := FAfter;
end;

function TStripReloc.Before: Cardinal;
begin
  Result := FBefore;
end;

function TStripReloc.Difference: Cardinal;
begin
  Result := FDifference;
end;

function TStripReloc.Error: string;
begin
  Result := FError;
end;

end.
