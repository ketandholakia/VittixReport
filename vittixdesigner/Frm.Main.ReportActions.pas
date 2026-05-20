unit Frm.Main.ReportActions;

interface

uses
  System.SysUtils;

type
  TReportActionCallback = TProc;
  TReportNameActionCallback = TProc<string>;

procedure RunSampleReportAction(const AAction: TReportActionCallback);
procedure RunOpenReportAction(const AReportName: string; const AOpenReport: TReportNameActionCallback);
procedure RunRegressionTestReportsAction(
  const AUseSampleDataSet, ARefreshFieldList, ARefreshReportStructure, AUpdateAll: TReportActionCallback);

implementation

procedure RunSampleReportAction(const AAction: TReportActionCallback);
begin
  if Assigned(AAction) then
    AAction();
end;

procedure RunOpenReportAction(const AReportName: string; const AOpenReport: TReportNameActionCallback);
begin
  if Assigned(AOpenReport) then
    AOpenReport(AReportName);
end;

procedure RunRegressionTestReportsAction(
  const AUseSampleDataSet, ARefreshFieldList, ARefreshReportStructure, AUpdateAll: TReportActionCallback);
begin
  if Assigned(AUseSampleDataSet) then
    AUseSampleDataSet();
  if Assigned(ARefreshFieldList) then
    ARefreshFieldList();
  if Assigned(ARefreshReportStructure) then
    ARefreshReportStructure();
  if Assigned(AUpdateAll) then
    AUpdateAll();
end;

end.
