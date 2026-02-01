program ReportDesignerDemo;

uses
   madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
 Vcl.Forms,
  Vcl.ImgList,
  ReportDesignerDemo_MainForm in 'ReportDesignerDemo_MainForm.pas' {frmReportDesignerDemo};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmReportDesignerDemo, frmReportDesignerDemo);
  Application.Run;
end.