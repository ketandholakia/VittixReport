unit Vittix.Report.LayoutCache;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects;

procedure CacheReportBands(
  AReport: TReportModel;
  out ATitleBand: TReportBand;
  out AHeaderBand: TReportBand;
  out AColumnHeaderBand: TReportBand;
  out AMasterBand: TReportBand;
  out AFooterBand: TReportBand;
  out ASummaryBand: TReportBand;
  out AOverlayBand: TReportBand;
  AGroupHeaders: TObjectList<TReportBand>;
  AGroupFooters: TObjectList<TReportBand>;
  ADetailBands: TObjectList<TReportBand>);

implementation

procedure CacheReportBands(
  AReport: TReportModel;
  out ATitleBand: TReportBand;
  out AHeaderBand: TReportBand;
  out AColumnHeaderBand: TReportBand;
  out AMasterBand: TReportBand;
  out AFooterBand: TReportBand;
  out ASummaryBand: TReportBand;
  out AOverlayBand: TReportBand;
  AGroupHeaders: TObjectList<TReportBand>;
  AGroupFooters: TObjectList<TReportBand>;
  ADetailBands: TObjectList<TReportBand>);
var
  Obj: TReportObject;
  I: Integer;
begin
  ATitleBand        := nil;
  AHeaderBand       := nil;
  AColumnHeaderBand := nil;
  AMasterBand       := nil;
  AFooterBand       := nil;
  ASummaryBand      := nil;
  AOverlayBand      := nil;

  AGroupHeaders.Clear;
  AGroupFooters.Clear;
  ADetailBands.Clear;

  for I := 0 to AReport.Objects.Count - 1 do
  begin
    Obj := AReport.Objects[I];
    if Obj is TReportBand then
      case TReportBand(Obj).BandType of
        btReportTitle:   ATitleBand        := TReportBand(Obj);
        btPageHeader:    AHeaderBand       := TReportBand(Obj);
        btColumnHeader:  AColumnHeaderBand := TReportBand(Obj);
        btMasterData:    if not Assigned(AMasterBand) then
                           AMasterBand := TReportBand(Obj);
        btDetail:        ADetailBands.Add(TReportBand(Obj));
        btPageFooter:    AFooterBand       := TReportBand(Obj);
        btReportSummary: ASummaryBand      := TReportBand(Obj);
        btOverlay:       AOverlayBand      := TReportBand(Obj);
        btGroupHeader:   AGroupHeaders.Add(TReportBand(Obj));
        btGroupFooter:   AGroupFooters.Add(TReportBand(Obj));
      end;
  end;

  if (not Assigned(AMasterBand)) and (ADetailBands.Count > 0) then
  begin
    AMasterBand := ADetailBands[0];
    ADetailBands.Delete(0);
  end;

  AGroupHeaders.Sort(TComparer<TReportBand>.Construct(
    function(const L, R: TReportBand): Integer
    begin
      Result := L.GroupLevel - R.GroupLevel;
    end));

  AGroupFooters.Sort(TComparer<TReportBand>.Construct(
    function(const L, R: TReportBand): Integer
    begin
      Result := R.GroupLevel - L.GroupLevel;
    end));
end;

end.
