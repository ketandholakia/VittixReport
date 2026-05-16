unit Frm.BandManager;

(*
  Frm.BandManager — Band Manager Dialog
  ======================================
  Shows a list of all bands currently in the report.
  The user can:
    • Add a new band of any type
    • Delete a selected band (and all its children)
    • Edit a band's Height, GroupField, GroupLevel, CanGrow, CanShrink,
      StartNewPage, BackColor, BackColorTransparent
    • Move bands up/down in the list (changes display order only; the
      designer control re-sorts by BAND_ORDER so this is mainly for reference)
*)

interface

uses
  System.SysUtils, System.Classes, System.Types,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.Dialogs, Vcl.Graphics,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Serializer;

type
  TfrmBandManager = class(TForm)
    pnlTop       : TPanel;
    lblTitle     : TLabel;
    pnlList      : TPanel;
    lblBands     : TLabel;
    lstBands     : TListBox;
    pnlListBtns  : TPanel;
    btnAddBand   : TButton;
    btnDelBand   : TButton;
    btnMoveUp    : TButton;
    btnMoveDown  : TButton;
    splH         : TSplitter;
    pnlEdit      : TPanel;
    lblEditTitle : TLabel;
    lblBandType  : TLabel;
    cboBandType  : TComboBox;
    lblHeight    : TLabel;
    edtHeight    : TEdit;
    lblDataSetName: TLabel;
    cboDataSetName: TComboBox;
    lblGroupField: TLabel;
    edtGroupField: TEdit;
    lblGroupLevel: TLabel;
    edtGroupLevel: TEdit;
    chkCanGrow   : TCheckBox;
    chkCanShrink : TCheckBox;
    chkStartNewPage: TCheckBox;
    chkTransparent : TCheckBox;
    lblBackColor : TLabel;
    pnlColorSwatch: TPanel;
    btnPickColor : TButton;
    pnlBottom    : TPanel;
    btnOK        : TButton;
    btnCancel    : TButton;
    dlgColor     : TColorDialog;

    procedure FormCreate(Sender: TObject);
    procedure lstBandsClick(Sender: TObject);
    procedure btnAddBandClick(Sender: TObject);
    procedure btnDelBandClick(Sender: TObject);
    procedure btnMoveUpClick(Sender: TObject);
    procedure btnMoveDownClick(Sender: TObject);
    procedure btnPickColorClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);

  private
    FReport     : TReportModel; // staged working report owned by dialog
    FCurrentBand: TReportBand;
    FLoadingEditor: Boolean;

    procedure RefreshList;
    procedure RefreshDataSetNameList;
    procedure LoadBandToEditor(ABand: TReportBand);
    procedure SaveEditorToBand(ABand: TReportBand);
    procedure ApplyCurrentBandEdits;
    function  SelectedBand: TReportBand;
    function  BandTypeFromCombo: TReportBandType;
    function  ComboIndexFromBandType(ABandType: TReportBandType): Integer;

  public
    destructor Destroy; override;
    procedure LoadReport(AReport: TReportModel);
    function  TakeStagedReport: TReportModel;
  end;

implementation

{$R *.dfm}

uses
  Vcl.ActnList;

function BandTypeToStr(BT: TReportBandType): string; forward;

procedure TfrmBandManager.FormCreate(Sender: TObject);
var
  BT: TReportBandType;
begin
  cboBandType.Items.Clear;
  for BT := Low(TReportBandType) to High(TReportBandType) do
    cboBandType.Items.AddObject(BandTypeToStr(BT), TObject(NativeInt(Ord(BT))));
  cboBandType.ItemIndex := 0;

  pnlColorSwatch.Color  := clWhite;
  FCurrentBand := nil;
  FLoadingEditor := False;
end;

function BandTypeToStr(BT: TReportBandType): string;
begin
  case BT of
    btReportTitle:   Result := 'Report Title';
    btPageHeader:    Result := 'Page Header';
    btMasterData:    Result := 'Master Data';
    btPageFooter:    Result := 'Page Footer';
    btReportSummary: Result := 'Report Summary';
    btGroupHeader:   Result := 'Group Header';
    btGroupFooter:   Result := 'Group Footer';
    btColumnHeader:  Result := 'Column Header';
    btDetail:        Result := 'Detail';
    btOverlay:       Result := 'Overlay';
  else
    Result := 'Band';
  end;
end;

procedure TfrmBandManager.LoadReport(AReport: TReportModel);
begin
  FreeAndNil(FReport);
  if Assigned(AReport) then
    FReport := TReportSerializer.CloneReport(AReport)
  else
    FReport := TReportModel.Create;
  RefreshDataSetNameList;
  RefreshList;
end;

destructor TfrmBandManager.Destroy;
begin
  FReport.Free;
  inherited;
end;

function TfrmBandManager.TakeStagedReport: TReportModel;
begin
  Result := FReport;
  FReport := nil;
  FCurrentBand := nil;
end;

procedure TfrmBandManager.RefreshDataSetNameList;
var
  Obj: TReportObject;
  Band: TReportBand;
  SubRep: TReportSubReportObject;
  Name: string;
begin
  cboDataSetName.Items.BeginUpdate;
  try
    cboDataSetName.Items.Clear;
    cboDataSetName.Items.Add('');
    if not Assigned(FReport) then Exit;

    for Name in FReport.DataSetNames do
      if cboDataSetName.Items.IndexOf(Name) < 0 then
        cboDataSetName.Items.Add(Name);

    for Obj in FReport.Objects do
    begin
      if Obj is TReportBand then
      begin
        Band := TReportBand(Obj);
        Name := Trim(Band.DataSetName);
        if (Name <> '') and (cboDataSetName.Items.IndexOf(Name) < 0) then
          cboDataSetName.Items.Add(Name);
      end
      else if Obj is TReportSubReportObject then
      begin
        SubRep := TReportSubReportObject(Obj);
        Name := Trim(SubRep.DataSetName);
        if (Name <> '') and (cboDataSetName.Items.IndexOf(Name) < 0) then
          cboDataSetName.Items.Add(Name);
      end;
    end;
  finally
    cboDataSetName.Items.EndUpdate;
  end;
end;

procedure TfrmBandManager.RefreshList;
var
  Obj : TReportObject;
  Band: TReportBand;
  Sel : Integer;
begin
  ApplyCurrentBandEdits;

  Sel := lstBands.ItemIndex;
  lstBands.Items.BeginUpdate;
  try
    lstBands.Items.Clear;
    if not Assigned(FReport) then Exit;
    for Obj in FReport.Objects do
      if Obj is TReportBand then
      begin
        Band := TReportBand(Obj);
        lstBands.Items.AddObject(
          BandTypeToStr(Band.BandType) + '  (H=' + IntToStr(Band.Height) + ')',
          Band);
      end;
  finally
    lstBands.Items.EndUpdate;
  end;
  if (Sel < 0) and (lstBands.Count > 0) then
    Sel := 0;
  if Sel >= lstBands.Count then Sel := lstBands.Count - 1;
  lstBands.ItemIndex := Sel;
  FCurrentBand := SelectedBand;
  LoadBandToEditor(FCurrentBand);
end;

function TfrmBandManager.SelectedBand: TReportBand;
begin
  Result := nil;
  if lstBands.ItemIndex < 0 then Exit;
  Result := TReportBand(lstBands.Items.Objects[lstBands.ItemIndex]);
end;

procedure TfrmBandManager.lstBandsClick(Sender: TObject);
begin
  ApplyCurrentBandEdits;
  FCurrentBand := SelectedBand;
  LoadBandToEditor(FCurrentBand);
end;

procedure TfrmBandManager.LoadBandToEditor(ABand: TReportBand);
begin
  FLoadingEditor := True;
  try
  if not Assigned(ABand) then
  begin
    cboBandType.ItemIndex := 0;
    edtHeight.Text        := '40';
    cboDataSetName.Text   := '';
    edtGroupField.Text    := '';
    edtGroupLevel.Text    := '0';
    chkCanGrow.Checked    := False;
    chkCanShrink.Checked  := False;
    chkStartNewPage.Checked := False;
    chkTransparent.Checked  := True;
    pnlColorSwatch.Color    := clWhite;
    Exit;
  end;
  cboBandType.ItemIndex    := ComboIndexFromBandType(ABand.BandType);
  edtHeight.Text           := IntToStr(ABand.Height);
  cboDataSetName.Text      := ABand.DataSetName;
  edtGroupField.Text       := ABand.GroupField;
  edtGroupLevel.Text       := IntToStr(ABand.GroupLevel);
  chkCanGrow.Checked       := ABand.CanGrow;
  chkCanShrink.Checked     := ABand.CanShrink;
  chkStartNewPage.Checked  := ABand.StartNewPage;
  chkTransparent.Checked   := ABand.BackColorTransparent;
  pnlColorSwatch.Color     := ABand.BackColor;
  finally
    FLoadingEditor := False;
  end;
end;

procedure TfrmBandManager.SaveEditorToBand(ABand: TReportBand);
begin
  if not Assigned(ABand) or FLoadingEditor then Exit;
  ABand.BandType           := BandTypeFromCombo;
  ABand.Height             := StrToIntDef(edtHeight.Text, 40);
  ABand.DataSetName        := Trim(cboDataSetName.Text);
  ABand.GroupField         := edtGroupField.Text;
  ABand.GroupLevel         := StrToIntDef(edtGroupLevel.Text, 0);
  ABand.CanGrow            := chkCanGrow.Checked;
  ABand.CanShrink          := chkCanShrink.Checked;
  ABand.StartNewPage       := chkStartNewPage.Checked;
  ABand.BackColorTransparent := chkTransparent.Checked;
  ABand.BackColor          := pnlColorSwatch.Color;
  if (ABand.DataSetName <> '') and (Assigned(FReport))
     and (FReport.DataSetNames.IndexOf(ABand.DataSetName) < 0) then
    FReport.DataSetNames.Add(ABand.DataSetName);
  RefreshDataSetNameList;
end;

procedure TfrmBandManager.ApplyCurrentBandEdits;
begin
  if Assigned(FCurrentBand) then
    SaveEditorToBand(FCurrentBand);
end;

function TfrmBandManager.BandTypeFromCombo: TReportBandType;
begin
  Result := btReportTitle;
  if (cboBandType.ItemIndex >= 0) and (cboBandType.ItemIndex < cboBandType.Items.Count) then
    Result := TReportBandType(NativeInt(cboBandType.Items.Objects[cboBandType.ItemIndex]));
end;

function TfrmBandManager.ComboIndexFromBandType(ABandType: TReportBandType): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to cboBandType.Items.Count - 1 do
    if NativeInt(cboBandType.Items.Objects[I]) = Ord(ABandType) then
      Exit(I);
  if cboBandType.Items.Count > 0 then
    Result := 0;
end;

procedure TfrmBandManager.btnAddBandClick(Sender: TObject);
var
  Band: TReportBand;
begin
  if not Assigned(FReport) then Exit;
  ApplyCurrentBandEdits;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height   := 40;
  FReport.Objects.Add(Band);
  RefreshList;
  lstBands.ItemIndex := lstBands.Count - 1;
  lstBandsClick(nil);
end;

procedure TfrmBandManager.btnDelBandClick(Sender: TObject);
var
  Band: TReportBand;
  Idx : Integer;
begin
  ApplyCurrentBandEdits;
  Band := SelectedBand;
  if not Assigned(Band) then Exit;
  if MessageDlg('Delete this band and all its objects?',
                mtConfirmation, [mbYes, mbNo], 0) = mrNo then Exit;
  Idx := FReport.Objects.IndexOf(Band);
  FReport.Objects.Delete(Idx);   // list owns objects — frees band
  FCurrentBand := nil;
  RefreshList;
end;

procedure TfrmBandManager.btnMoveUpClick(Sender: TObject);
var
  Idx: Integer;
  Obj: TReportObject;
begin
  if not Assigned(FReport) then Exit;
  ApplyCurrentBandEdits;
  Idx := lstBands.ItemIndex;
  if Idx <= 0 then Exit;
  // Find position in FReport.Objects and swap with previous band
  var RealIdx := FReport.Objects.IndexOf(SelectedBand);
  if RealIdx <= 0 then Exit;
  Obj := FReport.Objects.Extract(FReport.Objects[RealIdx]);
  FReport.Objects.Insert(RealIdx - 1, Obj);
  RefreshList;
  lstBands.ItemIndex := Idx - 1;
end;

procedure TfrmBandManager.btnMoveDownClick(Sender: TObject);
var
  Idx   : Integer;
  Obj   : TReportObject;
begin
  if not Assigned(FReport) then Exit;
  ApplyCurrentBandEdits;
  Idx := lstBands.ItemIndex;
  if Idx >= lstBands.Count - 1 then Exit;
  var RealIdx := FReport.Objects.IndexOf(SelectedBand);
  if RealIdx >= FReport.Objects.Count - 1 then Exit;
  Obj := FReport.Objects.Extract(FReport.Objects[RealIdx]);
  FReport.Objects.Insert(RealIdx + 1, Obj);
  RefreshList;
  lstBands.ItemIndex := Idx + 1;
end;

procedure TfrmBandManager.btnPickColorClick(Sender: TObject);
begin
  dlgColor.Color := pnlColorSwatch.Color;
  if dlgColor.Execute then
    pnlColorSwatch.Color := dlgColor.Color;
end;

procedure TfrmBandManager.btnOKClick(Sender: TObject);
begin
  ApplyCurrentBandEdits;
  RefreshList;
  ModalResult := mrOk;
end;

end.
