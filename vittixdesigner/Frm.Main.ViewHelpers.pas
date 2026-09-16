unit Frm.Main.ViewHelpers;

interface

uses
  System.SysUtils,
  Vcl.ComCtrls,
  Vittix.Report.DesignerControl;

procedure ConfigureViewToggleButtons(
  AGrid, ASnap, ARuler, AMargin: TToolButton);
procedure UpdateStatusBar(AStatusBar: TStatusBar;
  ADesigner: TVittixReportDesigner; AModified: Boolean;
  const ACurrentFile: string);

implementation

uses
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Frm.Main.Helpers;

procedure ConfigureViewToggleButtons(
  AGrid, ASnap, ARuler, AMargin: TToolButton);
begin
  if Assigned(AGrid) then
  begin
    AGrid.Hint := 'Show or hide the designer grid';
    AGrid.ShowHint := True;
  end;

  if Assigned(ASnap) then
  begin
    ASnap.Hint := 'Snap moved and resized objects to the designer grid';
    ASnap.ShowHint := True;
  end;

  if Assigned(ARuler) then
  begin
    ARuler.Hint := 'Show or hide page rulers around the designer surface';
    ARuler.ShowHint := True;
  end;

  if Assigned(AMargin) then
  begin
    AMargin.Hint := 'Show or hide page margin guides';
    AMargin.ShowHint := True;
  end;
end;

procedure UpdateStatusBar(AStatusBar: TStatusBar;
  ADesigner: TVittixReportDesigner; AModified: Boolean;
  const ACurrentFile: string);
var
  SelCount: Integer;
  Obj: TReportObject;
  FileText: string;
begin
  if not Assigned(AStatusBar) or not Assigned(ADesigner) then
    Exit;

  SelCount := ADesigner.SelectedCount;

  if SelCount = 0 then
    AStatusBar.Panels[0].Text := 'No selection'
  else if SelCount = 1 then
  begin
    Obj := ADesigner.PrimarySelected;
    if Assigned(Obj) then
    begin
      if Obj is TReportBand then
        AStatusBar.Panels[0].Text :=
          'Selected band: ' + BandTypeName(TReportBand(Obj).BandType) +
          ' (' + TReportBand(Obj).Name + ')' +
          ' | Y=' + IntToStr(TReportBand(Obj).Bounds.Top) +
          ' | Height=' + IntToStr(TReportBand(Obj).Height) +
          ' | Resize: drag the band edge'
      else
        AStatusBar.Panels[0].Text :=
          'Selected: ' + Obj.ClassName +
          ' | X=' + IntToStr(Obj.Bounds.Left) +
          ' Y=' + IntToStr(Obj.Bounds.Top) +
          ' W=' + IntToStr(Obj.Bounds.Width) +
          ' H=' + IntToStr(Obj.Bounds.Height) +
          ' | Resize: drag handles (Shift = constrain)';
    end
    else
      AStatusBar.Panels[0].Text := '1 object selected';
  end
  else
    AStatusBar.Panels[0].Text :=
      IntToStr(SelCount) + ' objects selected | Resize: drag the union handles (Shift = constrain)';

  // File panel (index 2). Panel 1 is reserved for the property hint written by
  // UpdatePropertyPanelHintForRow, so the two must not share a panel.
  if AStatusBar.Panels.Count > 2 then
  begin
    if ACurrentFile = '' then
      FileText := 'New report (not saved)'
    else
      FileText := ExtractFileName(ACurrentFile);

    if AModified then
      FileText := FileText + ' *';

    AStatusBar.Panels[2].Text := FileText;
  end;

  // Full path is available on hover (the file panel itself is too narrow).
  AStatusBar.Hint := ACurrentFile;
  AStatusBar.ShowHint := ACurrentFile <> '';

  if AStatusBar.Panels.Count > 3 then
    AStatusBar.Panels[3].Text := 'Zoom: ' + IntToStr(ADesigner.Zoom) + '%';
end;

end.
