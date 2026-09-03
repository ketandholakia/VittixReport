unit Vittix.Report.Objects;

interface

uses
  System.UITypes, System.Classes,
  System.Types,
  System.SysUtils,
  System.NetEncoding,
  System.StrUtils,
  System.Generics.Collections,
  System.MaskUtils,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Imaging.GIFImg,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage,
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
    FLocked:      Boolean;
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
    property Locked:       Boolean read FLocked       write FLocked       default False;
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
{ Phase 4G-1: SetReportNamedDataSets, SetReportObjectRenderHooks,
  and ClearReportObjectRenderHooks were the public mutators of the four
  removed render globals. They had no callers inside the repository and
  have been deleted. Named datasets and before/after object hooks are now
  reached exclusively through TExpressionContext.Hooks (IReportRenderHooks)
  which the engine populates on every render path. }
{ Phase 4G-1: pure predicate for an object printWhen evaluation.
  Exposed publicly only so the dedicated render-internals test fixture
  can drive it directly. The guard short-circuit for the in-flight
  AObject is read from Context.PrecheckedObjectForPrintWhen. }
function ShouldPrintObject(AObj: TReportObject;
  const Context: TExpressionContext): Boolean;

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
    function ResolveDisplayText(const Context: TExpressionContext): string;
    procedure ResolveTextStyle(
      const Context: TExpressionContext;
      out AFontColor: TColor;
      out ABackground: TColor;
      out ABorderColor: TColor);
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
    function ResolveImageSource(const Context: TExpressionContext): string;
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
    FAllowHTML:  Boolean;
  public
    constructor Create; override;
    class function DisplayName: string; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    function MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer; override;
  published
    property AutoHeight: Boolean read FAutoHeight write FAutoHeight default True;
    property MinHeight:  Integer read FMinHeight  write FMinHeight  default 20;
    property AllowHTML:  Boolean read FAllowHTML  write FAllowHTML  default False;
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
    FExtendToPageBottom: Boolean;
  public
    constructor Create; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    class function DisplayName: string; override;
  published
    property Orientation: TLineOrientation read FOrientation write FOrientation default loHorizontal;
    property LineColor:   TColor           read FLineColor   write FLineColor;
    property LineWidth:   Integer          read FLineWidth   write FLineWidth   default 1;
    property LineStyle:   TPenStyle        read FLineStyle   write FLineStyle   default psSolid;
    property ExtendToPageBottom: Boolean   read FExtendToPageBottom write FExtendToPageBottom default False;
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

{$IFDEF DEBUG}
procedure DebugLogDataFieldIssue(AObj: TReportObject; const ADataField, AReason: string;
  ADataSet: TDataSet);
begin
  if not Assigned(AObj) then
    Exit;
  Vittix.Report.Utils.DebugLogDataFieldIssue(AObj.ClassName, AObj.Name, ADataField, AReason, ADataSet);
end;
{$ENDIF}

procedure DrawReportObjectWithHooks(
  AObject: TReportObject;
  C: TCanvas;
  const Context: TExpressionContext);
var
  CanPrint: Boolean;
  // Phase 4G-1: per-render reentrancy guard. Mutated on a local copy
  // so the callers const Context is not modified.
  Ctx: TExpressionContext;
begin
  if not Assigned(AObject) then
    Exit;

  // Required execution order:
  // PrintWhen -> persisted/runtime before-hooks -> draw -> persisted/runtime after-hooks.
  // Evaluate PrintWhen first so object hooks are skipped when the object will not print.
  if not ShouldPrintObject(AObject, Context) then
    Exit;

  CanPrint := True;
  if Assigned(Context.Hooks) then
    Context.Hooks.InvokeBeforeObjectPrint(AObject, Context, CanPrint);
  if not CanPrint then
    Exit;

  Ctx := Context;
  Ctx.PrecheckedObjectForPrintWhen := AObject;
  try
    AObject.Draw(C, Ctx);
  finally
    Ctx.PrecheckedObjectForPrintWhen := nil;
  end;

  if Assigned(Context.Hooks) then
    Context.Hooks.InvokeAfterObjectPrint(AObject, Context);
end;

procedure EnsureRegistryInitialized;
begin
  if not Assigned(GRegistryCS) then
    GRegistryCS := TCriticalSection.Create;
  if not Assigned(GRegistry) then
    GRegistry := TList<TReportObjectClass>.Create;
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
  FLocked       := False;
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
  if FLocked then
  begin
    C.Pen.Style := psDot;
    C.Pen.Color := clRed;
    C.Brush.Style := bsClear;
    C.Rectangle(FBounds);
    C.Pen.Style := psSolid;
    Exit;
  end;

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

  // Phase 4G-1: per-render reentrancy guard.
  if (Context.PrecheckedObjectForPrintWhen <> nil) and
     (AObj = TReportObject(Context.PrecheckedObjectForPrintWhen)) then
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

function FormatFieldDisplayValue(
  const AValue: Variant;
  const ADisplayFormat: string;
  const AEditMask: string): string; forward;

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

function TReportTextObject.ResolveDisplayText(
  const Context: TExpressionContext): string;
begin
  if FExpression <> '' then
    Result := VarToStr(TReportExpression.Evaluate(FExpression, Context))
  else if (FDataField <> '') and SourceActive(Context.DataSet, Context.UserDataSet) then
  begin
    if Self is TReportFieldObject then
      Result := FormatFieldDisplayValue(
        SafeSourceFieldValue(Context.DataSet, Context.UserDataSet, FDataField),
        TReportFieldObject(Self).FDisplayFormat,
        TReportFieldObject(Self).FEditMask)
    else
      Result := SafeSourceFieldAsString(Context.DataSet, Context.UserDataSet, FDataField);
  end
  else if Pos('[', FText) > 0 then
    // FText contains embedded system/field tokens — evaluate them.
    Result := VarToStr(TReportExpression.Evaluate(FText, Context))
  else
    Result := FText;
end;

procedure TReportTextObject.ResolveTextStyle(
  const Context: TExpressionContext;
  out AFontColor: TColor;
  out ABackground: TColor;
  out ABorderColor: TColor);
begin
  ResolveConditionalStyle(Context, AFontColor, ABackground, ABorderColor);
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
  else if (FDataField <> '') and SourceActive(Context.DataSet, Context.UserDataSet) then
  begin
{$IFDEF DEBUG}
    if not Assigned(Context.UserDataSet) and not TryGetField(Context.DataSet, FDataField, Fld) then
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
        SafeSourceFieldValue(Context.DataSet, Context.UserDataSet, FDataField),
        TReportFieldObject(Self).FDisplayFormat,
        TReportFieldObject(Self).FEditMask)
    else
      S := SafeSourceFieldAsString(Context.DataSet, Context.UserDataSet, FDataField);
  end
{$IFDEF DEBUG}
  else if FDataField <> '' then
  begin
    if not Assigned(Context.DataSet) and not Assigned(Context.UserDataSet) then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset nil', Context.DataSet)
    else if not SourceActive(Context.DataSet, Context.UserDataSet) then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset inactive', Context.DataSet);
    S := FText;
  end
{$ENDIF}
  else if Pos('[', FText) > 0 then
    // FText contains embedded system/field tokens — evaluate them.
    S := VarToStr(TReportExpression.Evaluate(FText, Context))
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
  else if (FDataField <> '') and SourceActive(Context.DataSet, Context.UserDataSet) then
  begin
    if Self is TReportFieldObject then
      S := FormatFieldDisplayValue(
        SafeSourceFieldValue(Context.DataSet, Context.UserDataSet, FDataField),
        TReportFieldObject(Self).FDisplayFormat,
        TReportFieldObject(Self).FEditMask)
    else
      S := SafeSourceFieldAsString(Context.DataSet, Context.UserDataSet, FDataField);
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

function TReportImageObject.ResolveImageSource(
  const Context: TExpressionContext): string;
begin
  Result := '';
  if FDataField = '' then
    Exit;

  Result := SafeSourceFieldAsString(Context.DataSet, Context.UserDataSet, FDataField);
end;

function TryLoadPictureFromBase64(APicture: TPicture; const AText: string): Boolean;
{
  Loads an inline base64 image value (the documented DataField alternative
  to a file path) into APicture.  Accepts either a full data-URI
  ("data:image/png;base64,....") or a bare base64 string; the graphic format
  is detected from the decoded magic bytes and loaded with the matching
  registered graphic class.  Best-effort: any failure leaves APicture empty
  and returns False (same contract as TryLoadPictureFromFile).
}
const
  Base64Chars = ['A'..'Z', 'a'..'z', '0'..'9', '+', '/', '='];
var
  Payload: string;
  Bytes: TBytes;
  Stream: TMemoryStream;
  G: TGraphic;
  I: Integer;
begin
  Result := False;
  if not Assigned(APicture) then
    Exit;

  // Fixed-width DB string fields are commonly space-padded and base64
  // encoders commonly wrap lines; strip all whitespace up front so padded
  // and wrapped values still decode.
  Payload := '';
  for I := 1 to Length(AText) do
    if not CharInSet(AText[I], [#32, #9, #13, #10]) then
      Payload := Payload + AText[I];
  if StartsText('data:', Payload) then
  begin
    // data-URI: everything after the (case-insensitive) "base64," marker.
    I := Pos('base64,', LowerCase(Payload));
    if I > 0 then
      Payload := Copy(Payload, I + Length('base64,'), MaxInt)
    else
      Payload := '';
  end
  else
  begin
    // Bare base64: require a plausible alphabet before attempting decode.
    if (Length(Payload) < 8) then
      Payload := '';
    for I := 1 to Length(Payload) do
      if not (Payload[I] in Base64Chars) then
      begin
        Payload := '';
        Break;
      end;
  end;
  if Payload = '' then
    Exit;

  try
    Bytes := TNetEncoding.Base64.DecodeStringToBytes(Payload);
  except
    Exit;
  end;
  if Length(Bytes) < 8 then
    Exit;

  // Format sniff from magic bytes; EMF/WMF are not supported inline.
  if (Length(Bytes) >= 4) and (Bytes[0] = $89) and (Bytes[1] = $50) and
     (Bytes[2] = $4E) and (Bytes[3] = $47) then
    G := TPngImage.Create
  else if (Bytes[0] = $FF) and (Bytes[1] = $D8) and (Bytes[2] = $FF) then
    G := TJPEGImage.Create
  else if (Length(Bytes) >= 4) and (Bytes[0] = Ord('G')) and
          (Bytes[1] = Ord('I')) and (Bytes[2] = Ord('F')) and
          (Bytes[3] = Ord('8')) then
    G := TGIFImage.Create
  else if (Bytes[0] = Ord('B')) and (Bytes[1] = Ord('M')) then
    G := Vcl.Graphics.TBitmap.Create
  else
    Exit;
  try
    try
      Stream := TMemoryStream.Create;
      try
        Stream.WriteBuffer(Bytes[0], Length(Bytes));
        Stream.Position := 0;
        G.LoadFromStream(Stream);
        APicture.Assign(G);
        Result := Assigned(APicture.Graphic) and (not APicture.Graphic.Empty);
      finally
        Stream.Free;
      end;
    except
      APicture.Assign(nil);
      Result := False;
    end;
  finally
    G.Free;
  end;
end;

function TryLoadPictureFromFile(APicture: TPicture; const AFileName: string): Boolean;
var
  Ext: string;
  Meta: TMetafile;
  Wic: TWICImage;
begin
  Result := False;
  if not Assigned(APicture) then
    Exit;

  Ext := LowerCase(ExtractFileExt(AFileName));
  if (Ext = '.emf') or (Ext = '.wmf') then
  begin
    Meta := TMetafile.Create;
    try
      try
        Meta.LoadFromFile(AFileName);
        if not Meta.Empty then
        begin
          APicture.Assign(Meta);
          Result := Assigned(APicture.Graphic) and (not APicture.Graphic.Empty);
        end;
      except
        APicture.Assign(nil);
        Result := False;
      end;
    finally
      Meta.Free;
    end;
    Exit;
  end;

  try
    APicture.LoadFromFile(AFileName);
    Result := Assigned(APicture.Graphic) and (not APicture.Graphic.Empty);
    if Result then
      Exit;
  except
    APicture.Assign(nil);
  end;

  Wic := TWICImage.Create;
  try
    try
      Wic.LoadFromFile(AFileName);
      if not Wic.Empty then
      begin
        APicture.Assign(Wic);
        Result := Assigned(APicture.Graphic) and (not APicture.Graphic.Empty);
      end;
    except
      APicture.Assign(nil);
      Result := False;
    end;
  finally
    Wic.Free;
  end;
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
    if not Assigned(Context.DataSet) and not Assigned(Context.UserDataSet) then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset nil', Context.DataSet)
    else if not SourceActive(Context.DataSet, Context.UserDataSet) then
      DebugLogDataFieldIssue(Self, FDataField, 'dataset inactive', Context.DataSet)
    else if not Assigned(Context.UserDataSet) and not TryGetField(Context.DataSet, FDataField, Fld) then
      DebugLogDataFieldIssue(Self, FDataField, 'field missing', Context.DataSet);
    if Assigned(Fld) then
      try
        DiagStr := Fld.AsString;
      except
        DebugLogDataFieldIssue(Self, FDataField, 'field value conversion/read error', Context.DataSet);
      end;
{$ENDIF}
    PathOrBase64 := SafeSourceFieldAsString(Context.DataSet, Context.UserDataSet, FDataField);
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
          FCachedImageValid := TryLoadPictureFromFile(FCachedPicture, PathOrBase64);
          if FCachedImageValid then
            FPicture.Assign(FCachedPicture);
        except
          // silently ignore invalid image data/path
          FCachedImageValid := False;
          FCachedPicture.Assign(nil);
        end;
      end
      else
      begin
        // Documented alternative source: inline base64 image value
        // (data-URI or bare base64).  Same cache semantics as file paths.
        try
          FCachedImageValid := TryLoadPictureFromBase64(FCachedPicture, PathOrBase64);
          if FCachedImageValid then
            FPicture.Assign(FCachedPicture);
        except
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
    Color: TColor;
    FontName: string;
    Size: Integer;
    IsBreak: Boolean;
  end;

  TMemoSeg = record
    Text: string;
    Style: TFontStyles;
    Color: TColor;
    FontName: string;
    Size: Integer;
    Width: Integer;
  end;

  TMemoLine = record
    Segments: TArray<TMemoSeg>;
    Width: Integer;
    Height: Integer;
  end;

procedure AddMemoRun(var Runs: TArray<TMemoRun>; const AText: string;
  const AStyle: TFontStyles; AColor: TColor; const AFontName: string; ASize: Integer; AIsBreak: Boolean);
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
  else if (AMemo.FDataField <> '') and SourceActive(Context.DataSet, Context.UserDataSet) then
  begin
{$IFDEF DEBUG}
    if not Assigned(Context.UserDataSet) and not TryGetField(Context.DataSet, AMemo.FDataField, Fld) then
      DebugLogDataFieldIssue(AMemo, AMemo.FDataField, 'field missing', Context.DataSet);
    if Assigned(Fld) then
      try
        DiagStr := Fld.AsString;
      except
        DebugLogDataFieldIssue(AMemo, AMemo.FDataField, 'field value conversion/read error', Context.DataSet);
      end;
{$ENDIF}
    Result := SafeSourceFieldAsString(Context.DataSet, Context.UserDataSet, AMemo.FDataField)
  end
{$IFDEF DEBUG}
  else if AMemo.FDataField <> '' then
  begin
    if not Assigned(Context.DataSet) and not Assigned(Context.UserDataSet) then
      DebugLogDataFieldIssue(AMemo, AMemo.FDataField, 'dataset nil', Context.DataSet)
    else if not SourceActive(Context.DataSet, Context.UserDataSet) then
      DebugLogDataFieldIssue(AMemo, AMemo.FDataField, 'dataset inactive', Context.DataSet);
    Result := AMemo.FText;
  end
{$ENDIF}
  else
    Result := AMemo.FText;
end;

procedure ParseMemoRuns(const S: string; const BaseStyle: TFontStyles;
  BaseColor: TColor; const BaseFontName: string; BaseSize: Integer;
  AllowHTML: Boolean; out Runs: TArray<TMemoRun>);
type
  TMemoState = record
    Style: TFontStyles;
    Color: TColor;
    FontName: string;
    Size: Integer;
  end;
var
  I, J, K: Integer;
  Buf: string;
  Tag: string;
  StateStack: TArray<TMemoState>;
  CurState: TMemoState;
  Attrs: TArray<string>;
  P: Integer;
  AName, AVal: string;
  TagL: string;

  procedure PushState;
  begin
    SetLength(StateStack, Length(StateStack) + 1);
    StateStack[High(StateStack)] := CurState;
  end;
  
  procedure PopState;
  begin
    if Length(StateStack) > 0 then
    begin
      CurState := StateStack[High(StateStack)];
      SetLength(StateStack, Length(StateStack) - 1);
    end;
  end;

  function ParseColor(const SC: string): TColor;
  var 
    L: string;
  begin
    if SC = '' then Exit(BaseColor);
    if (Length(SC) > 0) and (SC[1] = '#') then
    begin
      if Length(SC) = 7 then
        Result := RGB(StrToIntDef('$' + Copy(SC, 2, 2), 0),
                      StrToIntDef('$' + Copy(SC, 4, 2), 0),
                      StrToIntDef('$' + Copy(SC, 6, 2), 0))
      else
        Result := BaseColor;
    end
    else
    begin
      L := LowerCase(SC);
      if L = 'red' then Result := clRed
      else if L = 'blue' then Result := clBlue
      else if L = 'green' then Result := clGreen
      else if L = 'black' then Result := clBlack
      else if L = 'white' then Result := clWhite
      else if L = 'yellow' then Result := clYellow
      else if L = 'gray' then Result := clGray
      else if L = 'silver' then Result := clSilver
      else if L = 'maroon' then Result := clMaroon
      else if L = 'olive' then Result := clOlive
      else if L = 'navy' then Result := clNavy
      else if L = 'purple' then Result := clPurple
      else if L = 'teal' then Result := clTeal
      else if L = 'fuchsia' then Result := clFuchsia
      else if L = 'aqua' then Result := clAqua
      else if Copy(L, 1, 2) = 'cl' then
        Result := StringToColor(SC)
      else
        Result := BaseColor;
    end;
  end;

begin
  SetLength(Runs, 0);
  SetLength(StateStack, 0);
  CurState.Style := BaseStyle;
  CurState.Color := BaseColor;
  CurState.FontName := BaseFontName;
  CurState.Size := BaseSize;
  Buf := '';
  I := 1;

  while I <= Length(S) do
  begin
    if AllowHTML and (S[I] = '<') then
    begin
      J := I + 1;
      while (J <= Length(S)) and (S[J] <> '>') do Inc(J);
      if J <= Length(S) then
      begin
        AddMemoRun(Runs, DecodeHtmlEntities(Buf), CurState.Style, CurState.Color, CurState.FontName, CurState.Size, False);
        Buf := '';

        Tag := Trim(Copy(S, I + 1, J - I - 1));
        TagL := LowerCase(Tag);

        if TagL = 'b' then
        begin
          PushState;
          Include(CurState.Style, fsBold);
        end
        else if TagL = '/b' then PopState
        else if TagL = 'i' then
        begin
          PushState;
          Include(CurState.Style, fsItalic);
        end
        else if TagL = '/i' then PopState
        else if TagL = 'u' then
        begin
          PushState;
          Include(CurState.Style, fsUnderline);
        end
        else if TagL = '/u' then PopState
        else if (TagL = 'br') or (TagL = 'br/') or (TagL = 'br /') then
          AddMemoRun(Runs, '', CurState.Style, CurState.Color, CurState.FontName, CurState.Size, True)
        else if (TagL = 'p') or (TagL = '/p') then
          AddMemoRun(Runs, '', CurState.Style, CurState.Color, CurState.FontName, CurState.Size, True)
        else if TagL = '/font' then PopState
        else if Copy(TagL, 1, 5) = 'font ' then
        begin
          PushState;
          Attrs := Tag.Substring(5).Split([' '], TStringSplitOptions.ExcludeEmpty);
          for K := 0 to High(Attrs) do
          begin
            P := Pos('=', Attrs[K]);
            if P > 0 then
            begin
              AName := LowerCase(Trim(Copy(Attrs[K], 1, P - 1)));
              AVal := Trim(Copy(Attrs[K], P + 1, Length(Attrs[K])));
              AVal := StringReplace(AVal, '"', '', [rfReplaceAll]);
              AVal := StringReplace(AVal, '', '', [rfReplaceAll]);
              if AName = 'color' then CurState.Color := ParseColor(AVal)
              else if AName = 'face' then CurState.FontName := AVal
              else if AName = 'size' then CurState.Size := StrToIntDef(AVal, CurState.Size);
            end;
          end;
        end
        else
          Buf := Buf + Copy(S, I, J - I + 1);

        I := J + 1;
        Continue;
      end;
    end;

    if (S[I] = #13) or (S[I] = #10) then
    begin
      AddMemoRun(Runs, DecodeHtmlEntities(Buf), CurState.Style, CurState.Color, CurState.FontName, CurState.Size, False);
      Buf := '';
      AddMemoRun(Runs, '', CurState.Style, CurState.Color, CurState.FontName, CurState.Size, True);
      if (S[I] = #13) and (I < Length(S)) and (S[I + 1] = #10) then
        Inc(I);
    end
    else
      Buf := Buf + S[I];

    Inc(I);
  end;

  AddMemoRun(Runs, DecodeHtmlEntities(Buf), CurState.Style, CurState.Color, CurState.FontName, CurState.Size, False);
end;

function StyledTextWidth(C: TCanvas; BaseFont: TFont; const S: string;
  const Style: TFontStyles; const FontName: string; Size: Integer): Integer;
begin
  if S = '' then Exit(0);
  C.Font.Assign(BaseFont);
  C.Font.Style := Style;
  if FontName <> '' then C.Font.Name := FontName;
  if Size > 0 then C.Font.Size := Size;
  Result := C.TextWidth(S);
end;

function StyledTextHeight(C: TCanvas; BaseFont: TFont;
  const Style: TFontStyles; const FontName: string; Size: Integer): Integer;
begin
  C.Font.Assign(BaseFont);
  C.Font.Style := Style;
  if FontName <> '' then C.Font.Name := FontName;
  if Size > 0 then C.Font.Size := Size;
  Result := C.TextHeight('Hg');
end;

procedure AddLineSegment(var Line: TMemoLine; C: TCanvas; BaseFont: TFont;
  const S: string; const Style: TFontStyles; Color: TColor; const FontName: string; Size: Integer);
var
  L: Integer;
  W: Integer;
  H: Integer;
begin
  if S = '' then Exit;

  W := StyledTextWidth(C, BaseFont, S, Style, FontName, Size);
  H := StyledTextHeight(C, BaseFont, Style, FontName, Size);

  L := Length(Line.Segments);
  if (L > 0) and (Line.Segments[L - 1].Style = Style) and (Line.Segments[L - 1].Color = Color) and (SameText(Line.Segments[L - 1].FontName, FontName)) and (Line.Segments[L - 1].Size = Size) then
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

procedure BuildMemoLines(C: TCanvas; BaseFont: TFont; BaseColor: TColor; const Text: string;
  MaxWidth: Integer; WordWrap: Boolean; AllowHTML: Boolean; out Lines: TArray<TMemoLine>;
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

  ParseMemoRuns(Text, BaseFont.Style, BaseColor, BaseFont.Name, BaseFont.Size, AllowHTML, Runs);

  DefaultH := StyledTextHeight(C, BaseFont, BaseFont.Style, BaseFont.Name, BaseFont.Size);
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
        AddLineSegment(Line, C, BaseFont, Token, Run.Style, Run.Color, Run.FontName, Run.Size);
      end
      else
      begin
        if IsSpace and (Line.Width = 0) then
        begin
          I := J;
          Continue;
        end;

        var TokenW := StyledTextWidth(C, BaseFont, Token, Run.Style, Run.FontName, Run.Size);

        if (Line.Width + TokenW <= MaxWidth) or (Line.Width = 0) then
          AddLineSegment(Line, C, BaseFont, Token, Run.Style, Run.Color, Run.FontName, Run.Size)
        else if IsSpace then
          PushLine(Lines, Line, DefaultH, False)
        else if TokenW <= MaxWidth then
        begin
          PushLine(Lines, Line, DefaultH, False);
          AddLineSegment(Line, C, BaseFont, Token, Run.Style, Run.Color, Run.FontName, Run.Size);
        end
        else
        begin
          for Ch in Token do
          begin
            var CharText := string(Ch);
            var CharW := StyledTextWidth(C, BaseFont, CharText, Run.Style, Run.FontName, Run.Size);
            if (Line.Width > 0) and (Line.Width + CharW > MaxWidth) then
              PushLine(Lines, Line, DefaultH, False);
            AddLineSegment(Line, C, BaseFont, CharText, Run.Style, Run.Color, Run.FontName, Run.Size);
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

  BuildMemoLines(C, FFont, DrawFontColor, S, MaxWidth, FWordWrap, FAllowHTML, Lines, TotalH);

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
        C.Font.Style := Lines[I].Segments[J].Style;
        if Lines[I].Segments[J].Color <> clNone then
          C.Font.Color := Lines[I].Segments[J].Color
        else
          C.Font.Color := DrawFontColor;
        if Lines[I].Segments[J].FontName <> '' then
          C.Font.Name := Lines[I].Segments[J].FontName;
        if Lines[I].Segments[J].Size > 0 then
          C.Font.Size := Lines[I].Segments[J].Size;
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

  BuildMemoLines(C, FFont, FFont.Color, S, MaxWidth, FWordWrap, FAllowHTML, Lines, TotalH);

  if TotalH > 0 then
  begin
    Needed := TotalH + FPaddingTop + FPaddingBottom;
    if Needed < FMinHeight then Needed := FMinHeight;
    Result  := FBounds.Top + Needed;
  end
  else if FMinHeight > 0 then
    Result := FBounds.Top + FMinHeight;
end;

{ ================= Sub-report Object ================= }

function ResolveSubReportDataSet(Obj: TReportSubReportObject;
  const Context: TExpressionContext): TDataSet;
begin
  Result := Context.DataSet;
  if Trim(Obj.FDataSetName) = '' then
    Exit;

  Result := nil;
  if Assigned(Context.Hooks) then
    Result := Context.Hooks.GetNamedDataSet(Obj.FDataSetName);
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
  FExtendToPageBottom := False;
  FBounds      := Rect(10, 10, 200, 12);  // thin horizontal rule
end;

procedure TReportLineObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  R: TRect;
  CX, CY: Integer;
begin
  if not ShouldPrintObject(Self, Context) then Exit;
  R  := FBounds;
  if FExtendToPageBottom and (FOrientation = loVertical) and
     (Context.PageBottom > R.Top) then
    R.Bottom := Context.PageBottom;
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
  EnsureRegistryInitialized;
  RegisterReportObject(TReportTextObject);
  RegisterReportObject(TReportLabelObject);
  RegisterReportObject(TReportFieldObject);
  RegisterReportObject(TReportShapeObject);
  RegisterReportObject(TReportImageObject);
  RegisterReportObject(TReportMemoObject);
  RegisterReportObject(TReportSubReportObject);
  RegisterReportObject(TReportLineObject);

finalization
  if Assigned(GRegistryCS) then
  begin
    GRegistryCS.Enter;
    try
      FreeAndNil(GRegistry);
    finally
      GRegistryCS.Leave;
      FreeAndNil(GRegistryCS);
    end;
  end
  else
    FreeAndNil(GRegistry);

end.
