unit Vittix.Report.Renderer;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Engine;

type
  { Rendered page container }

  TRenderPage = class
  public
    Bitmap: TBitmap;
    constructor Create(AWidth, AHeight: Integer);
    destructor Destroy; override;
  end;

type
  TReportRenderer = class
  private
    FPages: TObjectList<TRenderPage>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Render(AReport: TReportModel; ADataSet: TDataSet);

    property Pages: TObjectList<TRenderPage> read FPages;
  end;

implementation

uses
  System.Types,
  Vittix.Report.Objects,
  Winapi.Windows;

{ ================= Render Page ================= }

constructor TRenderPage.Create(AWidth, AHeight: Integer);
begin
  Bitmap := Vcl.Graphics.TBitmap.Create;
  Bitmap.SetSize(AWidth, AHeight);
  Bitmap.Canvas.Brush.Color := clWhite;
  Bitmap.Canvas.FillRect(Rect(0,0,AWidth,AHeight));
end;

destructor TRenderPage.Destroy;
begin
  Bitmap.Free;
  inherited;
end;

{ ================= Renderer ================= }

constructor TReportRenderer.Create;
begin
  FPages := TObjectList<TRenderPage>.Create(True);
end;

destructor TReportRenderer.Destroy;
begin
  FPages.Free;
  inherited;
end;

procedure TReportRenderer.Render(
  AReport: TReportModel;
  ADataSet: TDataSet);
var
  Engine: TReportEngine;
  i: Integer;
  Page: TRenderPage;
  DC: HDC;
  R: TRect;
begin
  FPages.Clear;

  if not Assigned(AReport) then Exit;

  Engine := TReportEngine.Create(AReport, ADataSet);
  try
    Engine.Prepare;
    
    for i := 0 to Engine.Pages.Count - 1 do
    begin
      Page := TRenderPage.Create(TReportEngine.PAGE_WIDTH, TReportEngine.PAGE_HEIGHT);
      
      DC := Page.Bitmap.Canvas.Handle;
      R := Rect(0, 0, Page.Bitmap.Width, Page.Bitmap.Height);
      
      PlayEnhMetaFile(DC, Engine.Pages[i].Handle, R);
      
      FPages.Add(Page);
    end;
  finally
    Engine.Free;
  end;
end;

end.
