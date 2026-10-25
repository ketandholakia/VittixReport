program VittixReportDemo;

uses
  Winapi.Windows,
  System.SysUtils,
  System.IOUtils,
  Vcl.Forms,
  FireDAC.Phys.SQLite, // Ensure FireDAC SQLite driver is linked (initialize before forms)
  Frm.DemoMain in 'Frm.DemoMain.pas' {frmDemoMain};

{$R *.res}

var
  ValidationLog, ValidationMessage: string;

begin
  // Enable memory leak reporting in debug mode to ensure the report engine and model free objects correctly.
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmDemoMain, frmDemoMain);
  if SameText(ParamStr(1), '--validate-acceptance-fixture') then
  begin
    ValidationLog := GetEnvironmentVariable('VITTIX_GUI_ACCEPTANCE_LOG');
    AllocConsole;
    try
      try
        frmDemoMain.ValidateAcceptanceFixtureForTest;
        ValidationMessage := 'PASS: ' + frmDemoMain.AcceptanceValidationEvidence;
        ExitCode := 0;
      except
        on E: Exception do
        begin
          ValidationMessage := 'FAIL: ' + E.ClassName + ': ' + E.Message;
          ExitCode := 1;
        end;
      end;
      Writeln(ValidationMessage);
      if ValidationLog <> '' then
        TFile.WriteAllText(ValidationLog, ValidationMessage, TEncoding.UTF8);
    finally
      FreeConsole;
    end;
    Halt(ExitCode);
  end;
  Application.Run;
end.
