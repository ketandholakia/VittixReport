unit Vittix.Report.Core;

interface

uses
  Vittix.Report.Bands,
  Vittix.Report.Model,
  Vittix.Report.Objects;

type
  TReportBandType = Vittix.Report.Bands.TReportBandType;
  TReportBand = Vittix.Report.Bands.TReportBand;
  
  TReportModel = Vittix.Report.Model.TReportModel;

  TReportObject = Vittix.Report.Objects.TReportObject;
  TReportObjectClass = Vittix.Report.Objects.TReportObjectClass;
  TReportTextObject = Vittix.Report.Objects.TReportTextObject;
  TReportLabelObject = Vittix.Report.Objects.TReportLabelObject;
  TReportFieldObject = Vittix.Report.Objects.TReportFieldObject;
  TReportShapeType = Vittix.Report.Objects.TReportShapeType;
  TReportShapeObject = Vittix.Report.Objects.TReportShapeObject;
  TReportImageObject = Vittix.Report.Objects.TReportImageObject;
  TReportMemoObject = Vittix.Report.Objects.TReportMemoObject;
  TReportSubReportObject = Vittix.Report.Objects.TReportSubReportObject;
  TLineOrientation = Vittix.Report.Objects.TLineOrientation;
  TReportLineObject = Vittix.Report.Objects.TReportLineObject;

const
  btReportTitle   = Vittix.Report.Bands.btReportTitle;
  btPageHeader    = Vittix.Report.Bands.btPageHeader;
  btMasterData    = Vittix.Report.Bands.btMasterData;
  btPageFooter    = Vittix.Report.Bands.btPageFooter;
  btReportSummary = Vittix.Report.Bands.btReportSummary;
  btGroupHeader   = Vittix.Report.Bands.btGroupHeader;
  btGroupFooter   = Vittix.Report.Bands.btGroupFooter;
  btColumnHeader  = Vittix.Report.Bands.btColumnHeader;
  btDetail        = Vittix.Report.Bands.btDetail;
  btOverlay       = Vittix.Report.Bands.btOverlay;

  stRectangle = Vittix.Report.Objects.stRectangle;
  stRoundRect = Vittix.Report.Objects.stRoundRect;
  stEllipse   = Vittix.Report.Objects.stEllipse;
  stLine      = Vittix.Report.Objects.stLine;
  stDiagLine  = Vittix.Report.Objects.stDiagLine;

  loHorizontal = Vittix.Report.Objects.loHorizontal;
  loVertical   = Vittix.Report.Objects.loVertical;

procedure RegisterReportObject(AClass: TReportObjectClass);
function GetRegisteredReportObjects: TArray<TReportObjectClass>;

implementation

procedure RegisterReportObject(AClass: TReportObjectClass);
begin
  Vittix.Report.Objects.RegisterReportObject(Vittix.Report.Objects.TReportObjectClass(AClass));
end;

function GetRegisteredReportObjects: TArray<TReportObjectClass>;
var
  Source: TArray<Vittix.Report.Objects.TReportObjectClass>;
  I: Integer;
begin
  Source := Vittix.Report.Objects.GetRegisteredReportObjects;
  SetLength(Result, Length(Source));
  for I := 0 to High(Source) do
    Result[I] := TReportObjectClass(Source[I]);
end;

end.
