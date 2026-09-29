unit Test.Vittix.Report.Undo;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  Vittix.Report.Objects,
  Vittix.Report.Undo;

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

initialization
  TDUnitX.RegisterTestFixture(TTestMacroCommand);
  TDUnitX.RegisterTestFixture(TTestCommandManager);
  TDUnitX.RegisterTestFixture(TTestObjectRefInvalidation);
  TDUnitX.RegisterTestFixture(TTestMoveObjectCommand);

end.
