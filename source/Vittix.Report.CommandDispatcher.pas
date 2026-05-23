unit Vittix.Report.CommandDispatcher;

interface

uses
  Vittix.Report.Undo;

type
  TCommandDispatcher = class
  private
    FCommands: TCommandManager;
  public
    constructor Create;
    destructor Destroy; override;

    procedure DoCommand(ACommand: TUndoableAction);
    procedure Undo;
    procedure Redo;
    procedure Clear;

    function CanUndo: Boolean;
    function CanRedo: Boolean;
    function NextUndoName: string;
    function NextRedoName: string;
  end;

implementation

constructor TCommandDispatcher.Create;
begin
  inherited Create;
  FCommands := TCommandManager.Create;
end;

destructor TCommandDispatcher.Destroy;
begin
  FCommands.Free;
  inherited;
end;

procedure TCommandDispatcher.DoCommand(ACommand: TUndoableAction);
begin
  FCommands.DoCommand(ACommand);
end;

procedure TCommandDispatcher.Undo;
begin
  FCommands.UndoLast;
end;

procedure TCommandDispatcher.Redo;
begin
  FCommands.RedoLast;
end;

procedure TCommandDispatcher.Clear;
begin
  FCommands.Clear;
end;

function TCommandDispatcher.CanUndo: Boolean;
begin
  Result := FCommands.CanUndo;
end;

function TCommandDispatcher.CanRedo: Boolean;
begin
  Result := FCommands.CanRedo;
end;

function TCommandDispatcher.NextUndoName: string;
begin
  Result := FCommands.NextUndoName;
end;

function TCommandDispatcher.NextRedoName: string;
begin
  Result := FCommands.NextRedoName;
end;

end.
