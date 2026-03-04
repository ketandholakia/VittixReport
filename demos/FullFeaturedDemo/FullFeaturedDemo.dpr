program FullFeaturedDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'VittixReport Full-Featured Demo';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
