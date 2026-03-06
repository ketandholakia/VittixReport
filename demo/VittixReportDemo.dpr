program VittixReportDemo;

uses
  Vcl.Forms,
  Frm.DemoMain in 'Frm.DemoMain.pas' {frmDemoMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmDemoMain, frmDemoMain);
  Application.Run;
end.

