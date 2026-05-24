unit Vittix.Report.Objects;

interface

uses
  System.Classes,
  System.Types,
  System.SysUtils,
  System.Generics.Collections,
  System.MaskUtils,
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
    FOnBeforePrint: string;
    FOnAfterPrint:  string;
    FAnchorRight: Boolean;
    FAnchorBottom:Boolean;
    FPageBreakBefore: Boolean;
    FPageBreakAfter: Boolean;
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
    property OnBeforePrint: string read FOnBeforePrint write FOnBeforePrint;
    property OnAfterPrint:  string read FOnAfterPrint  write FOnAfterPrint;
    property AnchorRight:  Boolean read FAnchorRight  write FAnchorRight  default False;
    property AnchorBottom: Boolean read FAnchorBottom write FAnchorBottom default False;
    property PageBreakBefore: Boolean read FPageBreakBefore write FPageBreakBefore default False;
    property PageBreakAfter:  Boolean read FPageBreakAfter  write FPageBreakAfter  default False;
  end;

  TReportObjectClass = class of TReportObject;

  TReportObjectBeforePrintEvent = procedure(
    AObject: TReportObject;
    const Context: TExpressionContext;
    var ACanPrint: Boolean) of object;

  TReportObjectAfterPrintEvent = procedure(
    AObject: TReportObject;
    const Context: TExpressionContext) of object;

{ ================= Registry ================= }

procedure RegisterReportObject(AClass: TReportObjectClass);
function GetRegisteredReportObjects: TArray<TReportObjectClass>;
procedure SetReportNamedDataSets(ANamedDataSets: TDictionary<string, TDataSet>);
procedure SetReportObjectRenderHooks(
  const ABeforePrint: TReportObjectBeforePrintEvent;
  const AAfterPrint: TReportObjectAfterPrintEvent);
procedure ClearReportObjectRenderHooks;
procedure DrawReportObjectWithHooks(
  AObject: TReportObject;
  C: TCanvas;
  const Context: TExpressionContext);

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
    FFontColorCondition:   string;
    FFontColorOnTrue:      TColor;
    FBackgroundCondition:  string;
    FBackgroundOnTrue:     TColor;
    FBorderColorCondition: string;
    FBorderColorOnTrue:    TColor;
  protected
    procedure ResolveConditionalStyle(
      const Context: TExpressionContext;
      out AFontColor: TColor;
      out ABackground: TColor;
      out ABorderColor: TColor);
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    function MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer; override;
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
    property FontColorCondition: string read FFontColorCondition write FFontColorCondition;
    property FontColorOnTrue: TColor read FFontColorOnTrue write FFontColorOnTrue default clRed;
    property BackgroundCondition: string read FBackgroundCondition write FBackgroundCondition;
    property BackgroundOnTrue: TColor read FBackgroundOnTrue write FBackgroundOnTrue default clYellow;
    property BorderColorCondition: string read FBorderColorCondition write FBorderColorCondition;
    property BorderColorOnTrue: TColor read FBorderColorOnTrue write FBorderColorOnTrue default clRed;
  end;

{ ================= Label Object (static text) ================= }

  TReportLabelObject = class(TReportTextObject)
  public
    constructor Create; override;
    class function DisplayName: string; override;
  end;

{ ================= Field Object (data-bound) ================= }

  TReportFieldObject = class(TReportTextObject)
  private
    FDisplayFormat: string;
    FEditMask:      string;
  public
    constructor Create; override;
    class function DisplayName: string; override;
  published
    property DisplayFormat: string read FDisplayFormat write FDisplayFormat;
    property EditMask:      string read FEditMask      write FEditMask;
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
    FCachedImagePath: string;
    FCachedPicture:   TPicture;
    FCachedImageValid: Boolean;
    FCachedImageAttempted: Boolean;
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
    procedure ResetImageCache;
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
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    function MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer; override;
  published
    property AutoHeight: Boolean read FAutoHeight write FAutoHeight default True;
    property MinHeight:  Integer read FMinHeight  write FMinHeight  default 20;
  end;

{ ================= Sub-report Object (nested report + own dataset) ========= }

  TReportSubReportObject = class(TReportObject)
  private
    FReportJSON:    string;
    FDataSetName:   string;
    FMasterField:   string;
    FDetailField:   string;
    FTransparent:   Boolean;
    FBackground:    TColor;
    FBorderVisible: Boolean;
    FBorderColor:   TColor;
    FBorderWidth:   Integer;
  public
    constructor Create; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    function MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer; override;
    class function DisplayName: string; override;
  published
    property ReportJSON:  string  read FReportJSON  write FReportJSON;
    property DataSetName: string  read FDataSetName write FDataSetName;
    property MasterField: string  read FMasterField write FMasterField;
    property DetailField: string  read FDetailField write FDetailField;
    property Transparent: Boolean read FTransparent write FTransparent default True;
    property Background:  TColor  read FBackground  write FBackground  default clWhite;
    property BorderVisible: Boolean read FBorderVisible write FBorderVisible default True;
    property BorderColor: TColor read FBorderColor write FBorderColor default clSilver;
    property BorderWidth: Integer read FBorderWidth write FBorderWidth default 1;
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
  Vittix.Report.Serializer,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Utils,
  Winapi.Windows, // Keep here
  System.Variants, // Keep here
  System.SyncObjs;

var
  GRegistry: TList<TReportObjectClass>;
  GRegistryCS: TCriticalSection;
  GNamedDataSets: TDictionary<string, TDataSet>;
  GBeforeObjectPrint: TReportObjectBeforePrintEvent;
  GAfterObjectPrint: TReportObjectAfterPrintEvent;
  GPrecheckedObjectForPrintWhen: TReportObject;

{$IFDEF DEBUG}
procedure DebugLogDataFieldIssue(AObj: TReportObject; const ADataField, AReason: string;
  ADataSet: TDataSet);
begin
  if not Assigned(AObj) then
    Exit;
  Vittix.Report.Utils.DebugLogDataFieldIssue(AObj.ClassName, AObj.Name, ADataField, AReason, ADataSet);
end;
{$ENDIF}

function ShouldPrintObject(AObj: TReportObject;
  const Context: TExpressionContext): Boolean; forward;

procedure SetReportObjectRenderHooks(
  const ABeforePrint: TReportObjectBeforePrintEvent;
  const AAfterPrint: TReportObjectAfterPrintEvent);
begin
  GBeforeObjectPrint := ABeforePrint;
  GAfterObjectPrint := AAfterPrint;
end;

procedure ClearReportObjectRenderHooks;
begin
  GBeforeObjectPrint := nil;
  GAfterObjectPrint := nil;
end;

procedure DrawReportObjectWithHooks(
  AObject: TReportObject;
  C: TCanvas;
  const Context: TExpressionContext);
var
  CanPrint: Boolean;
begin
  if not Assigned(AObject) then
    Exit;

  // Required execution order:
  // PrintWhen -> persisted/runtime before-hooks -> draw -> persisted/runtime after-hooks.
  // Evaluate PrintWhen first so object hooks are skipped when the object will not print.
  if not ShouldPrintObject(AObject, Context) then
    Exit;

  CanPrint := True;
  if Assigned(GBeforeObjectPrint) then
    GBeforeObjectPrint(AObject, Context, CanPrint);
  if not CanPrint then
    Exit;

  GPrecheckedObjectForPrintWhen := AObject;
  try
    AObject.Draw(C, Context);
  finally
    GPrecheckedObjectForPrintWhen := nil;
  end;

  if Assigned(GAfterObjectPrint) then
    GAfterObjectPrint(AObject, Context);
end;

procedure EnsureRegistryInitialized;
begin
  if not Assigned(GRegistryCS) or not Assigned(GRegistry) then
    raise EInvalidOperation.Create('Report object registry is not initialized');
end;

{ ================= Registry ================= }

procedure RegisterReportObject(AClass: TReportObjectClass);
begin
  EnsureRegistryInitialized;
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
  EnsureRegistryInitialized;
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
  FOnBeforePrint := '';
  FOnAfterPrint := '';
  FAnchorRight  := False;
  FAnchorBottom := False;
  FPageBreakBefore := False;
  FPageBreakAfter  := False;
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
  FFontColorCondition   := '';
  FFontColorOnTrue      := clRed;
  FBackgroundCondition  := '';
  FBackgroundOnTrue     := clYellow;
  FBorderColorCondition := '';
  FBorderColorOnTrue    := clRed;
end;

function EvaluateConditionExpression(const Expr: string;
  const Context: TExpressionContext): Boolean;
var
  V: Variant;
begin
  if Trim(Expr) = '' then Exit(False);
  try
    V := TReportExpression.Evaluate(Expr, Context);
    Result := ConditionVariantToBool(V);
  except
    Result := False;
  end;
end;

function ShouldPrintObject(AObj: TReportObject;
  const Context: TExpressionContext): Boolean;
var
  PWResult: Variant;
begin
  Result := False;
  if not Assigned(AObj) then
    Exit;

  if AObj = GPrecheckedObjectForPrintWhen then
    Exit(True);

  if not AObj.Visible then
    Exit;

  if Trim(AObj.PrintWhen) = '' then
  begin
    Result := True;
    Exit;
  end;

  try
    PWResult := TReportExpression.Evaluate(AObj.PrintWhen, Context);
  except
    Exit(False);
  end;

  if VarIsNull(PWResult) or VarIsEmpty(PWResult) then
    Exit(False);

  Result := ConditionVariantToBool(PWResult);
end;

procedure TReportTextObject.ResolveConditionalStyle(
  const Context: TExpressionContext;
  out AFontColor: TColor;
  out ABackground: TColor;
  out ABorderColor: TColor);
begin
  AFontColor := FFont.Color;
  ABackground := FBackground;
  ABorderColor := FBorderColor;

  if EvaluateConditionExpression(FFontColorCondition, Context) then
    AFontColor := FFontColorOnTrue;
  if EvaluateConditionExpression(FBackgroundCondition, Context) then
    ABackground := FBackgroundOnTrue;
  if EvaluateConditionExpression(FBorderColorCondition, Context) then
    ABorderColor := FBorderColorOnTrue;
end;

function FormatFieldDisplayValue(
  const AValue: Variant;
  const ADisplayFormat: string;
  const AEditMask: string): string;
var
  ValueVarType: TVarType;
  NumericValue: Double;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit('');

  Result := VarToStr(AValue);

  if ADisplayFormat <> '' then
  begin
    try
      // Normalize by-ref variants so date/datetime values are detected reliably.
      ValueVarType := VarType(AValue) and varTypeMask;

      if ValueVarType = varDate then
        Result := FormatDateTime(ADisplayFormat, VarToDateTime(AValue))
      else
      begin
        // Guard numeric conversion before FormatFloat to keep failures non-fatal.
        NumericValue := VarAsType(AValue, varDouble);
        Result := FormatFloat(ADisplayFormat, NumericValue);
      end;
    except
      on Exception do
      begin
        try
          Result := System.SysUtils.Format(ADisplayFormat, [VarToStr(AValue)]);
        except
          Result := VarToStr(AValue);
        end;
      end;
    end;
  end;

  if (AEditMask <> '') and (Result <> '') then
  begin
    try
      Result := System.MaskUtils.FormatMaskText(AEditMask, Result);
    except
      // Keep unmasked text if mask format fails.
    end;
  end;
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
  DrawFontColor: TColor;
  DrawBackground: TColor;
  DrawBorderColor: TColor;
{$IFDEF DEBUG}
  Fld: TField;
  DiagStr: string;
  DiagVal: Variant;
{$ENDIF}
begin
  if not ShouldPrintObject(Self, Context) then Exit;

  R := FBounds;
  ResolveConditionalStyle(Context, DrawFontColor, DrawBackground, DrawBorderColor);

  // Background
  if not FTransparent then
  begin
    C.Brush.Style := bsSolid;
    C.Brush.Color := DrawBackground;
    C.FillRect(R);
  end
  else
    C.Brush.Style := bsClear;

  // Border
  if FBorderVisible then
  begin
    C.Pen.Color   := DrawBorderColor;
    C.Pen.Width   := FBorderWidth;
    C.Pen.Style   := psSolid;
    C.Brush.Style := bsClear;
    C.Rectangle(R);
  end;

  // Resolve text value
  if FExpression <> '' then
    S := VarToStr(TReportExpression.Evaluate(FExpression, Context))
  else if (FDataField <> '') and Assigned(Context.DataSet) and Context.DataSet.Active then
  begin
{$IFDEF DEBUG}
    if not TryGetField(Context.DataSet, FDataField, Fld) then
      DebugLogDataFieldIssue(Self, FDataField, 'field missing', Context.DataSet);
    if Assigned(Fld) then
      try
        if Self is TReportFieldObject then
          DiagVal := Fld.Value
        else
          DiagStr := Fld.AsString;
      except
        DebugLogDataFieldIssue(Self, FDataField, 'field value conversion/read error', Context.DataSet);
      end;
{$ENDIF}
    if Self is TReportFieldObject then
      S := FormatFieldDisplayValue(
        SafeFieldValue(Context.DataSet, FDataField),
        TReportFieldObject(Self).FDisplayFormat,
        TReportFieldObject(Self).FEditMask)
    else
      S := SafeFieldAsString(Context.DataSet, FDataField);
  end
{$IFDEF DEBUG}
  else if FDataField <> '' then
  begin
    if not Assigned(Context.DataSet) then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset nil', Context.DataSet)
    else if not Context.DataSet.Active then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset inactive', Context.DataSet);
    S := FText;
  end
{$ENDIF}
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
  C.Font.Color := DrawFontColor;
  C.Brush.Style := bsClear;

  // AutoSize: measure text and grow bounds downward
  if FAutoSize and FWordWrap then
  begin
    TxtH := DrawText(C.Handle, PChar(S), Length(S), TR, Fmt or DT_CALCRECT);
    if TxtH > 0 then
    begin
      R.Bottom := R.Top + TxtH + FPaddingTop + FPaddingBottom;
      TR := Rect(R.Left + FPaddingLeft, R.Top + FPaddingTop,
                 R.Right - FPaddingRight, R.Bottom - FPaddingBottom);
    end;
  end;

  if FWordWrap then
    DrawText(C.Handle, PChar(S), Length(S), TR, Fmt)
  else
  begin
    var X := TR.Left;
    var Y := TR.Top;
    var TW := C.TextWidth(S);
    var TH := C.TextHeight(S);

    case FHAlign of
      taRightJustify: X := TR.Right - TW;
      taCenter:       X := TR.Left + ((TR.Right - TR.Left - TW) div 2);
    end;

    case FVAlign of
      taAlignBottom:   Y := TR.Bottom - TH;
      taVerticalCenter:Y := TR.Top + ((TR.Bottom - TR.Top - TH) div 2);
    end;

    if X < TR.Left then X := TR.Left;
    if Y < TR.Top then Y := TR.Top;
    C.TextOut(X, Y, S);
  end;

  if FSelected then DrawSelection(C);
end;

class function TReportTextObject.DisplayName: string;
begin
  Result := 'Text';
end;

function TReportTextObject.MeasuredBottom(C: TCanvas;
  const Context: TExpressionContext): Integer;
var
  S: string;
  R: TRect;
  Fmt: UINT;
  TxtH: Integer;
begin
  Result := FBounds.Bottom;
  if not ShouldPrintObject(Self, Context) then Exit;
  if not (FAutoSize and FWordWrap) then Exit;
  if not Assigned(C) then Exit;

  if FExpression <> '' then
    S := VarToStr(TReportExpression.Evaluate(FExpression, Context))
  else if (FDataField <> '') and Assigned(Context.DataSet) and Context.DataSet.Active then
  begin
    if Self is TReportFieldObject then
      S := FormatFieldDisplayValue(
        SafeFieldValue(Context.DataSet, FDataField),
        TReportFieldObject(Self).FDisplayFormat,
        TReportFieldObject(Self).FEditMask)
    else
      S := SafeFieldAsString(Context.DataSet, FDataField);
  end
  else
    S := FText;

  R := Rect(FBounds.Left + FPaddingLeft, FBounds.Top + FPaddingTop,
            FBounds.Right - FPaddingRight, FBounds.Bottom - FPaddingBottom);

  case FHAlign of
    taLeftJustify:  Fmt := DT_LEFT;
    taRightJustify: Fmt := DT_RIGHT;
    taCenter:       Fmt := DT_CENTER;
  else
    Fmt := DT_LEFT;
  end;
  Fmt := Fmt or DT_WORDBREAK;

  C.Font.Assign(FFont);
  TxtH := DrawText(C.Handle, PChar(S), Length(S), R, Fmt or DT_CALCRECT);
  if TxtH > 0 then
    Result := FBounds.Top + TxtH + FPaddingTop + FPaddingBottom;
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
  FDisplayFormat := '';
  FEditMask      := '';
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
  if not ShouldPrintObject(Self, Context) then Exit;

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
  FCachedPicture := TPicture.Create;
  FCachedImagePath := '';
  FCachedImageValid := False;
  FCachedImageAttempted := False;
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
  FCachedPicture.Free;
  FPicture.Free;
  inherited;
end;

procedure TReportImageObject.ResetImageCache;
begin
  FCachedImagePath := '';
  FCachedImageValid := False;
  FCachedImageAttempted := False;
  FCachedPicture.Assign(nil);
  FPicture.Assign(nil);
end;

procedure TReportImageObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  R:              TRect;
  PW, PH, BW, BH: Integer;
  ScaleX, ScaleY, Scale: Double;
  PathOrBase64:   string;
{$IFDEF DEBUG}
  Fld: TField;
  DiagStr: string;
{$ENDIF}
begin
  if not ShouldPrintObject(Self, Context) then Exit;

  R := FBounds;

  // Try loading from DataField at runtime
  if FDataField <> '' then
  begin
{$IFDEF DEBUG}
    if not Assigned(Context.DataSet) then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset nil', Context.DataSet)
    else if not Context.DataSet.Active then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset inactive', Context.DataSet)
    else if not TryGetField(Context.DataSet, FDataField, Fld) then
      DebugLogDataFieldIssue(Self, FDataField, 'field missing', Context.DataSet);
    if Assigned(Fld) then
      try
        DiagStr := Fld.AsString;
      except
        DebugLogDataFieldIssue(Self, FDataField, 'field value conversion/read error', Context.DataSet);
      end;
{$ENDIF}
    PathOrBase64 := SafeFieldAsString(Context.DataSet, FDataField);
    FPicture.Assign(nil); // avoid stale image reuse when field is blank/missing/null

    if PathOrBase64 = '' then
    begin
      // Blank/missing/null field: keep empty and do not reuse prior row image.
    end
    else if (FCachedImageAttempted) and SameText(PathOrBase64, FCachedImagePath) then
    begin
      if FCachedImageValid then
        FPicture.Assign(FCachedPicture);
      // Cached invalid path stays empty.
    end
    else
    begin
      FCachedImagePath := PathOrBase64;
      FCachedImageAttempted := True;
      FCachedImageValid := False;
      FCachedPicture.Assign(nil);

      if FileExists(PathOrBase64) then
      begin
        try
          FCachedPicture.LoadFromFile(PathOrBase64);
          FCachedImageValid := Assigned(FCachedPicture.Graphic) and
                               (not FCachedPicture.Graphic.Empty);
          if FCachedImageValid then
            FPicture.Assign(FCachedPicture);
        except
          // silently ignore invalid image data/path
          FCachedImageValid := False;
          FCachedPicture.Assign(nil);
        end;
      end;
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

type
  TMemoRun = record
    Text: string;
    Style: TFontStyles;
    IsBreak: Boolean;
  end;

  TMemoSeg = record
    Text: string;
    Style: TFontStyles;
    Width: Integer;
  end;

  TMemoLine = record
    Segments: TArray<TMemoSeg>;
    Width: Integer;
    Height: Integer;
  end;

procedure AddMemoRun(var Runs: TArray<TMemoRun>; const AText: string;
  const AStyle: TFontStyles; AIsBreak: Boolean);
var
  L: Integer;
begin
  if (AText = '') and (not AIsBreak) then Exit;
  L := Length(Runs);
  SetLength(Runs, L + 1);
  Runs[L].Text := AText;
  Runs[L].Style := AStyle;
  Runs[L].IsBreak := AIsBreak;
end;

function DecodeHtmlEntities(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll, rfIgnoreCase]);
end;

function ResolveMemoText(AMemo: TReportMemoObject;
  const Context: TExpressionContext): string;
{$IFDEF DEBUG}
var
  Fld: TField;
  DiagStr: string;
{$ENDIF}
begin
  if AMemo.FExpression <> '' then
    Result := VarToStr(TReportExpression.Evaluate(AMemo.FExpression, Context))
  else if (AMemo.FDataField <> '') and Assigned(Context.DataSet)
       and Context.DataSet.Active then
  begin
{$IFDEF DEBUG}
    if not TryGetField(Context.DataSet, AMemo.FDataField, Fld) then
      DebugLogDataFieldIssue(AMemo, AMemo.FDataField, 'field missing', Context.DataSet);
    if Assigned(Fld) then
      try
        DiagStr := Fld.AsString;
      except
        DebugLogDataFieldIssue(AMemo, AMemo.FDataField, 'field value conversion/read error', Context.DataSet);
      end;
{$ENDIF}
    Result := SafeFieldAsString(Context.DataSet, AMemo.FDataField)
  end
{$IFDEF DEBUG}
  else if AMemo.FDataField <> '' then
  begin
    if not Assigned(Context.DataSet) then
      DebugLogDataFieldIssue(AMemo, AMemo.FDataField, 'dataset nil', Context.DataSet)
    else if not Context.DataSet.Active then
      DebugLogDataFieldIssue(AMemo, AMemo.FDataField, 'dataset inactive', Context.DataSet);
    Result := AMemo.FText;
  end
{$ENDIF}
  else
    Result := AMemo.FText;
end;

procedure ParseMemoRuns(const S: string; const BaseStyle: TFontStyles;
  out Runs: TArray<TMemoRun>);
var
  I, J: Integer;
  Buf: string;
  Tag: string;
  CurStyle: TFontStyles;
begin
  SetLength(Runs, 0);
  CurStyle := BaseStyle;
  Buf := '';
  I := 1;

  while I <= Length(S) do
  begin
    if (S[I] = '<') then
    begin
      J := I + 1;
      while (J <= Length(S)) and (S[J] <> '>') do Inc(J);
      if J <= Length(S) then
      begin
        AddMemoRun(Runs, DecodeHtmlEntities(Buf), CurStyle, False);
        Buf := '';

        Tag := LowerCase(Trim(Copy(S, I + 1, J - I - 1)));

        if (Tag = 'b') then
          Include(CurStyle, fsBold)
        else if (Tag = '/b') then
          Exclude(CurStyle, fsBold)
        else if (Tag = 'i') then
          Include(CurStyle, fsItalic)
        else if (Tag = '/i') then
          Exclude(CurStyle, fsItalic)
        else if (Tag = 'u') then
          Include(CurStyle, fsUnderline)
        else if (Tag = '/u') then
          Exclude(CurStyle, fsUnderline)
        else if (Tag = 'br') or (Tag = 'br/') or (Tag = 'br /') then
          AddMemoRun(Runs, '', CurStyle, True)
        else if (Tag = 'p') or (Tag = '/p') then
          AddMemoRun(Runs, '', CurStyle, True)
        else
          Buf := Buf + Copy(S, I, J - I + 1);

        I := J + 1;
        Continue;
      end;
    end;

    if (S[I] = #13) or (S[I] = #10) then
    begin
      AddMemoRun(Runs, DecodeHtmlEntities(Buf), CurStyle, False);
      Buf := '';
      AddMemoRun(Runs, '', CurStyle, True);
      if (S[I] = #13) and (I < Length(S)) and (S[I + 1] = #10) then
        Inc(I);
    end
    else
      Buf := Buf + S[I];

    Inc(I);
  end;

  AddMemoRun(Runs, DecodeHtmlEntities(Buf), CurStyle, False);
end;

function StyledTextWidth(C: TCanvas; BaseFont: TFont; const S: string;
  const Style: TFontStyles): Integer;
begin
  if S = '' then Exit(0);
  C.Font.Assign(BaseFont);
  C.Font.Style := Style;
  Result := C.TextWidth(S);
end;

function StyledTextHeight(C: TCanvas; BaseFont: TFont;
  const Style: TFontStyles): Integer;
begin
  C.Font.Assign(BaseFont);
  C.Font.Style := Style;
  Result := C.TextHeight('Hg');
end;

procedure AddLineSegment(var Line: TMemoLine; C: TCanvas; BaseFont: TFont;
  const S: string; const Style: TFontStyles);
var
  L: Integer;
  W: Integer;
  H: Integer;
begin
  if S = '' then Exit;

  W := StyledTextWidth(C, BaseFont, S, Style);
  H := StyledTextHeight(C, BaseFont, Style);

  L := Length(Line.Segments);
  if (L > 0) and (Line.Segments[L - 1].Style = Style) then
  begin
    Line.Segments[L - 1].Text := Line.Segments[L - 1].Text + S;
    Line.Segments[L - 1].Width := Line.Segments[L - 1].Width + W;
  end
  else
  begin
    SetLength(Line.Segments, L + 1);
    Line.Segments[L].Text := S;
    Line.Segments[L].Style := Style;
    Line.Segments[L].Width := W;
  end;

  Inc(Line.Width, W);
  if H > Line.Height then
    Line.Height := H;
end;

procedure PushLine(var Lines: TArray<TMemoLine>; var Line: TMemoLine;
  DefaultHeight: Integer; ForceEmpty: Boolean);
var
  L: Integer;
begin
  if (Length(Line.Segments) = 0) and (not ForceEmpty) then Exit;
  if Line.Height <= 0 then
    Line.Height := DefaultHeight;
  L := Length(Lines);
  SetLength(Lines, L + 1);
  Lines[L] := Line;
  Line.Segments := nil;
  Line.Width := 0;
  Line.Height := DefaultHeight;
end;

procedure BuildMemoLines(C: TCanvas; BaseFont: TFont; const Text: string;
  MaxWidth: Integer; WordWrap: Boolean; out Lines: TArray<TMemoLine>;
  out TotalHeight: Integer);
var
  Runs: TArray<TMemoRun>;
  Run: TMemoRun;
  Line: TMemoLine;
  I, J: Integer;
  Token: string;
  IsSpace: Boolean;
  DefaultH: Integer;
  Ch: Char;
begin
  SetLength(Lines, 0);
  TotalHeight := 0;

  ParseMemoRuns(Text, BaseFont.Style, Runs);

  DefaultH := StyledTextHeight(C, BaseFont, BaseFont.Style);
  if DefaultH <= 0 then DefaultH := 14;
  if MaxWidth <= 0 then MaxWidth := 1;

  Line.Segments := nil;
  Line.Width := 0;
  Line.Height := DefaultH;

  for Run in Runs do
  begin
    if Run.IsBreak then
    begin
      PushLine(Lines, Line, DefaultH, True);
      Continue;
    end;

    I := 1;
    while I <= Length(Run.Text) do
    begin
      IsSpace := (Run.Text[I] = ' ') or (Run.Text[I] = #9);
      J := I;
      while (J <= Length(Run.Text))
            and (((Run.Text[J] = ' ') or (Run.Text[J] = #9)) = IsSpace) do
        Inc(J);
      Token := Copy(Run.Text, I, J - I);

      if not WordWrap then
      begin
        AddLineSegment(Line, C, BaseFont, Token, Run.Style);
      end
      else
      begin
        if IsSpace and (Line.Width = 0) then
        begin
          I := J;
          Continue;
        end;

        var TokenW := StyledTextWidth(C, BaseFont, Token, Run.Style);

        if (Line.Width + TokenW <= MaxWidth) or (Line.Width = 0) then
          AddLineSegment(Line, C, BaseFont, Token, Run.Style)
        else if IsSpace then
          PushLine(Lines, Line, DefaultH, False)
        else if TokenW <= MaxWidth then
        begin
          PushLine(Lines, Line, DefaultH, False);
          AddLineSegment(Line, C, BaseFont, Token, Run.Style);
        end
        else
        begin
          for Ch in Token do
          begin
            var CharText := string(Ch);
            var CharW := StyledTextWidth(C, BaseFont, CharText, Run.Style);
            if (Line.Width > 0) and (Line.Width + CharW > MaxWidth) then
              PushLine(Lines, Line, DefaultH, False);
            AddLineSegment(Line, C, BaseFont, CharText, Run.Style);
          end;
        end;
      end;

      I := J;
    end;
  end;

  PushLine(Lines, Line, DefaultH, False);
  for I := 0 to High(Lines) do
    Inc(TotalHeight, Lines[I].Height);
end;

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

procedure TReportMemoObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  S: string;
  R, TR: TRect;
  Lines: TArray<TMemoLine>;
  TotalH: Integer;
  Y, X: Integer;
  I, J: Integer;
  MaxWidth: Integer;
  DrawFontColor: TColor;
  DrawBackground: TColor;
  DrawBorderColor: TColor;
begin
  if not ShouldPrintObject(Self, Context) then Exit;

  R := FBounds;
  ResolveConditionalStyle(Context, DrawFontColor, DrawBackground, DrawBorderColor);

  if not FTransparent then
  begin
    C.Brush.Style := bsSolid;
    C.Brush.Color := DrawBackground;
    C.FillRect(R);
  end
  else
    C.Brush.Style := bsClear;

  if FBorderVisible then
  begin
    C.Pen.Color   := DrawBorderColor;
    C.Pen.Width   := FBorderWidth;
    C.Pen.Style   := psSolid;
    C.Brush.Style := bsClear;
    C.Rectangle(R);
  end;

  S := ResolveMemoText(Self, Context);

  TR := Rect(R.Left  + FPaddingLeft,
             R.Top   + FPaddingTop,
             R.Right - FPaddingRight,
             R.Bottom- FPaddingBottom);
  MaxWidth := TR.Right - TR.Left;
  if MaxWidth <= 0 then
  begin
    if FSelected then DrawSelection(C);
    Exit;
  end;

  BuildMemoLines(C, FFont, S, MaxWidth, FWordWrap, Lines, TotalH);

  Y := TR.Top;
  if not FWordWrap then
    case FVAlign of
      taAlignBottom:    Y := TR.Bottom - TotalH;
      taVerticalCenter: Y := TR.Top + ((TR.Bottom - TR.Top - TotalH) div 2);
    end;

  if Y < TR.Top then Y := TR.Top;

  SaveDC(C.Handle);
  try
    IntersectClipRect(C.Handle, TR.Left, TR.Top, TR.Right, TR.Bottom);

    for I := 0 to High(Lines) do
    begin
      case FHAlign of
        taRightJustify: X := TR.Right - Lines[I].Width;
        taCenter:       X := TR.Left + ((MaxWidth - Lines[I].Width) div 2);
      else
        X := TR.Left;
      end;
      if X < TR.Left then X := TR.Left;

      for J := 0 to High(Lines[I].Segments) do
      begin
        C.Font.Assign(FFont);
        C.Font.Color := DrawFontColor;
        C.Font.Style := Lines[I].Segments[J].Style;
        C.Brush.Style := bsClear;
        C.TextOut(X, Y, Lines[I].Segments[J].Text);
        Inc(X, Lines[I].Segments[J].Width);
      end;

      Inc(Y, Lines[I].Height);
      if Y >= TR.Bottom then Break;
    end;
  finally
    RestoreDC(C.Handle, -1);
  end;

  if FSelected then DrawSelection(C);
end;

function TReportMemoObject.MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer;
var
  S: string;
  Lines: TArray<TMemoLine>;
  TotalH: Integer;
  MaxWidth: Integer;
  Needed: Integer;
begin
  Result := FBounds.Bottom;
  if not ShouldPrintObject(Self, Context) then Exit;
  if not FAutoHeight then Exit;
  if not Assigned(C) then Exit;

  S := ResolveMemoText(Self, Context);

  if S = '' then
  begin
    if FMinHeight > 0 then
      Result := FBounds.Top + FMinHeight;
    Exit;
  end;

  MaxWidth := (FBounds.Right - FBounds.Left) - FPaddingLeft - FPaddingRight;
  if MaxWidth <= 0 then
  begin
    if FMinHeight > 0 then
      Result := FBounds.Top + FMinHeight;
    Exit;
  end;

  BuildMemoLines(C, FFont, S, MaxWidth, FWordWrap, Lines, TotalH);

  if TotalH > 0 then
  begin
    Needed := TotalH + FPaddingTop + FPaddingBottom;
    if Needed < FMinHeight then Needed := FMinHeight;
    Result  := FBounds.Top + Needed;
  end
  else if FMinHeight > 0 then
    Result := FBounds.Top + FMinHeight;
end;

procedure SetReportNamedDataSets(ANamedDataSets: TDictionary<string, TDataSet>);
begin
  GNamedDataSets := ANamedDataSets;
end;

{ ================= Sub-report Object ================= }

function ResolveSubReportDataSet(Obj: TReportSubReportObject;
  const Context: TExpressionContext): TDataSet;
begin
  Result := Context.DataSet;
  if Trim(Obj.FDataSetName) = '' then
    Exit;

  Result := nil;
  try
    if Assigned(GNamedDataSets) then
      if not GNamedDataSets.TryGetValue(Obj.FDataSetName, Result) then
        Result := nil;
  except
    Result := nil;
  end;
end;

function FindSubReportMasterBand(AModel: TReportModel): TReportBand;
var
  Obj: TReportObject;
begin
  Result := nil;
  if not Assigned(AModel) then Exit;

  for Obj in AModel.Objects do
    if (Obj is TReportBand) and (TReportBand(Obj).BandType = btMasterData) then
      Exit(TReportBand(Obj));

  for Obj in AModel.Objects do
    if (Obj is TReportBand) and (TReportBand(Obj).BandType = btDetail) then
      Exit(TReportBand(Obj));
end;

constructor TReportSubReportObject.Create;
begin
  inherited;
  FReportJSON    := '';
  FDataSetName   := '';
  FMasterField   := '';
  FDetailField   := '';
  FTransparent   := True;
  FBackground    := clWhite;
  FBorderVisible := True;
  FBorderColor   := clSilver;
  FBorderWidth   := 1;
  FBounds        := Rect(10, 10, 260, 110);
end;

class function TReportSubReportObject.DisplayName: string;
begin
  Result := 'SubReport';
end;

function SubReportRowMatchesLink(AMasterDS, ADetailDS: TDataSet;
  const AMasterField, ADetailField: string): Boolean;
begin
  if not Assigned(AMasterDS) or not AMasterDS.Active then Exit(True);
  if (AMasterField = '') or (ADetailField = '') then Exit(True);
  if not Assigned(AMasterDS.FindField(AMasterField)) then Exit(True);
  if not Assigned(ADetailDS.FindField(ADetailField)) then Exit(True);

  Result := VarSameValue(
    AMasterDS.FieldByName(AMasterField).Value,
    ADetailDS.FieldByName(ADetailField).Value);
end;

procedure TReportSubReportObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  R: TRect;
  Model: TReportModel;
  MasterBand: TReportBand;
  DS: TDataSet;
  SaveBM: TBookmark;
  HasSaveBM: Boolean;
  DrawY: Integer;
  SubCtx: TExpressionContext;
begin
  if not ShouldPrintObject(Self, Context) then Exit;
  if Context.IsCountingPass then Exit;

  R := FBounds;
  if not FTransparent then
  begin
    C.Brush.Style := bsSolid;
    C.Brush.Color := FBackground;
    C.FillRect(R);
  end;

  if Trim(FReportJSON) = '' then
  begin
    if FBorderVisible then
    begin
      C.Pen.Color := FBorderColor;
      C.Pen.Width := FBorderWidth;
      C.Brush.Style := bsClear;
      C.Rectangle(R);
    end;
    if FSelected then DrawSelection(C);
    Exit;
  end;

  Model := nil;
  try
    try
      Model := TReportSerializer.LoadFromJSON(FReportJSON);
    except
      Exit;
    end;
    MasterBand := FindSubReportMasterBand(Model);
    if not Assigned(MasterBand) then Exit;

    DS := ResolveSubReportDataSet(Self, Context);
    if not Assigned(DS) or not DS.Active then Exit;

    SaveBM := nil;
    HasSaveBM := False;
    if DataSetSupportsBookmarks(DS) then
    begin
      SaveBM := DS.GetBookmark;
      HasSaveBM := True;
    end;

    DrawY := R.Top + 2;
    SaveDC(C.Handle);
    try
      IntersectClipRect(C.Handle, R.Left, R.Top, R.Right, R.Bottom);
      DS.DisableControls;
      try
        DS.First;
        while (not DS.Eof) and (DrawY < R.Bottom) do
        begin
          if SubReportRowMatchesLink(Context.DataSet, DS, FMasterField, FDetailField) then
          begin
            SubCtx := Context;
            SubCtx.DataSet := DS;
            SaveDC(C.Handle);
            try
              SetViewportOrgEx(C.Handle, R.Left + 2, DrawY, nil);
              MasterBand.Draw(C, SubCtx);
            finally
              RestoreDC(C.Handle, -1);
            end;
            Inc(DrawY, MasterBand.Height);
          end;
          DS.Next;
        end;
      finally
        DS.EnableControls;
      end;
    finally
      RestoreDC(C.Handle, -1);
      if HasSaveBM and (SaveBM <> nil) and DS.BookmarkValid(SaveBM) then
        DS.GotoBookmark(SaveBM);
      if HasSaveBM and (SaveBM <> nil) then
        DS.FreeBookmark(SaveBM);
    end;
  finally
    Model.Free;
  end;

  if FBorderVisible then
  begin
    C.Pen.Color := FBorderColor;
    C.Pen.Width := FBorderWidth;
    C.Brush.Style := bsClear;
    C.Rectangle(R);
  end;

  if FSelected then DrawSelection(C);
end;

function TReportSubReportObject.MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer;
var
  Model: TReportModel;
  MasterBand: TReportBand;
  DS: TDataSet;
  SaveBM: TBookmark;
  HasSaveBM: Boolean;
  RowCount: Integer;
  NeededH: Integer;
begin
  Result := FBounds.Bottom;
  if not ShouldPrintObject(Self, Context) then Exit;
  if Context.IsCountingPass then Exit;
  if Trim(FReportJSON) = '' then Exit;

  Model := nil;
  try
    try
      Model := TReportSerializer.LoadFromJSON(FReportJSON);
    except
      Exit;
    end;
    MasterBand := FindSubReportMasterBand(Model);
    if not Assigned(MasterBand) then Exit;

    DS := ResolveSubReportDataSet(Self, Context);
    if not Assigned(DS) or not DS.Active then Exit;

    SaveBM := nil;
    HasSaveBM := False;
    if DataSetSupportsBookmarks(DS) then
    begin
      SaveBM := DS.GetBookmark;
      HasSaveBM := True;
    end;

    RowCount := 0;
    DS.DisableControls;
    try
      DS.First;
      while not DS.Eof do
      begin
        if SubReportRowMatchesLink(Context.DataSet, DS, FMasterField, FDetailField) then
          Inc(RowCount);
        DS.Next;
      end;
    finally
      DS.EnableControls;
      if HasSaveBM and (SaveBM <> nil) and DS.BookmarkValid(SaveBM) then
        DS.GotoBookmark(SaveBM);
      if HasSaveBM and (SaveBM <> nil) then
        DS.FreeBookmark(SaveBM);
    end;

    NeededH := 4 + (RowCount * MasterBand.Height);
    if NeededH < (FBounds.Bottom - FBounds.Top) then
      NeededH := (FBounds.Bottom - FBounds.Top);
    Result := FBounds.Top + NeededH;
  finally
    Model.Free;
  end;
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
  if not ShouldPrintObject(Self, Context) then Exit;
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
  GRegistryCS := TCriticalSection.Create;
  GRegistry := TList<TReportObjectClass>.Create;
  RegisterReportObject(TReportTextObject);
  RegisterReportObject(TReportLabelObject);
  RegisterReportObject(TReportFieldObject);
  RegisterReportObject(TReportShapeObject);
  RegisterReportObject(TReportImageObject);
  RegisterReportObject(TReportMemoObject);
  RegisterReportObject(TReportSubReportObject);
  RegisterReportObject(TReportLineObject);

finalization
  FreeAndNil(GRegistry);
  FreeAndNil(GRegistryCS);

end.
