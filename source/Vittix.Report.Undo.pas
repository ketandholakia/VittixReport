unit Vittix.Report.Undo;

(*
  Vittix.Report.Undo
  ==================
  Command-pattern undo/redo infrastructure for the VittixReport designer.

  Ownership contract
  ------------------
  TObjectList<TReportObject> with OwnsObjects=True owns its elements.
  Commands that remove objects from such lists must take ownership so the
  object survives until re-inserted on redo/undo.

    TInsertObjectCommand
      After Execute  -> model list owns FObj (FOwned = False)
      After Rollback -> command owns FObj  (FOwned = True)
      Destructor     -> frees FObj if FOwned

    TDeleteObjectsCommand
      After Execute  -> FBuffer owns all deleted objects
      After Rollback -> model lists own all objects; FBuffer is empty
      Destructor     -> FBuffer frees whatever it still holds
*)

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Types,
  System.Rtti,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Model;

type
  // ---------------------------------------------------------------------------
  // Base command
  // ---------------------------------------------------------------------------
  TUndoableAction = class
  public
    procedure Execute;  virtual; abstract;
    procedure Rollback; virtual; abstract;
  end;

  // ---------------------------------------------------------------------------
  // Command manager
  // ---------------------------------------------------------------------------
  TCommandManager = class
  private
    FUndo: TObjectList<TUndoableAction>;
    FRedo: TObjectList<TUndoableAction>;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure DoCommand(C: TUndoableAction);
    procedure UndoLast;
    procedure RedoLast;
    procedure Clear;
    function  CanUndo: Boolean;
    function  CanRedo: Boolean;
  end;

  // ---------------------------------------------------------------------------
  // Move single object
  // ---------------------------------------------------------------------------
  TMoveObjectCommand = class(TUndoableAction)
  private
    FObj: TReportObject; FOldBounds, FNewBounds: TRect;
  public
    constructor Create(AObj: TReportObject; const OldB, NewB: TRect);
    procedure Execute;  override;
    procedure Rollback; override;
  end;

  // ---------------------------------------------------------------------------
  // Move/resize multiple objects
  // ---------------------------------------------------------------------------
  TMultiMoveCommand = class(TUndoableAction)
  private
    FItems: TArray<TReportObject>;
    FOld : TArray<TRect>;
    FNew : TArray<TRect>;
  public
    constructor Create(const Items: TArray<TReportObject>;
                       const OldB: TArray<TRect>;
                       const NewB: TArray<TRect>);
    procedure Execute;  override;
    procedure Rollback; override;
  end;

  // ---------------------------------------------------------------------------
  // Insert a single object into a list  (fixed ownership)
  // ---------------------------------------------------------------------------
  TInsertObjectCommand = class(TUndoableAction)
  private
    FList : TObjectList<TReportObject>;
    FObj  : TReportObject;
    FOwned: Boolean;
  public
    constructor Create(AList: TObjectList<TReportObject>; AObj: TReportObject);
    destructor  Destroy; override;
    procedure Execute;  override;
    procedure Rollback; override;
  end;

  // ---------------------------------------------------------------------------
  // Delete one or more objects  (buffer-based ownership)
  // ---------------------------------------------------------------------------
  TDeleteEntry = record
    OwnerList: TObjectList<TReportObject>;
    OrigIndex: Integer;
  end;

  TDeleteObjectsCommand = class(TUndoableAction)
  private
    FEntries: TArray<TDeleteEntry>;
    FBuffer : TObjectList<TReportObject>;
  public
    constructor Create(const AObjects   : TArray<TReportObject>;
                       const AOwnerLists: TArray<TObjectList<TReportObject>>;
                       const AIndices   : TArray<Integer>);
    destructor  Destroy; override;
    procedure Execute;  override;
    procedure Rollback; override;
  end;

  // ---------------------------------------------------------------------------
  // Resize a band (change Height)
  // ---------------------------------------------------------------------------
  TBandResizeCommand = class(TUndoableAction)
  private
    FBand: TReportBand; FOldH, FNewH: Integer;
  public
    constructor Create(ABand: TReportBand; OldH, NewH: Integer);
    procedure Execute;  override;
    procedure Rollback; override;
  end;

  // ---------------------------------------------------------------------------
  // Change z-order within a list
  // ---------------------------------------------------------------------------
  TZOrderCommand = class(TUndoableAction)
  private
    FList: TObjectList<TReportObject>;
    FObj : TReportObject;
    FOldIdx, FNewIdx: Integer;
    procedure MoveItem(FromIdx, ToIdx: Integer);
  public
    constructor Create(AList: TObjectList<TReportObject>;
                       AObj: TReportObject; OldIdx, NewIdx: Integer);
    procedure Execute;  override;
    procedure Rollback; override;
  end;

  // ---------------------------------------------------------------------------
  // Change a published property via RTTI
  // ---------------------------------------------------------------------------
  TPropertyChangeCommand = class(TUndoableAction)
  private
    FObj: TObject; FPropName: string; FOldValue, FNewValue: TValue;
  public
    constructor Create(AObj: TObject; const Prop: string;
                       const OldV, NewV: TValue);
    procedure Execute;  override;
    procedure Rollback; override;
  end;

implementation

// ===========================================================================
// TCommandManager
// ===========================================================================

constructor TCommandManager.Create;
begin
  FUndo := TObjectList<TUndoableAction>.Create(True);
  FRedo := TObjectList<TUndoableAction>.Create(True);
end;

destructor TCommandManager.Destroy;
begin
  FUndo.Free; FRedo.Free; inherited;
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
  Cmd := FUndo.Last; FUndo.Extract(Cmd);
  Cmd.Rollback; FRedo.Add(Cmd);
end;

procedure TCommandManager.RedoLast;
var Cmd: TUndoableAction;
begin
  if FRedo.Count = 0 then Exit;
  Cmd := FRedo.Last; FRedo.Extract(Cmd);
  Cmd.Execute; FUndo.Add(Cmd);
end;

procedure TCommandManager.Clear; begin FUndo.Clear; FRedo.Clear; end;
function  TCommandManager.CanUndo: Boolean; begin Result := FUndo.Count > 0; end;
function  TCommandManager.CanRedo: Boolean; begin Result := FRedo.Count > 0; end;

// ===========================================================================
// TMoveObjectCommand
// ===========================================================================

constructor TMoveObjectCommand.Create(AObj: TReportObject;
  const OldB, NewB: TRect);
begin FObj := AObj; FOldBounds := OldB; FNewBounds := NewB; end;

procedure TMoveObjectCommand.Execute;  begin FObj.Bounds := FNewBounds; end;
procedure TMoveObjectCommand.Rollback; begin FObj.Bounds := FOldBounds; end;

// ===========================================================================
// TMultiMoveCommand
// ===========================================================================

constructor TMultiMoveCommand.Create(const Items: TArray<TReportObject>;
  const OldB: TArray<TRect>; const NewB: TArray<TRect>);
begin
  inherited Create;
  FItems := Items;
  FOld   := OldB;
  FNew   := NewB;
end;

procedure TMultiMoveCommand.Execute;
var i: Integer;
begin for i := 0 to High(FItems) do FItems[i].Bounds := FNew[i]; end;

procedure TMultiMoveCommand.Rollback;
var i: Integer;
begin for i := 0 to High(FItems) do FItems[i].Bounds := FOld[i]; end;

// ===========================================================================
// TInsertObjectCommand
// ===========================================================================

constructor TInsertObjectCommand.Create(
  AList: TObjectList<TReportObject>; AObj: TReportObject);
begin FList := AList; FObj := AObj; FOwned := True; end;

destructor TInsertObjectCommand.Destroy;
begin if FOwned then FObj.Free; inherited; end;

procedure TInsertObjectCommand.Execute;
begin FList.Add(FObj); FOwned := False; end;

procedure TInsertObjectCommand.Rollback;
begin FList.Extract(FObj); FOwned := True; end;

// ===========================================================================
// TDeleteObjectsCommand
// ===========================================================================

constructor TDeleteObjectsCommand.Create(
  const AObjects   : TArray<TReportObject>;
  const AOwnerLists: TArray<TObjectList<TReportObject>>;
  const AIndices   : TArray<Integer>);
var i: Integer;
begin
  SetLength(FEntries, Length(AObjects));
  for i := 0 to High(AObjects) do
  begin
    FEntries[i].OwnerList := AOwnerLists[i];
    FEntries[i].OrigIndex := AIndices[i];
  end;
  FBuffer := TObjectList<TReportObject>.Create(True);
end;

destructor TDeleteObjectsCommand.Destroy;
begin FBuffer.Free; inherited; end;

procedure TDeleteObjectsCommand.Execute;
var
  i  : Integer;
  Obj: TReportObject;
begin
  // Extract in reverse index order so indices remain valid
  for i := High(FEntries) downto 0 do
  begin
    Obj := FEntries[i].OwnerList.Extract(
             FEntries[i].OwnerList[FEntries[i].OrigIndex]);
    FBuffer.Add(Obj);
  end;
end;

procedure TDeleteObjectsCommand.Rollback;
var
  BufIdx, EntryIdx, InsertAt: Integer;
  Obj: TReportObject;
begin
  // FBuffer holds items in reverse order of FEntries; restore in original order
  for BufIdx := FBuffer.Count - 1 downto 0 do
  begin
    EntryIdx := High(FEntries) - BufIdx;
    Obj      := FBuffer.Extract(FBuffer[BufIdx]);
    InsertAt := FEntries[EntryIdx].OrigIndex;
    if InsertAt > FEntries[EntryIdx].OwnerList.Count then
      InsertAt := FEntries[EntryIdx].OwnerList.Count;
    FEntries[EntryIdx].OwnerList.Insert(InsertAt, Obj);
  end;
end;

// ===========================================================================
// TBandResizeCommand
// ===========================================================================

constructor TBandResizeCommand.Create(ABand: TReportBand; OldH, NewH: Integer);
begin FBand := ABand; FOldH := OldH; FNewH := NewH; end;

procedure TBandResizeCommand.Execute;  begin FBand.Height := FNewH; end;
procedure TBandResizeCommand.Rollback; begin FBand.Height := FOldH; end;

// ===========================================================================
// TZOrderCommand
// ===========================================================================

constructor TZOrderCommand.Create(AList: TObjectList<TReportObject>;
  AObj: TReportObject; OldIdx, NewIdx: Integer);
begin FList := AList; FObj := AObj; FOldIdx := OldIdx; FNewIdx := NewIdx; end;

procedure TZOrderCommand.MoveItem(FromIdx, ToIdx: Integer);
var
  Obj     : TReportObject;
  InsertAt: Integer;
begin
  Obj      := FList.Extract(FList[FromIdx]);
  InsertAt := ToIdx;
  if FromIdx < ToIdx then Dec(InsertAt);
  if InsertAt < 0 then InsertAt := 0;
  if InsertAt >= FList.Count then FList.Add(Obj) else FList.Insert(InsertAt, Obj);
end;

procedure TZOrderCommand.Execute;  begin MoveItem(FOldIdx, FNewIdx); end;
procedure TZOrderCommand.Rollback; begin MoveItem(FNewIdx, FOldIdx); end;

// ===========================================================================
// TPropertyChangeCommand
// ===========================================================================

constructor TPropertyChangeCommand.Create(AObj: TObject; const Prop: string;
  const OldV, NewV: TValue);
begin FObj := AObj; FPropName := Prop; FOldValue := OldV; FNewValue := NewV; end;

procedure TPropertyChangeCommand.Execute;
var ctx: TRttiContext; p: TRttiProperty;
begin
  ctx := TRttiContext.Create;
  p   := ctx.GetType(FObj.ClassType).GetProperty(FPropName);
  if Assigned(p) then p.SetValue(FObj, FNewValue);
end;

procedure TPropertyChangeCommand.Rollback;
var ctx: TRttiContext; p: TRttiProperty;
begin
  ctx := TRttiContext.Create;
  p   := ctx.GetType(FObj.ClassType).GetProperty(FPropName);
  if Assigned(p) then p.SetValue(FObj, FOldValue);
end;

end.
