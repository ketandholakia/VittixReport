unit Vittix.Report.Undo;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Types,
  Vittix.Report.Objects,
  Vittix.Report.Model,
  System.Rtti;

type
  { ================= Base Command ================= }

  TUndoableAction = class
  public
    procedure Execute; virtual; abstract;
    procedure Rollback; virtual; abstract;
  end;

  { ================= Command Manager ================= }

  TCommandManager = class
  private
    FUndo: TObjectList<TUndoableAction>;
    FRedo: TObjectList<TUndoableAction>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure DoCommand(C: TUndoableAction);
    procedure UndoLast;
    procedure RedoLast;

    procedure Clear;
  end;

  { ================= Move Command ================= }

  TMoveObjectCommand = class(TUndoableAction)
  private
    FObj: TReportObject;
    FOldBounds: TRect;
    FNewBounds: TRect;
  public
    constructor Create(AObj: TReportObject;
                       const OldB, NewB: TRect);

    procedure Execute; override;
    procedure Rollback; override;
  end;

  { ================= Insert Command ================= }

  TInsertObjectCommand = class(TUndoableAction)
  private
    FModel: TReportModel;
    FObj: TReportObject;
  public
    constructor Create(AModel: TReportModel;
                       AObj: TReportObject);

    procedure Execute; override;
    procedure Rollback; override;
  end;

  { ================= Multi Move Command ================= }

  TMultiMoveCommand = class(TUndoableAction)
  private
    FItems: TArray<TReportObject>;
    FOld: TArray<TRect>;
    FNew: TArray<TRect>;
  public
    constructor Create(const Items: TArray<TReportObject>;
                       const OldB, NewB: TArray<TRect>);
    procedure Execute; override;
    procedure Rollback; override;
  end;

  { ================= Property Change ================= }

  TPropertyChangeCommand = class(TUndoableAction)
  private
    FObj: TObject;
    FPropName: string;
    FOldValue: TValue;
    FNewValue: TValue;
  public
    constructor Create(AObj: TObject;
                       const Prop: string;
                       const OldV, NewV: TValue);

    procedure Execute; override;
    procedure Rollback; override;
  end;

implementation

{ ================= Manager ================= }

constructor TCommandManager.Create;
begin
  FUndo := TObjectList<TUndoableAction>.Create(True);
  FRedo := TObjectList<TUndoableAction>.Create(True);
end;

destructor TCommandManager.Destroy;
begin
  FUndo.Free;
  FRedo.Free;
  inherited;
end;

procedure TCommandManager.DoCommand(C: TUndoableAction);
begin
  C.Execute;
  FUndo.Add(C);
  FRedo.Clear;
end;

procedure TCommandManager.UndoLast;
var Cmd: TUndoableAction;
begin
  if FUndo.Count = 0 then Exit;
  Cmd := FUndo.Last;
  FUndo.Extract(Cmd); // Extract prevents freeing the object
  Cmd.Rollback;
  FRedo.Add(Cmd);
end;

procedure TCommandManager.RedoLast;
var Cmd: TUndoableAction;
begin
  if FRedo.Count = 0 then Exit;
  Cmd := FRedo.Last;
  FRedo.Extract(Cmd); // Extract prevents freeing the object
  Cmd.Execute;
  FUndo.Add(Cmd);
end;

procedure TCommandManager.Clear;
begin
  FUndo.Clear;
  FRedo.Clear;
end;

{ ================= Move ================= }

constructor TMoveObjectCommand.Create(
  AObj: TReportObject;
  const OldB, NewB: TRect);
begin
  FObj := AObj;
  FOldBounds := OldB;
  FNewBounds := NewB;
end;

procedure TMoveObjectCommand.Execute;
begin
  FObj.Bounds := FNewBounds;
end;

procedure TMoveObjectCommand.Rollback;
begin
  FObj.Bounds := FOldBounds;
end;

{ ================= Insert ================= }

constructor TInsertObjectCommand.Create(
  AModel: TReportModel;
  AObj: TReportObject);
begin
  FModel := AModel;
  FObj := AObj;
end;

procedure TInsertObjectCommand.Execute;
begin
  FModel.Objects.Add(FObj);
end;

procedure TInsertObjectCommand.Rollback;
begin
  FModel.Objects.Remove(FObj);
end;

{ ================= Multi Move ================= }

constructor TMultiMoveCommand.Create(const Items: TArray<TReportObject>;
  const OldB, NewB: TArray<TRect>);
begin
  inherited Create;
  FItems := Items;
  FOld := OldB;
  FNew := NewB;
end;

procedure TMultiMoveCommand.Execute;
var i: Integer;
begin
  for i := 0 to High(FItems) do
    FItems[i].Bounds := FNew[i];
end;

procedure TMultiMoveCommand.Rollback;
var i: Integer;
begin
  for i := 0 to High(FItems) do
    FItems[i].Bounds := FOld[i];
end;

{ ================= Property ================= }

constructor TPropertyChangeCommand.Create(
  AObj: TObject;
  const Prop: string;
  const OldV, NewV: TValue);
begin
  FObj := AObj;
  FPropName := Prop;
  FOldValue := OldV;
  FNewValue := NewV;
end;

procedure TPropertyChangeCommand.Execute;
var ctx: TRttiContext; p: TRttiProperty;
begin
  ctx := TRttiContext.Create;
  p := ctx.GetType(FObj.ClassType).GetProperty(FPropName);
  if Assigned(p) then p.SetValue(FObj, FNewValue);
end;

procedure TPropertyChangeCommand.Rollback;
var ctx: TRttiContext; p: TRttiProperty;
begin
  ctx := TRttiContext.Create;
  p := ctx.GetType(FObj.ClassType).GetProperty(FPropName);
  if Assigned(p) then p.SetValue(FObj, FOldValue);
end;

end.
