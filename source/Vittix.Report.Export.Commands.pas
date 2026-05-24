unit Vittix.Report.Export.Commands;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Types,
  Vcl.Graphics;

type
  TReportExportCommandKind = (
    eckText,
    eckLine,
    eckRectangle,
    eckFillRectangle,
    eckImage
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
  public
    constructor Create;
    destructor Destroy; override;
    function AddPage(AWidth, AHeight: Integer): TReportExportPage;
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
begin
  FPages.Free;
  inherited;
end;

function TReportExportDocument.AddPage(AWidth, AHeight: Integer): TReportExportPage;
begin
  Result := TReportExportPage.Create(AWidth, AHeight);
  FPages.Add(Result);
end;

end.
