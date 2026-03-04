unit Vittix.Report.Objects;

interface

uses
  System.Classes,
  System.Types,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Data.DB,
  Vittix.Report.Context;

{ ================= Base Object ================= }

type
  TReportObject = class(TPersistent)
  private
    FBounds:      TRect;
    FSelected:    Boolean;
    FName:        string;
    FVisible:     Boolean;
    FPrintWhen:   string;
    FAnchorRight: Boolean;
    FAnchorBottom:Boolean;
  protected
    procedure DrawSelection(C: TCanvas);
  public
    constructor Create; virtual;

    procedure Draw(C: TCanvas; const Context: TExpressionContext); virtual;
    function  MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer; virtual;
    function Hit(X,Y: Integer): Boolean; virtual;

    procedure MoveBy(dx,dy: Integer);

    class function DisplayName: string; virtual;

    property Bounds:   TRect   read FBounds   write FBounds;
    property Selected: Boolean read FSelected write FSelected;
  published
    property Name:         string  read FName         write FName;
    property Visible:      Boolean read FVisible      write FVisible      default True;
    property PrintWhen:    string  read FPrintWhen    write FPrintWhen;
    property AnchorRight:  Boolean read FAnchorRight  write FAnchorRight  default False;
    property AnchorBottom: Boolean read FAnchorBottom write FAnchorBottom default False;
  end;

  TReportObjectClass = class of TReportObject;

{ ================= Registry ================= }

procedure RegisterReportObject(AClass: TReportObjectClass);
function GetRegisteredReportObjects: TArray<TReportObjectClass>;

{ ================= Text Object ================= }

type
  TReportTextObject = class(TReportObject)
  private
    FText:          string;
    FDataField:     string;
    FExpression:    string;
    FFont:          TFont;
    FHAlign:        TAlignment;
    FVAlign:        TVerticalAlignment;
    FBackground:    TColor;
    FTransparent:   Boolean;
    FBorderColor:   TColor;
    FBorderWidth:   Integer;
    FBorderVisible: Boolean;
    FWordWrap:      Boolean;
    FAutoSize:      Boolean;
    FPaddingLeft:   Integer;
    FPaddingTop:    Integer;
    FPaddingRight:  Integer;
    FPaddingBottom: Integer;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    class function DisplayName: string; override;
  published
    property Text:          string             read FText          write FText;
    property DataField:     string             read FDataField     write FDataField;
    property Expression:    string             read FExpression    write FExpression;
    property Font:          TFont              read FFont          write FFont;
    property HAlign:        TAlignment         read FHAlign        write FHAlign         default taLeftJustify;
    property VAlign:        TVerticalAlignment read FVAlign        write FVAlign         default taVerticalCenter;
    property Background:    TColor             read FBackground    write FBackground;
    property Transparent:   Boolean            read FTransparent   write FTransparent    default True;
    property BorderVisible: Boolean            read FBorderVisible write FBorderVisible  default False;
    property BorderColor:   TColor             read FBorderColor   write FBorderColor;
    property BorderWidth:   Integer            read FBorderWidth   write FBorderWidth    default 1;
    property WordWrap:      Boolean            read FWordWrap      write FWordWrap       default False;
    property AutoSize:      Boolean            read FAutoSize      write FAutoSize       default False;
    property PaddingLeft:   Integer            read FPaddingLeft   write FPaddingLeft    default 2;
    property PaddingTop:    Integer            read FPaddingTop    write FPaddingTop     default 2;
    property PaddingRight:  Integer            read FPaddingRight  write FPaddingRight   default 2;
    property PaddingBottom: Integer            read FPaddingBottom write FPaddingBottom  default 2;
  end;

{ ================= Label Object (static text) ================= }

  TReportLabelObject = class(TReportTextObject)
  public
    constructor Create; override;
    class function DisplayName: string; override;
  end;

{ ================= Field Object (data-bound) ================= }

  TReportFieldObject = class(TReportTextObject)
  public
    constructor Create; override;
    class function DisplayName: string; override;
  end;

{ ================= Shape Object ================= }

type
  TReportShapeType = (stRectangle, stRoundRect, stEllipse, stLine, stDiagLine);

  TReportShapeObject = class(TReportObject)
  private
    FShapeType:    TReportShapeType;
    FPenColor:     TColor;
    FPenWidth:     Integer;
    FPenStyle:     TPenStyle;
    FBrushColor:   TColor;
    FBrushStyle:   TBrushStyle;
    FCornerRadius: Integer;
  public
    constructor Create; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    class function DisplayName: string; override;
  published
    property ShapeType:    TReportShapeType read FShapeType    write FShapeType    default stRectangle;
    property PenColor:     TColor           read FPenColor     write FPenColor;
    property PenWidth:     Integer          read FPenWidth     write FPenWidth     default 1;
    property PenStyle:     TPenStyle        read FPenStyle     write FPenStyle     default psSolid;
    property BrushColor:   TColor           read FBrushColor   write FBrushColor;
    property BrushStyle:   TBrushStyle      read FBrushStyle   write FBrushStyle   default bsSolid;
    property CornerRadius: Integer          read FCornerRadius write FCornerRadius default 12;
  end;

{ ================= Image Object ================= }

  TReportImageObject = class(TReportObject)
  private
    FPicture:        TPicture;
    FStretch:        Boolean;
    FCenter:         Boolean;
    FProportional:   Boolean;
    FBorderVisible:  Boolean;
    FBorderColor:    TColor;
    FBorderWidth:    Integer;
    FDataField:      string;  // field holding a file path or base64 image
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    class function DisplayName: string; override;
    property Picture: TPicture read FPicture;
  published
    property Stretch:       Boolean read FStretch       write FStretch       default True;
    property Center:        Boolean read FCenter        write FCenter        default True;
    property Proportional:  Boolean read FProportional  write FProportional  default True;
    property BorderVisible: Boolean read FBorderVisible write FBorderVisible default False;
    property BorderColor:   TColor  read FBorderColor   write FBorderColor;
    property BorderWidth:   Integer read FBorderWidth   write FBorderWidth   default 1;
    property DataField:     string  read FDataField     write FDataField;
  end;

{ ================= Memo Object (multi-line, auto-height) ================= }

  TReportMemoObject = class(TReportTextObject)
  private
    FAutoHeight: Boolean;
    FMinHeight:  Integer;
  public
    constructor Create; override;
    class function DisplayName: string; override;
    function MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer; override;
  published
    property AutoHeight: Boolean read FAutoHeight write FAutoHeight default True;
    property MinHeight:  Integer read FMinHeight  write FMinHeight  default 20;
  end;

{ ================= Line Object (separator / rule) ================= }

type
  TLineOrientation = (loHorizontal, loVertical);

  TReportLineObject = class(TReportObject)
  private
    FOrientation: TLineOrientation;
    FLineColor:   TColor;
    FLineWidth:   Integer;
    FLineStyle:   TPenStyle;
  public
    constructor Create; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    class function DisplayName: string; override;
  published
    property Orientation: TLineOrientation read FOrientation write FOrientation default loHorizontal;
    property LineColor:   TColor           read FLineColor   write FLineColor;
    property LineWidth:   Integer          read FLineWidth   write FLineWidth   default 1;
    property LineStyle:   TPenStyle        read FLineStyle   write FLineStyle   default psSolid;
  end;

implementation

uses
  Vittix.Report.Expressions, // Keep here
  Winapi.Windows, // Keep here
  System.Variants, // Keep here
  System.SyncObjs;

var
  GRegistry: TList<TReportObjectClass>;
  GRegistryCS: TCriticalSection;

{ ================= Registry ================= }

procedure RegisterReportObject(AClass: TReportObjectClass);
begin
  GRegistryCS.Enter;
  try
    if GRegistry.IndexOf(AClass) < 0 then
      GRegistry.Add(AClass);
  finally
    GRegistryCS.Leave;
  end;
end;

function GetRegisteredReportObjects: TArray<TReportObjectClass>;
begin
  GRegistryCS.Enter;
  try
    Result := GRegistry.ToArray;
  finally
    GRegistryCS.Leave;
  end;
end;

{ ================= Base Object ================= }

constructor TReportObject.Create;
begin
  inherited;
  FBounds       := Rect(10, 10, 110, 40);
  FVisible      := True;
  FAnchorRight  := False;
  FAnchorBottom := False;
end;
 
procedure TReportObject.Draw(C: TCanvas; const Context: TExpressionContext);
begin
  C.Brush.Style := bsClear;
  C.Rectangle(FBounds);

  if FSelected then
    DrawSelection(C);
end;

procedure TReportObject.DrawSelection(C: TCanvas);
const
  H = 4; // half handle size
var
  CX, CY: Integer;
begin
  CX := (FBounds.Left + FBounds.Right)  div 2;
  CY := (FBounds.Top  + FBounds.Bottom) div 2;

  C.Pen.Color   := clBlack;
  C.Pen.Style   := psSolid;
  C.Pen.Width   := 1;
  C.Brush.Color := clWhite;
  C.Brush.Style := bsSolid;

  // 8 handles: corners + mid-edges
  C.Rectangle(FBounds.Left  - H, FBounds.Top    - H, FBounds.Left  + H, FBounds.Top    + H); // TL
  C.Rectangle(CX            - H, FBounds.Top    - H, CX            + H, FBounds.Top    + H); // TM
  C.Rectangle(FBounds.Right - H, FBounds.Top    - H, FBounds.Right + H, FBounds.Top    + H); // TR
  C.Rectangle(FBounds.Right - H, CY             - H, FBounds.Right + H, CY             + H); // MR
  C.Rectangle(FBounds.Right - H, FBounds.Bottom - H, FBounds.Right + H, FBounds.Bottom + H); // BR
  C.Rectangle(CX            - H, FBounds.Bottom - H, CX            + H, FBounds.Bottom + H); // BM
  C.Rectangle(FBounds.Left  - H, FBounds.Bottom - H, FBounds.Left  + H, FBounds.Bottom + H); // BL
  C.Rectangle(FBounds.Left  - H, CY             - H, FBounds.Left  + H, CY             + H); // ML

  // Focus rect around the whole object
  C.Pen.Style := psDot;
  C.Pen.Color := cl3DDkShadow;
  C.Brush.Style := bsClear;
  C.Rectangle(FBounds);
  C.Pen.Style := psSolid;
end;

function TReportObject.Hit(X,Y: Integer): Boolean;
begin
  Result := PtInRect(FBounds, Point(X,Y));
end;

procedure TReportObject.MoveBy(dx,dy: Integer);
begin
  OffsetRect(FBounds, dx, dy);
end;

class function TReportObject.DisplayName: string;
begin
  Result := ClassName;
end;

function TReportObject.MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer;
begin
  Result := FBounds.Bottom;  // default: static bounds
end;


constructor TReportTextObject.Create;
begin
  inherited;
  FFont           := TFont.Create;
  FFont.Name      := 'Tahoma';
  FFont.Size      := 10;
  FText           := 'Text';
  FHAlign         := taLeftJustify;
  FVAlign         := taVerticalCenter;
  FBackground     := clWhite;
  FTransparent    := True;
  FBorderColor    := clBlack;
  FBorderWidth    := 1;
  FBorderVisible  := False;
  FWordWrap       := False;
  FAutoSize       := False;
  FPaddingLeft    := 2;
  FPaddingTop     := 2;
  FPaddingRight   := 2;
  FPaddingBottom  := 2;
end;

destructor TReportTextObject.Destroy;
begin
  FFont.Free;
  inherited;
end;

procedure TReportTextObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  S:       string;
  R, TR:   TRect;
  Fmt:     UINT;
  TxtH:    Integer;
begin
  if not FVisible then Exit;

  R := FBounds;

  // Background
  if not FTransparent then
  begin
    C.Brush.Style := bsSolid;
    C.Brush.Color := FBackground;
    C.FillRect(R);
  end
  else
    C.Brush.Style := bsClear;

  // Border
  if FBorderVisible then
  begin
    C.Pen.Color   := FBorderColor;
    C.Pen.Width   := FBorderWidth;
    C.Pen.Style   := psSolid;
    C.Brush.Style := bsClear;
    C.Rectangle(R);
  end;

  // Resolve text value
  if FExpression <> '' then
    S := VarToStr(TReportExpression.Evaluate(FExpression, Context))
  else if (FDataField <> '') and Assigned(Context.DataSet) and Context.DataSet.Active then
    S := Context.DataSet.FieldByName(FDataField).AsString
  else
    S := FText;

  // Apply padding
  TR := Rect(R.Left  + FPaddingLeft,
             R.Top   + FPaddingTop,
             R.Right - FPaddingRight,
             R.Bottom- FPaddingBottom);

  // Horizontal alignment flag
  case FHAlign of
    taLeftJustify:  Fmt := DT_LEFT;
    taRightJustify: Fmt := DT_RIGHT;
    taCenter:       Fmt := DT_CENTER;
  else
    Fmt := DT_LEFT;
  end;

  if FWordWrap then
    Fmt := Fmt or DT_WORDBREAK
  else
  begin
    // Vertical alignment only meaningful for single-line
    case FVAlign of
      taAlignTop:      Fmt := Fmt or DT_TOP;
      taAlignBottom:   Fmt := Fmt or DT_BOTTOM;
      taVerticalCenter:Fmt := Fmt or DT_VCENTER;
    else
      Fmt := Fmt or DT_VCENTER;
    end;
    Fmt := Fmt or DT_SINGLELINE;
  end;

  C.Font.Assign(FFont);
  C.Brush.Style := bsClear;

  // AutoSize: measure text and grow bounds downward
  if FAutoSize and FWordWrap then
  begin
    TxtH := DrawText(C.Handle, PChar(S), Length(S), TR, Fmt or DT_CALCRECT);
    if TxtH > 0 then
    begin
      FBounds.Bottom := FBounds.Top + TxtH + FPaddingTop + FPaddingBottom;
      R  := FBounds;
      TR := Rect(R.Left + FPaddingLeft, R.Top + FPaddingTop,
                 R.Right - FPaddingRight, R.Bottom - FPaddingBottom);
    end;
  end;

  DrawText(C.Handle, PChar(S), Length(S), TR, Fmt);

  if FSelected then DrawSelection(C);
end;

class function TReportTextObject.DisplayName: string;
begin
  Result := 'Text';
end;

{ ================= Label Object ================= }

constructor TReportLabelObject.Create;
begin
  inherited;
  FText        := 'Label';
  FFont.Style  := FFont.Style + [fsBold];
  FTransparent := True;
  FBounds      := Rect(10, 10, 150, 30);
end;

class function TReportLabelObject.DisplayName: string;
begin
  Result := 'Label';
end;

{ ================= Field Object ================= }

constructor TReportFieldObject.Create;
begin
  inherited;
  FText        := '[DataField]';
  FTransparent := True;
  FBorderVisible := True;
  FBorderColor := clSilver;
  FBounds      := Rect(10, 10, 150, 30);
end;

class function TReportFieldObject.DisplayName: string;
begin
  Result := 'Data Field';
end;

{ ================= Shape Object ================= }

constructor TReportShapeObject.Create;
begin
  inherited;
  FShapeType    := stRectangle;
  FPenColor     := clBlack;
  FPenWidth     := 1;
  FPenStyle     := psSolid;
  FBrushColor   := clWhite;
  FBrushStyle   := bsSolid;
  FCornerRadius := 12;
  FBounds       := Rect(10, 10, 110, 60);
end;

procedure TReportShapeObject.Draw(C: TCanvas; const Context: TExpressionContext);
begin
  if not FVisible then Exit;

  C.Pen.Color   := FPenColor;
  C.Pen.Width   := FPenWidth;
  C.Pen.Style   := FPenStyle;
  C.Brush.Color := FBrushColor;
  C.Brush.Style := FBrushStyle;

  case FShapeType of
    stRectangle: C.Rectangle(FBounds);
    stRoundRect: C.RoundRect(FBounds.Left, FBounds.Top,
                              FBounds.Right, FBounds.Bottom,
                              FCornerRadius, FCornerRadius);
    stEllipse:   C.Ellipse(FBounds);
    stLine:
    begin
      C.MoveTo(FBounds.Left,  (FBounds.Top + FBounds.Bottom) div 2);
      C.LineTo(FBounds.Right, (FBounds.Top + FBounds.Bottom) div 2);
    end;
    stDiagLine:
    begin
      C.MoveTo(FBounds.Left,  FBounds.Top);
      C.LineTo(FBounds.Right, FBounds.Bottom);
    end;
  end;

  if FSelected then DrawSelection(C);
end;

class function TReportShapeObject.DisplayName: string;
begin
  Result := 'Shape';
end;

{ ================= Image Object ================= }

constructor TReportImageObject.Create;
begin
  inherited;
  FPicture       := TPicture.Create;
  FStretch       := True;
  FCenter        := True;
  FProportional  := True;
  FBorderVisible := False;
  FBorderColor   := clBlack;
  FBorderWidth   := 1;
  FBounds        := Rect(10, 10, 120, 90);
end;

destructor TReportImageObject.Destroy;
begin
  FPicture.Free;
  inherited;
end;

procedure TReportImageObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  R:              TRect;
  PW, PH, BW, BH: Integer;
  ScaleX, ScaleY, Scale: Double;
  PathOrBase64:   string;
begin
  if not FVisible then Exit;

  R := FBounds;

  // Try loading from DataField at runtime
  if (FDataField <> '') and Assigned(Context.DataSet) and Context.DataSet.Active then
  begin
    PathOrBase64 := Context.DataSet.FieldByName(FDataField).AsString;
    if FileExists(PathOrBase64) then
    try
      FPicture.LoadFromFile(PathOrBase64);
    except
      // silently ignore bad path
    end;
  end;

  // Border
  if FBorderVisible then
  begin
    C.Pen.Color   := FBorderColor;
    C.Pen.Width   := FBorderWidth;
    C.Pen.Style   := psSolid;
    C.Brush.Style := bsClear;
    C.Rectangle(R);
  end
  else
  begin
    C.Pen.Color   := clSilver;
    C.Pen.Style   := psDot;
    C.Brush.Style := bsClear;
    C.Rectangle(R);
    C.Pen.Style   := psSolid;
  end;

  if not Assigned(FPicture.Graphic) or FPicture.Graphic.Empty then
  begin
    C.Font.Color := clGray;
    C.Brush.Style := bsClear;
    C.TextOut(FBounds.Left + 4, FBounds.Top + 4, '[Image]');
  end
  else
  begin
    PW := FPicture.Width;
    PH := FPicture.Height;
    BW := R.Width;
    BH := R.Height;
    if FStretch then
    begin
      if FProportional and (PW > 0) and (PH > 0) then
      begin
        ScaleX := BW / PW;
        ScaleY := BH / PH;
        if ScaleX < ScaleY then Scale := ScaleX else Scale := ScaleY;
        R := Rect(R.Left, R.Top,
                  R.Left + Round(PW * Scale),
                  R.Top  + Round(PH * Scale));
        if FCenter then
          OffsetRect(R, (BW - R.Width) div 2, (BH - R.Height) div 2);
      end;
      C.StretchDraw(R, FPicture.Graphic);
    end
    else if FCenter then
      C.Draw(FBounds.Left + (BW - PW) div 2,
             FBounds.Top  + (BH - PH) div 2, FPicture.Graphic)
    else
      C.Draw(FBounds.Left, FBounds.Top, FPicture.Graphic);
  end;

  if FSelected then DrawSelection(C);
end;

class function TReportImageObject.DisplayName: string;
begin
  Result := 'Image';
end;

{ ================= Memo Object ================= }

constructor TReportMemoObject.Create;
begin
  inherited;
  FText          := 'Memo';
  FWordWrap      := True;
  FBorderVisible := True;
  FAutoHeight    := True;
  FMinHeight     := 20;
  FBounds        := Rect(10, 10, 200, 80);
end;

class function TReportMemoObject.DisplayName: string;
begin
  Result := 'Memo';
end;

function TReportMemoObject.MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer;
var
  S:    string;
  TR:   TRect;
  TxtH: Integer;
  Needed: Integer;
begin
  Result := FBounds.Bottom;
  if not FAutoHeight then Exit;
  if not Assigned(C) then Exit;

  // Resolve display text (mirror TReportTextObject.Draw logic)
  if FExpression <> '' then
    S := VarToStr(TReportExpression.Evaluate(FExpression, Context))
  else if (FDataField <> '') and Assigned(Context.DataSet) and Context.DataSet.Active then
    S := Context.DataSet.FieldByName(FDataField).AsString
  else
    S := FText;

  if S = '' then
  begin
    if FMinHeight > 0 then
      Result := FBounds.Top + FMinHeight;
    Exit;
  end;

  C.Font.Assign(FFont);
  TR := Rect(FBounds.Left + FPaddingLeft,
             FBounds.Top  + FPaddingTop,
             FBounds.Right - FPaddingRight,
             FBounds.Top   + 5000);   // large bottom — CALCRECT will shrink it
  if TR.Right <= TR.Left + 4 then Exit;

  TxtH := Winapi.Windows.DrawText(C.Handle, PChar(S), Length(S), TR,
             DT_LEFT or DT_WORDBREAK or DT_CALCRECT);

  if TxtH > 0 then
  begin
    Needed := TxtH + FPaddingTop + FPaddingBottom;
    if Needed < FMinHeight then Needed := FMinHeight;
    Result  := FBounds.Top + Needed;
  end
  else if FMinHeight > 0 then
    Result := FBounds.Top + FMinHeight;
end;

{ ================= Line Object ================= }

constructor TReportLineObject.Create;
begin
  inherited;
  FOrientation := loHorizontal;
  FLineColor   := clBlack;
  FLineWidth   := 1;
  FLineStyle   := psSolid;
  FBounds      := Rect(10, 10, 200, 12);  // thin horizontal rule
end;

procedure TReportLineObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  R: TRect;
  CX, CY: Integer;
begin
  if not FVisible then Exit;
  R  := FBounds;
  CX := (R.Left + R.Right)  div 2;
  CY := (R.Top  + R.Bottom) div 2;

  C.Pen.Color  := FLineColor;
  C.Pen.Width  := FLineWidth;
  C.Pen.Style  := FLineStyle;
  C.Brush.Style := bsClear;

  if FOrientation = loHorizontal then
  begin
    C.MoveTo(R.Left,  CY);
    C.LineTo(R.Right, CY);
  end
  else
  begin
    C.MoveTo(CX, R.Top);
    C.LineTo(CX, R.Bottom);
  end;

  if FSelected then DrawSelection(C);
end;

class function TReportLineObject.DisplayName: string;
begin
  Result := 'Line';
end;

{ ================= Init ================= }

initialization
  GRegistry := TList<TReportObjectClass>.Create;
  GRegistryCS := TCriticalSection.Create;
  RegisterReportObject(TReportTextObject);
  RegisterReportObject(TReportLabelObject);
  RegisterReportObject(TReportFieldObject);
  RegisterReportObject(TReportShapeObject);
  RegisterReportObject(TReportImageObject);
  RegisterReportObject(TReportMemoObject);
  RegisterReportObject(TReportLineObject);

finalization
  GRegistry.Free;
  GRegistryCS.Free;

end.
