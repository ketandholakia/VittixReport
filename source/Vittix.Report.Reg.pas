unit Vittix.Report.Reg;

interface

procedure Register;

implementation

uses
  System.Classes,
  Vittix.Report.DesignerControl,
  Vittix.Report.Toolbox,
  Vittix.Report.Preview;

procedure Register;
begin
  { Design-time component registration }
  RegisterComponents('Vittix Reporting', [
    TVittixReportDesigner,
    TVittixReportToolbox,
    TVittixReportPreview
  ]);
end;

end.
