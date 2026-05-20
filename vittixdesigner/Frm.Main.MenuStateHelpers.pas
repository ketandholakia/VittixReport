unit Frm.Main.MenuStateHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.Buttons,
  Vcl.CheckLst,
  Vcl.ComCtrls,
  Vcl.Menus,
  Vittix.Report.DesignerControl;

procedure UpdateMenuState(
  ADesigner: TVittixReportDesigner;
  AMnuUndo, AMnuRedo, AMnuCut, AMnuCopy, AMnuDelete: TMenuItem;
  AMnuAlignLeft, AMnuAlignRight, AMnuAlignTop, AMnuAlignBottom,
  AMnuSameWidth, AMnuSameHeight, AMnuCenterH, AMnuCenterV,
  AMnuDistH, AMnuDistV, AMnuFront, AMnuBack,
  AMnuShowGrid, AMnuSnapGrid, AMnuShowRulers, AMnuShowMargins: TMenuItem;
  ABtnUndo, ABtnRedo, ABtnDelete, ABtnCopy,
  ABtnAlignLeft, ABtnAlignRight, ABtnAlignTop, ABtnAlignBottom,
  ABtnSameW, ABtnSameH, ABtnCenterH, ABtnCenterV,
  ABtnDistH, ABtnDistV, ABtnFront, ABtnBack: TToolButton;
  ACheckListBox: TCheckListBox;
  AUpdateStatusBar: TProc);

implementation

procedure UpdateMenuState(
  ADesigner: TVittixReportDesigner;
  AMnuUndo, AMnuRedo, AMnuCut, AMnuCopy, AMnuDelete: TMenuItem;
  AMnuAlignLeft, AMnuAlignRight, AMnuAlignTop, AMnuAlignBottom,
  AMnuSameWidth, AMnuSameHeight, AMnuCenterH, AMnuCenterV,
  AMnuDistH, AMnuDistV, AMnuFront, AMnuBack,
  AMnuShowGrid, AMnuSnapGrid, AMnuShowRulers, AMnuShowMargins: TMenuItem;
  ABtnUndo, ABtnRedo, ABtnDelete, ABtnCopy,
  ABtnAlignLeft, ABtnAlignRight, ABtnAlignTop, ABtnAlignBottom,
  ABtnSameW, ABtnSameH, ABtnCenterH, ABtnCenterV,
  ABtnDistH, ABtnDistV, ABtnFront, ABtnBack: TToolButton;
  ACheckListBox: TCheckListBox;
  AUpdateStatusBar: TProc);
var
  HasSel: Boolean;
  Multi: Boolean;
  UndoName: string;
  RedoName: string;
begin
  if not Assigned(ADesigner) then
    Exit;

  HasSel := ADesigner.SelectedCount > 0;
  Multi := ADesigner.SelectedCount >= 2;

  AMnuUndo.Enabled := ADesigner.CanUndo;
  AMnuRedo.Enabled := ADesigner.CanRedo;
  ABtnUndo.Enabled := ADesigner.CanUndo;
  ABtnRedo.Enabled := ADesigner.CanRedo;

  UndoName := Trim(ADesigner.NextUndoName);
  RedoName := Trim(ADesigner.NextRedoName);
  if ADesigner.CanUndo and (UndoName <> '') then
  begin
    AMnuUndo.Caption := '&Undo ' + UndoName;
    ABtnUndo.Hint := 'Undo ' + UndoName;
  end
  else
  begin
    AMnuUndo.Caption := '&Undo';
    ABtnUndo.Hint := 'Undo';
  end;
  if ADesigner.CanRedo and (RedoName <> '') then
  begin
    AMnuRedo.Caption := '&Redo ' + RedoName;
    ABtnRedo.Hint := 'Redo ' + RedoName;
  end
  else
  begin
    AMnuRedo.Caption := '&Redo';
    ABtnRedo.Hint := 'Redo';
  end;
  ABtnUndo.ShowHint := True;
  ABtnRedo.ShowHint := True;

  AMnuCut.Enabled := HasSel;
  AMnuCopy.Enabled := HasSel;
  AMnuDelete.Enabled := HasSel;
  ABtnDelete.Enabled := HasSel;
  ABtnCopy.Enabled := HasSel;

  AMnuAlignLeft.Enabled := Multi;
  AMnuAlignRight.Enabled := Multi;
  AMnuAlignTop.Enabled := Multi;
  AMnuAlignBottom.Enabled := Multi;
  AMnuSameWidth.Enabled := Multi;
  AMnuSameHeight.Enabled := Multi;
  ABtnAlignLeft.Enabled := Multi;
  ABtnAlignRight.Enabled := Multi;
  ABtnAlignTop.Enabled := Multi;
  ABtnAlignBottom.Enabled := Multi;
  ABtnSameW.Enabled := Multi;
  ABtnSameH.Enabled := Multi;

  AMnuCenterH.Enabled := HasSel;
  AMnuCenterV.Enabled := HasSel;
  ABtnCenterH.Enabled := HasSel;
  ABtnCenterV.Enabled := HasSel;

  AMnuDistH.Enabled := ADesigner.SelectedCount >= 3;
  AMnuDistV.Enabled := ADesigner.SelectedCount >= 3;
  ABtnDistH.Enabled := ADesigner.SelectedCount >= 3;
  ABtnDistV.Enabled := ADesigner.SelectedCount >= 3;

  AMnuFront.Enabled := HasSel;
  AMnuBack.Enabled := HasSel;
  ABtnFront.Enabled := HasSel;
  ABtnBack.Enabled := HasSel;

  AMnuShowGrid.Checked := ADesigner.ShowGrid;
  AMnuSnapGrid.Checked := ADesigner.SnapToGrid;
  AMnuShowRulers.Checked := ADesigner.ShowRulers;
  AMnuShowMargins.Checked := ADesigner.ShowMargins;
  if Assigned(ACheckListBox) and (ACheckListBox.Items.Count >= 4) then
  begin
    ACheckListBox.Checked[0] := ADesigner.ShowGrid;
    ACheckListBox.Checked[1] := ADesigner.SnapToGrid;
    ACheckListBox.Checked[2] := ADesigner.ShowRulers;
    ACheckListBox.Checked[3] := ADesigner.ShowMargins;
  end;

  if Assigned(AUpdateStatusBar) then
    AUpdateStatusBar();
end;

end.
