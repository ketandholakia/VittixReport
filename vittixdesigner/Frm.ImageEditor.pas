unit Frm.ImageEditor;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls;

type
  TfrmImageEditor = class(TForm)
  private
    FImage: TImage;
    FBtnImport: TButton;
    FBtnPaste: TButton;
    FBtnOK: TButton;
    FBtnCancel: TButton;
    FStatusLabel: TLabel;
    procedure ImportClick(Sender: TObject);
    procedure PasteClick(Sender: TObject);
    procedure UpdateStatus;
  public
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    class function EditPicture(AInitialPicture, AResultPicture: TPicture): Boolean;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Clipbrd,
  Vcl.Dialogs,
  Vcl.ExtDlgs;

constructor TfrmImageEditor.CreateNew(AOwner: TComponent; Dummy: Integer);
var
  ButtonPanel: TPanel;
begin
  inherited CreateNew(AOwner, Dummy);

  Caption := 'Embedded Image';
  Width := 600;
  Height := 440;
  Position := poMainFormCenter;
  BorderStyle := bsSizeable;

  ButtonPanel := TPanel.Create(Self);
  ButtonPanel.Parent := Self;
  ButtonPanel.Align := alBottom;
  ButtonPanel.Height := 52;
  ButtonPanel.BevelOuter := bvNone;

  FBtnImport := TButton.Create(Self);
  FBtnImport.Parent := ButtonPanel;
  FBtnImport.Caption := 'Import...';
  FBtnImport.SetBounds(8, 12, 92, 27);
  FBtnImport.OnClick := ImportClick;

  FBtnPaste := TButton.Create(Self);
  FBtnPaste.Parent := ButtonPanel;
  FBtnPaste.Caption := 'Paste Image';
  FBtnPaste.SetBounds(108, 12, 100, 27);
  FBtnPaste.OnClick := PasteClick;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := ButtonPanel;
  FStatusLabel.SetBounds(220, 18, 140, 20);

  FBtnOK := TButton.Create(Self);
  FBtnOK.Parent := ButtonPanel;
  FBtnOK.Caption := 'OK';
  FBtnOK.Default := True;
  FBtnOK.ModalResult := mrOk;
  FBtnOK.SetBounds(ButtonPanel.Width - 176, 12, 80, 27);
  FBtnOK.Anchors := [akTop, akRight];

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := ButtonPanel;
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.Cancel := True;
  FBtnCancel.ModalResult := mrCancel;
  FBtnCancel.SetBounds(ButtonPanel.Width - 88, 12, 80, 27);
  FBtnCancel.Anchors := [akTop, akRight];

  FImage := TImage.Create(Self);
  FImage.Parent := Self;
  FImage.Align := alClient;
  FImage.AlignWithMargins := True;
  FImage.Margins.SetBounds(10, 10, 10, 10);
  FImage.Center := True;
  FImage.Proportional := True;
  FImage.Stretch := True;
end;

procedure TfrmImageEditor.ImportClick(Sender: TObject);
var
  Dlg: TOpenPictureDialog;
begin
  Dlg := TOpenPictureDialog.Create(Self);
  try
    Dlg.Title := 'Import Embedded Image';
    Dlg.Filter :=
      'Supported Images (*.bmp;*.jpg;*.jpeg;*.png;*.gif;*.wmf;*.emf)|*.bmp;*.jpg;*.jpeg;*.png;*.gif;*.wmf;*.emf|' +
      'All Files (*.*)|*.*';
    if not Dlg.Execute then
      Exit;
    try
      FImage.Picture.LoadFromFile(Dlg.FileName);
      UpdateStatus;
    except
      on E: Exception do
        MessageDlg('Unable to load image: ' + E.Message, mtError, [mbOK], 0);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmImageEditor.PasteClick(Sender: TObject);
begin
  if not Clipboard.HasFormat(CF_BITMAP) then
  begin
    MessageDlg('The clipboard does not contain a bitmap image.', mtInformation,
      [mbOK], 0);
    Exit;
  end;

  FImage.Picture.Bitmap.Assign(Clipboard);
  UpdateStatus;
end;

procedure TfrmImageEditor.UpdateStatus;
begin
  if Assigned(FImage.Picture.Graphic) and not FImage.Picture.Graphic.Empty then
    FStatusLabel.Caption := Format('%d x %d', [FImage.Picture.Width, FImage.Picture.Height])
  else
    FStatusLabel.Caption := 'No image';
end;

class function TfrmImageEditor.EditPicture(AInitialPicture,
  AResultPicture: TPicture): Boolean;
var
  Dlg: TfrmImageEditor;
begin
  Result := False;
  if not Assigned(AResultPicture) then
    Exit;

  Dlg := TfrmImageEditor.CreateNew(Application);
  try
    if Assigned(AInitialPicture) then
      Dlg.FImage.Picture.Assign(AInitialPicture);
    Dlg.UpdateStatus;
    if Dlg.ShowModal <> mrOk then
      Exit;
    AResultPicture.Assign(Dlg.FImage.Picture);
    Result := True;
  finally
    Dlg.Free;
  end;
end;

end.
