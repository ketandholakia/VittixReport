unit Frm.ExpressionEditor;

interface

uses
  System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, 
  Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TfrmExpressionEditor = class(TForm)
  private
    FMemo: TMemo;
    FBtnOK: TButton;
    FBtnCancel: TButton;
    FLabel: TLabel;
  public
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    class function EditExpression(const ATitle: string; var AExpression: string): Boolean;
  end;

implementation

constructor TfrmExpressionEditor.CreateNew(AOwner: TComponent; Dummy: Integer);
var
  PnlBottom: TPanel;
begin
  inherited CreateNew(AOwner, Dummy);
  Caption := 'Expression Editor';
  Width := 500;
  Height := 350;
  Position := poMainFormCenter;
  BorderStyle := bsDialog;

  FLabel := TLabel.Create(Self);
  FLabel.Parent := Self;
  FLabel.Align := alTop;
  FLabel.Margins.SetBounds(10, 10, 10, 5);
  FLabel.AlignWithMargins := True;
  FLabel.Caption := 'Enter dynamic expression (e.g. IF(<Dataset.Value> < 0, clRed, clBlack)):';

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.Margins.SetBounds(10, 0, 10, 10);
  FMemo.AlignWithMargins := True;
  FMemo.Font.Name := 'Consolas';
  FMemo.Font.Size := 10;
  FMemo.ScrollBars := ssVertical;

  PnlBottom := TPanel.Create(Self);
  PnlBottom.Parent := Self;
  PnlBottom.Align := alBottom;
  PnlBottom.Height := 45;
  PnlBottom.BevelOuter := bvNone;

  FBtnOK := TButton.Create(Self);
  FBtnOK.Parent := PnlBottom;
  FBtnOK.SetBounds(PnlBottom.Width - 180, 10, 80, 25);
  FBtnOK.Anchors := [akTop, akRight];
  FBtnOK.Caption := 'OK';
  FBtnOK.Default := True;
  FBtnOK.ModalResult := mrOk;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := PnlBottom;
  FBtnCancel.SetBounds(PnlBottom.Width - 90, 10, 80, 25);
  FBtnCancel.Anchors := [akTop, akRight];
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.Cancel := True;
  FBtnCancel.ModalResult := mrCancel;
end;

class function TfrmExpressionEditor.EditExpression(const ATitle: string; var AExpression: string): Boolean;
var
  Frm: TfrmExpressionEditor;
begin
  Frm := TfrmExpressionEditor.CreateNew(nil);
  try
    Frm.Caption := ATitle;
    Frm.FMemo.Text := AExpression;
    Result := Frm.ShowModal = mrOk;
    if Result then
      AExpression := Frm.FMemo.Text;
  finally
    Frm.Free;
  end;
end;

end.