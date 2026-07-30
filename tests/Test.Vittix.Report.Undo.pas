unit Test.Vittix.Report.Undo;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
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

initialization
  TDUnitX.RegisterTestFixture(TTestMacroCommand);
  TDUnitX.RegisterTestFixture(TTestCommandManager);

end.
