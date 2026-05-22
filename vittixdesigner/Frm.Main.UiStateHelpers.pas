unit Frm.Main.UiStateHelpers;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Menus;

type
  TTitleBarCaptionProc = reference to procedure(const ATitle: string);

procedure UpdateTitleBarText(
  const ACurrentFile: string;
  AModified, AReportMetadataDirty: Boolean;
  ACaption: TTitleBarCaptionProc);
procedure ConfigureLayoutGuidance(
  ABtnAlignLeft, ABtnAlignRight, ABtnAlignTop, ABtnAlignBottom: TControl;
  ABtnSameW, ABtnSameH, ABtnCenterH, ABtnCenterV, ABtnDistH, ABtnDistV: TControl;
  ABtnFront, ABtnBack, ABtnFrontQuick, ABtnBackQuick: TControl;
  AMnuAlignLeft, AMnuAlignRight, AMnuAlignTop, AMnuAlignBottom: TMenuItem;
  AMnuSameWidth, AMnuSameHeight, AMnuCenterH, AMnuCenterV: TMenuItem;
  AMnuDistH, AMnuDistV, AMnuFront, AMnuBack: TMenuItem;
  AMnuShowGrid, AMnuSnapGrid, AMnuShowRulers, AMnuShowMargins: TMenuItem;
  ABtnZoomIn, ABtnZoomOut, ABtnZoomApply: TControl;
  AMnuZoomIn, AMnuZoomOut, AMnuZoomReset: TMenuItem);

implementation

uses
  System.SysUtils;

procedure UpdateTitleBarText(
  const ACurrentFile: string;
  AModified, AReportMetadataDirty: Boolean;
  ACaption: TTitleBarCaptionProc);
var
  Title: string;
begin
  Title := 'Vittix Report Designer';
  if ACurrentFile <> '' then
    Title := Title + '  —  ' + ExtractFileName(ACurrentFile);
  if AModified or AReportMetadataDirty then
    Title := Title + ' *';
  if Assigned(ACaption) then
    ACaption(Title);
end;

procedure ConfigureLayoutGuidance(
  ABtnAlignLeft, ABtnAlignRight, ABtnAlignTop, ABtnAlignBottom: TControl;
  ABtnSameW, ABtnSameH, ABtnCenterH, ABtnCenterV, ABtnDistH, ABtnDistV: TControl;
  ABtnFront, ABtnBack, ABtnFrontQuick, ABtnBackQuick: TControl;
  AMnuAlignLeft, AMnuAlignRight, AMnuAlignTop, AMnuAlignBottom: TMenuItem;
  AMnuSameWidth, AMnuSameHeight, AMnuCenterH, AMnuCenterV: TMenuItem;
  AMnuDistH, AMnuDistV, AMnuFront, AMnuBack: TMenuItem;
  AMnuShowGrid, AMnuSnapGrid, AMnuShowRulers, AMnuShowMargins: TMenuItem;
  ABtnZoomIn, ABtnZoomOut, ABtnZoomApply: TControl;
  AMnuZoomIn, AMnuZoomOut, AMnuZoomReset: TMenuItem);
begin
  ABtnAlignLeft.Hint := 'Align selected objects to the leftmost edge in the selection';
  ABtnAlignRight.Hint := 'Align selected objects to the rightmost edge in the selection';
  ABtnAlignTop.Hint := 'Align selected objects to the topmost edge in the selection';
  ABtnAlignBottom.Hint := 'Align selected objects to the bottommost edge in the selection';
  ABtnSameW.Hint := 'Make same width using last selected object as reference';
  ABtnSameH.Hint := 'Make same height using last selected object as reference';
  ABtnCenterH.Hint := 'Center selected objects horizontally on the page';
  ABtnCenterV.Hint := 'Center vertically within each object''s band';
  ABtnDistH.Hint := 'Distribute horizontally between current left/right bounds; works best within the same band';
  ABtnDistV.Hint := 'Distribute vertically using object local band coordinates';
  ABtnFront.Hint := 'Bring last selected object to front';
  ABtnBack.Hint := 'Send last selected object to back';
  ABtnFrontQuick.Hint := 'Bring last selected object to front';
  ABtnBackQuick.Hint := 'Send last selected object to back';
  ABtnFrontQuick.ShowHint := True;
  ABtnBackQuick.ShowHint := True;

  AMnuAlignLeft.Hint := ABtnAlignLeft.Hint;
  AMnuAlignRight.Hint := ABtnAlignRight.Hint;
  AMnuAlignTop.Hint := ABtnAlignTop.Hint;
  AMnuAlignBottom.Hint := ABtnAlignBottom.Hint;
  AMnuSameWidth.Hint := ABtnSameW.Hint;
  AMnuSameHeight.Hint := ABtnSameH.Hint;
  AMnuCenterH.Hint := ABtnCenterH.Hint;
  AMnuCenterV.Hint := ABtnCenterV.Hint;
  AMnuDistH.Hint := ABtnDistH.Hint;
  AMnuDistV.Hint := ABtnDistV.Hint;
  AMnuFront.Hint := ABtnFront.Hint;
  AMnuBack.Hint := ABtnBack.Hint;

  AMnuShowGrid.Hint := 'Show or hide the designer grid';
  AMnuSnapGrid.Hint := 'Snap moved and resized objects to the designer grid';
  AMnuShowRulers.Hint := 'Show or hide page rulers around the designer surface';
  AMnuShowMargins.Hint := 'Show or hide page margin guides';
  ABtnZoomIn.Hint := 'Zoom in the designer surface';
  ABtnZoomOut.Hint := 'Zoom out the designer surface';
  ABtnZoomApply.Hint := 'Apply zoom percentage';
  AMnuZoomIn.Hint := ABtnZoomIn.Hint;
  AMnuZoomOut.Hint := ABtnZoomOut.Hint;
  AMnuZoomReset.Hint := 'Reset zoom to 100%';
end;

end.
