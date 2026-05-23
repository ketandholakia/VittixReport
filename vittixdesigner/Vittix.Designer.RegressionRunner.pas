unit Vittix.Designer.RegressionRunner;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.IOUtils,
  Vcl.Dialogs,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Renderer,
  Vittix.Report.Serializer;

procedure RunRegressionTestReports(
  const AGetRegressionReportPath: TFunc<string, string>;
  const AUseSampleDataSet: TProc;
  const AGetSampleDataSet: TFunc<TDataSet>;
  const ARefreshUI: TProc);

implementation

procedure RunRegressionTestReports(
  const AGetRegressionReportPath: TFunc<string, string>;
  const AUseSampleDataSet: TProc;
  const AGetSampleDataSet: TFunc<TDataSet>;
  const ARefreshUI: TProc);
const
  ReportFiles: array[0..17] of string = (
    '01_simple_masterdata.vrt',
    '03_grouped_report.vrt',
    '05_cangrow_remarks.vrt',
    '06_barcode_test.vrt',
    '07_imagepath_test.vrt',
    '11_exact_fit_boundary.vrt',
    '12_summary_new_page_header.vrt',
    '13_group_header_pagebreak.vrt',
    '14_group_footer_pagebreak.vrt',
    '15_large_preview_stress.vrt',
    '17_object_printwhen_core.vrt',
    '18_barcode_printwhen.vrt',
    '19_displayformat_values.vrt',
    '20_printwhen_boolean_coercion.vrt',
    '21_condition_color_boolean_coercion.vrt',
    '22_expression_usage_demo.vrt',
    '23_invalid_datafield_diagnostics.vrt',
    '29_band_gap_layout.vrt'
  );
var
  Lines: TStringList;
  I: Integer;
  FN: string;
  ReportModel: TReportModel;
  Renderer: TReportRenderer;
  PassedCount: Integer;
  FailedCount: Integer;
  PageSuffix: string;
begin
  if Assigned(AUseSampleDataSet) then
    AUseSampleDataSet;

  Lines := TStringList.Create;
  try
    PassedCount := 0;
    FailedCount := 0;

    for I := Low(ReportFiles) to High(ReportFiles) do
    begin
      FN := AGetRegressionReportPath(ReportFiles[I]);
      if not TFile.Exists(FN) then
      begin
        Inc(FailedCount);
        Lines.Add('FAIL ' + ReportFiles[I] + ' - Test report file not found: ' + FN);
        Continue;
      end;

      ReportModel := nil;
      Renderer := nil;
      try
        ReportModel := TReportSerializer.LoadFromFile(FN);
        Renderer := TReportRenderer.Create;
        if Assigned(AGetSampleDataSet) then
          Renderer.Render(ReportModel, AGetSampleDataSet)
        else
          Renderer.Render(ReportModel, nil);
        Inc(PassedCount);
        if Renderer.Pages.Count = 1 then
          PageSuffix := ''
        else
          PageSuffix := 's';
        Lines.Add(Format('PASS %s (%d page%s)',
          [ReportFiles[I], Renderer.Pages.Count, PageSuffix]));
      except
        on E: Exception do
        begin
          Inc(FailedCount);
          Lines.Add('FAIL ' + ReportFiles[I] + ' - ' + E.Message);
        end;
      end;
      Renderer.Free;
      ReportModel.Free;
    end;

    Lines.Insert(0, Format('Failed: %d', [FailedCount]));
    Lines.Insert(0, Format('Passed: %d', [PassedCount]));
    Lines.Insert(0, Format('Total tests: %d', [Length(ReportFiles)]));
    ShowMessage(Lines.Text);
  finally
    Lines.Free;
    if Assigned(ARefreshUI) then
      ARefreshUI;
  end;
end;

end.
