unit Vittix.Report.SelectionHelpers;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Types,
  Vcl.Controls,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.DesignerInteraction,
  Vittix.Report.CommandDispatcher;

type
  TSelectedChangedEvent = TNotifyEvent;
  TSimpleNotifyProc = procedure of object;
  TBandOwnerFunc = function(AObj: TReportObject): TReportBand of object;
  TObjectScreenRectFunc = function(AObj: TReportObject): TRect of object;

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

procedure DesignerNudgeSelected(
  ASelected: TList<TReportObject>;
  DX, DY: Integer;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  ASender: TObject);

procedure DesignerResizeSelected(
  ASelected: TList<TReportObject>;
  DW, DH, AMinSize: Integer;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  ASender: TObject);

function DesignerApplyRubberBandSelection(
  ASelected: TList<TReportObject>;
  ABandLayouts: array of TDesignerBandLayout;
  const ARubberRect: TRect;
  AObjScreenRect: TObjectScreenRectFunc;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject): Boolean;

function DesignerBeginRubberBandSelection(
  ASelected: TList<TReportObject>;
  var AActiveBand: TReportBand;
  Shift: TShiftState;
  const APoint: TPoint;
  const APageRect: TRect;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject): Boolean;

implementation

uses
  System.Math,
  System.SysUtils,
  Vittix.Report.Undo;

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

procedure DesignerNudgeSelected(
  ASelected: TList<TReportObject>;
  DX, DY: Integer;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  ASender: TObject);
var
  I: Integer;
  Obj: TReportObject;
  R: TRect;
  Objects: TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if not Assigned(ASelected) or (ASelected.Count = 0) or not Assigned(ACommands) then
    Exit;

  SetLength(Objects, ASelected.Count);
  SetLength(OldBounds, ASelected.Count);
  SetLength(NewBounds, ASelected.Count);
  for I := 0 to ASelected.Count - 1 do
  begin
    Obj := ASelected[I];
    Objects[I] := Obj;
    OldBounds[I] := Obj.Bounds;
    R := Obj.Bounds;
    NewBounds[I] := Bounds(R.Left + DX, R.Top + DY, R.Width, R.Height);
    Obj.Bounds := NewBounds[I];
  end;

  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  if Length(Objects) <= 1 then
    Cmd.ActionName := 'Move Object'
  else
    Cmd.ActionName := 'Move Objects';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then
    AOnModified;
end;

procedure DesignerResizeSelected(
  ASelected: TList<TReportObject>;
  DW, DH, AMinSize: Integer;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  ASender: TObject);
var
  I: Integer;
  Obj: TReportObject;
  R: TRect;
  NewW, NewH: Integer;
  ChangedCount: Integer;
  Objects: TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if not Assigned(ASelected) or (ASelected.Count = 0) or not Assigned(ACommands) then
    Exit;

  SetLength(Objects, ASelected.Count);
  SetLength(OldBounds, ASelected.Count);
  SetLength(NewBounds, ASelected.Count);
  ChangedCount := 0;

  for I := 0 to ASelected.Count - 1 do
  begin
    Obj := ASelected[I];
    if Obj is TReportBand then
      Continue;

    R := Obj.Bounds;
    NewW := Max(AMinSize, R.Width + DW);
    NewH := Max(AMinSize, R.Height + DH);
    if (NewW = R.Width) and (NewH = R.Height) then
      Continue;

    Objects[ChangedCount] := Obj;
    OldBounds[ChangedCount] := R;
    NewBounds[ChangedCount] := Bounds(R.Left, R.Top, NewW, NewH);
    Obj.Bounds := NewBounds[ChangedCount];
    Inc(ChangedCount);
  end;

  if ChangedCount = 0 then
    Exit;

  SetLength(Objects, ChangedCount);
  SetLength(OldBounds, ChangedCount);
  SetLength(NewBounds, ChangedCount);
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  if Length(Objects) <= 1 then
    Cmd.ActionName := 'Resize Object'
  else
    Cmd.ActionName := 'Resize Objects';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then
    AOnModified;
end;

function DesignerApplyRubberBandSelection(
  ASelected: TList<TReportObject>;
  ABandLayouts: array of TDesignerBandLayout;
  const ARubberRect: TRect;
  AObjScreenRect: TObjectScreenRectFunc;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject): Boolean;
var
  I: Integer;
  Obj: TReportObject;
  BL: TDesignerBandLayout;
  NormRect: TRect;
  ObjRect: TRect;
  TmpRect: TRect;
  TmpValue: Integer;
  Changed: Boolean;
begin
  Result := False;
  if not Assigned(ASelected) or not Assigned(AObjScreenRect) then
    Exit;

  NormRect := ARubberRect;
  if NormRect.Right < NormRect.Left then
  begin
    TmpValue := NormRect.Left;
    NormRect.Left := NormRect.Right;
    NormRect.Right := TmpValue;
  end;
  if NormRect.Bottom < NormRect.Top then
  begin
    TmpValue := NormRect.Top;
    NormRect.Top := NormRect.Bottom;
    NormRect.Bottom := TmpValue;
  end;

  Changed := False;
  for I := 0 to High(ABandLayouts) do
  begin
    BL := ABandLayouts[I];
    for Obj in BL.Band.Children do
    begin
      ObjRect := AObjScreenRect(Obj);
      if IntersectRect(TmpRect, NormRect, ObjRect) and not ASelected.Contains(Obj) then
      begin
        ASelected.Add(Obj);
        Changed := True;
      end;
    end;
  end;

  Result := Changed;
end;

function DesignerBeginRubberBandSelection(
  ASelected: TList<TReportObject>;
  var AActiveBand: TReportBand;
  Shift: TShiftState;
  const APoint: TPoint;
  const APageRect: TRect;
  AOnSelectionChanged: TSelectedChangedEvent;
  ASender: TObject): Boolean;
begin
  Result := False;
  if not (ssCtrl in Shift) then
  begin
    if (Assigned(ASelected) and (ASelected.Count > 0)) or Assigned(AActiveBand) then
    begin
      if Assigned(ASelected) then
        ASelected.Clear;
      AActiveBand := nil;
      if Assigned(AOnSelectionChanged) then
        AOnSelectionChanged(ASender);
    end;
  end;

  Result :=
    (APoint.X >= APageRect.Left) and
    (APoint.Y >= APageRect.Top) and
    (APoint.X < APageRect.Right) and
    (APoint.Y < APageRect.Bottom);
end;

end.
