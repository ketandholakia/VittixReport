unit ReportDesignerDemo_MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Data.DB, Datasnap.DBClient,
  Vittix.Report.DesignerControl,
  Vittix.Report.Toolbox,
  Vittix.Report.Preview,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Serializer,
  Vittix.Report.Engine,
  Vittix.Report.Renderer,
  Vittix.Report.Export.PDF, System.ImageList, Vcl.ImgList, Vcl.ToolWin;

type
  TfrmReportDesignerDemo = class(TForm)
    MainMenu1: TMainMenu;
    mnuFile: TMenuItem;
    mnuNew: TMenuItem;
    mnuOpen: TMenuItem;
    mnuSave: TMenuItem;
    mnuSaveAs: TMenuItem;
    N1: TMenuItem;
    mnuExit: TMenuItem;
    mnuEdit: TMenuItem;
    mnuUndo: TMenuItem;
    mnuRedo: TMenuItem;
    N2: TMenuItem;
    mnuCut: TMenuItem;
    mnuCopy: TMenuItem;
    mnuPaste: TMenuItem;
    mnuDelete: TMenuItem;
    mnuReport: TMenuItem;
    mnuPreview: TMenuItem;
    mnuExportPDF: TMenuItem;
    mnuAlign: TMenuItem;
    mnuAlignLeft: TMenuItem;
    mnuAlignRight: TMenuItem;
    mnuAlignTop: TMenuItem;
    mnuAlignBottom: TMenuItem;
    N3: TMenuItem;
    mnuSameWidth: TMenuItem;
    mnuSameHeight: TMenuItem;
    N4: TMenuItem;
    mnuDistributeH: TMenuItem;
    mnuDistributeV: TMenuItem;
    StatusBar1: TStatusBar;
    pnlLeft: TPanel;
    pnlToolbox: TPanel;
    lblToolbox: TLabel;
    pnlProperties: TPanel;
    lblProperties: TLabel;
    Splitter1: TSplitter;
    pnlDesigner: TPanel;
    ToolBar1: TToolBar;
    btnNew: TToolButton;
    btnOpen: TToolButton;
    btnSave: TToolButton;
    ToolButton1: TToolButton;
    btnUndo: TToolButton;
    btnRedo: TToolButton;
    ToolButton2: TToolButton;
    btnCopy: TToolButton;
    btnPaste: TToolButton;
    ToolButton3: TToolButton;
    btnPreview: TToolButton;
    btnExportPDF: TToolButton;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    SaveDialog2: TSaveDialog;
    pnlPropertyGrid: TPanel;
    memoProperties: TMemo;
    pnlTop: TPanel;
    lblTitle: TLabel;
    lblDataSource: TLabel;
    cbDataSource: TComboBox;
    btnRefreshData: TButton;
    ClientDataSet1: TClientDataSet;
    DataSource1: TDataSource;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure mnuNewClick(Sender: TObject);
    procedure mnuOpenClick(Sender: TObject);
    procedure mnuSaveClick(Sender: TObject);
    procedure mnuSaveAsClick(Sender: TObject);
    procedure mnuExitClick(Sender: TObject);
    procedure mnuUndoClick(Sender: TObject);
    procedure mnuRedoClick(Sender: TObject);
    procedure mnuCopyClick(Sender: TObject);
    procedure mnuPasteClick(Sender: TObject);
    procedure mnuPreviewClick(Sender: TObject);
    procedure mnuExportPDFClick(Sender: TObject);
    procedure mnuAlignLeftClick(Sender: TObject);
    procedure mnuAlignRightClick(Sender: TObject);
    procedure mnuAlignTopClick(Sender: TObject);
    procedure mnuAlignBottomClick(Sender: TObject);
    procedure mnuSameWidthClick(Sender: TObject);
    procedure mnuSameHeightClick(Sender: TObject);
    procedure mnuDistributeHClick(Sender: TObject);
    procedure mnuDistributeVClick(Sender: TObject);
    procedure cbDataSourceChange(Sender: TObject);
    procedure btnRefreshDataClick(Sender: TObject);
  private
    FReportDesigner: TVittixReportDesigner;
    FReportToolbox: TVittixReportToolbox;
    FCurrentFileName: string;
    
    FPreviewControl: TVittixReportPreview;
    FPageLabel: TLabel;

    procedure PreviewBtnFirstClick(Sender: TObject);
    procedure PreviewBtnPrevClick(Sender: TObject);
    procedure PreviewBtnNextClick(Sender: TObject);
    procedure PreviewBtnLastClick(Sender: TObject);

    procedure SetupDemoData;
    procedure ToolboxToolSelected(Sender: TObject);
    procedure DesignerSelectionChanged(Sender: TObject);
    procedure UpdatePropertyDisplay;
    procedure UpdateStatusBar;
  public
    { Public declarations }
  end;

var
  frmReportDesignerDemo: TfrmReportDesignerDemo;

implementation

{$R *.dfm}

uses
  Vittix.Report.Bands,
  System.TypInfo,
  System.Rtti;

{ ================= Form Create/Destroy ================= }

procedure TfrmReportDesignerDemo.FormCreate(Sender: TObject);
begin
  // Force linker to include TImageList class
  TImageList.ClassName;
  
  Caption := 'Vittix Report Designer Demo - [Untitled]';
  FCurrentFileName := '';
  
  // Create and setup the report designer
  FReportDesigner := TVittixReportDesigner.Create(Self);
  FReportDesigner.Parent := pnlDesigner;
  FReportDesigner.Align := alClient;
  FReportDesigner.Color := clWhite;
  FReportDesigner.ShowGrid := True;
  FReportDesigner.SnapToGrid := True;
  FReportDesigner.GridSize := 8;
  FReportDesigner.OnSelectionChanged := DesignerSelectionChanged;
  
  // Create and setup the toolbox
  FReportToolbox := TVittixReportToolbox.Create(Self);
  FReportToolbox.Parent := pnlToolbox;
  FReportToolbox.Align := alClient;
  FReportToolbox.OnToolSelected := ToolboxToolSelected;
  FReportToolbox.RefreshToolList;
  
  // Setup demo data
  SetupDemoData;
  
  // Initial status
  UpdateStatusBar;
  UpdatePropertyDisplay;
end;

procedure TfrmReportDesignerDemo.FormDestroy(Sender: TObject);
begin
  // Components are auto-freed by owner
end;

{ ================= Demo Data Setup ================= }

procedure TfrmReportDesignerDemo.SetupDemoData;
begin
  // Create sample data for the report
  ClientDataSet1.Close;
  
  // Define fields
  ClientDataSet1.FieldDefs.Clear;
  ClientDataSet1.FieldDefs.Add('ID', ftInteger);
  ClientDataSet1.FieldDefs.Add('CustomerName', ftString, 50);
  ClientDataSet1.FieldDefs.Add('OrderDate', ftDate);
  ClientDataSet1.FieldDefs.Add('Amount', ftCurrency);
  ClientDataSet1.FieldDefs.Add('Category', ftString, 30);
  ClientDataSet1.FieldDefs.Add('Region', ftString, 20);
  ClientDataSet1.CreateDataSet;
  
  // Add sample data
  ClientDataSet1.AppendRecord([1, 'Acme Corp', EncodeDate(2025, 1, 15), 1250.50, 'Electronics', 'North']);
  ClientDataSet1.AppendRecord([2, 'TechWorld Inc', EncodeDate(2025, 1, 16), 3400.75, 'Electronics', 'North']);
  ClientDataSet1.AppendRecord([3, 'Global Trading', EncodeDate(2025, 1, 17), 890.25, 'Furniture', 'South']);
  ClientDataSet1.AppendRecord([4, 'Best Services', EncodeDate(2025, 1, 18), 2100.00, 'Electronics', 'East']);
  ClientDataSet1.AppendRecord([5, 'Prime Solutions', EncodeDate(2025, 1, 19), 1650.80, 'Furniture', 'South']);
  ClientDataSet1.AppendRecord([6, 'Alpha Industries', EncodeDate(2025, 1, 20), 4200.30, 'Electronics', 'West']);
  ClientDataSet1.AppendRecord([7, 'Beta Company', EncodeDate(2025, 1, 21), 780.60, 'Furniture', 'North']);
  ClientDataSet1.AppendRecord([8, 'Gamma Enterprises', EncodeDate(2025, 1, 22), 2950.45, 'Electronics', 'East']);
  ClientDataSet1.AppendRecord([9, 'Delta Corp', EncodeDate(2025, 1, 23), 1120.90, 'Furniture', 'South']);
  ClientDataSet1.AppendRecord([10, 'Epsilon Ltd', EncodeDate(2025, 1, 24), 3700.15, 'Electronics', 'West']);
  
  ClientDataSet1.First;
  
  // Connect to designer
  FReportDesigner.DataSet := ClientDataSet1;
  
  // Setup data source combo
  cbDataSource.Clear;
  cbDataSource.Items.Add('ClientDataSet1 (Sample Orders)');
  cbDataSource.ItemIndex := 0;
end;

{ ================= Toolbox Events ================= }

procedure TfrmReportDesignerDemo.ToolboxToolSelected(Sender: TObject);
begin
  if Assigned(FReportToolbox.SelectedObjectClass) then
  begin
    FReportDesigner.BeginInsertObject(FReportToolbox.SelectedObjectClass);
    UpdateStatusBar;
  end;
end;

{ ================= Designer Events ================= }

procedure TfrmReportDesignerDemo.DesignerSelectionChanged(Sender: TObject);
begin
  UpdatePropertyDisplay;
  UpdateStatusBar;
end;

{ ================= File Menu ================= }

procedure TfrmReportDesignerDemo.mnuNewClick(Sender: TObject);
begin
  if MessageDlg('Create a new report? Any unsaved changes will be lost.',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FReportDesigner.Report.Objects.Clear;
    FReportDesigner.ClearSelection;
    FCurrentFileName := '';
    Caption := 'Vittix Report Designer Demo - [Untitled]';
    UpdateStatusBar;
  end;
end;

procedure TfrmReportDesignerDemo.mnuOpenClick(Sender: TObject);
var
  NewReport: TReportModel;
begin
  if OpenDialog1.Execute then
  begin
    try
      NewReport := TReportSerializer.LoadFromFile(OpenDialog1.FileName);
      
      // Replace current report
      FReportDesigner.Report.Objects.Clear;
      // Add objects one by one as AddRange might not be available or cause compiler issues
      for var i := 0 to NewReport.Objects.Count - 1 do
        FReportDesigner.Report.Objects.Add(TReportObject(NewReport.Objects.Items[i]));
      
      // Don't free the objects, just the container
      NewReport.Objects.OwnsObjects := False;
      NewReport.Free;
      
      FCurrentFileName := OpenDialog1.FileName;
      Caption := 'Vittix Report Designer Demo - ' + ExtractFileName(FCurrentFileName);
      FReportDesigner.Invalidate;
      UpdateStatusBar;
      
      ShowMessage('Report loaded successfully!');
    except
      on E: Exception do
        ShowMessage('Error loading report: ' + E.Message);
    end;
  end;
end;

procedure TfrmReportDesignerDemo.mnuSaveClick(Sender: TObject);
begin
  if FCurrentFileName = '' then
    mnuSaveAsClick(Sender)
  else
  begin
    try
      TReportSerializer.SaveToFile(FReportDesigner.Report, FCurrentFileName);
      ShowMessage('Report saved successfully!');
    except
      on E: Exception do
        ShowMessage('Error saving report: ' + E.Message);
    end;
  end;
end;

procedure TfrmReportDesignerDemo.mnuSaveAsClick(Sender: TObject);
begin
  SaveDialog1.FileName := FCurrentFileName;
  if SaveDialog1.Execute then
  begin
    try
      TReportSerializer.SaveToFile(FReportDesigner.Report, SaveDialog1.FileName);
      FCurrentFileName := SaveDialog1.FileName;
      Caption := 'Vittix Report Designer Demo - ' + ExtractFileName(FCurrentFileName);
      ShowMessage('Report saved successfully!');
    except
      on E: Exception do
        ShowMessage('Error saving report: ' + E.Message);
    end;
  end;
end;

procedure TfrmReportDesignerDemo.mnuExitClick(Sender: TObject);
begin
  Close;
end;

{ ================= Edit Menu ================= }

procedure TfrmReportDesignerDemo.mnuUndoClick(Sender: TObject);
begin
  // Undo functionality is built into the designer
  ShowMessage('Undo: Press Ctrl+Z in the designer');
end;

procedure TfrmReportDesignerDemo.mnuRedoClick(Sender: TObject);
begin
  // Redo functionality is built into the designer
  ShowMessage('Redo: Press Ctrl+Y in the designer');
end;

procedure TfrmReportDesignerDemo.mnuCopyClick(Sender: TObject);
begin
  FReportDesigner.CopySelection;
  UpdateStatusBar;
end;

procedure TfrmReportDesignerDemo.mnuPasteClick(Sender: TObject);
begin
  FReportDesigner.PasteSelection;
  UpdateStatusBar;
end;

{ ================= Alignment Menu ================= }

procedure TfrmReportDesignerDemo.mnuAlignLeftClick(Sender: TObject);
begin
  FReportDesigner.AlignLeft;
end;

procedure TfrmReportDesignerDemo.mnuAlignRightClick(Sender: TObject);
begin
  FReportDesigner.AlignRight;
end;

procedure TfrmReportDesignerDemo.mnuAlignTopClick(Sender: TObject);
begin
  FReportDesigner.AlignTop;
end;

procedure TfrmReportDesignerDemo.mnuAlignBottomClick(Sender: TObject);
begin
  FReportDesigner.AlignBottom;
end;

procedure TfrmReportDesignerDemo.mnuSameWidthClick(Sender: TObject);
begin
  FReportDesigner.SameWidth;
end;

procedure TfrmReportDesignerDemo.mnuSameHeightClick(Sender: TObject);
begin
  FReportDesigner.SameHeight;
end;

procedure TfrmReportDesignerDemo.mnuDistributeHClick(Sender: TObject);
begin
  FReportDesigner.DistributeH;
end;

procedure TfrmReportDesignerDemo.mnuDistributeVClick(Sender: TObject);
begin
  FReportDesigner.DistributeV;
end;

{ ================= Report Menu ================= }

procedure TfrmReportDesignerDemo.mnuPreviewClick(Sender: TObject);
var
  PreviewForm: TForm;
  Preview: TVittixReportPreview;
  Renderer: TReportRenderer;
  Toolbar: TToolBar;
  btnFirst, btnPrev, btnNext, btnLast: TToolButton;
  lblPage: TLabel;
begin
  // Create preview form
  PreviewForm := TForm.Create(Self);
  try
    PreviewForm.Caption := 'Report Preview';
    PreviewForm.Width := 800;
    PreviewForm.Height := 600;
    PreviewForm.Position := poScreenCenter;
    
    // Create toolbar
    Toolbar := TToolBar.Create(PreviewForm);
    Toolbar.Parent := PreviewForm;
    Toolbar.Align := alTop;
    Toolbar.ShowCaptions := True;
    
    btnFirst := TToolButton.Create(Toolbar);
    btnFirst.Parent := Toolbar;
    btnFirst.Caption := 'First';
    
    btnPrev := TToolButton.Create(Toolbar);
    btnPrev.Parent := Toolbar;
    btnPrev.Caption := 'Previous';
    
    btnNext := TToolButton.Create(Toolbar);
    btnNext.Parent := Toolbar;
    btnNext.Caption := 'Next';
    
    btnLast := TToolButton.Create(Toolbar);
    btnLast.Parent := Toolbar;
    btnLast.Caption := 'Last';
    
    lblPage := TLabel.Create(Toolbar);
    lblPage.Parent := Toolbar;
    lblPage.Left := 200;
    lblPage.Top := 8;
    lblPage.Caption := 'Page 1 of 1';
    
    // Create preview control
    Preview := TVittixReportPreview.Create(PreviewForm);
    Preview.Parent := PreviewForm;
    Preview.Align := alClient;
    Preview.ZoomPercent := 100;
    
    // Generate report
    Renderer := TReportRenderer.Create;
    try
      // The Render method handles engine creation, preparation, and page rendering
      Renderer.Render(FReportDesigner.Report, ClientDataSet1);
      
      Preview.LoadFromRenderer(Renderer);
      
      // Setup button events
      FPreviewControl := Preview;
      FPageLabel := lblPage;

      btnFirst.OnClick := PreviewBtnFirstClick;
      btnPrev.OnClick := PreviewBtnPrevClick;
      btnNext.OnClick := PreviewBtnNextClick;
      btnLast.OnClick := PreviewBtnLastClick;
      
      lblPage.Caption := Format('Page %d of %d', [Preview.PageIndex + 1, Preview.PageCount]);
      
      PreviewForm.ShowModal;

      // Clean up fields
      FPreviewControl := nil;
      FPageLabel := nil;
    finally
      Renderer.Free;
    end;
  finally
    PreviewForm.Free;
  end;
end;

procedure TfrmReportDesignerDemo.mnuExportPDFClick(Sender: TObject);
var
  Engine: TReportEngine;
begin
  if SaveDialog2.Execute then
  begin
    Engine := TReportEngine.Create(FReportDesigner.Report, ClientDataSet1);
    try
      Engine.Prepare;
      
      // TReportPDFExporter.ExportToPDF is a class procedure, no instance creation needed.
      TReportPDFExporter.ExportToPDF(Engine, SaveDialog2.FileName);
      ShowMessage('PDF exported successfully to: ' + SaveDialog2.FileName);
    finally
      Engine.Free;
    end;
  end;
end;

{ ================= Data Source Events ================= }

procedure TfrmReportDesignerDemo.cbDataSourceChange(Sender: TObject);
begin
  // In a real application, you would switch between different datasets
  FReportDesigner.DataSet := ClientDataSet1;
  UpdateStatusBar;
end;

procedure TfrmReportDesignerDemo.btnRefreshDataClick(Sender: TObject);
begin
  ClientDataSet1.Close;
  ClientDataSet1.Open;
  FReportDesigner.Invalidate;
  ShowMessage('Data refreshed!');
end;

{ ================= UI Updates ================= }

procedure TfrmReportDesignerDemo.UpdatePropertyDisplay;
var
  Obj: TReportObject;
  TextObj: TReportTextObject;
begin
  memoProperties.Clear;
  
  Obj := FReportDesigner.PrimarySelected;
  if Assigned(Obj) then
  begin
    memoProperties.Lines.Add('=== Selected Object ===');
    memoProperties.Lines.Add('Type: ' + Obj.ClassName);
    memoProperties.Lines.Add('Name: ' + Obj.Name);
    memoProperties.Lines.Add(Format('Position: (%d, %d)', [Obj.Bounds.Left, Obj.Bounds.Top]));
    memoProperties.Lines.Add(Format('Size: %d x %d', [Obj.Bounds.Width, Obj.Bounds.Height]));
    
    if Obj is TReportTextObject then
    begin
      TextObj := TReportTextObject(Obj);
      memoProperties.Lines.Add('');
      memoProperties.Lines.Add('--- Text Properties ---');
      memoProperties.Lines.Add('Text: ' + TextObj.Text);
      memoProperties.Lines.Add('DataField: ' + TextObj.DataField);
      memoProperties.Lines.Add('Expression: ' + TextObj.Expression);
      memoProperties.Lines.Add('Font: ' + TextObj.Font.Name + ', ' + IntToStr(TextObj.Font.Size) + 'pt');
    end;
    
    if Obj is TReportBand then
    begin
      memoProperties.Lines.Add('');
      memoProperties.Lines.Add('--- Band Properties ---');
      memoProperties.Lines.Add('BandType: ' + TValue.From(TReportBand(Obj).BandType).ToString);
      memoProperties.Lines.Add('Height: ' + IntToStr(TReportBand(Obj).Height));
    end;
  end
  else
  begin
    memoProperties.Lines.Add('No object selected');
    memoProperties.Lines.Add('');
    memoProperties.Lines.Add('Click on an object to select it');
    memoProperties.Lines.Add('or choose a tool from the toolbox');
    memoProperties.Lines.Add('and click on the designer to add it.');
  end;
end;

procedure TfrmReportDesignerDemo.UpdateStatusBar;
begin
  StatusBar1.Panels[0].Text := Format('Objects: %d', [FReportDesigner.Report.Objects.Count]);
  
  if Assigned(FReportDesigner.PrimarySelected) then
    StatusBar1.Panels[1].Text := 'Selected: ' + FReportDesigner.PrimarySelected.ClassName
  else
    StatusBar1.Panels[1].Text := 'Ready';
    
  if ClientDataSet1.Active then
    StatusBar1.Panels[2].Text := Format('Records: %d', [ClientDataSet1.RecordCount])
  else
    StatusBar1.Panels[2].Text := 'No data';
end;

{ ================= Preview Form Events ================= }

procedure TfrmReportDesignerDemo.PreviewBtnFirstClick(Sender: TObject);
begin
  if Assigned(FPreviewControl) and Assigned(FPageLabel) then
  begin
    FPreviewControl.FirstPage;
    FPageLabel.Caption := Format('Page %d of %d', [FPreviewControl.PageIndex + 1, FPreviewControl.PageCount]);
  end;
end;

procedure TfrmReportDesignerDemo.PreviewBtnPrevClick(Sender: TObject);
begin
  if Assigned(FPreviewControl) and Assigned(FPageLabel) then
  begin
    FPreviewControl.PrevPage;
    FPageLabel.Caption := Format('Page %d of %d', [FPreviewControl.PageIndex + 1, FPreviewControl.PageCount]);
  end;
end;

procedure TfrmReportDesignerDemo.PreviewBtnNextClick(Sender: TObject);
begin
  if Assigned(FPreviewControl) and Assigned(FPageLabel) then
  begin
    FPreviewControl.NextPage;
    FPageLabel.Caption := Format('Page %d of %d', [FPreviewControl.PageIndex + 1, FPreviewControl.PageCount]);
  end;
end;

procedure TfrmReportDesignerDemo.PreviewBtnLastClick(Sender: TObject);
begin
  if Assigned(FPreviewControl) and Assigned(FPageLabel) then
  begin
    FPreviewControl.LastPage;
    FPageLabel.Caption := Format('Page %d of %d', [FPreviewControl.PageIndex + 1, FPreviewControl.PageCount]);
  end;
end;

initialization
  RegisterClass(TImageList);

end.
