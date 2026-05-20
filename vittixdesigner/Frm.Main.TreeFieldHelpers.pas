unit Frm.Main.TreeFieldHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ValEdit,
  Vcl.Clipbrd,
  Vcl.Dialogs,
  Vcl.Forms,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.DesignerControl;

procedure RefreshFieldList(ALstFields: TListBox; ALblFields: TLabel; ADesigner: TVittixReportDesigner);
function VariableTokenForNode(ANode: TTreeNode; out AToken: string; out ASupported: Boolean): Boolean;
function CanInsertVariableIntoCurrentProperty(APropEditor: TValueListEditor; out AKey: string): Boolean;
procedure InsertVariableToken(APropEditor: TValueListEditor; APropEditorDirty: TProc<Boolean>; AUpdateHint: TProc<Integer>; const AToken: string);

implementation

procedure RefreshFieldList(ALstFields: TListBox; ALblFields: TLabel; ADesigner: TVittixReportDesigner);
var
  Names: TArray<string>;
  N: string;
begin
  if not Assigned(ALstFields) or not Assigned(ALblFields) then
    Exit;

  ALstFields.Items.BeginUpdate;
  try
    ALstFields.Items.Clear;
    if Assigned(ADesigner) then
    begin
      Names := ADesigner.GetFieldNames;
      for N in Names do
        ALstFields.Items.Add(N);
    end;
  finally
    ALstFields.Items.EndUpdate;
  end;

  if ALstFields.Items.Count = 0 then
    ALblFields.Caption := ' Dataset Fields  (none)'
  else
    ALblFields.Caption := Format(' Dataset Fields  (%d)', [ALstFields.Items.Count]);
end;

function VariableTokenForNode(ANode: TTreeNode; out AToken: string; out ASupported: Boolean): Boolean;
var
  S: string;
begin
  Result := False;
  AToken := '';
  ASupported := False;
  if not Assigned(ANode) then
    Exit;
  S := Trim(ANode.Text);
  if Pos('(', S) > 0 then
    S := Trim(Copy(S, 1, Pos('(', S) - 1));
  if SameText(S, 'Date') then
    AToken := '[Date]'
  else if SameText(S, 'Time') then
    AToken := '[Time]'
  else if SameText(S, 'Page') then
    AToken := '[Page]'
  else if SameText(S, 'Page#') then
    AToken := '[Page#]'
  else if SameText(S, 'TotalPages') then
    AToken := '[TotalPages]'
  else if SameText(S, 'TotalPages#') then
    AToken := '[TotalPages#]'
  else if SameText(S, 'Line') then
    AToken := '[Line]'
  else if SameText(S, 'Line#') then
    AToken := '[Line#]';
  ASupported := AToken <> '';
  Result := ASupported or SameText(S, 'CopyName#') or SameText(S, 'TableRow') or SameText(S, 'TableColumn');
end;

function CanInsertVariableIntoCurrentProperty(APropEditor: TValueListEditor; out AKey: string): Boolean;
begin
  Result := False;
  AKey := '';
  if not Assigned(APropEditor) or (APropEditor.Row <= 0) or (APropEditor.Row >= APropEditor.RowCount) then
    Exit;
  AKey := Trim(APropEditor.Keys[APropEditor.Row]);
  if (Length(AKey) >= 3) and (AKey[1] = '[') and (AKey[Length(AKey)] = ']') then
    Exit;
  Result := SameText(AKey, 'Text') or SameText(AKey, 'Expression') or SameText(AKey, 'PrintWhen') or
    SameText(AKey, 'BackgroundCondition') or SameText(AKey, 'FontColorCondition') or SameText(AKey, 'BorderColorCondition');
end;

procedure InsertVariableToken(APropEditor: TValueListEditor; APropEditorDirty: TProc<Boolean>; AUpdateHint: TProc<Integer>; const AToken: string);
var
  KeyName: string;
  CurV: string;
begin
  if CanInsertVariableIntoCurrentProperty(APropEditor, KeyName) then
  begin
    CurV := Trim(APropEditor.Values[KeyName]);
    if CurV = '' then
      APropEditor.Values[KeyName] := AToken
    else if (Length(CurV) > 0) and (CurV[Length(CurV)] = ' ') then
      APropEditor.Values[KeyName] := CurV + AToken
    else
      APropEditor.Values[KeyName] := CurV + ' ' + AToken;
    if Assigned(APropEditorDirty) then APropEditorDirty(True);
    if Assigned(AUpdateHint) then AUpdateHint(APropEditor.Row);
    Exit;
  end;
  Clipboard.AsText := AToken;
  ShowMessage('No compatible property row is active. Token copied to clipboard: ' + AToken);
end;

end.
