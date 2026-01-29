unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ValEdit,
  Data.DB, Datasnap.DBClient,

  Vittix.Report.DesignerControl,
  Vittix.Report.Toolbox,
  Vittix.Report.Preview,
  Vittix.Report.Renderer,
  Vittix.Report.Model,
  Vittix.Report.PropertyBridge;

type
  TfrmMain = class(TForm)
  private
    Designer: TVittixReportDesigner;
    Toolbox: TVittixReportToolbox;
    Preview: TVittixReportPreview;
    PropGrid: TValueListEditor;

    BtnRender: TButton;
    BtnInsert: TButton;

    CDS: TClientDataSet;
    DS: TDataSource;

    Renderer: TReportRenderer;

    procedure ToolboxClick(Sender: TObject);
    procedure DesignerSelectionChanged(Sender: TObject);
    procedure PropGridEdit(Sender: TObject; ACol, ARow: Integer; const Value: string);
    procedure RenderClick(Sender: TObject);

    procedure BuildSampleData;

  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  frmMain: TfrmMain;

implementation

{ ================= Constructor ================= }

constructor TfrmMain.Create(AOwner: TComponent);
var
  RightPanel: TPanel;
  TopBar: TPanel;
begin
  inherited;

  Width := 1200;
  Height := 800;
  Caption := 'Vittix Report Designer Demo';

  { ---------- Top bar ---------- }

  TopBar := TPanel.Create(Self);
  TopBar.Parent := Self;
  TopBar.Align := alTop;
  TopBar.Height := 40;

  BtnInsert := TButton.Create(Self);
  BtnInsert.Parent := TopBar;
  BtnInsert.Left := 10;
  BtnInsert.Top := 8;
  BtnInsert.Caption := 'Insert Tool';
  BtnInsert.OnClick := ToolboxClick;

  BtnRender := TButton.Create(Self);
  BtnRender.Parent := TopBar;
  BtnRender.Left := 110;
  BtnRender.Top := 8;
  BtnRender.Caption := 'Render Preview';
  BtnRender.OnClick := RenderClick;

  { ---------- Toolbox ---------- }

  Toolbox := TVittixReportToolbox.Create(Self);
  Toolbox.Parent := Self;
  Toolbox.Align := alLeft;
  Toolbox.Width := 200;

  { ---------- Right panel ---------- }

  RightPanel := TPanel.Create(Self);
  RightPanel.Parent := Self;
  RightPanel.Align := alRight;
  RightPanel.Width := 300;

  PropGrid := TValueListEditor.Create(Self);
  PropGrid.Parent := RightPanel;
  PropGrid.Align := alClient;
  PropGrid.OnSetEditText := PropGridEdit;

  { ---------- Preview ---------- }

  Preview := TVittixReportPreview.Create(Self);
  Preview.Parent := RightPanel;
  Preview.Align := alBottom;
  Preview.Height := 350;

  { ---------- Designer ---------- }

  Designer := TVittixReportDesigner.Create(Self);
  Designer.Parent := Self;
  Designer.Align := alClient;
  Designer.OnSelectionChanged := DesignerSelectionChanged;

  { ---------- Dataset ---------- }

  CDS := TClientDataSet.Create(Self);
  DS := TDataSource.Create(Self);
  DS.DataSet := CDS;

  BuildSampleData;

  { ---------- Renderer ---------- }

  Renderer := TReportRenderer.Create;

  { link dataset }
  Designer.DataSet := CDS;
end;

{ ================= Sample Data ================= }

procedure TfrmMain.BuildSampleData;
begin
  CDS.FieldDefs.Add('Item', ftString, 50);
  CDS.FieldDefs.Add('Qty', ftInteger);
  CDS.FieldDefs.Add('Price', ftFloat);
  CDS.CreateDataSet;

  CDS.AppendRecord(['Pen', 10, 1.5]);
  CDS.AppendRecord(['Book', 5, 12]);
  CDS.AppendRecord(['Bag', 2, 45]);
end;

{ ================= Toolbox Insert ================= }

procedure TfrmMain.ToolboxClick(Sender: TObject);
begin
  if Assigned(Toolbox.SelectedObjectClass) then
    Designer.BeginInsertObject(Toolbox.SelectedObjectClass);
end;

{ ================= Selection Sync ================= }

procedure TfrmMain.DesignerSelectionChanged(Sender: TObject);
begin
  TReportPropertyBridge.LoadObjectToGrid(
    Designer.SelectedObject,
    PropGrid
  );
end;

{ ================= Property Grid Edit ================= }

procedure TfrmMain.PropGridEdit(Sender: TObject; ACol, ARow: Integer; const Value: string);
begin
  TReportPropertyBridge.SaveGridToObject(
    Designer.SelectedObject,
    PropGrid
  );
  Designer.Invalidate;
end;

{ ================= Render Preview ================= }

procedure TfrmMain.RenderClick(Sender: TObject);
begin
  Renderer.Render(Designer.Report, CDS);
  Preview.LoadFromRenderer(Renderer);
end;

end.
