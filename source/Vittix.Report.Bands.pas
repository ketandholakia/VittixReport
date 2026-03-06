unit Vittix.Report.Bands;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Graphics,
  System.Generics.Collections,
  Vittix.Report.Objects, // Keep here
  Data.DB,
  Vittix.Report.Context;

type
  TReportBandType = (
    btReportTitle,    // 0 — Prints once at the top of the first page
    btPageHeader,     // 1 — Prints at the top of every page
    btMasterData,     // 2 — Prints once per data row
    btPageFooter,     // 3 — Prints at the bottom of every page
    btReportSummary,  // 4 — Prints once after all data
    btGroupHeader,    // 5 — Prints when the group field value changes (top)
    btGroupFooter,    // 6 — Prints when the group field value changes (bottom)
    // --- appended after v1; ordinals 7+ safe to add ---
    btColumnHeader,   // 7 — Below PageHeader; repeats after every group header
    btDetail,         // 8 — Synonym for btMasterData (alias for clarity)
    btOverlay         // 9 — Drawn last over the full page (watermark / stamp)
  );

type
  TReportBand = class(TReportObject)
  private
    FBandType:           TReportBandType;
    FHeight:             Integer;
    FGroupLevel:         Integer;
    FGroupField:         string;
    FStartNewPage:       Boolean;
    FCanGrow:            Boolean;
    FCanShrink:          Boolean;
    FBackColor:          TColor;
    FBackColorTransparent: Boolean;
    FChildren: TObjectList<TReportObject>;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    property Children: TObjectList<TReportObject> read FChildren;

  published
    property BandType:  TReportBandType read FBandType  write FBandType;
    property Height:    Integer         read FHeight    write FHeight;
    property GroupField:  string        read FGroupField  write FGroupField;
    property GroupLevel:  Integer       read FGroupLevel  write FGroupLevel;
    property StartNewPage: Boolean      read FStartNewPage write FStartNewPage;
    property CanGrow:   Boolean         read FCanGrow   write FCanGrow   default False;
    property CanShrink: Boolean         read FCanShrink write FCanShrink default False;
    property BackColor: TColor          read FBackColor write FBackColor default clWhite;
    property BackColorTransparent: Boolean
                                        read FBackColorTransparent
                                        write FBackColorTransparent default True;
  end;

implementation

uses
  Winapi.Windows;

constructor TReportBand.Create;
begin
  inherited Create;
  FHeight               := 40;
  FCanGrow              := False;
  FCanShrink            := False;
  FBackColor            := clWhite;
  FBackColorTransparent := True;
  FChildren := TObjectList<TReportObject>.Create(True);
end;

destructor TReportBand.Destroy;
begin
  FChildren.Free;
  inherited;
end;

procedure TReportBand.Draw(C: TCanvas; const Context: TExpressionContext);
var
  Obj:    TReportObject;
  BandR:  TRect;
begin
  BandR := Rect(Bounds.Left, Bounds.Top, Bounds.Right, Bounds.Top + FHeight);

  // Background fill
  if not FBackColorTransparent then
  begin
    C.Brush.Color := FBackColor;
    C.Brush.Style := bsSolid;
    C.FillRect(BandR);
  end;

  // Bottom separator line
  C.Pen.Color := clSilver;
  C.Pen.Width := 1;
  C.Pen.Style := psSolid;
  C.MoveTo(BandR.Left,  BandR.Bottom);
  C.LineTo(BandR.Right, BandR.Bottom);

  // Draw children with DC offset so child Bounds are band-relative
  SaveDC(C.Handle);
  try
    OffsetViewportOrgEx(C.Handle, Bounds.Left, Bounds.Top, nil);
    for Obj in FChildren do
      if Obj.Visible then
        Obj.Draw(C, Context);
  finally
    RestoreDC(C.Handle, -1);
  end;
end;

initialization
  RegisterReportObject(TReportBand);

end.
