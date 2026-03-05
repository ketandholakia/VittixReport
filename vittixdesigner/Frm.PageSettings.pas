unit Frm.PageSettings;

(*
  Frm.PageSettings — Page Setup Dialog
  =====================================
  Lets the user configure:
    • Paper size (A4, Letter, Legal, A3, Custom)
    • Orientation (Portrait / Landscape)
    • Margins (Left, Top, Right, Bottom in pixels @96 DPI)
    • Custom page dimensions (only enabled when PaperSize = Custom)

  After OK, the caller calls SaveSettings(Designer.Report.PageSettings)
  and then Designer.RebuildLayout.
*)

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vittix.Report.PageSettings;

type
  TfrmPageSettings = class(TForm)
    pnlTop        : TPanel;
    lblCaption    : TLabel;
    grpPaper      : TGroupBox;
    lblPaper      : TLabel;
    cboPaper      : TComboBox;
    rdbPortrait   : TRadioButton;
    rdbLandscape  : TRadioButton;
    lblCustomW    : TLabel;
    edtCustomW    : TEdit;
    lblCustomH    : TLabel;
    edtCustomH    : TEdit;
    grpMargins    : TGroupBox;
    lblLeft       : TLabel;
    edtLeft       : TEdit;
    lblTop        : TLabel;
    edtTop        : TEdit;
    lblRight      : TLabel;
    edtRight      : TEdit;
    lblBottom     : TLabel;
    edtBottom     : TEdit;
    pnlPreview    : TPanel;
    lblPreview    : TLabel;
    lblDimensions : TLabel;
    pnlBottom     : TPanel;
    btnOK         : TButton;
    btnCancel     : TButton;
    btnDefaults   : TButton;

    procedure FormCreate(Sender: TObject);
    procedure cboPaperChange(Sender: TObject);
    procedure rdbOrientationClick(Sender: TObject);
    procedure edtChange(Sender: TObject);
    procedure btnDefaultsClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);

  private
    FSettings: TReportPageSettings;   // a working copy, not the real one

    procedure UpdatePreview;
    procedure UpdateCustomEnable;

  public
    procedure LoadSettings(ASource: TReportPageSettings);
    procedure SaveSettings(ADest: TReportPageSettings);
  end;

implementation

{$R *.dfm}

function IfThen(Cond: Boolean; A, B: TReportOrientation): TReportOrientation; forward;

procedure TfrmPageSettings.FormCreate(Sender: TObject);
begin
  FSettings := TReportPageSettings.Create;

  cboPaper.Items.Clear;
  cboPaper.Items.Add('A4  (210 × 297 mm)');
  cboPaper.Items.Add('Letter  (8.5 × 11 in)');
  cboPaper.Items.Add('Legal  (8.5 × 14 in)');
  cboPaper.Items.Add('A3  (297 × 420 mm)');
  cboPaper.Items.Add('Custom');
  cboPaper.ItemIndex := 0;
end;

procedure TfrmPageSettings.LoadSettings(ASource: TReportPageSettings);
begin
  ASource.AssignTo(FSettings);

  cboPaper.ItemIndex   := Ord(FSettings.PaperSize);
  rdbPortrait.Checked  := FSettings.Orientation = orPortrait;
  rdbLandscape.Checked := FSettings.Orientation = orLandscape;
  edtCustomW.Text      := IntToStr(FSettings.CustomWidth);
  edtCustomH.Text      := IntToStr(FSettings.CustomHeight);
  edtLeft.Text         := IntToStr(FSettings.Margins.Left);
  edtTop.Text          := IntToStr(FSettings.Margins.Top);
  edtRight.Text        := IntToStr(FSettings.Margins.Right);
  edtBottom.Text       := IntToStr(FSettings.Margins.Bottom);

  UpdateCustomEnable;
  UpdatePreview;
end;

procedure TfrmPageSettings.SaveSettings(ADest: TReportPageSettings);
var
  M: TReportMargins;
begin
  FSettings.PaperSize    := TReportPaperSize(cboPaper.ItemIndex);
  if rdbLandscape.Checked then
    FSettings.Orientation := orLandscape
  else
    FSettings.Orientation := orPortrait;
  FSettings.CustomWidth  := StrToIntDef(edtCustomW.Text, 793);
  FSettings.CustomHeight := StrToIntDef(edtCustomH.Text, 1122);

  M.Left   := StrToIntDef(edtLeft.Text,   40);
  M.Top    := StrToIntDef(edtTop.Text,    40);
  M.Right  := StrToIntDef(edtRight.Text,  40);
  M.Bottom := StrToIntDef(edtBottom.Text, 40);
  FSettings.Margins := M;

  FSettings.AssignTo(ADest);
end;

procedure TfrmPageSettings.cboPaperChange(Sender: TObject);
begin
  FSettings.PaperSize := TReportPaperSize(cboPaper.ItemIndex);
  UpdateCustomEnable;
  UpdatePreview;
end;

procedure TfrmPageSettings.rdbOrientationClick(Sender: TObject);
begin
  UpdatePreview;
end;

procedure TfrmPageSettings.edtChange(Sender: TObject);
begin
  UpdatePreview;
end;

procedure TfrmPageSettings.UpdateCustomEnable;
var IsCustom: Boolean;
begin
  IsCustom := cboPaper.ItemIndex = Ord(psCustom);
  edtCustomW.Enabled := IsCustom;
  edtCustomH.Enabled := IsCustom;
  lblCustomW.Enabled := IsCustom;
  lblCustomH.Enabled := IsCustom;
end;

procedure TfrmPageSettings.UpdatePreview;
var
  PS: TReportPageSettings;
  W, H, CW, CH: Integer;
begin
  PS := TReportPageSettings.Create;
  try
    PS.PaperSize    := TReportPaperSize(cboPaper.ItemIndex);
    PS.Orientation  := IfThen(rdbLandscape.Checked, orLandscape, orPortrait);
    PS.CustomWidth  := StrToIntDef(edtCustomW.Text, 793);
    PS.CustomHeight := StrToIntDef(edtCustomH.Text, 1122);
    var M: TReportMargins;
    M.Left   := StrToIntDef(edtLeft.Text,   40);
    M.Top    := StrToIntDef(edtTop.Text,    40);
    M.Right  := StrToIntDef(edtRight.Text,  40);
    M.Bottom := StrToIntDef(edtBottom.Text, 40);
    PS.Margins := M;

    W  := PS.PageWidth;
    H  := PS.PageHeight;
    CW := PS.ContentWidth;
    CH := PS.ContentHeight;

    lblDimensions.Caption :=
      Format('Page: %d × %d px    Content: %d × %d px    @96 DPI',
             [W, H, CW, CH]);
  finally
    PS.Free;
  end;
end;

procedure TfrmPageSettings.btnDefaultsClick(Sender: TObject);
var
  Def: TReportPageSettings;
begin
  Def := TReportPageSettings.Create;
  try
    LoadSettings(Def);
  finally
    Def.Free;
  end;
end;

procedure TfrmPageSettings.btnOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

function IfThen(Cond: Boolean; A, B: TReportOrientation): TReportOrientation;
begin
  if Cond then Result := A else Result := B;
end;

initialization
  // nothing

end.
