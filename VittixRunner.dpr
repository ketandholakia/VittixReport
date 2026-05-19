program VittixRunner;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Vittix.Runner.Console in 'Vittix.Runner.Console.pas';

begin
  try
    TVittixConsoleRunner.Run;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.