unit Test.Vittix.Report.Undo;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
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

implementation

{ TMockUndoableAction }

constructor TMockUndoableAction.Create;
begin
  inherited Create;
  FExecuteCount := 0;
  FRollbackCount := 0;
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

initialization
  TDUnitX.RegisterTestFixture(TTestMacroCommand);

end.
