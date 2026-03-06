unit Vittix.Report.Reg;

{
  Vittix.Report.Reg
  =================
  Single entry point for all design-time registration.
  The IDE calls Register once when the package is installed.

  NOTE: TVittixReportDesigner, TVittixReportToolbox and TVittixReportPreview
  each have their own Register procedure in their own units and are already
  listed in VittixReportRuntime.dpk.  Calling RegisterComponents for them
  here again causes duplicate palette entries.  Only TVittixReport (the new
  non-visual component) needs registering here because its unit is new and
  its own Register procedure is called via this entry point.
}

interface

procedure Register;

implementation

uses
  System.Classes,
  Vittix.Report.Component,       // TVittixReport  (non-visual)
  Vittix.Report.ComponentEditor; // TVittixReportComponentEditor

procedure Register;
begin
  // Register the non-visual component on the palette
  RegisterComponents('Vittix Reporting', [TVittixReport]);

  // Wire double-click on TVittixReport icon to open VittixDesigner.exe
  RegisterVittixReportComponentEditor;
end;

end.
