unit Test.Vittix.Report.Undo;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  Vcl.Controls,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Undo,
  Vittix.Report.CommandDispatcher,
  Vittix.Report.DesignerInteraction,
  Vittix.Report.DesignerInteractionController;

type
  TMockUndoableAction = class(TUndoableAction)
  private
    FExecuteCount: Integer;
    FRollbackCount: Integer;
  public
    constructor Create; override;
    procedure Execute; override;
    procedure Rollback; override;
    property ExecuteCount: Integer read FExecuteCount;
    property RollbackCount: Integer read FRollbackCount;
  end;

  { Stands in for TReportSnapshotCommand: its Execute replaces the object
    graph the manager's older entries still point into. }
  TMockInvalidatingAction = class(TMockUndoableAction)
  public
    function InvalidatesObjectRefs: Boolean; override;
  end;

  TRollbackRaisingAction = class(TUndoableAction)
  public
    procedure Execute; override;
    procedure Rollback; override;
  end;

  TExecuteRaisingAction = class(TUndoableAction)
  public
    procedure Execute; override;
    procedure Rollback; override;
  end;

  [TestFixture]
  TTestMacroCommand = class
  public
    [Test]
    procedure Test_MacroCommand_ExecuteOrder;
    [Test]
    procedure Test_MacroCommand_RollbackOrder;
  end;

  [TestFixture]
  TTestCommandManager = class
  public
    [Test]
    procedure Test_DoCommand_AddsToUndo;
    [Test]
    procedure Test_UndoLast_RollsBack;
    [Test]
    procedure Test_RedoLast_ExecutesAgain;
    [Test]
    procedure Test_DoCommand_CapsHistoryAt100;
  end;

  [TestFixture]
  TTestObjectRefInvalidation = class
  public
    [Test]
    procedure Test_Default_InvalidatesObjectRefs_IsFalse;
    [Test]
    procedure Test_DoCommand_Invalidating_DropsPriorHistory;
    [Test]
    procedure Test_DoCommand_Invalidating_ClearsRedoStack;
    [Test]
    procedure Test_UndoAfterInvalidation_LeavesNoOlderEntries;
    [Test]
    procedure Test_DoCommand_ExecuteRaises_DoesNotStrandCommand;
    [Test]
    procedure Test_UndoLast_RollbackRaises_DoesNotStrandCommand;
  end;

  [TestFixture]
  TTestMoveObjectCommand = class
  public
    [Test]
    procedure Test_NilObject_ExecuteRollback_DoesNotRaise;
  end;

  [TestFixture]
  TTestDesignerClickHistory = class
  public
    [Test]
    procedure Test_PlainClick_AddsNoHistoryEntry;
    [Test]
    procedure Test_DragBeyondThreshold_AddsOneMoveEntry;
  end;

  { Minimal IDesignerSurface for controller-level tests: hit tests answer
    for one object only; the remaining members are inert so the controller's
    click/drag path can be driven without a real control. }
  TControllerSurfaceFake = class(TInterfacedObject, IDesignerSurface)
  private
    FObj: TReportObject;
    FBand: TReportBand;
    FSelected: TList<TReportObject>;
    FCommands: TCommandDispatcher;
    FActiveBand: TReportBand;
  public
    constructor Create(AObj: TReportObject; ABand: TReportBand);
    destructor Destroy; override;
    property Commands: TCommandDispatcher read FCommands;

    // IDesignerSurface - only the members the click/drag path touches do work.
    procedure SetFocus;
    procedure Invalidate;
    procedure DoModified;
    procedure DoSelectionChanged;
    function GetCursor: TCursor;
    procedure SetCursor(Value: TCursor);
    function GetCommands: TCommandDispatcher;
    function GetSelected: TList<TReportObject>;
    function GetBandLayouts: TDesignerBandLayouts;
    procedure SetActiveBand(ABand: TReportBand);
    function GetActiveBand: TReportBand;
    function GetInsertClass: TReportObjectClass;
    procedure SetInsertClass(AClass: TReportObjectClass);
    function UnScale(V: Integer): Integer;
    function SnapV(V: Integer): Integer;
    function ScreenToPage(const P: TPoint): TPoint;
    procedure ClearSelection;
    procedure AddToSelection(AObj: TReportObject);
    procedure RemoveFromSelection(AObj: TReportObject);
    procedure SelectObject(AObj: TReportObject);
    function GetPrimarySelected: TReportObject;
    function GetObjectBandMap: TDictionary<TReportObject, TReportBand>;
    function GetSmartGuides: Boolean;
    procedure ComputeBandLayouts;
    function BandOwnerOf(AObj: TReportObject): TReportBand;
    procedure UpdateCursor(X, Y: Integer);
    function GetPageLeft: Integer;
    function GetPageTop: Integer;
    function GetPageWidth: Integer;
    function GetPageHeight: Integer;
    function BandSepHitTest(ScreenPt: TPoint; out HitBand: TReportBand): Boolean;
    function BandHeaderHitTest(ScreenPt: TPoint; out HitBand: TReportBand): Boolean;
    function BandHitTest(ScreenPt: TPoint; out HitBand: TReportBand): Boolean;
    function ObjectHitTest(ScreenPt: TPoint; out HitObj: TReportObject): Boolean;
    function HandleHitTest(ScreenPt: TPoint; out H: TResizeHandle): Boolean;
    function ObjScreenRect(Obj: TReportObject): TRect;
  end;

implementation

{ TMockUndoableAction }

constructor TMockUndoableAction.Create;
begin
  inherited Create;
  FExecuteCount := 0;
  FRollbackCount := 0;
  ActionName := 'MockAction';
end;

procedure TMockUndoableAction.Execute;
begin
  Inc(FExecuteCount);
end;

procedure TMockUndoableAction.Rollback;
begin
  Inc(FRollbackCount);
end;

function TMockInvalidatingAction.InvalidatesObjectRefs: Boolean;
begin
  Result := True;
end;

procedure TRollbackRaisingAction.Execute;
begin
  // no-op: only Rollback raises
end;

procedure TRollbackRaisingAction.Rollback;
begin
  raise Exception.Create('intentional Rollback failure');
end;

procedure TExecuteRaisingAction.Execute;
begin
  raise Exception.Create('intentional Execute failure');
end;

procedure TExecuteRaisingAction.Rollback;
begin
  // no-op: only Execute raises
end;

{ TTestMacroCommand }

procedure TTestMacroCommand.Test_MacroCommand_ExecuteOrder;
var
  LMacro: TMacroCommand;
  LAction1, LAction2: TMockUndoableAction;
begin
  LMacro := TMacroCommand.Create;
  try
    LAction1 := TMockUndoableAction.Create;
    LAction2 := TMockUndoableAction.Create;
    
    LMacro.Add(LAction1);
    LMacro.Add(LAction2);
    
    LMacro.Execute;
    
    Assert.AreEqual(1, LAction1.ExecuteCount, 'Action 1 should be executed once');
    Assert.AreEqual(1, LAction2.ExecuteCount, 'Action 2 should be executed once');
    Assert.AreEqual(0, LAction1.RollbackCount, 'Action 1 should not be rolled back');
    Assert.AreEqual(0, LAction2.RollbackCount, 'Action 2 should not be rolled back');
  finally
    LMacro.Free;
  end;
end;

procedure TTestMacroCommand.Test_MacroCommand_RollbackOrder;
var
  LMacro: TMacroCommand;
  LAction1, LAction2: TMockUndoableAction;
begin
  LMacro := TMacroCommand.Create;
  try
    LAction1 := TMockUndoableAction.Create;
    LAction2 := TMockUndoableAction.Create;
    
    LMacro.Add(LAction1);
    LMacro.Add(LAction2);
    
    LMacro.Execute;
    LMacro.Rollback;
    
    Assert.AreEqual(1, LAction1.RollbackCount, 'Action 1 should be rolled back once');
    Assert.AreEqual(1, LAction2.RollbackCount, 'Action 2 should be rolled back once');
  finally
    LMacro.Free;
  end;
end;

{ TTestCommandManager }

procedure TTestCommandManager.Test_DoCommand_AddsToUndo;
var
  Mgr: TCommandManager;
  Act: TMockUndoableAction;
begin
  Mgr := TCommandManager.Create;
  try
    Act := TMockUndoableAction.Create;
    Mgr.DoCommand(Act);
    Assert.AreEqual(1, Act.ExecuteCount);
    Assert.IsTrue(Mgr.CanUndo);
    Assert.IsFalse(Mgr.CanRedo);
    Assert.AreEqual('MockAction', Mgr.NextUndoName);
  finally
    Mgr.Free;
  end;
end;

procedure TTestCommandManager.Test_UndoLast_RollsBack;
var
  Mgr: TCommandManager;
  Act: TMockUndoableAction;
begin
  Mgr := TCommandManager.Create;
  try
    Act := TMockUndoableAction.Create;
    Mgr.DoCommand(Act);
    Mgr.UndoLast;
    Assert.AreEqual(1, Act.RollbackCount);
    Assert.IsFalse(Mgr.CanUndo);
    Assert.IsTrue(Mgr.CanRedo);
  finally
    Mgr.Free;
  end;
end;

procedure TTestCommandManager.Test_RedoLast_ExecutesAgain;
var
  Mgr: TCommandManager;
  Act: TMockUndoableAction;
begin
  Mgr := TCommandManager.Create;
  try
    Act := TMockUndoableAction.Create;
    Mgr.DoCommand(Act);
    Mgr.UndoLast;
    Mgr.RedoLast;
    Assert.AreEqual(2, Act.ExecuteCount);
    Assert.IsTrue(Mgr.CanUndo);
    Assert.IsFalse(Mgr.CanRedo);
  finally
    Mgr.Free;
  end;
end;

procedure TTestCommandManager.Test_DoCommand_CapsHistoryAt100;
var
  Mgr: TCommandManager;
  I: Integer;
  Act: TMockUndoableAction;
begin
  // DP-23 / M-1: the history must not grow without bound; the oldest
  // entries fall off once the cap is reached (FIFO).
  Mgr := TCommandManager.Create;
  try
    for I := 1 to 150 do
    begin
      Act := TMockUndoableAction.Create;
      Act.ActionName := Format('A%d', [I]);
      Mgr.DoCommand(Act);
    end;

    Assert.AreEqual(100, Mgr.UndoCount, 'undo history must be capped at 100');
    Assert.AreEqual('A150', Mgr.NextUndoName, 'the newest command stays on top');

    // Exactly the surviving 100 entries are undoable; the dropped oldest
    // 50 entries can no longer be rolled back.
    for I := 1 to 100 do
      Mgr.UndoLast;
    Assert.IsFalse(Mgr.CanUndo, 'only the capped history must be undoable');
    Assert.AreEqual(100, Mgr.RedoCount, 'the capped history must be redoable');
  finally
    Mgr.Free;
  end;
end;

{ TTestObjectRefInvalidation }

procedure TTestObjectRefInvalidation.Test_Default_InvalidatesObjectRefs_IsFalse;
var
  Act: TMockUndoableAction;
begin
  Act := TMockUndoableAction.Create;
  try
    Assert.IsFalse(Act.InvalidatesObjectRefs, 'plain commands must keep history');
  finally
    Act.Free;
  end;
end;

procedure TTestObjectRefInvalidation.Test_DoCommand_Invalidating_DropsPriorHistory;
var
  Mgr: TCommandManager;
  Obj1, Obj2: TReportTextObject;
  Snap: TMockInvalidatingAction;
begin
  // DP-08: the two move commands hold raw pointers into the object graph.
  // The invalidating command replaces that graph (like the Band Manager
  // snapshot reloads the whole report), so the move entries MUST be dropped:
  // undoing past the snapshot would write through dangling references.
  Obj1 := TReportTextObject.Create;
  Obj2 := TReportTextObject.Create;
  try
    Mgr := TCommandManager.Create;
    try
      Mgr.DoCommand(TMoveObjectCommand.Create(Obj1, Rect(0, 0, 10, 10), Rect(5, 5, 15, 15)));
      Mgr.DoCommand(TMoveObjectCommand.Create(Obj2, Rect(0, 0, 10, 10), Rect(5, 5, 15, 15)));
      Assert.AreEqual(2, Mgr.UndoCount);

      Snap := TMockInvalidatingAction.Create;
      Snap.ActionName := 'Band Manager Changes';
      Mgr.DoCommand(Snap);

      Assert.AreEqual(1, Mgr.UndoCount,
        'history older than the invalidating command must be dropped');
      Assert.AreEqual('Band Manager Changes', Mgr.NextUndoName);
    finally
      Mgr.Free;
    end;
  finally
    Obj1.Free;
    Obj2.Free;
  end;
end;

procedure TTestObjectRefInvalidation.Test_DoCommand_Invalidating_ClearsRedoStack;
var
  Mgr: TCommandManager;
  Act: TMockUndoableAction;
  Snap: TMockInvalidatingAction;
begin
  Mgr := TCommandManager.Create;
  try
    Act := TMockUndoableAction.Create;
    Mgr.DoCommand(Act);
    Mgr.UndoLast;
    Assert.IsTrue(Mgr.CanRedo);

    Snap := TMockInvalidatingAction.Create;
    Mgr.DoCommand(Snap);

    Assert.AreEqual(1, Mgr.UndoCount, 'only the invalidating command remains');
    Assert.IsFalse(Mgr.CanRedo, 'redo entries must not survive the invalidation');
  finally
    Mgr.Free;
  end;
end;

procedure TTestObjectRefInvalidation.Test_UndoAfterInvalidation_LeavesNoOlderEntries;
var
  Mgr: TCommandManager;
  Obj1: TReportTextObject;
  Snap: TMockInvalidatingAction;
begin
  Obj1 := TReportTextObject.Create;
  try
    Mgr := TCommandManager.Create;
    try
      Mgr.DoCommand(TMoveObjectCommand.Create(Obj1, Rect(0, 0, 10, 10), Rect(5, 5, 15, 15)));

      Snap := TMockInvalidatingAction.Create;
      Mgr.DoCommand(Snap);

      Mgr.UndoLast;  // must roll back the snapshot only

      Assert.AreEqual(1, Snap.RollbackCount);
      Assert.IsFalse(Mgr.CanUndo, 'undo must stop at the invalidating command');
      Assert.IsTrue(Mgr.CanRedo);
    finally
      Mgr.Free;
    end;
  finally
    Obj1.Free;
  end;
end;

procedure TTestObjectRefInvalidation.Test_DoCommand_ExecuteRaises_DoesNotStrandCommand;
var
  Mgr: TCommandManager;
begin
  Mgr := TCommandManager.Create;
  try
    Assert.WillRaise(
      procedure begin Mgr.DoCommand(TExecuteRaisingAction.Create); end,
      Exception);

    Assert.IsFalse(Mgr.CanUndo, 'a failed command must not enter the undo stack');
    Assert.IsFalse(Mgr.CanRedo);
  finally
    Mgr.Free;
  end;
end;

procedure TTestObjectRefInvalidation.Test_UndoLast_RollbackRaises_DoesNotStrandCommand;
var
  Mgr: TCommandManager;
begin
  Mgr := TCommandManager.Create;
  try
    Mgr.DoCommand(TRollbackRaisingAction.Create);

    Assert.WillRaise(
      procedure begin Mgr.UndoLast; end,
      Exception);

    Assert.IsFalse(Mgr.CanUndo, 'the failed command must leave the undo stack');
    Assert.IsFalse(Mgr.CanRedo, 'the failed command must not enter the redo stack');
  finally
    Mgr.Free;
  end;
end;

{ TTestMoveObjectCommand }

procedure TTestMoveObjectCommand.Test_NilObject_ExecuteRollback_DoesNotRaise;
var
  Cmd: TMoveObjectCommand;
begin
  // Defense-in-depth for the dangling-reference era: a stale command can
  // never be allowed to dereference absent storage (DP-08).
  Cmd := TMoveObjectCommand.Create(nil, Rect(0, 0, 10, 10), Rect(5, 5, 15, 15));
  try
    Cmd.Execute;
    Cmd.Rollback;
  finally
    Cmd.Free;
  end;
  Assert.Pass;
end;

{ TControllerSurfaceFake }

constructor TControllerSurfaceFake.Create(AObj: TReportObject;
  ABand: TReportBand);
begin
  inherited Create;
  FObj := AObj;
  FBand := ABand;
  FSelected := TList<TReportObject>.Create;
  FCommands := TCommandDispatcher.Create;
end;

destructor TControllerSurfaceFake.Destroy;
begin
  FCommands.Free;
  FSelected.Free;
  inherited;
end;

procedure TControllerSurfaceFake.SetFocus; begin end;
procedure TControllerSurfaceFake.Invalidate; begin end;
procedure TControllerSurfaceFake.DoModified; begin end;
procedure TControllerSurfaceFake.DoSelectionChanged; begin end;

function TControllerSurfaceFake.GetCursor: TCursor;
begin
  Result := crDefault;
end;

procedure TControllerSurfaceFake.SetCursor(Value: TCursor); begin end;

function TControllerSurfaceFake.GetCommands: TCommandDispatcher;
begin
  Result := FCommands;
end;

function TControllerSurfaceFake.GetSelected: TList<TReportObject>;
begin
  Result := FSelected;
end;

function TControllerSurfaceFake.GetBandLayouts: TDesignerBandLayouts;
begin
  Result := nil;
end;

procedure TControllerSurfaceFake.SetActiveBand(ABand: TReportBand);
begin
  FActiveBand := ABand;
end;

function TControllerSurfaceFake.GetActiveBand: TReportBand;
begin
  Result := FActiveBand;
end;

function TControllerSurfaceFake.GetInsertClass: TReportObjectClass;
begin
  Result := nil;
end;

procedure TControllerSurfaceFake.SetInsertClass(AClass: TReportObjectClass); begin end;

function TControllerSurfaceFake.UnScale(V: Integer): Integer;
begin
  Result := V;
end;

function TControllerSurfaceFake.SnapV(V: Integer): Integer;
begin
  Result := V;
end;

function TControllerSurfaceFake.ScreenToPage(const P: TPoint): TPoint;
begin
  Result := P;
end;

procedure TControllerSurfaceFake.ClearSelection;
begin
  FSelected.Clear;
end;

procedure TControllerSurfaceFake.AddToSelection(AObj: TReportObject);
begin
  FSelected.Add(AObj);
end;

procedure TControllerSurfaceFake.RemoveFromSelection(AObj: TReportObject);
begin
  FSelected.Remove(AObj);
end;

procedure TControllerSurfaceFake.SelectObject(AObj: TReportObject);
begin
  FSelected.Clear;
  if Assigned(AObj) then
    FSelected.Add(AObj);
end;

function TControllerSurfaceFake.GetPrimarySelected: TReportObject;
begin
  if FSelected.Count > 0 then
    Result := FSelected[0]
  else
    Result := nil;
end;

function TControllerSurfaceFake.GetObjectBandMap: TDictionary<TReportObject, TReportBand>;
begin
  Result := nil;
end;

function TControllerSurfaceFake.GetSmartGuides: Boolean;
begin
  Result := False;
end;

procedure TControllerSurfaceFake.ComputeBandLayouts; begin end;

function TControllerSurfaceFake.BandOwnerOf(AObj: TReportObject): TReportBand;
begin
  Result := FBand;
end;

procedure TControllerSurfaceFake.UpdateCursor(X, Y: Integer); begin end;

function TControllerSurfaceFake.GetPageLeft: Integer;
begin
  Result := 0;
end;

function TControllerSurfaceFake.GetPageTop: Integer;
begin
  Result := 0;
end;

function TControllerSurfaceFake.GetPageWidth: Integer;
begin
  Result := 800;
end;

function TControllerSurfaceFake.GetPageHeight: Integer;
begin
  Result := 1100;
end;

function TControllerSurfaceFake.BandSepHitTest(ScreenPt: TPoint;
  out HitBand: TReportBand): Boolean;
begin
  HitBand := nil;
  Result := False;
end;

function TControllerSurfaceFake.BandHeaderHitTest(ScreenPt: TPoint;
  out HitBand: TReportBand): Boolean;
begin
  HitBand := nil;
  Result := False;
end;

function TControllerSurfaceFake.BandHitTest(ScreenPt: TPoint;
  out HitBand: TReportBand): Boolean;
begin
  HitBand := nil;
  Result := False;
end;

function TControllerSurfaceFake.ObjectHitTest(ScreenPt: TPoint;
  out HitObj: TReportObject): Boolean;
begin
  // Every click lands on the single object this surface knows about.
  HitObj := FObj;
  Result := Assigned(FObj);
end;

function TControllerSurfaceFake.HandleHitTest(ScreenPt: TPoint;
  out H: TResizeHandle): Boolean;
begin
  H := rhNone;
  Result := False;
end;

function TControllerSurfaceFake.ObjScreenRect(Obj: TReportObject): TRect;
begin
  if Assigned(Obj) then
    Result := Obj.Bounds
  else
    Result := Rect(0, 0, 0, 0);
end;

{ TTestDesignerClickHistory }

procedure TTestDesignerClickHistory.Test_PlainClick_AddsNoHistoryEntry;
var
  Obj: TReportTextObject;
  Band: TReportBand;
  Fake: TControllerSurfaceFake;
  Surface: IDesignerSurface;
  Controller: TDesignerInteractionController;
begin
  // DP-23 / M-2: selecting an object with a plain click must not push the
  // no-op move command (Old = New bounds) that MouseUp used to create.
  Obj := TReportTextObject.Create;
  Obj.Bounds := Rect(10, 10, 110, 40);
  Band := TReportBand.Create;
  Band.Height := 80;
  Band.Children.Add(Obj); // the band owns the object

  Fake := TControllerSurfaceFake.Create(Obj, Band);
  try
    Surface := Fake;
    Controller := TDesignerInteractionController.Create(Surface);
    try
      Controller.MouseDown(mbLeft, [], 50, 25);
      Controller.MouseUp(mbLeft, [], 50, 25); // released at the same point

      Assert.AreEqual(0, Fake.Commands.UndoCount,
        'a plain click must not add a no-op move command to the undo history');
      Assert.IsTrue(Obj.Bounds = Rect(10, 10, 110, 40),
        'a plain click must not change the object bounds');
    finally
      Controller.Free;
      Surface := nil; // releases the fake (interface refcount reaches zero)
    end;
  finally
    Band.Free;
  end;
end;

procedure TTestDesignerClickHistory.Test_DragBeyondThreshold_AddsOneMoveEntry;
var
  Obj: TReportTextObject;
  Band: TReportBand;
  Fake: TControllerSurfaceFake;
  Surface: IDesignerSurface;
  Controller: TDesignerInteractionController;
begin
  // Control: a real drag (crossing the move threshold) still records exactly
  // one move command carrying the moved bounds.
  Obj := TReportTextObject.Create;
  Obj.Bounds := Rect(10, 10, 110, 40);
  Band := TReportBand.Create;
  Band.Height := 80;
  Band.Children.Add(Obj);

  Fake := TControllerSurfaceFake.Create(Obj, Band);
  try
    Surface := Fake;
    Controller := TDesignerInteractionController.Create(Surface);
    try
      Controller.MouseDown(mbLeft, [], 50, 25);
      Controller.MouseMove([], 80, 25); // 30 px right
      Controller.MouseUp(mbLeft, [], 80, 25);

      Assert.AreEqual(1, Fake.Commands.UndoCount,
        'a real drag must add exactly one move command');
      Assert.IsTrue(Obj.Bounds = Rect(40, 10, 140, 40),
        'bounds must follow the drag');
    finally
      Controller.Free;
      Surface := nil;
    end;
  finally
    Band.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestMacroCommand);
  TDUnitX.RegisterTestFixture(TTestCommandManager);
  TDUnitX.RegisterTestFixture(TTestObjectRefInvalidation);
  TDUnitX.RegisterTestFixture(TTestMoveObjectCommand);
  TDUnitX.RegisterTestFixture(TTestDesignerClickHistory);

end.
