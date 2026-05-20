unit Frm.Main.SampleHelpers;

interface

uses
  System.SysUtils;

function GetRegressionReportPath(const AFileName: string): string;
procedure OpenRegressionReport(const AFileName: string;
  const AConfirmSaveIfModified: TProc;
  const ALoadDesignerReportFromFile: TProc<string>;
  const AShowMessage: TProc<string>;
  const AGetRegressionReportPath: TFunc<string, string>);

implementation

uses
  System.IOUtils,
  System.Classes,
  System.Types,
  System.UITypes;

function GetRegressionReportPath(const AFileName: string): string;
var
  Candidates: array[0..3] of string;
  I: Integer;
begin
  Candidates[0] := TPath.Combine(ExtractFilePath(ParamStr(0)), 'reports\' + AFileName);
  Candidates[1] := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\reports\' + AFileName));
  Candidates[2] := TPath.GetFullPath(TPath.Combine(GetCurrentDir, 'reports\' + AFileName));
  Candidates[3] := TPath.GetFullPath(TPath.Combine(GetCurrentDir, '..\reports\' + AFileName));

  for I := Low(Candidates) to High(Candidates) do
    if TFile.Exists(Candidates[I]) then
      Exit(Candidates[I]);

  Result := Candidates[1];
end;

procedure OpenRegressionReport(const AFileName: string;
  const AConfirmSaveIfModified: TProc;
  const ALoadDesignerReportFromFile: TProc<string>;
  const AShowMessage: TProc<string>;
  const AGetRegressionReportPath: TFunc<string, string>);
var
  FN: string;
begin
  if Assigned(AConfirmSaveIfModified) then
    AConfirmSaveIfModified();
  if not Assigned(AGetRegressionReportPath) or not Assigned(ALoadDesignerReportFromFile) or not Assigned(AShowMessage) then
    Exit;
  FN := AGetRegressionReportPath(AFileName);
  if not TFile.Exists(FN) then
  begin
    AShowMessage('Test report file not found: ' + FN);
    Exit;
  end;
  try
    ALoadDesignerReportFromFile(FN);
  except
    on E: Exception do
      AShowMessage('Error loading report: ' + E.Message);
  end;
end;

end.
