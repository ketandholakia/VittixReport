unit Frm.TextExpressionEditor;

interface

uses
  System.Classes,
  System.SysUtils,
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
    FPropertyKey: string;
    procedure DataListDblClick(Sender: TObject);
    procedure VariableListDblClick(Sender: TObject);
    procedure FunctionListDblClick(Sender: TObject);
    procedure LoadFields(const AFields: TArray<string>);
    procedure LoadVariables;
    procedure LoadFunctions;
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

  SidePanel := TPanel.Create(Self);
  SidePanel.Parent := Self;
  SidePanel.Align := alRight;
  SidePanel.Width := 230;
  SidePanel.BevelOuter := bvNone;

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
    Frm.LoadFields(AFields);
    Frm.FMemo.Lines.Text := AValue;
    Result := Frm.ShowModal = mrOk;
    if Result then
      AValue := Frm.FMemo.Lines.Text;
  finally
    Frm.Free;
  end;
end;

end.
