unit Vittix.Report.SelectionHelpers;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.DesignerInteraction;

type
  TSelectedChangedEvent = TNotifyEvent;
  TBandOwnerFunc = function(AObj: TReportObject): TReportBand of object;

procedure DesignerClearSelection(
  ASelected: TList<TReportObject>;
  var AActiveBand: TReportBand;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject);

procedure DesignerAddToSelection(
  ASelected: TList<TReportObject>;
  AObj: TReportObject;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject);

procedure DesignerRemoveFromSelection(
  ASelected: TList<TReportObject>;
  AObj: TReportObject;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject);

procedure DesignerSelectObject(
  ASelected: TList<TReportObject>;
  var AActiveBand: TReportBand;
  AObj: TReportObject;
  ABandOwner: TBandOwnerFunc;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject);

procedure DesignerSelectAllObjects(
  ASelected: TList<TReportObject>;
  ABandLayouts: array of TDesignerBandLayout;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject);

implementation

uses
  System.SysUtils;

procedure DesignerClearSelection(
  ASelected: TList<TReportObject>;
  var AActiveBand: TReportBand;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject);
begin
  if not Assigned(ASelected) then
    Exit;
  if (ASelected.Count > 0) or Assigned(AActiveBand) then
  begin
    ASelected.Clear;
    AActiveBand := nil;
    if Assigned(AOnSelectionChanged) then
      AOnSelectionChanged(ASender);
  end;
end;

procedure DesignerAddToSelection(
  ASelected: TList<TReportObject>;
  AObj: TReportObject;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject);
begin
  if not Assigned(ASelected) or not Assigned(AObj) then
    Exit;
  if not ASelected.Contains(AObj) then
  begin
    ASelected.Add(AObj);
    if Assigned(AOnSelectionChanged) then
      AOnSelectionChanged(ASender);
  end;
end;

procedure DesignerRemoveFromSelection(
  ASelected: TList<TReportObject>;
  AObj: TReportObject;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject);
begin
  if not Assigned(ASelected) or not Assigned(AObj) then
    Exit;
  if ASelected.Remove(AObj) >= 0 then
    if Assigned(AOnSelectionChanged) then
      AOnSelectionChanged(ASender);
end;

procedure DesignerSelectObject(
  ASelected: TList<TReportObject>;
  var AActiveBand: TReportBand;
  AObj: TReportObject;
  ABandOwner: TBandOwnerFunc;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject);
var
  OwnerBand: TReportBand;
begin
  if not Assigned(ASelected) then
    Exit;

  if AObj = nil then
  begin
    if (ASelected.Count > 0) or Assigned(AActiveBand) then
    begin
      ASelected.Clear;
      AActiveBand := nil;
      if Assigned(AOnSelectionChanged) then
        AOnSelectionChanged(ASender);
    end;
    Exit;
  end;

  ASelected.Clear;

  if AObj is TReportBand then
  begin
    AActiveBand := TReportBand(AObj);
    if Assigned(AOnSelectionChanged) then
      AOnSelectionChanged(ASender);
    Exit;
  end;

  OwnerBand := nil;
  if Assigned(ABandOwner) then
    OwnerBand := ABandOwner(AObj);
  AActiveBand := OwnerBand;
  ASelected.Add(AObj);
  if Assigned(AOnSelectionChanged) then
    AOnSelectionChanged(ASender);
end;

procedure DesignerSelectAllObjects(
  ASelected: TList<TReportObject>;
  ABandLayouts: array of TDesignerBandLayout;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject);
var
  I: Integer;
  Obj: TReportObject;
  BL: TDesignerBandLayout;
begin
  if not Assigned(ASelected) then
    Exit;

  ASelected.Clear;
  for I := 0 to High(ABandLayouts) do
  begin
    BL := ABandLayouts[I];
    for Obj in BL.Band.Children do
      ASelected.Add(Obj);
  end;
  if Assigned(AOnSelectionChanged) then
    AOnSelectionChanged(ASender);
end;

end.
