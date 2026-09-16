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

    { Read-only history access, forwarded to the command manager. }
    function UndoCount: Integer;
    function RedoCount: Integer;
    function UndoName(AIndex: Integer): string;
    function RedoName(AIndex: Integer): string;
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

function TCommandDispatcher.UndoCount: Integer;
begin
  Result := FCommands.UndoCount;
end;

function TCommandDispatcher.RedoCount: Integer;
begin
  Result := FCommands.RedoCount;
end;

function TCommandDispatcher.UndoName(AIndex: Integer): string;
begin
  Result := FCommands.UndoName(AIndex);
end;

function TCommandDispatcher.RedoName(AIndex: Integer): string;
begin
  Result := FCommands.RedoName(AIndex);
end;

end.
