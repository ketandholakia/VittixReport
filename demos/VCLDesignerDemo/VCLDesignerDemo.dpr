program VCLDesignerDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
