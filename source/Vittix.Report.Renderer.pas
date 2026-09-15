unit Vittix.Report.Renderer;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.UserDataSet,
  Vittix.Report.Engine;

type
  { Rendered page container.

    GAP-005 / P2 (lazy rasterisation): the METAFILE is the primary retained
    representation, and it is the only artefact `TReportRenderer.Render`
    produces. The raster BITMAP is materialised on first access from the
    metafile and then cached, so a consumer that only needs the vector form
    (PDF export, e-mail export, `IReportExporter.ExportPages`) never pays for a
    full-page raster.

    Ownership: the page owns both artefacts; `Destroy` frees whichever exist.
    Because the bitmap is derived from `FMetafile` and lives beside it, a
    materialised bitmap can never outlive the metafile it came from.

    Threading: pages are created and consumed by `TReportRenderer`, which is
    used from the owning VCL thread (see the renderer note below). No
    synchronisation is introduced; there is no supported concurrent use to
    protect. }
  TRenderPage = class
  private
    FMetafile: TMetafile;
    FBitmap: TBitmap;      // nil until first Bitmap access (lazy)
    FWidth: Integer;
    FHeight: Integer;
    FRasterCount: Integer; // diagnostic: 0 or 1
    function GetBitmap: TBitmap;
  public
    constructor Create(AWidth, AHeight: Integer);
    destructor Destroy; override;

    { Vector representation. Always present after Render; never rasterised. }
    property Metafile: TMetafile read FMetafile;
    { Rasterised view, materialised on first access and cached thereafter. }
    property Bitmap: TBitmap read GetBitmap;
    { Diagnostic counter of rasterisations performed for this page (0 or 1). }
    property RasterCount: Integer read FRasterCount;
  end;

type
  { Renders a prepared report into one vector page per engine page.

    Ownership (GAP-005/P2): `FPages` owns every `TRenderPage`; each page owns its
    metafile and (once materialised) its bitmap. Freeing the renderer frees all
    pages and therefore both artefacts.

    Threading: not thread-safe by design. `Render` calls into `TReportEngine`
    (VCL/GDI, owning UI thread) and pages are consumed on the same thread by
    `Print` and the preview. No lock is added; there is no supported concurrent
    use to protect. }
  TReportRenderer = class
  private
    FPages: TObjectList<TRenderPage>;
    FParameters: TStrings;
    FTwoPassRendering: Boolean;
    procedure SetParameters(const Value: TStrings);
  protected
    { Draws one retained page into ACanvas using the shared mapping
      (Vittix.Report.PrintMapping).

      GAP-005/P3: the METAFILE is the source, matching TVittixReportPreview.Print
      and the PDF exporter; the bitmap is only a defensive fallback for a page
      with no usable metafile. Full stretch is the default, so printed geometry
      is unchanged from before P3.

      Exposed as a protected seam so the print path can be verified WITHOUT a
      printer: a test descendant drives it with an off-screen canvas and asserts
      which source was used (a metafile draw leaves TRenderPage.RasterCount at
      0). This adds no public API. }
    procedure DrawPageTo(ACanvas: TCanvas;
      APageIndex, ADeviceWidth, ADeviceHeight: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Render(AEngine: TReportEngine; APageWidth, APageHeight: Integer);
    procedure Print;

    property Pages: TObjectList<TRenderPage> read FPages;
    property Parameters: TStrings read FParameters write SetParameters;
    property TwoPassRendering: Boolean read FTwoPassRendering write FTwoPassRendering;
  end;

implementation

uses
  System.Types,
  Vittix.Report.Objects,
  Vittix.Report.PrintMapping,
  Vcl.Printers,
  Winapi.Windows;

{ ================= Render Page ================= }

constructor TRenderPage.Create(AWidth, AHeight: Integer);
begin
  FWidth := AWidth;
  FHeight := AHeight;
  FMetafile := Vcl.Graphics.TMetafile.Create;
  // The raster bitmap is deliberately NOT created here: Render must not
  // allocate a full-page raster for a page the consumer may never need
  // (GAP-005/P2). It is materialised by GetBitmap on first access.
end;

destructor TRenderPage.Destroy;
begin
  FBitmap.Free;
  FMetafile.Free;
  inherited;
end;

{ The single rasterisation path for a rendered page (GAP-005/P2 §9).

  Materialises the cached bitmap from the retained metafile on first access.
  The sequence (white fill, then StretchDraw the metafile at the page size)
  is byte-for-byte the sequence the eager path used to perform inside
  TReportRenderer.Render, so visual output is unchanged; it simply happens on
  demand instead of for every page. Repeated access returns the same cached
  instance and does not rasterise again. }
function TRenderPage.GetBitmap: Vcl.Graphics.TBitmap;
var
  R: TRect;
begin
  if not Assigned(FBitmap) then
  begin
    FBitmap := Vcl.Graphics.TBitmap.Create;
    FBitmap.SetSize(FWidth, FHeight);
    FBitmap.Canvas.Brush.Color := clWhite;
    FBitmap.Canvas.FillRect(Rect(0, 0, FWidth, FHeight));
    if Assigned(FMetafile) and (FMetafile.Width > 0) and (FMetafile.Height > 0) then
    begin
      R := Rect(0, 0, FWidth, FHeight);
      FBitmap.Canvas.StretchDraw(R, FMetafile);
    end;
    Inc(FRasterCount);
  end;
  Result := FBitmap;
end;

{ ================= Renderer ================= }

constructor TReportRenderer.Create;
begin
  FPages := TObjectList<TRenderPage>.Create(True);
  FParameters := TStringList.Create;
  FTwoPassRendering := True;
end;

destructor TReportRenderer.Destroy;
begin
  FParameters.Free;
  FPages.Free;
  inherited;
end;

procedure TReportRenderer.SetParameters(const Value: TStrings);
begin
  FParameters.Clear;
  if Assigned(Value) then
    FParameters.Assign(Value);
end;

procedure TReportRenderer.Render(AEngine: TReportEngine; APageWidth, APageHeight: Integer);
var
  i:      Integer;
  Page:   TRenderPage;
begin
  FPages.Clear;
  if not Assigned(AEngine) then Exit;

  AEngine.Parameters.Assign(FParameters);
  AEngine.TwoPassRendering := FTwoPassRendering;
  AEngine.Prepare;

  for i := 0 to AEngine.Pages.Count - 1 do
  begin
    Page := TRenderPage.Create(APageWidth, APageHeight);
    try
      // Retain the VECTOR representation only (GAP-005/P2). The raster is
      // materialised on demand by TRenderPage.GetBitmap, so a consumer that
      // never asks for a bitmap never allocates one.
      Page.Metafile.Assign(AEngine.Pages[i]);
      FPages.Add(Page);
      Page := nil; // owned by FPages after Add
    finally
      Page.Free;
    end;
  end;
end;

procedure TReportRenderer.Print;
var
  i: Integer;
begin
  if FPages.Count = 0 then Exit;

  Printer.BeginDoc;
  try
    for i := 0 to FPages.Count - 1 do
    begin
      DrawPageTo(Printer.Canvas, i, Printer.PageWidth, Printer.PageHeight);
      if i < FPages.Count - 1 then
        Printer.NewPage;
    end;
    Printer.EndDoc;
  except
    Printer.Abort;
    raise;
  end;
end;

procedure TReportRenderer.DrawPageTo(ACanvas: TCanvas;
  APageIndex, ADeviceWidth, ADeviceHeight: Integer);
var
  Page: TRenderPage;
  Dest: TRect;
begin
  if (not Assigned(ACanvas)) or (APageIndex < 0) or (APageIndex >= FPages.Count) then
    Exit;

  Page := FPages[APageIndex];
  if not Assigned(Page) then Exit;

  // Full stretch (GAP-005/P3 decision D2): identical geometry to before P3.
  Dest := CalculatePrintDestRect(Page.Metafile.Width, Page.Metafile.Height,
    ADeviceWidth, ADeviceHeight, prsFullStretch);

  // Vector source first (P3); the bitmap is a defensive fallback only.
  if (Page.Metafile <> nil) and (Page.Metafile.Width > 0) and
     (Page.Metafile.Height > 0) then
    ACanvas.StretchDraw(Dest, Page.Metafile)
  else
    ACanvas.StretchDraw(Dest, Page.Bitmap);
end;

end.
