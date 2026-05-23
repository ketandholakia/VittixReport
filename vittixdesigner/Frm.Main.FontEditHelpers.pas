unit Frm.Main.FontEditHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Variants,
  Vcl.Graphics,
  Vcl.StdCtrls,
  Vcl.Dialogs,
  Vittix.Report.DesignerControl,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vcl.ValEdit,
  Vittix.Designer.Commands;

function EditFontPropertyRow(
  AOwner: TComponent;
  ADesigner: TVittixReportDesigner;
  APropEditor: TValueListEditor;
  ARow: Integer;
  ACurrentPropertyTarget: TFunc<TReportObject>;
  ASetPropertyPanelDirty: TProc<Boolean>;
  AUpdateTitleBar: TProc;
  AUpdatePropertyPanel: TProc;
  AUpdateStatusBar: TProc;
  ARefreshReportStructure: TProc;
  ASyncReportStructureSelection: TProc): Boolean;

implementation

function EditFontPropertyRow(
  AOwner: TComponent;
  ADesigner: TVittixReportDesigner;
  APropEditor: TValueListEditor;
  ARow: Integer;
  ACurrentPropertyTarget: TFunc<TReportObject>;
  ASetPropertyPanelDirty: TProc<Boolean>;
  AUpdateTitleBar: TProc;
  AUpdatePropertyPanel: TProc;
  AUpdateStatusBar: TProc;
  ARefreshReportStructure: TProc;
  ASyncReportStructureSelection: TProc): Boolean;
var
  Obj: TReportObject;
  KeyName: string;
  Dlg: TFontDialog;
  OldFont: TFont;
  NewFont: TFont;
  Cmd: TTextFontChangeCommand;
begin
  Result := False;
  if (ARow <= 0) or (ARow >= APropEditor.RowCount) then
    Exit;

  KeyName := APropEditor.Keys[ARow];
  if KeyName = '' then
    Exit;

  Obj := ACurrentPropertyTarget();
  if not (Obj is TReportTextObject) then
    Exit;

  Dlg := TFontDialog.Create(AOwner);
  OldFont := TFont.Create;
  NewFont := TFont.Create;
  try
    OldFont.Assign(TReportTextObject(Obj).Font);
    Dlg.Font.Assign(TReportTextObject(Obj).Font);
    if not Dlg.Execute then
      Exit;

    NewFont.Assign(Dlg.Font);
    if (OldFont.Name = NewFont.Name) and
       (OldFont.Size = NewFont.Size) and
       (OldFont.Style = NewFont.Style) and
       (OldFont.Color = NewFont.Color) and
       (OldFont.Charset = NewFont.Charset) then
      Exit;

    Cmd := TTextFontChangeCommand.Create(TReportTextObject(Obj), OldFont, NewFont);
    if Assigned(ADesigner) and Assigned(ADesigner.Commands) then
      ADesigner.Commands.DoCommand(Cmd)
    else
      Cmd.Free;

    if Assigned(ADesigner) then
      ADesigner.RebuildLayout;
    if Assigned(ASetPropertyPanelDirty) then
      ASetPropertyPanelDirty(True);
    if Assigned(AUpdateTitleBar) then
      AUpdateTitleBar();
    if Assigned(AUpdatePropertyPanel) then
      AUpdatePropertyPanel();
    if Assigned(AUpdateStatusBar) then
      AUpdateStatusBar();
    if Assigned(ARefreshReportStructure) then
      ARefreshReportStructure();
    if Assigned(ASyncReportStructureSelection) then
      ASyncReportStructureSelection();
    Result := True;
  finally
    NewFont.Free;
    OldFont.Free;
    Dlg.Free;
  end;
end;

end.
