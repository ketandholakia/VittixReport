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
  TOwnerListFunc = function(AObj: TReportObject): TObjectList<TReportObject> of object;
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

procedure DesignerAlignLeft(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);

procedure DesignerAlignRight(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);

procedure DesignerAlignTop(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);

procedure DesignerAlignBottom(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);

procedure DesignerSameWidth(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);

procedure DesignerSameHeight(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);

procedure DesignerCenterH(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  APageWidth: Integer);

procedure DesignerCenterV(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  ABandOwnerOf: TBandOwnerFunc);

procedure DesignerDistributeH(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);

procedure DesignerDistributeV(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);

procedure DesignerBringToFront(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  AOwnerListOf: TOwnerListFunc);

procedure DesignerSendToBack(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  AOwnerListOf: TOwnerListFunc);

implementation

uses
  System.Math,
  System.SysUtils,
  System.Generics.Defaults,
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
  ChangedCount: Integer;
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
    if Obj.Locked then Continue;
    
    Objects[ChangedCount] := Obj;
    OldBounds[ChangedCount] := Obj.Bounds;
    R := Obj.Bounds;
    NewBounds[ChangedCount] := Bounds(R.Left + DX, R.Top + DY, R.Width, R.Height);
    Obj.Bounds := NewBounds[ChangedCount];
    Inc(ChangedCount);
  end;
  
  if ChangedCount = 0 then Exit;
  
  SetLength(Objects, ChangedCount);
  SetLength(OldBounds, ChangedCount);
  SetLength(NewBounds, ChangedCount);

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
    if (Obj is TReportBand) or Obj.Locked then
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




procedure DesignerAlignLeft(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);
var
  I, MinL: Integer;
  R: TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if ASelected.Count < 2 then Exit;
  MinL := MaxInt;
  for I := 0 to ASelected.Count - 1 do
    if ASelected[I].Bounds.Left < MinL then MinL := ASelected[I].Bounds.Left;
  SetLength(Objects,   ASelected.Count);
  SetLength(OldBounds, ASelected.Count);
  SetLength(NewBounds, ASelected.Count);
  for I := 0 to ASelected.Count - 1 do
  begin
    Objects[I]   := ASelected[I];
    OldBounds[I] := ASelected[I].Bounds;
    R := ASelected[I].Bounds;
    NewBounds[I] := Bounds(MinL, R.Top, R.Width, R.Height);
    ASelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  Cmd.ActionName := 'Align Left';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerAlignRight(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);
var
  I, MaxR: Integer;
  R: TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if ASelected.Count < 2 then Exit;
  MaxR := -MaxInt;
  for I := 0 to ASelected.Count - 1 do
    if ASelected[I].Bounds.Right > MaxR then MaxR := ASelected[I].Bounds.Right;
  SetLength(Objects,   ASelected.Count);
  SetLength(OldBounds, ASelected.Count);
  SetLength(NewBounds, ASelected.Count);
  for I := 0 to ASelected.Count - 1 do
  begin
    Objects[I]   := ASelected[I];
    OldBounds[I] := ASelected[I].Bounds;
    R := ASelected[I].Bounds;
    NewBounds[I] := Bounds(MaxR - R.Width, R.Top, R.Width, R.Height);
    ASelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  Cmd.ActionName := 'Align Right';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerAlignTop(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);
var
  I, MinT: Integer;
  R: TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if ASelected.Count < 2 then Exit;
  MinT := MaxInt;
  for I := 0 to ASelected.Count - 1 do
    if ASelected[I].Bounds.Top < MinT then MinT := ASelected[I].Bounds.Top;
  SetLength(Objects,   ASelected.Count);
  SetLength(OldBounds, ASelected.Count);
  SetLength(NewBounds, ASelected.Count);
  for I := 0 to ASelected.Count - 1 do
  begin
    Objects[I]   := ASelected[I];
    OldBounds[I] := ASelected[I].Bounds;
    R := ASelected[I].Bounds;
    NewBounds[I] := Bounds(R.Left, MinT, R.Width, R.Height);
    ASelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  Cmd.ActionName := 'Align Top';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerAlignBottom(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);
var
  I, MaxB: Integer;
  R: TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if ASelected.Count < 2 then Exit;
  MaxB := -MaxInt;
  for I := 0 to ASelected.Count - 1 do
    if ASelected[I].Bounds.Bottom > MaxB then MaxB := ASelected[I].Bounds.Bottom;
  SetLength(Objects,   ASelected.Count);
  SetLength(OldBounds, ASelected.Count);
  SetLength(NewBounds, ASelected.Count);
  for I := 0 to ASelected.Count - 1 do
  begin
    Objects[I]   := ASelected[I];
    OldBounds[I] := ASelected[I].Bounds;
    R := ASelected[I].Bounds;
    NewBounds[I] := Bounds(R.Left, MaxB - R.Height, R.Width, R.Height);
    ASelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  Cmd.ActionName := 'Align Bottom';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerSameWidth(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);
var
  I, W: Integer;
  R   : TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if ASelected.Count < 2 then Exit;
  W := ASelected[ASelected.Count - 1].Bounds.Width;
  SetLength(Objects,   ASelected.Count - 1);
  SetLength(OldBounds, ASelected.Count - 1);
  SetLength(NewBounds, ASelected.Count - 1);
  for I := 0 to ASelected.Count - 2 do
  begin
    Objects[I]   := ASelected[I];
    OldBounds[I] := ASelected[I].Bounds;
    R := ASelected[I].Bounds;
    NewBounds[I] := Bounds(R.Left, R.Top, W, R.Height);
    ASelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  Cmd.ActionName := 'Same Width';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerSameHeight(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);
var
  I, H: Integer;
  R   : TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if ASelected.Count < 2 then Exit;
  H := ASelected[ASelected.Count - 1].Bounds.Height;
  SetLength(Objects,   ASelected.Count - 1);
  SetLength(OldBounds, ASelected.Count - 1);
  SetLength(NewBounds, ASelected.Count - 1);
  for I := 0 to ASelected.Count - 2 do
  begin
    Objects[I]   := ASelected[I];
    OldBounds[I] := ASelected[I].Bounds;
    R := ASelected[I].Bounds;
    NewBounds[I] := Bounds(R.Left, R.Top, R.Width, H);
    ASelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  Cmd.ActionName := 'Same Height';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerCenterH(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  APageWidth: Integer);
var
  I, Mid: Integer;
  R : TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if ASelected.Count = 0 then Exit;
  Mid := APageWidth div 2;
  SetLength(Objects,   ASelected.Count);
  SetLength(OldBounds, ASelected.Count);
  SetLength(NewBounds, ASelected.Count);
  for I := 0 to ASelected.Count - 1 do
  begin
    Objects[I]   := ASelected[I];
    OldBounds[I] := ASelected[I].Bounds;
    R := ASelected[I].Bounds;
    NewBounds[I] := Bounds(Mid - R.Width div 2, R.Top, R.Width, R.Height);
    ASelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  Cmd.ActionName := 'Center Horizontally';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerCenterV(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  ABandOwnerOf: TBandOwnerFunc);
var
  I   : Integer;
  Band: TReportBand;
  R   : TRect;
  Mid : Integer;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if ASelected.Count = 0 then Exit;
  SetLength(Objects,   ASelected.Count);
  SetLength(OldBounds, ASelected.Count);
  SetLength(NewBounds, ASelected.Count);
  for I := 0 to ASelected.Count - 1 do
  begin
    Objects[I]   := ASelected[I];
    OldBounds[I] := ASelected[I].Bounds;
    Band := ABandOwnerOf(ASelected[I]);
    R    := ASelected[I].Bounds;
    if Assigned(Band) then
    begin
      Mid := Band.Height div 2;
      NewBounds[I] := Bounds(R.Left, Mid - R.Height div 2, R.Width, R.Height);
    end
    else
      NewBounds[I] := R;  // no band owner — leave unchanged
    ASelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  Cmd.ActionName := 'Center Vertically';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerDistributeH(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);
var
  I, TotalW, Gap, CurX, MinL, MaxR: Integer;
  R: TRect;
  Sorted   : TArray<TReportObject>;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if ASelected.Count < 3 then Exit;

  { Sort a copy of the selection by Left position so spacing is meaningful
    regardless of the order the user clicked objects }
  SetLength(Sorted, ASelected.Count);
  for I := 0 to ASelected.Count - 1 do
    Sorted[I] := ASelected[I];
  TArray.Sort<TReportObject>(Sorted,
    TComparer<TReportObject>.Construct(
      function(const L, R2: TReportObject): Integer
      begin
        Result := L.Bounds.Left - R2.Bounds.Left;
      end));

  MinL := MaxInt; MaxR := -MaxInt; TotalW := 0;
  for I := 0 to High(Sorted) do
  begin
    R := Sorted[I].Bounds;
    if R.Left < MinL then MinL := R.Left;
    if R.Right > MaxR then MaxR := R.Right;
    Inc(TotalW, R.Width);
  end;
  Gap  := (MaxR - MinL - TotalW) div (Length(Sorted) - 1);
  CurX := MinL;

  SetLength(Objects,   Length(Sorted));
  SetLength(OldBounds, Length(Sorted));
  SetLength(NewBounds, Length(Sorted));
  for I := 0 to High(Sorted) do
  begin
    Objects[I]   := Sorted[I];
    OldBounds[I] := Sorted[I].Bounds;
    R := Sorted[I].Bounds;
    NewBounds[I] := Bounds(CurX, R.Top, R.Width, R.Height);
    Sorted[I].Bounds := NewBounds[I];
    Inc(CurX, R.Width + Gap);
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  Cmd.ActionName := 'Distribute Horizontally';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerDistributeV(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc);
var
  I, TotalH, Gap, CurY, MinT, MaxB: Integer;
  R: TRect;
  Sorted   : TArray<TReportObject>;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if ASelected.Count < 3 then Exit;

  { Sort a copy of the selection by Top position so spacing is meaningful
    regardless of the order the user clicked objects }
  SetLength(Sorted, ASelected.Count);
  for I := 0 to ASelected.Count - 1 do
    Sorted[I] := ASelected[I];
  TArray.Sort<TReportObject>(Sorted,
    TComparer<TReportObject>.Construct(
      function(const L, R2: TReportObject): Integer
      begin
        Result := L.Bounds.Top - R2.Bounds.Top;
      end));

  MinT := MaxInt; MaxB := -MaxInt; TotalH := 0;
  for I := 0 to High(Sorted) do
  begin
    R := Sorted[I].Bounds;
    if R.Top < MinT then MinT := R.Top;
    if R.Bottom > MaxB then MaxB := R.Bottom;
    Inc(TotalH, R.Height);
  end;
  Gap  := (MaxB - MinT - TotalH) div (Length(Sorted) - 1);
  CurY := MinT;

  SetLength(Objects,   Length(Sorted));
  SetLength(OldBounds, Length(Sorted));
  SetLength(NewBounds, Length(Sorted));
  for I := 0 to High(Sorted) do
  begin
    Objects[I]   := Sorted[I];
    OldBounds[I] := Sorted[I].Bounds;
    R := Sorted[I].Bounds;
    NewBounds[I] := Bounds(R.Left, CurY, R.Width, R.Height);
    Sorted[I].Bounds := NewBounds[I];
    Inc(CurY, R.Height + Gap);
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  Cmd.ActionName := 'Distribute Vertically';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerBringToFront(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  AOwnerListOf: TOwnerListFunc);
var
  Obj : TReportObject;
  List: TObjectList<TReportObject>;
  From: Integer;
  Cmd : TZOrderCommand;
begin
  if ASelected.Count = 0 then Exit;
  Obj  := ASelected[ASelected.Count - 1];
  List := AOwnerListOf(Obj);
  if List = nil then Exit;
  From := List.IndexOf(Obj);
  if From < 0 then Exit;
  Cmd := TZOrderCommand.Create(List, Obj, From, List.Count - 1);
  Cmd.ActionName := 'Bring To Front';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

procedure DesignerSendToBack(
  ASelected: TList<TReportObject>;
  ACommands: TCommandDispatcher;
  AOnModified: TSimpleNotifyProc;
  AOwnerListOf: TOwnerListFunc);
var
  Obj : TReportObject;
  List: TObjectList<TReportObject>;
  From: Integer;
  Cmd : TZOrderCommand;
begin
  if ASelected.Count = 0 then Exit;
  Obj  := ASelected[ASelected.Count - 1];
  List := AOwnerListOf(Obj);
  if List = nil then Exit;
  From := List.IndexOf(Obj);
  if From < 0 then Exit;
  Cmd := TZOrderCommand.Create(List, Obj, From, 0);
  Cmd.ActionName := 'Send To Back';
  ACommands.DoCommand(Cmd);
  if Assigned(AOnModified) then AOnModified;
end;

end.
