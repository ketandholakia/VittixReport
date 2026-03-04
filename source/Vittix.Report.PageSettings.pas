unit Vittix.Report.PageSettings;

{
  Vittix.Report.PageSettings
  ==========================
  Value object that describes a report page's physical properties.

  Design notes
  ------------
  • All dimensions are in pixels at 96 DPI (the WinAPI default).
  • TReportModel owns one TReportPageSettings instance.
  • TReportEngine reads page dimensions from this object only — the
    hard-coded 793/1122 constants in the engine are gone.
  • Persisted to/from JSON by TReportSerializer alongside the model.

  Pre-defined paper sizes (96 DPI)
  ---------------------------------
    A4 Portrait  793 × 1122
    A4 Landscape 1122 × 793
    Letter       816 × 1056  (8.5 × 11 in @ 96 DPI)
    Legal        816 × 1344  (8.5 × 14 in @ 96 DPI)
}

interface

uses
  System.Classes;   // TPersistent

type
  TReportPaperSize = (
    psA4,           // ISO 210 × 297 mm
    psLetter,       // US 8.5 × 11 in
    psLegal,        // US 8.5 × 14 in
    psA3,           // ISO 297 × 420 mm
    psCustom        // pick arbitrary Width/Height
  );

  TReportOrientation = (
    orPortrait,
    orLandscape
  );

  TReportMargins = record
    Left, Top, Right, Bottom: Integer; // pixels
    class function Default: TReportMargins; static;
  end;

  TReportPageSettings = class(TPersistent)
  private
    FPaperSize: TReportPaperSize;
    FOrientation: TReportOrientation;
    FMargins: TReportMargins;
    FCustomWidth: Integer;
    FCustomHeight: Integer;

    procedure ApplyPreset;
    procedure SetPaperSize(const V: TReportPaperSize);
    procedure SetOrientation(const V: TReportOrientation);
    function GetPageWidth: Integer;
    function GetPageHeight: Integer;
    function GetContentWidth: Integer;
    function GetContentHeight: Integer;
  public
    constructor Create;

    procedure AssignTo(Dest: TPersistent); override;

    { Computed read-only geometry }
    property PageWidth:     Integer read GetPageWidth;
    property PageHeight:    Integer read GetPageHeight;
    property ContentWidth:  Integer read GetContentWidth;   // page - left - right margin
    property ContentHeight: Integer read GetContentHeight;  // page - top - bottom margin

  published
    property PaperSize: TReportPaperSize
      read FPaperSize write SetPaperSize default psA4;

    property Orientation: TReportOrientation
      read FOrientation write SetOrientation default orPortrait;

    property Margins: TReportMargins
      read FMargins write FMargins;

    { Only meaningful when PaperSize = psCustom }
    property CustomWidth:  Integer read FCustomWidth  write FCustomWidth  default 793;
    property CustomHeight: Integer read FCustomHeight write FCustomHeight default 1122;
  end;

implementation

// ---------------------------------------------------------------------------
// TReportMargins
// ---------------------------------------------------------------------------

class function TReportMargins.Default: TReportMargins;
begin
  Result.Left   := 40;
  Result.Top    := 40;
  Result.Right  := 40;
  Result.Bottom := 40;
end;

// ---------------------------------------------------------------------------
// Paper presets at 96 DPI — portrait dimensions; landscape swaps W/H.
// ---------------------------------------------------------------------------

type
  TPaperPreset = record W, H: Integer; end;

const
  PRESETS: array[TReportPaperSize] of TPaperPreset = (
    (W: 793;  H: 1122),  // A4
    (W: 816;  H: 1056),  // Letter
    (W: 816;  H: 1344),  // Legal
    (W: 1122; H: 1587),  // A3
    (W: 793;  H: 1122)   // Custom — seed values; overridden by CustomWidth/Height
  );

// ---------------------------------------------------------------------------
// TReportPageSettings
// ---------------------------------------------------------------------------

constructor TReportPageSettings.Create;
begin
  inherited;
  FPaperSize    := psA4;
  FOrientation  := orPortrait;
  FMargins      := TReportMargins.Default;
  FCustomWidth  := 793;
  FCustomHeight := 1122;
end;

procedure TReportPageSettings.AssignTo(Dest: TPersistent);
var D: TReportPageSettings;
begin
  if Dest is TReportPageSettings then
  begin
    D := TReportPageSettings(Dest);
    D.FPaperSize    := FPaperSize;
    D.FOrientation  := FOrientation;
    D.FMargins      := FMargins;
    D.FCustomWidth  := FCustomWidth;
    D.FCustomHeight := FCustomHeight;
  end
  else
    inherited;
end;

procedure TReportPageSettings.ApplyPreset;
begin
  // Nothing to mutate — geometry is computed on the fly in the property getters.
end;

procedure TReportPageSettings.SetPaperSize(const V: TReportPaperSize);
begin
  FPaperSize := V;
  ApplyPreset;
end;

procedure TReportPageSettings.SetOrientation(const V: TReportOrientation);
begin
  FOrientation := V;
end;

function TReportPageSettings.GetPageWidth: Integer;
var W, H: Integer;
begin
  if FPaperSize = psCustom then
  begin
    W := FCustomWidth;
    H := FCustomHeight;
  end
  else
  begin
    W := PRESETS[FPaperSize].W;
    H := PRESETS[FPaperSize].H;
  end;

  if FOrientation = orLandscape then
    Result := H
  else
    Result := W;
end;

function TReportPageSettings.GetPageHeight: Integer;
var W, H: Integer;
begin
  if FPaperSize = psCustom then
  begin
    W := FCustomWidth;
    H := FCustomHeight;
  end
  else
  begin
    W := PRESETS[FPaperSize].W;
    H := PRESETS[FPaperSize].H;
  end;

  if FOrientation = orLandscape then
    Result := W
  else
    Result := H;
end;

function TReportPageSettings.GetContentWidth: Integer;
begin
  Result := PageWidth - FMargins.Left - FMargins.Right;
end;

function TReportPageSettings.GetContentHeight: Integer;
begin
  Result := PageHeight - FMargins.Top - FMargins.Bottom;
end;

end.
