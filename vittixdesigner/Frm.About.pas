unit Frm.About;

(*
  Frm.About - About dialog.

  Shows the product name, the version and build date read from the built
  executable's own version resource (so they cannot drift away from the binary
  that is actually running), the compiler/RTL and OS it is running on, and the
  executable path.

  "Copy Details" puts the same information on the clipboard as plain text, which
  is what a bug report normally needs.

  Reached from Help > About Vittix Report Designer.
*)

interface

uses
  System.Classes,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls,
  Vcl.Imaging.pngimage;

type
  TfrmAbout = class(TForm)
    imgLogo         : TImage;
    lblProduct      : TLabel;
    lblVersion      : TLabel;
    lblTagline      : TLabel;
    bevSep          : TBevel;
    lblKeyEngine    : TLabel;
    lblValEngine    : TLabel;
    lblKeyCompiler  : TLabel;
    lblValCompiler  : TLabel;
    lblKeyPlatform  : TLabel;
    lblValPlatform  : TLabel;
    lblKeyExecutable: TLabel;
    lblValExecutable: TLabel;
    lblCopyright    : TLabel;
    pnlButtons      : TPanel;
    btnCopyDetails  : TButton;
    btnClose        : TButton;

    procedure FormCreate(Sender: TObject);
    procedure btnCopyDetailsClick(Sender: TObject);

  private
    function LoadBrandLogo: Boolean;
    function EngineText: string;
    function CompilerText: string;
    function PlatformText: string;
    function VersionText: string;
    function BuildDateText: string;
    function DetailsText: string;
  end;

implementation

{$R *.dfm}

uses
  Winapi.Windows,
  System.SysUtils,
  System.DateUtils,
  Vcl.Clipbrd;

const
  { Resource name of the designer logo, embedded from \branding by
    branding\build_brand_assets.py. }
  BrandLogoResource = 'VITTIX_LOGO';

  { Space the logo column occupies on the left of the header. }
  LogoColumnWidth = 146;
  ProductName     = 'Vittix Report Designer';
  ProductTagline  = 'A Delphi VCL reporting engine with a visual designer, ' +
                    'live preview, printing and PDF / Excel export.';
  FallbackVersion = '1.0.0.0';
  Grey            = $00808080;

{ ================= Executable facts ================= }

{ Version straight out of the PE version resource, so it always matches the
  binary that is running rather than a constant that can go stale. }
function FileVersionText: string;
var
  Dummy: DWORD;
  Size : DWORD;
  Buf  : Pointer;
  Value: Pointer;
  Len  : UInt;
  Fixed: PVSFixedFileInfo;
begin
  Result := FallbackVersion;
  Size := GetFileVersionInfoSize(PChar(ParamStr(0)), Dummy);
  if Size = 0 then
    Exit;

  GetMem(Buf, Size);
  try
    if not GetFileVersionInfo(PChar(ParamStr(0)), 0, Size, Buf) then
      Exit;
    Len := 0;
    Value := nil;
    if not VerQueryValue(Buf, '\', Value, Len) then
      Exit;
    if (Value = nil) or (Len < SizeOf(TVSFixedFileInfo)) then
      Exit;

    Fixed := PVSFixedFileInfo(Value);
    Result := Format('%d.%d.%d.%d',
      [HiWord(Fixed.dwFileVersionMS), LoWord(Fixed.dwFileVersionMS),
       HiWord(Fixed.dwFileVersionLS), LoWord(Fixed.dwFileVersionLS)]);
  finally
    FreeMem(Buf);
  end;
end;

{ Last write stamp of the executable - i.e. when it was linked. }
function FileBuildDateText: string;
var
  H : THandle;
  FT: TFileTime;
  ST: TSystemTime;
begin
  Result := '';
  H := CreateFile(PChar(ParamStr(0)), GENERIC_READ, FILE_SHARE_READ, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if H = INVALID_HANDLE_VALUE then
    Exit;
  try
    if GetFileTime(H, nil, nil, @FT) and FileTimeToSystemTime(FT, ST) then
      Result := FormatDateTime('d mmm yyyy', SystemTimeToDateTime(ST));
  finally
    CloseHandle(H);
  end;
end;

{ ================= Form ================= }

procedure TfrmAbout.FormCreate(Sender: TObject);
begin
  Caption := 'About ' + ProductName;

  if not LoadBrandLogo then
  begin
    // No brand mark linked in: drop the slot and pull the title block left
    // rather than leaving a gap.
    imgLogo.Visible := False;
    lblProduct.Left := lblProduct.Left - LogoColumnWidth;
    lblVersion.Left := lblVersion.Left - LogoColumnWidth;
  end;

  lblProduct.Caption := ProductName;
  lblVersion.Caption := 'Version ' + VersionText;
  if BuildDateText <> '' then
    lblVersion.Caption := lblVersion.Caption + '  -  built ' + BuildDateText;

  lblTagline.Caption := ProductTagline;

  lblValEngine.Caption   := EngineText;
  lblValCompiler.Caption := CompilerText;
  lblValPlatform.Caption := PlatformText;
  lblValExecutable.Caption := ExpandFileName(ParamStr(0));
  lblValExecutable.Hint := lblValExecutable.Caption;

  lblCopyright.Caption := Format('Copyright (c) %d. All rights reserved.',
    [YearOf(Date)]);
end;

{ The designer logo ships as a wide transparent PNG in the module's resources.
  Using the logo rather than Application.Icon keeps the mark readable: the icon
  is a wide monogram and would be a speck at 32 px. }
function TfrmAbout.LoadBrandLogo: Boolean;
var
  Stream: TResourceStream;
  Png   : TPngImage;
begin
  Result := False;
  try
    Stream := TResourceStream.Create(HInstance, BrandLogoResource, RT_RCDATA);
  except
    Exit;   // not linked into this module
  end;
  try
    Png := TPngImage.Create;
    try
      Png.LoadFromStream(Stream);
      imgLogo.Picture.Assign(Png);
      Result := True;
    finally
      Png.Free;
    end;
  finally
    Stream.Free;
  end;
end;

function TfrmAbout.VersionText: string;
begin
  Result := FileVersionText;
end;

function TfrmAbout.BuildDateText: string;
begin
  Result := FileBuildDateText;
end;

function TfrmAbout.EngineText: string;
begin
  Result := 'VittixReport (VCL component library)';
end;

function TfrmAbout.CompilerText: string;
begin
  Result := Format('Delphi - RTL %.1f compiled', [RTLVersion]);
end;

function TfrmAbout.PlatformText: string;
begin
  Result := Format('%d-bit - Windows %d.%d (build %d)', [
    SizeOf(Pointer) * 8, TOSVersion.Major, TOSVersion.Minor, TOSVersion.Build]);
end;

function TfrmAbout.DetailsText: string;
var
  Built: string;
begin
  Built := BuildDateText;
  if Built <> '' then
    Built := ' (built ' + Built + ')'
  else
    Built := '';

  Result :=
    ProductName + sLineBreak +
    'Version ' + VersionText + Built + sLineBreak +
    sLineBreak +
    'Engine:      ' + EngineText + sLineBreak +
    'Compiler:    ' + CompilerText + sLineBreak +
    'Platform:    ' + PlatformText + sLineBreak +
    'Executable:  ' + ExpandFileName(ParamStr(0)) + sLineBreak;
end;

procedure TfrmAbout.btnCopyDetailsClick(Sender: TObject);
begin
  try
    Clipboard.AsText := DetailsText;
    btnCopyDetails.Caption := 'Copied';
    btnCopyDetails.Enabled := False;
  except
    on E: Exception do
      // Clipboard can be locked by another process; not worth an error dialog.
      btnCopyDetails.Caption := 'Copy failed';
  end;
end;

end.
