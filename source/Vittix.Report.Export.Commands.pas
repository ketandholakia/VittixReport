unit Vittix.Report.Export.Commands;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  System.IOUtils,
  System.Types,
  Vcl.Graphics;

type
  TReportExportCommandKind = (
    eckText,
    eckLine,
    eckRectangle,
    eckFillRectangle,
    eckImage,
    eckEllipse
  );

  TReportExportCommand = class
  private
    FKind: TReportExportCommandKind;
  protected
    constructor Create(AKind: TReportExportCommandKind);
  public
    property Kind: TReportExportCommandKind read FKind;
  end;

  TReportExportTextCommand = class(TReportExportCommand)
  public
    Bounds: TRect;
    Text: string;
    FontName: string;
    FontSize: Integer;
    FontStyle: TFontStyles;
    FontColor: TColor;
    HAlign: TAlignment;
    WordWrap: Boolean;
    constructor Create;
  end;

  TReportExportLineCommand = class(TReportExportCommand)
  public
    X1: Integer;
    Y1: Integer;
    X2: Integer;
    Y2: Integer;
    Color: TColor;
    Width: Integer;
    constructor Create;
  end;

  TReportExportRectangleCommand = class(TReportExportCommand)
  public
    Bounds: TRect;
    BorderColor: TColor;
    BorderWidth: Integer;
    constructor Create;
  end;

  TReportExportFillRectangleCommand = class(TReportExportCommand)
  public
    Bounds: TRect;
    FillColor: TColor;
    constructor Create;
  end;

  { Ellipse shape (stEllipse). A single command carries both fill and border
    state because a GDI Ellipse draws brush and pen together. HasFill is true
    only when the source brush is a solid fill; HasBorder is true only when
    the source pen is visible (non-clear). }
  TReportExportEllipseCommand = class(TReportExportCommand)
  public
    Bounds: TRect;
    BorderColor: TColor;
    BorderWidth: Integer;
    FillColor: TColor;
    HasFill: Boolean;
    HasBorder: Boolean;
    constructor Create;
  end;

  TReportExportImageCommand = class(TReportExportCommand)
  public
    Bounds: TRect;
    Source: string;
    Stretch: Boolean;
    Center: Boolean;
    Proportional: Boolean;
    constructor Create;
  end;

  TReportExportPage = class
  private
    FCommands: TObjectList<TReportExportCommand>;
    FWidth: Integer;
    FHeight: Integer;
  public
    constructor Create(AWidth, AHeight: Integer);
    destructor Destroy; override;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property Commands: TObjectList<TReportExportCommand> read FCommands;
  end;

  TReportExportDocument = class
  private
    FPages: TObjectList<TReportExportPage>;
    FTempFiles: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    function AddPage(AWidth, AHeight: Integer): TReportExportPage;
    { Registers a temporary image file created during export-command capture.
      The document deletes any registered file that still exists when it is
      freed (exporters run before the document is freed at all call sites). }
    procedure AddTempFile(const APath: string);
    property Pages: TObjectList<TReportExportPage> read FPages;
  end;

implementation

constructor TReportExportCommand.Create(AKind: TReportExportCommandKind);
begin
  inherited Create;
  FKind := AKind;
end;

constructor TReportExportTextCommand.Create;
begin
  inherited Create(eckText);
  FontName := 'Helvetica';
  FontSize := 10;
  FontStyle := [];
  FontColor := clBlack;
  HAlign := taLeftJustify;
  WordWrap := False;
end;

constructor TReportExportLineCommand.Create;
begin
  inherited Create(eckLine);
  Color := clBlack;
  Width := 1;
end;

constructor TReportExportRectangleCommand.Create;
begin
  inherited Create(eckRectangle);
  BorderColor := clBlack;
  BorderWidth := 1;
end;

constructor TReportExportFillRectangleCommand.Create;
begin
  inherited Create(eckFillRectangle);
  FillColor := clWhite;
end;

constructor TReportExportEllipseCommand.Create;
begin
  inherited Create(eckEllipse);
  BorderColor := clBlack;
  BorderWidth := 1;
  FillColor := clWhite;
  HasFill := False;
  HasBorder := True;
end;

constructor TReportExportImageCommand.Create;
begin
  inherited Create(eckImage);
  Stretch := True;
  Center := True;
  Proportional := True;
end;

constructor TReportExportPage.Create(AWidth, AHeight: Integer);
begin
  inherited Create;
  FWidth := AWidth;
  FHeight := AHeight;
  FCommands := TObjectList<TReportExportCommand>.Create(True);
end;

destructor TReportExportPage.Destroy;
begin
  FCommands.Free;
  inherited;
end;

constructor TReportExportDocument.Create;
begin
  inherited Create;
  FPages := TObjectList<TReportExportPage>.Create(True);
end;

destructor TReportExportDocument.Destroy;
var
  F: string;
begin
  if Assigned(FTempFiles) then
  begin
    for F in FTempFiles do
      if TFile.Exists(F) then
        TFile.Delete(F);
    FTempFiles.Free;
  end;
  FPages.Free;
  inherited;
end;

procedure TReportExportDocument.AddTempFile(const APath: string);
begin
  if not Assigned(FTempFiles) then
    FTempFiles := TStringList.Create;
  FTempFiles.Add(APath);
end;

function TReportExportDocument.AddPage(AWidth, AHeight: Integer): TReportExportPage;
begin
  Result := TReportExportPage.Create(AWidth, AHeight);
  FPages.Add(Result);
end;

end.
