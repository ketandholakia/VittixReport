unit Frm.TextExpressionEditor;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  TfrmTextExpressionEditor = class(TForm)
  private
    FMemo: TMemo;
    FBtnOK: TButton;
    FBtnCancel: TButton;
  public
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    class function EditValue(const ATitle: string; var AValue: string): Boolean;
  end;

implementation

constructor TfrmTextExpressionEditor.CreateNew(AOwner: TComponent; Dummy: Integer);
var
  BottomPanel: TPanel;
begin
  inherited CreateNew(AOwner, Dummy);

  Caption := 'Text / Expression Editor';
  Width := 760;
  Height := 460;
  Position := poMainFormCenter;
  BorderStyle := bsSizeable;

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

class function TfrmTextExpressionEditor.EditValue(const ATitle: string; var AValue: string): Boolean;
var
  Frm: TfrmTextExpressionEditor;
begin
  Frm := TfrmTextExpressionEditor.CreateNew(nil);
  try
    if ATitle <> '' then
      Frm.Caption := ATitle;
    Frm.FMemo.Lines.Text := AValue;
    Result := Frm.ShowModal = mrOk;
    if Result then
      AValue := Frm.FMemo.Lines.Text;
  finally
    Frm.Free;
  end;
end;

end.
