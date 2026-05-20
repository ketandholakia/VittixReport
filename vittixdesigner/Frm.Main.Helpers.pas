unit Frm.Main.Helpers;

interface

uses
  Vittix.Report.Bands,
  Vittix.Report.PageSettings;

function BandTypeName(BT: TReportBandType): string;
function PageSettingsEqual(A, B: TReportPageSettings): Boolean;

implementation

function BandTypeName(BT: TReportBandType): string;
begin
  case BT of
    btReportTitle:   Result := 'Report Title';
    btPageHeader:    Result := 'Page Header';
    btMasterData:    Result := 'Master Data';
    btPageFooter:    Result := 'Page Footer';
    btReportSummary: Result := 'Summary';
    btGroupHeader:   Result := 'Group Header';
    btGroupFooter:   Result := 'Group Footer';
    btColumnHeader:  Result := 'Column Header';
    btDetail:        Result := 'Detail';
    btOverlay:       Result := 'Overlay';
  else
    Result := 'Band';
  end;
end;

function PageSettingsEqual(A, B: TReportPageSettings): Boolean;
begin
  Result := Assigned(A) and Assigned(B) and
            (A.PaperSize = B.PaperSize) and
            (A.Orientation = B.Orientation) and
            (A.CustomWidth = B.CustomWidth) and
            (A.CustomHeight = B.CustomHeight) and
            (A.Margins.Left = B.Margins.Left) and
            (A.Margins.Top = B.Margins.Top) and
            (A.Margins.Right = B.Margins.Right) and
            (A.Margins.Bottom = B.Margins.Bottom);
end;

end.
