unit Frm.DesignerOptions;

interface

uses
  System.Classes, System.SysUtils, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Dialogs, Vcl.Graphics, Vcl.Samples.Spin,
  Vittix.Report.DesignerControl;

type
  TfrmDesignerOptions = class(TForm)
  private
    FGridType: TRadioGroup;
    FGridSize: TEdit;
    FShowGrid: TCheckBox;
    FSnapToGrid: TCheckBox;
    FShowRulers: TCheckBox;
    FShowMargins: TCheckBox;
    FPageColorBtn: TButton;
    FPageColorSwatch: TPanel;
    FCanvasColorBtn: TButton;
    FCanvasColorSwatch: TPanel;
    FBandGapLabel: TLabel;
    FBandGapEdit: TEdit;
    FGapLabel: TLabel;
    FOK: TButton;
    FCancel: TButton;
    FRestore: TButton;
    FOwnerDesigner: TVittixReportDesigner;
    procedure RestoreDefaults(Sender: TObject);
    procedure GridTypeChanged(Sender: TObject);
    procedure UpdateUnitCaption;
    procedure PickColor(Sender: TObject);
    procedure SyncColorSwatches;
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadFromDesigner(ADesigner: TVittixReportDesigner);
    procedure ApplyToDesigner(ADesigner: TVittixReportDesigner);
  end;

implementation

constructor TfrmDesignerOptions.Create(AOwner: TComponent);
var
  P: TPanel;
begin
  inherited CreateNew(AOwner);
  Caption := 'Designer Options';
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  ClientWidth := 470;
  ClientHeight := 290;
  BorderIcons := [biSystemMenu];

  P := TPanel.Create(Self);
  P.Parent := Self;
  P.Align := alBottom;
  P.Height := 44;
  P.BevelOuter := bvNone;

  FOK := TButton.Create(Self);
  FOK.Parent := P;
  FOK.Caption := 'OK';
  FOK.ModalResult := mrOk;
  FOK.Default := True;
  FOK.SetBounds(230, 8, 75, 25);

  FCancel := TButton.Create(Self);
  FCancel.Parent := P;
  FCancel.Caption := 'Cancel';
  FCancel.ModalResult := mrCancel;
  FCancel.Cancel := True;
  FCancel.SetBounds(310, 8, 75, 25);

  FRestore := TButton.Create(Self);
  FRestore.Parent := P;
  FRestore.Caption := 'Restore Defaults';
  FRestore.SetBounds(12, 8, 110, 25);
  FRestore.OnClick := RestoreDefaults;

  FGridType := TRadioGroup.Create(Self);
  FGridType.Parent := Self;
  FGridType.SetBounds(12, 12, 150, 140);
  FGridType.Caption := 'Grid';
  FGridType.Items.Add('Centimeters');
  FGridType.Items.Add('Inches');
  FGridType.Items.Add('Pixels');
  FGridType.Items.Add('Dialog form');
  FGridType.OnClick := GridTypeChanged;

  FGridSize := TEdit.Create(Self);
  FGridSize.Parent := Self;
  FGridSize.SetBounds(188, 38, 60, 23);

  FGapLabel := TLabel.Create(Self);
  FGapLabel.Parent := Self;
  FGapLabel.SetBounds(188, 20, 100, 16);
  FGapLabel.Caption := 'Grid size';

  FShowGrid := TCheckBox.Create(Self);
  FShowGrid.Parent := Self;
  FShowGrid.Caption := 'Show grid';
  FShowGrid.SetBounds(268, 22, 140, 20);

  FSnapToGrid := TCheckBox.Create(Self);
  FSnapToGrid.Parent := Self;
  FSnapToGrid.Caption := 'Snap to grid';
  FSnapToGrid.SetBounds(268, 46, 140, 20);

  FShowRulers := TCheckBox.Create(Self);
  FShowRulers.Parent := Self;
  FShowRulers.Caption := 'Show rulers';
  FShowRulers.SetBounds(268, 70, 140, 20);

  FShowMargins := TCheckBox.Create(Self);
  FShowMargins.Parent := Self;
  FShowMargins.Caption := 'Show margins';
  FShowMargins.SetBounds(268, 94, 140, 20);

  FPageColorBtn := TButton.Create(Self);
  FPageColorBtn.Parent := Self;
  FPageColorBtn.Caption := 'Page color...';
  FPageColorBtn.SetBounds(268, 126, 90, 25);
  FPageColorBtn.OnClick := PickColor;

  FPageColorSwatch := TPanel.Create(Self);
  FPageColorSwatch.Parent := Self;
  FPageColorSwatch.SetBounds(364, 126, 32, 25);
  FPageColorSwatch.BevelOuter := bvLowered;
  FPageColorSwatch.ParentBackground := False;
  FPageColorSwatch.Caption := '';

  FCanvasColorBtn := TButton.Create(Self);
  FCanvasColorBtn.Parent := Self;
  FCanvasColorBtn.Caption := 'Canvas color...';
  FCanvasColorBtn.SetBounds(268, 156, 90, 25);
  FCanvasColorBtn.OnClick := PickColor;

  FCanvasColorSwatch := TPanel.Create(Self);
  FCanvasColorSwatch.Parent := Self;
  FCanvasColorSwatch.SetBounds(364, 156, 32, 25);
  FCanvasColorSwatch.BevelOuter := bvLowered;
  FCanvasColorSwatch.ParentBackground := False;
  FCanvasColorSwatch.Caption := '';

  FBandGapLabel := TLabel.Create(Self);
  FBandGapLabel.Parent := Self;
  FBandGapLabel.SetBounds(268, 186, 100, 16);
  FBandGapLabel.Caption := 'Band spacing';

  FBandGapEdit := TEdit.Create(Self);
  FBandGapEdit.Parent := Self;
  FBandGapEdit.SetBounds(268, 206, 60, 23);

  UpdateUnitCaption;
end;

procedure TfrmDesignerOptions.LoadFromDesigner(ADesigner: TVittixReportDesigner);
begin
  FOwnerDesigner := ADesigner;
  if not Assigned(ADesigner) then Exit;
  FGridType.ItemIndex := Ord(ADesigner.GridUnit);
  FGridSize.Text := IntToStr(ADesigner.GridSize);
  FShowGrid.Checked := ADesigner.ShowGrid;
  FSnapToGrid.Checked := ADesigner.SnapToGrid;
  FShowRulers.Checked := ADesigner.ShowRulers;
  FShowMargins.Checked := ADesigner.ShowMargins;
  FPageColorBtn.Tag := ADesigner.PageColor;
  FCanvasColorBtn.Tag := ADesigner.CanvasColor;
  FBandGapEdit.Text := IntToStr(ADesigner.BandGap);
  SyncColorSwatches;
  UpdateUnitCaption;
end;

procedure TfrmDesignerOptions.ApplyToDesigner(ADesigner: TVittixReportDesigner);
begin
  if not Assigned(ADesigner) then Exit;
  ADesigner.GridSize := StrToIntDef(FGridSize.Text, ADesigner.GridSize);
  ADesigner.GridUnit := TDesignerGridUnit(FGridType.ItemIndex);
  ADesigner.ShowGrid := FShowGrid.Checked;
  ADesigner.SnapToGrid := FSnapToGrid.Checked;
  ADesigner.ShowRulers := FShowRulers.Checked;
  ADesigner.ShowMargins := FShowMargins.Checked;
  ADesigner.PageColor := TColor(FPageColorBtn.Tag);
  ADesigner.CanvasColor := TColor(FCanvasColorBtn.Tag);
  ADesigner.BandGap := StrToIntDef(FBandGapEdit.Text, ADesigner.BandGap);
end;

procedure TfrmDesignerOptions.RestoreDefaults(Sender: TObject);
begin
  if Assigned(FOwnerDesigner) then
  begin
    FGridSize.Text := '8';
    FShowGrid.Checked := True;
    FSnapToGrid.Checked := True;
    FShowRulers.Checked := True;
    FShowMargins.Checked := True;
    FPageColorBtn.Tag := ColorToRGB(clWhite);
    FCanvasColorBtn.Tag := ColorToRGB($00808080);
    FBandGapEdit.Text := '4';
    SyncColorSwatches;
  end;
end;

procedure TfrmDesignerOptions.GridTypeChanged(Sender: TObject);
begin
  UpdateUnitCaption;
end;

procedure TfrmDesignerOptions.UpdateUnitCaption;
const
  UnitNames: array[0..3] of string = ('cm', 'in', 'pt', 'pt');
begin
  if (FGridType.ItemIndex >= Low(UnitNames)) and (FGridType.ItemIndex <= High(UnitNames)) then
    FGapLabel.Caption := 'Grid size (' + UnitNames[FGridType.ItemIndex] + ')'
  else
    FGapLabel.Caption := 'Grid size';
end;

procedure TfrmDesignerOptions.PickColor(Sender: TObject);
var
  Btn: TButton;
  Dlg: TColorDialog;
begin
  if not (Sender is TButton) then Exit;
  Btn := TButton(Sender);
  Dlg := TColorDialog.Create(Self);
  try
    Dlg.Color := TColor(Btn.Tag);
    if Dlg.Execute then
    begin
      Btn.Tag := ColorToRGB(Dlg.Color);
      SyncColorSwatches;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmDesignerOptions.SyncColorSwatches;
begin
  FPageColorSwatch.Color := TColor(FPageColorBtn.Tag);
  FCanvasColorSwatch.Color := TColor(FCanvasColorBtn.Tag);
  FPageColorSwatch.Invalidate;
  FCanvasColorSwatch.Invalidate;
end;

end.
