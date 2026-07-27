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
  { Rendered page container }

  TRenderPage = class
  public
    Bitmap: TBitmap;
    Metafile: TMetafile;
    constructor Create(AWidth, AHeight: Integer);
    destructor Destroy; override;
  end;

type
  TReportRenderer = class
  private
    FPages: TObjectList<TRenderPage>;
    FParameters: TStrings;
    FTwoPassRendering: Boolean;
    procedure SetParameters(const Value: TStrings);
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
  Vcl.Printers,
  Winapi.Windows;

{ ================= Render Page ================= }

constructor TRenderPage.Create(AWidth, AHeight: Integer);
begin
  Metafile := Vcl.Graphics.TMetafile.Create;
  Bitmap := Vcl.Graphics.TBitmap.Create;
  Bitmap.SetSize(AWidth, AHeight);
  Bitmap.Canvas.Brush.Color := clWhite;
  Bitmap.Canvas.FillRect(Rect(0,0,AWidth,AHeight));
end;

destructor TRenderPage.Destroy;
begin
  Bitmap.Free;
  Metafile.Free;
  inherited;
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
  R:      TRect;
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
      R  := Rect(0, 0, APageWidth, APageHeight);
      Page.Metafile.Assign(AEngine.Pages[i]);
      Page.Bitmap.Canvas.StretchDraw(R, AEngine.Pages[i]);
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
  R: TRect;
begin
  if FPages.Count = 0 then Exit;

  Printer.BeginDoc;
  try
    for i := 0 to FPages.Count - 1 do
    begin
      R := Rect(0, 0, Printer.PageWidth, Printer.PageHeight);
      Printer.Canvas.StretchDraw(R, FPages[i].Bitmap);
      if i < FPages.Count - 1 then
        Printer.NewPage;
    end;
    Printer.EndDoc;
  except
    Printer.Abort;
    raise;
  end;
end;

end.
