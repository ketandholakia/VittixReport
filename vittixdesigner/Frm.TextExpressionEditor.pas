unit Frm.TextExpressionEditor;

interface

uses
  System.Classes,
  System.SysUtils,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  TfrmTextExpressionEditor = class(TForm)
  private
    FMemo: TMemo;
    FBtnOK: TButton;
    FBtnCancel: TButton;
    FDataList: TListBox;
    FVariableList: TListBox;
    FFunctionList: TListBox;
    FGuidanceLabel: TLabel;
    FStatusBar: TStatusBar;
    FPropertyKey: string;
    procedure DataListDblClick(Sender: TObject);
    procedure VariableListDblClick(Sender: TObject);
    procedure FunctionListDblClick(Sender: TObject);
    procedure MemoChange(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure LoadFields(const AFields: TArray<string>);
    procedure LoadVariables;
    procedure LoadFunctions;
    procedure UpdateGuidance;
    procedure UpdateStatus;
  public
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    class function EditValue(const ATitle, APropertyKey: string;
      const AFields: TArray<string>; var AValue: string): Boolean;
  end;

implementation

constructor TfrmTextExpressionEditor.CreateNew(AOwner: TComponent; Dummy: Integer);
var
  BottomPanel: TPanel;
  SidePanel: TPanel;
  Tabs: TPageControl;
  DataTab: TTabSheet;
  VariablesTab: TTabSheet;
  FunctionsTab: TTabSheet;
begin
  inherited CreateNew(AOwner, Dummy);

  Caption := 'Text / Expression Editor';
  Width := 760;
  Height := 460;
  Position := poMainFormCenter;
  BorderStyle := bsSizeable;
  KeyPreview := True;
  OnKeyDown := FormKeyDown;

  SidePanel := TPanel.Create(Self);
  SidePanel.Parent := Self;
  SidePanel.Align := alRight;
  SidePanel.Width := 230;
  SidePanel.BevelOuter := bvNone;

  FGuidanceLabel := TLabel.Create(Self);
  FGuidanceLabel.Parent := SidePanel;
  FGuidanceLabel.Align := alTop;
  FGuidanceLabel.AutoSize := False;
  FGuidanceLabel.Height := 42;
  FGuidanceLabel.WordWrap := True;

  Tabs := TPageControl.Create(Self);
  Tabs.Parent := SidePanel;
  Tabs.Align := alClient;
  Tabs.AlignWithMargins := True;
  Tabs.Margins.SetBounds(0, 8, 8, 8);

  DataTab := TTabSheet.Create(Self);
  DataTab.PageControl := Tabs;
  DataTab.Caption := 'Data';

  FDataList := TListBox.Create(Self);
  FDataList.Parent := DataTab;
  FDataList.Align := alClient;
  FDataList.OnDblClick := DataListDblClick;

  VariablesTab := TTabSheet.Create(Self);
  VariablesTab.PageControl := Tabs;
  VariablesTab.Caption := 'Variables';

  FVariableList := TListBox.Create(Self);
  FVariableList.Parent := VariablesTab;
  FVariableList.Align := alClient;
  FVariableList.OnDblClick := VariableListDblClick;
  LoadVariables;

  FunctionsTab := TTabSheet.Create(Self);
  FunctionsTab.PageControl := Tabs;
  FunctionsTab.Caption := 'Functions';

  FFunctionList := TListBox.Create(Self);
  FFunctionList.Parent := FunctionsTab;
  FFunctionList.Align := alClient;
  FFunctionList.OnDblClick := FunctionListDblClick;
  LoadFunctions;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.AlignWithMargins := True;
  FMemo.Margins.SetBounds(8, 8, 8, 8);
  FMemo.Font.Name := 'Consolas';
  FMemo.Font.Size := 10;
  FMemo.ScrollBars := ssBoth;
  FMemo.WordWrap := False;
  FMemo.OnChange := MemoChange;

  BottomPanel := TPanel.Create(Self);
  BottomPanel.Parent := Self;
  BottomPanel.Align := alBottom;
  BottomPanel.Height := 44;
  BottomPanel.BevelOuter := bvNone;

  FBtnOK := TButton.Create(Self);
  FBtnOK.Parent := BottomPanel;
  FBtnOK.Caption := 'OK';
  FBtnOK.Default := True;
  FBtnOK.ModalResult := mrOk;
  FBtnOK.SetBounds(BottomPanel.Width - 176, 9, 80, 25);
  FBtnOK.Anchors := [akTop, akRight];

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := BottomPanel;
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.Cancel := True;
  FBtnCancel.ModalResult := mrCancel;
  FBtnCancel.SetBounds(BottomPanel.Width - 88, 9, 80, 25);
  FBtnCancel.Anchors := [akTop, akRight];

  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := BottomPanel;
  FStatusBar.Align := alLeft;
  FStatusBar.Width := BottomPanel.Width - 200;
  FStatusBar.SimplePanel := True;
end;

procedure TfrmTextExpressionEditor.DataListDblClick(Sender: TObject);
var
  FieldName: string;
begin
  if FDataList.ItemIndex < 0 then
    Exit;

  FieldName := FDataList.Items[FDataList.ItemIndex];
  if SameText(FPropertyKey, 'Expression') or SameText(FPropertyKey, 'PrintWhen') then
    FMemo.SelText := '[' + FieldName + ']'
  else
    FMemo.SelText := FieldName;
  FMemo.SetFocus;
end;

procedure TfrmTextExpressionEditor.VariableListDblClick(Sender: TObject);
begin
  if FVariableList.ItemIndex < 0 then
    Exit;

  if not (SameText(FPropertyKey, 'Expression') or SameText(FPropertyKey, 'PrintWhen')) then
    Exit;

  FMemo.SelText := '[' + FVariableList.Items[FVariableList.ItemIndex] + ']';
  FMemo.SetFocus;
end;

procedure TfrmTextExpressionEditor.FunctionListDblClick(Sender: TObject);
begin
  if FFunctionList.ItemIndex < 0 then
    Exit;

  if not SameText(FPropertyKey, 'Expression') then
    Exit;

  FMemo.SelText := FFunctionList.Items[FFunctionList.ItemIndex];
  FMemo.SetFocus;
end;

procedure TfrmTextExpressionEditor.MemoChange(Sender: TObject);
begin
  UpdateStatus;
end;

procedure TfrmTextExpressionEditor.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    ModalResult := mrOk;
    Key := 0;
  end;
end;

procedure TfrmTextExpressionEditor.LoadFields(const AFields: TArray<string>);
var
  FieldName: string;
begin
  FDataList.Items.BeginUpdate;
  try
    FDataList.Items.Clear;
    for FieldName in AFields do
      if Trim(FieldName) <> '' then
        FDataList.Items.Add(FieldName);
  finally
    FDataList.Items.EndUpdate;
  end;
end;

procedure TfrmTextExpressionEditor.LoadVariables;
begin
  FVariableList.Items.Add('Date');
  FVariableList.Items.Add('Time');
  FVariableList.Items.Add('Page');
  FVariableList.Items.Add('Page#');
  FVariableList.Items.Add('TotalPages');
  FVariableList.Items.Add('TotalPages#');
  FVariableList.Items.Add('ReportTitle');
  FVariableList.Items.Add('ReportDate');
  FVariableList.Items.Add('DateTime');
  FVariableList.Items.Add('RecNo');
  FVariableList.Items.Add('RowNumber');
end;

procedure TfrmTextExpressionEditor.LoadFunctions;
begin
  FFunctionList.Items.Add('SUM([FieldName])');
  FFunctionList.Items.Add('COUNT([FieldName])');
  FFunctionList.Items.Add('AVG([FieldName])');
  FFunctionList.Items.Add('MIN([FieldName])');
  FFunctionList.Items.Add('MAX([FieldName])');
end;

procedure TfrmTextExpressionEditor.UpdateGuidance;
begin
  if SameText(FPropertyKey, 'Expression') then
    FGuidanceLabel.Caption := 'Double-click fields, variables, or functions to insert.'
  else if SameText(FPropertyKey, 'PrintWhen') then
    FGuidanceLabel.Caption := 'Double-click fields or variables to build a condition.'
  else if SameText(FPropertyKey, 'DataField') then
    FGuidanceLabel.Caption := 'Double-click a field to select its binding name.'
  else
    FGuidanceLabel.Caption := 'Text is literal. Inserted field names are not evaluated.';
end;

procedure TfrmTextExpressionEditor.UpdateStatus;
begin
  FStatusBar.SimpleText := Format('Lines: %d    Characters: %d    Ctrl+Enter: OK',
    [FMemo.Lines.Count, Length(FMemo.Text)]);
end;

class function TfrmTextExpressionEditor.EditValue(const ATitle, APropertyKey: string;
  const AFields: TArray<string>; var AValue: string): Boolean;
var
  Frm: TfrmTextExpressionEditor;
begin
  Frm := TfrmTextExpressionEditor.CreateNew(nil);
  try
    if ATitle <> '' then
      Frm.Caption := ATitle;
    Frm.FPropertyKey := APropertyKey;
    Frm.UpdateGuidance;
    Frm.LoadFields(AFields);
    Frm.FMemo.Lines.Text := AValue;
    Frm.UpdateStatus;
    Result := Frm.ShowModal = mrOk;
    if Result then
      AValue := Frm.FMemo.Lines.Text;
  finally
    Frm.Free;
  end;
end;

end.
