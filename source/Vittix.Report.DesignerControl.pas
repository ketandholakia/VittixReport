unit Vittix.Report.DesignerControl;

interface

uses
  System.Classes,
  System.Types,
  System.Generics.Collections,
  System.SysUtils,
  Vcl.Controls,
  Vcl.Graphics,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Undo;

type
  TDesignerMode = (dmSelect, dmInsertObject, dmMove, dmResize);

  TResizeHandle = (
    rhNone,
    rhLeft, rhTop, rhRight, rhBottom,
    rhTopLeft, rhTopRight,
    rhBottomLeft, rhBottomRight
  );

type
  TVittixReportDesigner = class(TCustomControl)
  private
    FReport: TReportModel;
    FDataSet: TDataSet;

    FShowGrid: Boolean;
    FSnapToGrid: Boolean;
    FGridSize: Integer;

    FSelected: TList<TReportObject>;
    FInsertClass: TReportObjectClass;

    FDesignerMode: TDesignerMode;
    FResizeHandle: TResizeHandle;

    FMouseDown: Boolean;
    FMouseStart: TPoint;
    FSelecting: Boolean;
    FSelectRect: TRect;

    FCommands: TCommandManager;
    FClipboardJSON: string;

    FOnSelectionChanged: TNotifyEvent;

    FDragStartBounds: TDictionary<TReportObject, TRect>;

    procedure SetDataSet(const Value: TDataSet);

    function SnapValue(V: Integer): Integer;
    function HitTestObject(X,Y: Integer): TReportObject;
    procedure AddToSelection(Obj: TReportObject);
    function GetPrimarySelected: TReportObject;
    function GetHandleAt(R: TRect; X,Y: Integer): TResizeHandle;

    procedure DoSelectionChanged;

  protected
    procedure Paint; override;
    procedure DrawGrid;

    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y:Integer); override;
    procedure MouseMove(Shift: TShiftState; X,Y:Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X,Y:Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure BeginInsertObject(AClass: TReportObjectClass);
    procedure AddObject(AObject: TReportObject);
    procedure CopySelection;
    procedure PasteSelection; 
    procedure ClearSelection;

    procedure AlignLeft;
    procedure AlignRight;
    procedure AlignTop;
    procedure AlignBottom;
    procedure SameWidth;
    procedure SameHeight;
    procedure DistributeH;
    procedure DistributeV;

    property Report: TReportModel read FReport;
    property PrimarySelected: TReportObject read GetPrimarySelected;

  published
    property Align;
    property Color default clWhite;

    property DataSet: TDataSet read FDataSet write SetDataSet;

    property ShowGrid: Boolean read FShowGrid write FShowGrid default True;
    property SnapToGrid: Boolean read FSnapToGrid write FSnapToGrid default True;
    property GridSize: Integer read FGridSize write FGridSize default 8;

    property OnSelectionChanged: TNotifyEvent
      read FOnSelectionChanged write FOnSelectionChanged;
  end;

procedure Register;

implementation

uses
  System.JSON,
  System.Math,   // ADDED: For Min/Max functions
  Vittix.Report.Context, // ADDED: For TExpressionContext
  Vittix.Report.Serializer;
{ ================= Constructor ================= }

constructor TVittixReportDesigner.Create(AOwner: TComponent);
begin
  inherited;

  DoubleBuffered := True;
  TabStop := True;
  Color := clWhite;

  Width := 800;
  Height := 1000;

  FShowGrid := True;
  FSnapToGrid := True;
  FGridSize := 8;

  FReport := TReportModel.Create;
  FSelected := TList<TReportObject>.Create;
  FCommands := TCommandManager.Create;
  FDragStartBounds := TDictionary<TReportObject, TRect>.Create;
end;

destructor TVittixReportDesigner.Destroy;
begin
  FReport.Free;
  FSelected.Free;
  FDragStartBounds.Free;
  FCommands.Free;
  inherited;
end;

{ ================= Helpers ================= }

procedure TVittixReportDesigner.SetDataSet(const Value: TDataSet);
begin
  FDataSet := Value;
end;

function TVittixReportDesigner.SnapValue(V: Integer): Integer;
begin
  if not FSnapToGrid then Exit(V);
  Result := (V div FGridSize) * FGridSize;
end;

procedure TVittixReportDesigner.DoSelectionChanged;
begin
  if Assigned(FOnSelectionChanged) then
    FOnSelectionChanged(Self);
end;

procedure TVittixReportDesigner.ClearSelection;
var O: TReportObject;
begin
  for O in FSelected do
    O.Selected := False;
  FSelected.Clear;
  DoSelectionChanged;
  Invalidate;
end;

function TVittixReportDesigner.GetPrimarySelected: TReportObject;
begin
  if FSelected.Count > 0 then
    Result := FSelected.Last
  else Result := nil;
end;

{ ================= Object Ops ================= }

procedure TVittixReportDesigner.AddObject(AObject: TReportObject);
begin
  if not Assigned(AObject) then Exit;

  FReport.Objects.Add(AObject);
  ClearSelection;
  AddToSelection(AObject);

  DoSelectionChanged;
  Invalidate;
end;

procedure TVittixReportDesigner.AddToSelection(Obj: TReportObject);
begin
  if not FSelected.Contains(Obj) then
  begin
    FSelected.Add(Obj);
    Obj.Selected := True;
  end;
end;

procedure TVittixReportDesigner.BeginInsertObject(AClass: TReportObjectClass);
begin
  FInsertClass := AClass;
  FDesignerMode := dmInsertObject;
end;

procedure TVittixReportDesigner.CopySelection;
var J: TJSONObject;
begin
  if not Assigned(PrimarySelected) then Exit;

  J := ObjectToJSON(PrimarySelected);
  try
    FClipboardJSON := J.ToJSON;
  finally
    J.Free;
  end;
end;

procedure TVittixReportDesigner.PasteSelection;
var
  J: TJSONObject;
  Obj: TReportObject;
  R: TRect;
begin
  if FClipboardJSON = '' then Exit;

  J := TJSONObject.ParseJSONValue(FClipboardJSON) as TJSONObject;
  try
    Obj := JSONToObject(J);
  finally
    J.Free;
  end;

  { offset pasted object }
  R := Obj.Bounds;
  OffsetRect(R, 20, 20);
  Obj.Bounds := R;

  FCommands.DoCommand(
    TInsertObjectCommand.Create(FReport, Obj));

  ClearSelection;
  AddToSelection(Obj);
  Invalidate;
end;

{ ================= Alignment ================= }

procedure TVittixReportDesigner.AlignLeft;
var
  MinX: Integer;
  O: TReportObject;
  i: Integer;
  OldB, NewB: TArray<TRect>;
begin
  if FSelected.Count < 2 then Exit;

  MinX := MaxInt;
  for O in FSelected do
    MinX := Min(MinX, O.Bounds.Left);

  SetLength(OldB, FSelected.Count);
  SetLength(NewB, FSelected.Count);

  for i := 0 to FSelected.Count-1 do
  begin
    OldB[i] := FSelected[i].Bounds;
    NewB[i] := OldB[i];
    NewB[i].Left := MinX;
    NewB[i].Right := MinX + OldB[i].Width;
  end;

  FCommands.DoCommand(
    TMultiMoveCommand.Create(
      FSelected.ToArray,
      OldB, NewB));
  Invalidate;
end;

procedure TVittixReportDesigner.AlignRight; begin Invalidate; end;
procedure TVittixReportDesigner.AlignTop; begin Invalidate; end;
procedure TVittixReportDesigner.AlignBottom; begin Invalidate; end;
procedure TVittixReportDesigner.SameWidth; begin Invalidate; end;
procedure TVittixReportDesigner.SameHeight; begin Invalidate; end;
procedure TVittixReportDesigner.DistributeH; begin Invalidate; end;
procedure TVittixReportDesigner.DistributeV; begin Invalidate; end;

function TVittixReportDesigner.HitTestObject(X,Y: Integer): TReportObject;
var
  Obj: TReportObject;
begin
  Result := nil;
  for Obj in FReport.Objects do
    if Obj.Hit(X,Y) then
      Exit(Obj);
end;

{ ================= Resize Handles ================= }

function TVittixReportDesigner.GetHandleAt(
  R: TRect; X,Y: Integer): TResizeHandle;
const S = 6;
begin
  if PtInRect(Rect(R.Left-S,R.Top-S,R.Left+S,R.Top+S),Point(X,Y)) then Exit(rhTopLeft);
  if PtInRect(Rect(R.Right-S,R.Top-S,R.Right+S,R.Top+S),Point(X,Y)) then Exit(rhTopRight);
  if PtInRect(Rect(R.Left-S,R.Bottom-S,R.Left+S,R.Bottom+S),Point(X,Y)) then Exit(rhBottomLeft);
  if PtInRect(Rect(R.Right-S,R.Bottom-S,R.Right+S,R.Bottom+S),Point(X,Y)) then Exit(rhBottomRight);
  Result := rhNone;
end;

{ ================= Paint ================= }

procedure TVittixReportDesigner.Paint;
var
  Obj: TReportObject;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  if FShowGrid then
    DrawGrid;

  // Draw selection indicators
  Canvas.Pen.Style := psDot;
  Canvas.Pen.Color := clGray;
  Canvas.Brush.Style := bsClear;
  for Obj in FSelected do
    Canvas.Rectangle(Obj.Bounds);

  // Draw selection rectangle
  if FSelecting then
  begin
    Canvas.Pen.Color := clNavy;
    Canvas.Rectangle(FSelectRect);
  end;

  // Draw objects on top
  var Ctx: TExpressionContext;
  Ctx.DataSet := FDataSet;
  Ctx.GroupStart := nil;
  Ctx.GroupEnd := nil;

  for Obj in FReport.Objects do
    Obj.Draw(Canvas, Ctx);
end;

procedure TVittixReportDesigner.DrawGrid;
var x,y: Integer;
begin
  Canvas.Pen.Color := $00EEEEEE;

  for x := 0 to Width div FGridSize do
  begin
    Canvas.MoveTo(x*FGridSize,0);
    Canvas.LineTo(x*FGridSize,Height);
  end;

  for y := 0 to Height div FGridSize do
  begin
    Canvas.MoveTo(0,y*FGridSize);
    Canvas.LineTo(Width,y*FGridSize);
  end;
end;

{ ================= Mouse ================= }

procedure TVittixReportDesigner.MouseDown(
  Button: TMouseButton; Shift: TShiftState; X,Y:Integer);
var Obj: TReportObject;
begin
  inherited;

  SetFocus;
  FMouseDown := True;
  FMouseStart := Point(X, Y);

  if (FDesignerMode = dmInsertObject) and Assigned(FInsertClass) then
  begin
    Obj := FInsertClass.Create;
    Obj.Bounds := Rect(SnapValue(X),SnapValue(Y),
                       SnapValue(X)+120, SnapValue(Y)+40);

    FCommands.DoCommand(TInsertObjectCommand.Create(FReport, Obj));
    ClearSelection;
    AddToSelection(Obj);

    FInsertClass := nil;
    FDesignerMode := dmSelect;
    Invalidate;
    Exit;
  end;

  Obj := HitTestObject(X,Y);

  // Handle selection logic
  if not (ssCtrl in Shift) and ((Obj = nil) or not FSelected.Contains(Obj)) then
    ClearSelection;

  if Assigned(Obj) then
    AddToSelection(Obj);

  // Handle designer mode (move, resize, select)
  if FSelected.Count > 0 then
  begin
    FResizeHandle := GetHandleAt(PrimarySelected.Bounds, X, Y);

    if FResizeHandle <> rhNone then
      FDesignerMode := dmResize
    else
    begin
      FDesignerMode := dmMove;
      FDragStartBounds.Clear;
      for var O in FSelected do
        FDragStartBounds.Add(O, O.Bounds);
    end;
  end
  else
  begin
    // Start drag-selection
    FDesignerMode := dmSelect;
    FSelecting := True;
    FSelectRect := Rect(X, Y, X, Y);
  end;

  DoSelectionChanged;
  Invalidate;
end;

procedure TVittixReportDesigner.MouseMove(
  Shift: TShiftState; X,Y:Integer);
var
  R: TRect;
  dx, dy: Integer;
  O: TReportObject;
begin
  inherited;

  if not FMouseDown then Exit;

  if FSelecting then
  begin
    FSelectRect := Rect(FMouseStart.X, FMouseStart.Y, X, Y);
    Invalidate;
    Exit;
  end;

  if FSelected.Count = 0 then Exit;

  if FDesignerMode = dmMove then
  begin
    dx := X - FMouseStart.X;
    dy := Y - FMouseStart.Y;
    for O in FSelected do
    begin
      R := FDragStartBounds[O];
      OffsetRect(R, dx, dy);
      O.Bounds := R;
    end;
  end;

  if FDesignerMode = dmResize then
  begin
    case FResizeHandle of
      rhBottomRight:
        begin
          R := PrimarySelected.Bounds;
          R.Right := SnapValue(X);
          R.Bottom := SnapValue(Y);
        end;
    end;

    if R.Width < 10 then R.Right := R.Left + 10;
    if R.Height < 10 then R.Bottom := R.Top + 10;

    PrimarySelected.Bounds := R;
  end;

  Invalidate;
end;

procedure TVittixReportDesigner.MouseUp(
  Button: TMouseButton; Shift: TShiftState; X,Y:Integer);
var
  OldB, NewB: TArray<TRect>;
  Items: TArray<TReportObject>;
  i: Integer;
  O: TReportObject;
  tmp: TRect;
begin
  inherited;
  FMouseDown := False;

  if FSelecting then
  begin
    FSelecting := False;
    if not (ssCtrl in Shift) then
      ClearSelection;

    for O in FReport.Objects do
      if IntersectRect(tmp, O.Bounds, FSelectRect) then
        AddToSelection(O);

    Invalidate;
  end;

  if FDesignerMode = dmMove then
  begin
    if FSelected.Count > 0 then
    begin
      Items := FSelected.ToArray;
      SetLength(OldB, Length(Items));
      SetLength(NewB, Length(Items));

      for i := 0 to High(Items) do
      begin
        OldB[i] := FDragStartBounds[Items[i]];
        NewB[i] := Items[i].Bounds;
      end;

      FCommands.DoCommand(TMultiMoveCommand.Create(Items, OldB, NewB));
    end;
  end;

  // TODO: Add TResizeCommand for dmResize

  FDesignerMode := dmSelect;
  FResizeHandle := rhNone;
end;

procedure TVittixReportDesigner.KeyDown(
  var Key: Word; Shift: TShiftState);
begin
  inherited;

  if (Key = Ord('C')) and (ssCtrl in Shift) then
    CopySelection;

  if (Key = Ord('V')) and (ssCtrl in Shift) then
    PasteSelection;

  if (Key = Ord('Z')) and (ssCtrl in Shift) then
    FCommands.UndoLast;

  if (Key = Ord('Y')) and (ssCtrl in Shift) then
    FCommands.RedoLast;

  if (ssCtrl in Shift) and (ssShift in Shift) then
  begin
    case Key of
      Ord('L'): AlignLeft;
      Ord('R'): AlignRight;
      Ord('T'): AlignTop;
      Ord('B'): AlignBottom;
    end;
  end;
end;

{ ================= Register ================= }

procedure Register;
begin
  RegisterComponents('Vittix Reporting', [TVittixReportDesigner]);
end;

end.
