program VittixReportDemo;

uses
  Vcl.Forms,
  FireDAC.Phys.SQLite, // Ensure FireDAC SQLite driver is linked (initialize before forms)
  Frm.DemoMain in 'Frm.DemoMain.pas' {frmDemoMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmDemoMain, frmDemoMain);
  Application.Run;
end.
