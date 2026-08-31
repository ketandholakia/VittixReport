program VittixRunner;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Vittix.Runner.Options in 'Vittix.Runner.Options.pas',
  Vittix.Runner.Execution in 'Vittix.Runner.Execution.pas',
  Vittix.Runner.Console in 'Vittix.Runner.Console.pas';

begin
  try
    TVittixConsoleRunner.Run;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.