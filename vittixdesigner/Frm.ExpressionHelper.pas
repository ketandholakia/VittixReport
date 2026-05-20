unit Frm.ExpressionHelper;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Generics.Collections, System.Variants,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  Vittix.Report.Context, Vittix.Report.Expressions;

type
  TfrmExpressionHelper = class(TForm)
    pnlLeft: TPanel;
    pnlCenter: TPanel;
    pnlRight: TPanel;
    pnlOperators: TPanel;
    pnlTemplates: TPanel;
    pnlBottom: TPanel;
    lblFields: TLabel;
    lblExamples: TLabel;
    lblRecent: TLabel;
    lstFields: TListBox;
    lstExamples: TListBox;
    lstRecent: TListBox;
    memExpression: TMemo;
    btnCheck: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    btnInsertField: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lstFieldsDblClick(Sender: TObject);
    procedure lstExamplesDblClick(Sender: TObject);
    procedure lstRecentDblClick(Sender: TObject);
    procedure btnInsertFieldClick(Sender: TObject);
    procedure btnCheckClick(Sender: TObject);
  private
    FPropertyKey: string;
    FContextBuilder: TFunc<TExpressionContext>;
    function  BucketKey(const APropertyKey: string): string;
    function  GetRecentList: TStringList;
    function  IsRecentHintItem(const AValue: string): Boolean;
    function  TryGetSelectedField(out AFieldName: string): Boolean;
    procedure AddRecent(const AExpr: string);
    procedure InsertText(const AText: string);
    procedure PopulateButtons;
    procedure PopulateTemplates;
  public
    function PromptExpression(const AInitialValue: string;
      const AFields: TArray<string>; const APropertyKey: string;
      const ABuildContext: TFunc<TExpressionContext>;
      out AEditedValue: string): Boolean;
  end;

var
  frmExpressionHelper: TfrmExpressionHelper;

implementation

{$R *.dfm}

uses
  Vcl.Dialogs;

const
  CMaxRecentItems = 20;

var
  GExprRecentsByKey: TObjectDictionary<string, TStringList>;

procedure TfrmExpressionHelper.FormCreate(Sender: TObject);
begin
  PopulateButtons;
  btnCancel.ModalResult := mrCancel;
  btnOK.ModalResult := mrOk;
end;

procedure TfrmExpressionHelper.FormDestroy(Sender: TObject);
begin
end;

procedure TfrmExpressionHelper.PopulateButtons;
  function AddButton(const AParent: TWinControl; const ACaption, AHint: string;
    ALeft, ATop, AWidth, AHeight: Integer; AOnClick: TNotifyEvent; ATag: Integer = 0): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
    Result.Hint := AHint;
    Result.ShowHint := AHint <> '';
    Result.Left := ALeft;
    Result.Top := ATop;
    Result.Width := AWidth;
    Result.Height := AHeight;
    Result.Tag := ATag;
    Result.OnClick := AOnClick;
  end;
begin
  AddButton(pnlOperators, '+', ' + ', 8, 8, 40, 26, btnInsertFieldClick);
  AddButton(pnlOperators, '-', ' - ', 56, 8, 40, 26, btnInsertFieldClick);
  AddButton(pnlOperators, '*', ' * ', 104, 8, 40, 26, btnInsertFieldClick);
  AddButton(pnlOperators, '/', ' / ', 152, 8, 40, 26, btnInsertFieldClick);
  AddButton(pnlOperators, '=', ' = ', 200, 8, 40, 26, btnInsertFieldClick);
  AddButton(pnlOperators, '<>', ' <> ', 248, 8, 52, 26, btnInsertFieldClick);
  AddButton(pnlOperators, '>', ' > ', 306, 8, 40, 26, btnInsertFieldClick);
  AddButton(pnlOperators, '>=', ' >= ', 354, 8, 44, 26, btnInsertFieldClick);
  AddButton(pnlOperators, '<', ' < ', 404, 8, 40, 26, btnInsertFieldClick);
  AddButton(pnlOperators, '<=', ' <= ', 452, 8, 44, 26, btnInsertFieldClick);
  AddButton(pnlOperators, '''''', '''''', 500, 8, 44, 26, btnInsertFieldClick);

  PopulateTemplates;
end;

procedure TfrmExpressionHelper.PopulateTemplates;
  function AddTemplateButton(const ACaption: string; const AText: string; ALeft, ATop, AWidth, AHeight, ATag: Integer): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := pnlTemplates;
    Result.Caption := ACaption;
    Result.Tag := ATag;
    Result.Left := ALeft;
    Result.Top := ATop;
    Result.Width := AWidth;
    Result.Height := AHeight;
    Result.OnClick := btnInsertFieldClick;
  end;
begin
  AddTemplateButton('[Field] > 0', '', 8, 8, 92, 26, 1);
  AddTemplateButton('[Field] = ''Text''', '', 108, 8, 108, 26, 2);
  AddTemplateButton('[Field] <> ''''', '', 224, 8, 94, 26, 3);
  AddTemplateButton('[Amount] > 1000', '', 328, 8, 116, 26, 4);
  AddTemplateButton('[Qty] > 5', '', 450, 8, 92, 26, 5);
end;

function TfrmExpressionHelper.PromptExpression(const AInitialValue: string;
  const AFields: TArray<string>; const APropertyKey: string;
  const ABuildContext: TFunc<TExpressionContext>;
  out AEditedValue: string): Boolean;
var
  I: Integer;
begin
  FPropertyKey := APropertyKey;
  FContextBuilder := ABuildContext;
  lstFields.Items.Clear;
  for I := Low(AFields) to High(AFields) do
    lstFields.Items.Add(AFields[I]);

  lstExamples.Items.Clear;
  lstExamples.Items.Add('[Field] > 0');
  lstExamples.Items.Add('[Field] = ''Text''');
  lstExamples.Items.Add('[Field] <> ''''');
  lstExamples.Items.Add('[Amount] > 1000');
  lstExamples.Items.Add('[Qty] > 5');

  lstRecent.Items.Clear;
  if GetRecentList <> nil then
  begin
    if GetRecentList.Count > 0 then
      lstRecent.Items.AddStrings(GetRecentList)
    else
      lstRecent.Items.Add('No recent expressions (session only)');
  end
  else
    lstRecent.Items.Add('No recent expressions (session only)');

  memExpression.Lines.Text := AInitialValue;
  Result := ShowModal = mrOk;
  if Result then
  begin
    AEditedValue := memExpression.Lines.Text;
    AddRecent(AEditedValue);
  end;
end;

function TfrmExpressionHelper.BucketKey(const APropertyKey: string): string;
begin
  if SameText(APropertyKey, 'Expression') then
    Exit('expression');
  if SameText(APropertyKey, 'PrintWhen') then
    Exit('printwhen');
  if SameText(APropertyKey, 'BackgroundCondition') then
    Exit('backgroundcondition');
  if SameText(APropertyKey, 'FontColorCondition') then
    Exit('fontcolorcondition');
  if SameText(APropertyKey, 'BorderColorCondition') then
    Exit('bordercolorcondition');
  Result := '';
end;

function TfrmExpressionHelper.GetRecentList: TStringList;
var
  Key: string;
begin
  Result := nil;
  Key := BucketKey(FPropertyKey);
  if Key = '' then
    Exit;
  if not Assigned(GExprRecentsByKey) then
    GExprRecentsByKey := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  if not GExprRecentsByKey.TryGetValue(Key, Result) then
  begin
    Result := TStringList.Create;
    GExprRecentsByKey.Add(Key, Result);
  end;
end;

function TfrmExpressionHelper.TryGetSelectedField(out AFieldName: string): Boolean;
begin
  Result := Assigned(lstFields) and (lstFields.ItemIndex >= 0);
  if not Result then
    Exit(False);
  AFieldName := Trim(lstFields.Items[lstFields.ItemIndex]);
  Result := AFieldName <> '';
end;

procedure TfrmExpressionHelper.AddRecent(const AExpr: string);
var
  ExprText: string;
  Recent: TStringList;
  I: Integer;
begin
  ExprText := Trim(AExpr);
  if ExprText = '' then
    Exit;
  if IsRecentHintItem(ExprText) then
    Exit;

  Recent := GetRecentList;
  if not Assigned(Recent) then
    Exit;

  for I := Recent.Count - 1 downto 0 do
    if SameText(Trim(Recent[I]), ExprText) then
      Recent.Delete(I);

  Recent.Insert(0, ExprText);
  while Recent.Count > CMaxRecentItems do
    Recent.Delete(Recent.Count - 1);
end;

function TfrmExpressionHelper.IsRecentHintItem(const AValue: string): Boolean;
begin
  Result := SameText(Trim(AValue), 'No recent expressions (session only)');
end;

procedure TfrmExpressionHelper.InsertText(const AText: string);
begin
  if Assigned(memExpression) then
  begin
    memExpression.SelText := AText;
    memExpression.SetFocus;
  end;
end;

procedure TfrmExpressionHelper.lstFieldsDblClick(Sender: TObject);
var
  FieldName: string;
begin
  if TryGetSelectedField(FieldName) then
    InsertText('[' + FieldName + ']');
end;

procedure TfrmExpressionHelper.lstExamplesDblClick(Sender: TObject);
begin
  if Assigned(lstExamples) and Assigned(memExpression) and (lstExamples.ItemIndex >= 0) then
  begin
    memExpression.Lines.Text := lstExamples.Items[lstExamples.ItemIndex];
    memExpression.SetFocus;
  end;
end;

procedure TfrmExpressionHelper.lstRecentDblClick(Sender: TObject);
var
  SelectedText: string;
begin
  if Assigned(lstRecent) and Assigned(memExpression) and (lstRecent.ItemIndex >= 0) then
  begin
    SelectedText := Trim(lstRecent.Items[lstRecent.ItemIndex]);
    if IsRecentHintItem(SelectedText) then
      Exit;
    memExpression.Lines.Text := SelectedText;
    memExpression.SetFocus;
  end;
end;

procedure TfrmExpressionHelper.btnInsertFieldClick(Sender: TObject);
var
  InsertTextValue: string;
  FieldName: string;
begin
  if Sender is TButton then
  begin
    if TButton(Sender).Tag in [1..5] then
    begin
      if not TryGetSelectedField(FieldName) then
      begin
        ShowMessage('Select a field first.');
        Exit;
      end;
      case TButton(Sender).Tag of
        1: InsertTextValue := '[' + FieldName + '] > 0';
        2: InsertTextValue := '[' + FieldName + '] = ''Text''';
        3: InsertTextValue := '[' + FieldName + '] <> ' + QuotedStr('');
        4: InsertTextValue := '[Amount] > 1000';
        5: InsertTextValue := '[Qty] > 5';
      else
        InsertTextValue := TButton(Sender).Hint;
      end;
    end
    else
      InsertTextValue := TButton(Sender).Hint;

    if InsertTextValue <> '' then
      InsertText(InsertTextValue);
  end;
end;

procedure TfrmExpressionHelper.btnCheckClick(Sender: TObject);
var
  ExprText: string;
  EvalResult: Variant;
  Ctx: TExpressionContext;
begin
  ExprText := Trim(memExpression.Lines.Text);
  if ExprText = '' then
  begin
    ShowMessage('Nothing to check.');
    Exit;
  end;

  if Assigned(FContextBuilder) then
    Ctx := FContextBuilder
  else
    Ctx := Default(TExpressionContext);

  try
    EvalResult := TReportExpression.Evaluate(ExprText, Ctx);
    ShowMessage('Check OK.' + sLineBreak +
      'Result: ' + VarToStr(EvalResult));
  except
    on E: Exception do
      ShowMessage('Check Error:' + sLineBreak + E.Message + sLineBreak +
        'You can still click OK to save the expression.');
  end;
end;

initialization
  GExprRecentsByKey := nil;

finalization
  GExprRecentsByKey.Free;

end.
