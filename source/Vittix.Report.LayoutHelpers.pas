unit Vittix.Report.LayoutHelpers;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.DesignerInteraction;

function BuildBandLayouts(
  AReport: TReportModel;
  const ALayoutOrder: TArray<Integer>;
  const AOrderComparer: TComparison<TDesignerBandLayout>;
  const AMarginTop: Integer;
  const ABandGap: Integer;
  AObjectBandMap: TDictionary<TReportObject, TReportBand>): TDesignerBandLayouts;

implementation

function BuildBandLayouts(
  AReport: TReportModel;
  const ALayoutOrder: TArray<Integer>;
  const AOrderComparer: TComparison<TDesignerBandLayout>;
  const AMarginTop: Integer;
  const ABandGap: Integer;
  AObjectBandMap: TDictionary<TReportObject, TReportBand>): TDesignerBandLayouts;
var
  I     : Integer;
  BL    : TDesignerBandLayout;
  CurY  : Integer;
  Obj   : TReportObject;
  Layouts: TList<TDesignerBandLayout>;
begin
  Result := nil;
  if not Assigned(AReport) then
    Exit;

  AObjectBandMap.Clear;
  Layouts := TList<TDesignerBandLayout>.Create;
  try
    for I := 0 to AReport.Objects.Count - 1 do
    begin
      if not (AReport.Objects[I] is TReportBand) then
        Continue;
      BL.Band := AReport.Objects[I] as TReportBand;
      BL.Y := 0;
      BL.Height := BL.Band.Height;
      Layouts.Add(BL);
    end;

    Layouts.Sort(TComparer<TDesignerBandLayout>.Construct(AOrderComparer));

    CurY := AMarginTop;
    for I := 0 to Layouts.Count - 1 do
    begin
      BL := Layouts[I];
      BL.Y := CurY;
      Inc(CurY, BL.Height + ABandGap);
      Result := Result + [BL];

      for Obj in BL.Band.Children do
        AObjectBandMap.AddOrSetValue(Obj, BL.Band);
    end;
  finally
    Layouts.Free;
  end;
end;

end.
