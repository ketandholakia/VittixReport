program VittixReportDemo;

uses
  Vcl.Forms,
  FireDAC.Phys.SQLite, // Ensure FireDAC SQLite driver is linked (initialize before forms)
  Frm.DemoMain in 'Frm.DemoMain.pas' {frmDemoMain};

{$R *.res}

begin
  // Enable memory leak reporting in debug mode to ensure the report engine and model free objects correctly.
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmDemoMain, frmDemoMain);
  Application.Run;
end.
