unit Vittix.Report.Objects;

interface

uses
  System.Classes,
  System.Types,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.Graphics,
  Data.DB,
  Vittix.Report.Context;

{ ================= Base Object ================= }

type
  TReportObject = class(TPersistent)
  private
    FBounds: TRect;
    FSelected: Boolean;
    FName: string;
  protected
    procedure DrawSelection(C: TCanvas);
  public
    constructor Create; virtual;

    procedure Draw(C: TCanvas; const Context: TExpressionContext); virtual;
    function Hit(X,Y: Integer): Boolean; virtual;

    procedure MoveBy(dx,dy: Integer);

    property Bounds: TRect read FBounds write FBounds;
    property Selected: Boolean read FSelected write FSelected;
  published
    property Name: string read FName write FName;
  end;

  TReportObjectClass = class of TReportObject;

{ ================= Registry ================= }

procedure RegisterReportObject(AClass: TReportObjectClass);
function GetRegisteredReportObjects: TArray<TReportObjectClass>;

{ ================= Text Object ================= }

type
  TReportTextObject = class(TReportObject)
  private
    FText: string;
    FDataField: string;
    FExpression: string;
    FFont: TFont;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
  published
    property Text: string read FText write FText;
    property DataField: string read FDataField write FDataField;
    property Expression: string read FExpression write FExpression;
    property Font: TFont read FFont write FFont;
  end;

implementation

uses
  Vittix.Report.Expressions, // Keep here
  Winapi.Windows, // Keep here
  System.Variants; // Keep here

var
  GRegistry: TList<TReportObjectClass>;

{ ================= Registry ================= }

procedure RegisterReportObject(AClass: TReportObjectClass);
begin
  if GRegistry.IndexOf(AClass) < 0 then
    GRegistry.Add(AClass);
end;

function GetRegisteredReportObjects: TArray<TReportObjectClass>;
begin
  Result := GRegistry.ToArray;
end;

{ ================= Base Object ================= }

constructor TReportObject.Create;
begin
  inherited;
  FBounds := Rect(10,10,110,40);
end;
 
procedure TReportObject.Draw(C: TCanvas; const Context: TExpressionContext);
begin
  C.Brush.Style := bsClear;
  C.Rectangle(FBounds);

  if FSelected then
    DrawSelection(C);
end;

procedure TReportObject.DrawSelection(C: TCanvas);
const S = 4;
begin
  C.Brush.Color := clBlue;
  C.Pen.Style := psClear;

  C.Rectangle(FBounds.Left-S, FBounds.Top-S,
              FBounds.Left+S, FBounds.Top+S);

  C.Rectangle(FBounds.Right-S, FBounds.Bottom-S,
              FBounds.Right+S, FBounds.Bottom+S);

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


{ ================= Text Object ================= }

constructor TReportTextObject.Create;
begin
  inherited;
  FFont := TFont.Create;
  FFont.Name := 'Tahoma';
  FFont.Size := 10;
  FText := 'Text';
end;

destructor TReportTextObject.Destroy;
begin
  FFont.Free;
  inherited;
end;

procedure TReportTextObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  S: string;
begin
  inherited Draw(C, Context); // Call inherited Draw to draw bounds and selection
  C.Font.Assign(FFont); // Apply font after inherited draw to not affect selection drawing
  C.Brush.Style := bsClear; // Ensure brush is clear for text background

  if FExpression <> '' then
    S := VarToStr(TReportExpression.Evaluate(FExpression, Context))
  else if (FDataField <> '') and Assigned(Context.DataSet) and Context.DataSet.Active then
    S := Context.DataSet.FieldByName(FDataField).AsString
  else
    S := FText;

  DrawText(C.Handle, PChar(S), Length(S), FBounds, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
end;

{ ================= Init ================= }

initialization
  GRegistry := TList<TReportObjectClass>.Create;
  RegisterReportObject(TReportTextObject);

finalization
  GRegistry.Free;

end.
