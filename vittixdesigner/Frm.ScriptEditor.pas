unit Frm.ScriptEditor;

interface

uses
  System.Classes, System.SysUtils, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vittix.Report.Objects, Vittix.Report.Bands;

type
  TfrmScriptEditor = class(TForm)
    pnlBottom: TPanel;
    btnOK: TButton;
    btnCancel: TButton;
    lblStats: TLabel;
    pnlHeader: TPanel;
    memInfo: TMemo;
    lblTip: TLabel;
    lblNoValidation: TLabel;
    lblSnippets: TLabel;
    cboSnippets: TComboBox;
    btnInsert: TButton;
    memScript: TMemo;
    procedure memScriptChange(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnInsertClick(Sender: TObject);
  private
    FStorageSubject: string;
    FTarget: TReportObject;
    procedure UpdateStats;
    procedure PopulateSnippets;
    procedure InsertSelectedSnippet;
    function SnippetText(const AName: string): string;
  public
    procedure Initialize(const ATitle, AStorageSubject, AValue: string; ATarget: TReportObject);
    function Execute(var AValue: string): Boolean;
  end;

implementation

{$R *.dfm}

procedure TfrmScriptEditor.Initialize(const ATitle, AStorageSubject, AValue: string; ATarget: TReportObject);
begin
  Caption := ATitle;
  FStorageSubject := AStorageSubject;
  FTarget := ATarget;
  memInfo.Lines.Text :=
    'This text is stored with the ' + FStorageSubject + ' and passed to the host script callback in the final render pass.' + sLineBreak +
    'Runtime Delphi callbacks are separate and are not stored in the report.';
  memScript.Lines.Text := AValue;
  PopulateSnippets;
  UpdateStats;
  ActiveControl := memScript;
end;

function TfrmScriptEditor.Execute(var AValue: string): Boolean;
begin
  Result := ShowModal = mrOk;
  if Result then
    AValue := memScript.Lines.Text;
end;

procedure TfrmScriptEditor.PopulateSnippets;
begin
  cboSnippets.Items.BeginUpdate;
  try
    cboSnippets.Items.Clear;
    cboSnippets.Items.Add('Comment/Header block');
    cboSnippets.Items.Add('If/Then template');
    if Assigned(FTarget) and (FTarget is TReportBand) then
    begin
      cboSnippets.Items.Add('Set visibility');
      cboSnippets.Items.Add('Set variable placeholder');
      cboSnippets.Items.Add('Host callback note');
    end
    else
    begin
      cboSnippets.Items.Add('Set visibility');
      cboSnippets.Items.Add('Cancel printing');
      if Assigned(FTarget) and (FTarget is TReportTextObject) then
      begin
        cboSnippets.Items.Add('Set text (Literal)');
        cboSnippets.Items.Add('Set text (Field)');
        cboSnippets.Items.Add('Set text color');
        cboSnippets.Items.Add('Set background');
      end
      else if Assigned(FTarget) and (FTarget is TReportImageObject) then
      begin
        cboSnippets.Items.Add('Set image data field');
        cboSnippets.Items.Add('Set image layout');
      end;
    end;
  finally
    cboSnippets.Items.EndUpdate;
  end;
  cboSnippets.ItemIndex := 0;
end;

function TfrmScriptEditor.SnippetText(const AName: string): string;
begin
  Result := '';
  if AName = 'Comment/Header block' then
    Result := '// Host callback script example' + sLineBreak + '// Purpose: describe what this hook should do'
  else if AName = 'If/Then template' then
    Result := 'if <condition> then' + sLineBreak + 'begin' + sLineBreak + '  // ...' + sLineBreak + 'end;'
  else if AName = 'Set visibility' then
    Result := 'Visible := False;'
  else if AName = 'Cancel printing' then
    Result := 'CanPrint := False;'
  else if AName = 'Set text (Literal)' then
    Result := 'Text := ''New Value'';'
  else if AName = 'Set text (Field)' then
    Result := 'Text := Field(''FieldName'');'
  else if AName = 'Set text color' then
    Result := 'FontColor := clRed;'
  else if AName = 'Set background' then
    Result := 'Background := clYellow;'
  else if AName = 'Set image data field' then
    Result := 'DataField := ''ImagePath'';'
  else if AName = 'Set image layout' then
    Result := 'Stretch := False; Center := True; Proportional := False;'
  else if AName = 'Set variable placeholder' then
    Result := '// Example: set variable in host callback' + sLineBreak + 'Vars[''MyVar''] := ''value'';'
  else if AName = 'Host callback note' then
    Result := '// This script is passed as text to the host callback implementation.' + sLineBreak +
      '// VittixReport does not execute this text by itself.';
end;

procedure TfrmScriptEditor.InsertSelectedSnippet;
var
  S: string;
begin
  if cboSnippets.ItemIndex < 0 then
    Exit;
  S := SnippetText(cboSnippets.Text);
  if S = '' then
    Exit;

  if (memScript.Text <> '') and (memScript.SelStart > 0) and
     (memScript.Text[memScript.SelStart] <> #10) and (memScript.Text[memScript.SelStart] <> #13) then
    memScript.SelText := sLineBreak + S
  else
    memScript.SelText := S;
  memScript.SetFocus;
end;

procedure TfrmScriptEditor.btnInsertClick(Sender: TObject);
begin
  InsertSelectedSnippet;
end;

procedure TfrmScriptEditor.memScriptChange(Sender: TObject);
begin
  UpdateStats;
end;

procedure TfrmScriptEditor.UpdateStats;
begin
  if memScript.Lines.Text = '' then
    lblStats.Caption := 'Lines: 0 | Chars: 0'
  else
    lblStats.Caption := Format('Lines: %d | Chars: %d', [memScript.Lines.Count, Length(memScript.Text)]);
end;

procedure TfrmScriptEditor.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    Key := 0;
    ModalResult := mrOk;
  end;
end;

end.
