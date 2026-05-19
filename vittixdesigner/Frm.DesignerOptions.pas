unit Frm.DesignerOptions;

interface

uses
  System.Classes, System.SysUtils, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Samples.Spin, Vittix.Report.DesignerControl;

type
  TfrmDesignerOptions = class(TForm)
  private
    FGridType: TRadioGroup;
    FGridSize: TEdit;
    FShowGrid: TCheckBox;
    FSnapToGrid: TCheckBox;
    FShowRulers: TCheckBox;
    FShowMargins: TCheckBox;
    FGapLabel: TLabel;
    FOK: TButton;
    FCancel: TButton;
    FRestore: TButton;
    FOwnerDesigner: TVittixReportDesigner;
    procedure RestoreDefaults(Sender: TObject);
    procedure GridTypeChanged(Sender: TObject);
    procedure UpdateUnitCaption;
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
  ClientHeight := 255;
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

end.
