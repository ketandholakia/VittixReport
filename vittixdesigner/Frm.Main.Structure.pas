unit Frm.Main.Structure;

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table;

function ShortNodePreview(const S: string; AMaxLen: Integer): string;
function StructureBandCaption(ABand: TReportBand): string;
function StructureObjectCaption(AObj: TReportObject): string;
function StructureObjectIconIndex(AObj: TReportObject): Integer;
function FindStructureNodeByData(ATree: TTreeView; AData: Pointer): TTreeNode;

implementation

const
  TREE_ICON_REPORT    = 21;
  TREE_ICON_BAND      = 22;
  TREE_ICON_TEXT      = 23;
  TREE_ICON_FIELD     = 24;
  TREE_ICON_MEMO      = 25;
  TREE_ICON_IMAGE     = 26;
  TREE_ICON_BARCODE   = 27;
  TREE_ICON_SHAPE     = 28;
  TREE_ICON_LINE      = 29;
  TREE_ICON_SUBREPORT = 30;
  TREE_ICON_TABLE     = 31;

function ShortNodePreview(const S: string; AMaxLen: Integer): string;
var
  Text: string;
begin
  Text := Trim(StringReplace(StringReplace(S, sLineBreak, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]));
  if Length(Text) > AMaxLen then
    Result := Copy(Text, 1, AMaxLen - 3) + '...'
  else
    Result := Text;
end;

function StructureBandCaption(ABand: TReportBand): string;
var
  BaseCaption: string;
begin
  if not Assigned(ABand) then
    Exit('Band');

  case ABand.BandType of
    btReportTitle:   BaseCaption := 'Report Title Band';
    btPageHeader:    BaseCaption := 'Page Header Band';
    btPageFooter:    BaseCaption := 'Page Footer Band';
    btMasterData:    BaseCaption := 'Master Data Band';
    btGroupHeader:   BaseCaption := 'Group Header Band';
    btGroupFooter:   BaseCaption := 'Group Footer Band';
    btColumnHeader:  BaseCaption := 'Column Header Band';
    btDetail:        BaseCaption := 'Detail Band';
    btReportSummary: BaseCaption := 'Report Summary Band';
    btOverlay:       BaseCaption := 'Overlay Band';
  else
    BaseCaption := 'Band';
  end;

  if Trim(ABand.Name) <> '' then
    Result := BaseCaption + ': ' + ABand.Name
  else
    Result := BaseCaption;
end;

function StructureObjectCaption(AObj: TReportObject): string;
begin
  if not Assigned(AObj) then
    Exit('Object');
  if Trim(AObj.Name) <> '' then
    Result := AObj.ClassName + ': ' + AObj.Name
  else
    Result := AObj.ClassName;
end;

function StructureObjectIconIndex(AObj: TReportObject): Integer;
begin
  if not Assigned(AObj) then Exit(TREE_ICON_REPORT);
  if AObj is TReportBand then Exit(TREE_ICON_BAND);
  if AObj is TReportTextObject then Exit(TREE_ICON_TEXT);
  if AObj is TReportFieldObject then Exit(TREE_ICON_FIELD);
  if AObj is TReportMemoObject then Exit(TREE_ICON_MEMO);
  if AObj is TReportImageObject then Exit(TREE_ICON_IMAGE);
  if AObj is TReportBarcodeObject then Exit(TREE_ICON_BARCODE);
  if AObj is TReportShapeObject then Exit(TREE_ICON_SHAPE);
  if AObj is TReportLineObject then Exit(TREE_ICON_LINE);
  if AObj is TReportSubReportObject then Exit(TREE_ICON_SUBREPORT);
  if AObj is TReportTableObject then Exit(TREE_ICON_TABLE);
  Result := TREE_ICON_REPORT;
end;

function FindStructureNodeByData(ATree: TTreeView; AData: Pointer): TTreeNode;
var
  Node: TTreeNode;
begin
  Result := nil;
  if not Assigned(ATree) then Exit;
  Node := ATree.Items.GetFirstNode;
  while Assigned(Node) do
  begin
    if Node.Data = AData then Exit(Node);
    Node := Node.GetNext;
  end;
end;

end.
