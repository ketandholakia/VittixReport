unit Frm.DemoMain;

interface

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.VCLUI.Wait,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.DApt,
  Vittix.Report.Component,
  Vittix.Report.Model,
  Vittix.Report.Serializer;

type
  TReportDemoDef = record
    Category: string;
    Title: string;
    Key: string;
    Description: string;
    ReportFile: string;
    MainSQL: string;
  end;

  TfrmDemoMain = class(TForm)
    pnlLeft: TPanel;
    tvSamples: TTreeView;
    pnlRight: TPanel;
    lblTitle: TLabel;
    lblReportFileCaption: TLabel;
    lblReportFile: TLabel;
    mmoDescription: TMemo;
    pnlButtons: TPanel;
    btnDesign: TButton;
    btnPreview: TButton;
    btnOpenFolder: TButton;
    StatusBar1: TStatusBar;
    Splitter1: TSplitter;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tvSamplesChange(Sender: TObject; Node: TTreeNode);
    procedure btnDesignClick(Sender: TObject);
    procedure btnPreviewClick(Sender: TObject);
    procedure btnOpenFolderClick(Sender: TObject);
  private
    FConn: TFDConnection;
    FMainQuery: TFDQuery;
    FMainSource: TDataSource;
    FReport: TVittixReport;
    FDemos: TList<TReportDemoDef>;

    procedure InitDatabase;
    function DbFilePath: string;
    function VrtFolderPath: string;
    procedure BuildDemoCatalog;
    procedure PopulateTree;
    function SelectedDemo(out ADemo: TReportDemoDef): Boolean;
    function DemoReportPath(const ADemo: TReportDemoDef): string;
    procedure LoadDemoInfo(const ADemo: TReportDemoDef);
    procedure PrepareDataForDemo(const ADemo: TReportDemoDef);
    procedure EnsureReportFileExists(const ADemo: TReportDemoDef);
    function FindDesignerExe: string;
    function LaunchAndWait(const ACmdLine: string): Boolean;
  end;

var
  frmDemoMain: TfrmDemoMain;

implementation

{$R *.dfm}

procedure TfrmDemoMain.FormCreate(Sender: TObject);
begin
  FDemos := TList<TReportDemoDef>.Create;
  InitDatabase;
  BuildDemoCatalog;
  PopulateTree;
  StatusBar1.SimpleText := 'Ready';
end;

procedure TfrmDemoMain.FormDestroy(Sender: TObject);
begin
  FDemos.Free;
end;

procedure TfrmDemoMain.InitDatabase;
var
  DBPath: string;
begin
  DBPath := DbFilePath;
  if not TFile.Exists(DBPath) then
    raise Exception.CreateFmt('Demo database not found: %s', [DBPath]);

  FConn := TFDConnection.Create(Self);
  FConn.LoginPrompt := False;
  FConn.Params.Clear;
  FConn.Params.Values['DriverID'] := 'SQLite';
  FConn.Params.Values['Database'] := DBPath;
  FConn.Connected := True;

  FMainQuery := TFDQuery.Create(Self);
  FMainQuery.Connection := FConn;

  FMainSource := TDataSource.Create(Self);
  FMainSource.DataSet := FMainQuery;

  FReport := TVittixReport.Create(Self);
  FReport.DataSource := FMainSource;
end;

function TfrmDemoMain.DbFilePath: string;
const
  REL_CANDIDATES: array[0..3] of string = (
    '..\..\db\vittixreportdemodb.db',
    '..\db\vittixreportdemodb.db',
    'db\vittixreportdemodb.db',
    '..\..\..\demo\db\vittixreportdemodb.db'
  );
var
  BaseDir: string;
  Candidate: string;
  Rel: string;
begin
  BaseDir := ExtractFilePath(ParamStr(0));
  for Rel in REL_CANDIDATES do
  begin
    Candidate := TPath.GetFullPath(TPath.Combine(BaseDir, Rel));
    if TFile.Exists(Candidate) then
      Exit(Candidate);
  end;
  Result := TPath.GetFullPath(TPath.Combine(BaseDir, REL_CANDIDATES[0]));
end;

function TfrmDemoMain.VrtFolderPath: string;
begin
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\vrt'));
  if not TDirectory.Exists(Result) then
    ForceDirectories(Result);
end;

procedure TfrmDemoMain.BuildDemoCatalog;
  procedure AddDemo(const ACategory, ATitle, AKey, ADescription, ASQL: string);
  var
    D: TReportDemoDef;
  begin
    D.Category := ACategory;
    D.Title := ATitle;
    D.Key := AKey;
    D.Description := ADescription;
    D.ReportFile := AKey + '.vrt';
    D.MainSQL := ASQL;
    FDemos.Add(D);
  end;
begin
  FDemos.Clear;

  AddDemo('Basic reports', 'Simple list', 'simple_list',
    'Simple table listing customers.',
    'select id, name, city, phone, email from customers order by name');

  AddDemo('Basic reports', 'Simple group', 'simple_group',
    'Grouped customer list by city.',
    'select city, name, phone, email from customers order by city, name');

  AddDemo('Basic reports', 'Nested group', 'nested_group',
    'Nested groups: city -> customer -> invoice.',
    'select c.city, c.name as customer_name, si.invoice_no, si.invoice_date, si.total ' +
    'from sales_invoice si join customers c on c.id = si.customer_id ' +
    'order by c.city, c.name, si.invoice_date');

  AddDemo('Basic reports', 'Master-Detail-SubDetail', 'master_detail_subdetail',
    'Invoice rows with detail lines and item category to emulate multi-level details.',
    'select si.id as invoice_id, si.invoice_no, si.invoice_date, c.name as customer_name, ' +
    'it.name as item_name, cat.name as category_name, sii.qty, sii.rate, sii.amount ' +
    'from sales_invoice si ' +
    'join customers c on c.id = si.customer_id ' +
    'join sales_invoice_items sii on sii.invoice_id = si.id ' +
    'join items it on it.id = sii.item_id ' +
    'left join categories cat on cat.id = it.category_id ' +
    'order by si.id, sii.id');

  AddDemo('Basic reports', 'Master-Detail-Detail', 'master_detail_detail',
    'Invoice master with item detail lines.',
    'select si.id as invoice_id, si.invoice_no, si.invoice_date, c.name as customer_name, ' +
    'it.name as item_name, sii.qty, sii.rate, sii.amount, si.total as invoice_total ' +
    'from sales_invoice si ' +
    'join customers c on c.id = si.customer_id ' +
    'join sales_invoice_items sii on sii.invoice_id = si.id ' +
    'join items it on it.id = sii.item_id ' +
    'order by si.id, sii.id');

  AddDemo('Basic reports', 'Multi-column list', 'multi_column_list',
    'Good for testing multi-column layout behavior with short rows.',
    'select id, name, price from items order by name');

  AddDemo('Basic reports', 'Multi-column band', 'multi_column_band',
    'Same dataset as multi-column list; design can use custom column-band logic.',
    'select id, name, price from items order by id');

  AddDemo('Basic reports', 'Memos and pictures', 'memos_pictures',
    'Includes long memo-like text fields for wrap, rich text, and image placeholders.',
    'select i.id, i.name, c.name as category_name, i.price, ' +
    '(i.name || '' is a demo item from '' || c.name || '' category. '') as notes, ' +
    '(''[image:'' || lower(replace(i.name, '' '', ''_'')) || ''.png]'') as picture_hint ' +
    'from items i left join categories c on c.id = i.category_id order by i.id');

  AddDemo('Basic reports', 'Split bands', 'split_bands',
    'Data suited for can-grow/can-shrink and split-across-pages testing.',
    'select si.invoice_no, c.name as customer_name, si.invoice_date, si.total, ' +
    '(''Payment terms and delivery notes for '' || c.name || ''. '') as memo_text ' +
    'from sales_invoice si join customers c on c.id = si.customer_id order by si.id');

  AddDemo('Basic reports', 'Subreports', 'subreports',
    'Customer sales summary, useful as a subreport source.',
    'select c.id as customer_id, c.name as customer_name, c.city, ' +
    'count(si.id) as invoice_count, ifnull(sum(si.total), 0) as sales_total ' +
    'from customers c left join sales_invoice si on si.customer_id = c.id ' +
    'group by c.id, c.name, c.city order by c.name');

  AddDemo('Basic reports', 'Side-by-side subreports', 'side_by_side_subreports',
    'Top customers and top suppliers style data in one rowset for side-by-side sections.',
    'select c.id as seq, c.name as customer_name, ifnull(cs.sales_total,0) as sales_total, ' +
    's.name as supplier_name, ifnull(ps.purchase_total,0) as purchase_total ' +
    'from customers c ' +
    'left join (select customer_id, sum(total) as sales_total from sales_invoice group by customer_id) cs ' +
    'on cs.customer_id = c.id ' +
    'left join suppliers s on s.id = c.id ' +
    'left join (select supplier_id, sum(total) as purchase_total from purchase_invoice group by supplier_id) ps ' +
    'on ps.supplier_id = s.id ' +
    'order by c.id');

  AddDemo('Basic reports', 'Report with title page', 'title_page_report',
    'Summary data for a report that starts with a dedicated title page.',
    'select ''Vittix Sales Overview'' as report_title, ' +
    'count(*) as invoice_count, ifnull(sum(total),0) as grand_total, ' +
    'min(invoice_date) as from_date, max(invoice_date) as to_date ' +
    'from sales_invoice');

  AddDemo('Basic reports', 'Interactive report', 'interactive_report',
    'Dataset for interactive expressions, drill links, and conditional formatting.',
    'select si.id, si.invoice_no, si.invoice_date, c.name as customer_name, si.total, ' +
    'case when si.total >= 10000 then ''High'' when si.total >= 5000 then ''Medium'' else ''Low'' end as amount_band ' +
    'from sales_invoice si join customers c on c.id = si.customer_id order by si.invoice_date desc');

  AddDemo('Basic reports', 'Charts', 'charts',
    'Monthly totals for bar/line/pie chart demonstrations.',
    'select strftime(''%Y-%m'', invoice_date) as month_key, count(*) as invoice_count, sum(total) as month_total ' +
    'from sales_invoice group by strftime(''%Y-%m'', invoice_date) order by month_key');

  AddDemo('Cross Tabs', 'No Rows', 'xtab_no_rows',
    'Cross-tab with measures only.',
    'select ''Sales Total'' as metric, ifnull(sum(total),0) as value from sales_invoice');

  AddDemo('Cross Tabs', 'No columns', 'xtab_no_columns',
    'Cross-tab with rows only and one value bucket.',
    'select c.city, ifnull(sum(si.total),0) as value ' +
    'from customers c left join sales_invoice si on si.customer_id = c.id ' +
    'group by c.city order by c.city');

  AddDemo('Cross Tabs', 'One row, one column', 'xtab_1r_1c',
    'One row dim (city) and one column dim (month).',
    'select c.city, strftime(''%Y-%m'', si.invoice_date) as month_key, sum(si.total) as value ' +
    'from sales_invoice si join customers c on c.id = si.customer_id ' +
    'group by c.city, strftime(''%Y-%m'', si.invoice_date) ' +
    'order by c.city, month_key');

  AddDemo('Cross Tabs', 'Two rows, one column', 'xtab_2r_1c',
    'Two row dims (city, customer) and one column dim (month).',
    'select c.city, c.name as customer_name, strftime(''%Y-%m'', si.invoice_date) as month_key, sum(si.total) as value ' +
    'from sales_invoice si join customers c on c.id = si.customer_id ' +
    'group by c.city, c.name, strftime(''%Y-%m'', si.invoice_date) ' +
    'order by c.city, c.name, month_key');

  AddDemo('Cross Tabs', 'Two columns, one row', 'xtab_2c_1r',
    'One row dim (customer) and two column dims (year, month).',
    'select c.name as customer_name, strftime(''%Y'', si.invoice_date) as year_key, ' +
    'strftime(''%m'', si.invoice_date) as month_key, sum(si.total) as value ' +
    'from sales_invoice si join customers c on c.id = si.customer_id ' +
    'group by c.name, strftime(''%Y'', si.invoice_date), strftime(''%m'', si.invoice_date) ' +
    'order by c.name, year_key, month_key');

  AddDemo('Cross Tabs', 'Two cell values', 'xtab_2values',
    'Two measures in one dataset: count and total.',
    'select c.city, strftime(''%Y-%m'', si.invoice_date) as month_key, ' +
    'count(*) as invoice_count, sum(si.total) as sales_total ' +
    'from sales_invoice si join customers c on c.id = si.customer_id ' +
    'group by c.city, strftime(''%Y-%m'', si.invoice_date) ' +
    'order by c.city, month_key');
end;

procedure TfrmDemoMain.PopulateTree;
var
  CatNodes: TDictionary<string, TTreeNode>;
  i: Integer;
  D: TReportDemoDef;
  CatNode, ItemNode: TTreeNode;
  FirstRoot, FirstChild: TTreeNode;
begin
  tvSamples.Items.BeginUpdate;
  CatNodes := TDictionary<string, TTreeNode>.Create;
  try
    tvSamples.Items.Clear;
    for i := 0 to FDemos.Count - 1 do
    begin
      D := FDemos[i];
      if not CatNodes.TryGetValue(D.Category, CatNode) then
      begin
        CatNode := tvSamples.Items.Add(nil, D.Category);
        CatNode.ImageIndex := 0;
        CatNode.SelectedIndex := 0;
        CatNodes.Add(D.Category, CatNode);
      end;
      ItemNode := tvSamples.Items.AddChild(CatNode, D.Title);
      ItemNode.ImageIndex := 1;
      ItemNode.SelectedIndex := 1;
      ItemNode.Data := Pointer(NativeInt(i) + 1);
    end;
    tvSamples.FullExpand;
    if tvSamples.Items.Count > 0 then
    begin
      FirstRoot := tvSamples.Items.GetFirstNode;
      if Assigned(FirstRoot) then
      begin
        FirstChild := FirstRoot.GetFirstChild;
        if Assigned(FirstChild) then
          tvSamples.Selected := FirstChild;
      end;
    end;
  finally
    CatNodes.Free;
    tvSamples.Items.EndUpdate;
  end;
end;

function TfrmDemoMain.SelectedDemo(out ADemo: TReportDemoDef): Boolean;
var
  Node: TTreeNode;
  Idx: NativeInt;
begin
  Result := False;
  Node := tvSamples.Selected;
  if not Assigned(Node) or not Assigned(Node.Parent) then
    Exit;
  if Node.Data = nil then
    Exit;

  Idx := NativeInt(Node.Data) - 1;
  if (Idx < 0) or (Idx >= FDemos.Count) then
    Exit;

  ADemo := FDemos[Idx];
  Result := True;
end;

function TfrmDemoMain.DemoReportPath(const ADemo: TReportDemoDef): string;
begin
  Result := TPath.Combine(VrtFolderPath, ADemo.ReportFile);
end;

procedure TfrmDemoMain.LoadDemoInfo(const ADemo: TReportDemoDef);
var
  Path: string;
begin
  lblTitle.Caption := ADemo.Title;
  mmoDescription.Lines.Text := ADemo.Description + sLineBreak + sLineBreak +
    'SQL preview source:' + sLineBreak + ADemo.MainSQL;

  Path := DemoReportPath(ADemo);
  lblReportFile.Caption := Path;

  if TFile.Exists(Path) then
    StatusBar1.SimpleText := 'Report file found.'
  else
    StatusBar1.SimpleText := 'Report file not found yet. Click Design to create it.';
end;

procedure TfrmDemoMain.PrepareDataForDemo(const ADemo: TReportDemoDef);
begin
  FMainQuery.Close;
  FMainQuery.SQL.Text := ADemo.MainSQL;
  FMainQuery.Open;
end;

procedure TfrmDemoMain.EnsureReportFileExists(const ADemo: TReportDemoDef);
var
  Path: string;
  R: TReportModel;
begin
  Path := DemoReportPath(ADemo);
  if TFile.Exists(Path) then
    Exit;

  ForceDirectories(ExtractFilePath(Path));
  R := TReportModel.Create;
  try
    R.Title := ADemo.Title;
    R.Author := 'VittixReport Demo';
    R.Description := ADemo.Description;
    TReportSerializer.SaveToFile(R, Path);
  finally
    R.Free;
  end;
end;

function TfrmDemoMain.FindDesignerExe: string;
const
  REL_CANDIDATES: array[0..6] of string = (
    'VittixDesigner.exe',
    '..\..\..\vittixdesigner\VittixDesigner.exe',
    '..\..\..\vittixdesigner\Win32\Debug\VittixDesigner.exe',
    '..\..\..\vittixdesigner\Win32\Release\VittixDesigner.exe',
    '..\..\vittixdesigner\VittixDesigner.exe',
    '..\vittixdesigner\VittixDesigner.exe',
    '..\..\..\..\vittixdesigner\VittixDesigner.exe'
  );
var
  BaseDir, Candidate, Rel: string;
begin
  BaseDir := ExtractFilePath(ParamStr(0));
  for Rel in REL_CANDIDATES do
  begin
    Candidate := TPath.GetFullPath(TPath.Combine(BaseDir, Rel));
    if TFile.Exists(Candidate) then
      Exit(Candidate);
  end;
  Result := '';
end;

function TfrmDemoMain.LaunchAndWait(const ACmdLine: string): Boolean;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd: string;
begin
  Result := False;
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_SHOWNORMAL;

  Cmd := ACmdLine;
  UniqueString(Cmd);
  if not CreateProcess(nil, PChar(Cmd), nil, nil, False, 0, nil, nil, SI, PI) then
    Exit;

  try
    while WaitForSingleObject(PI.hProcess, 50) = WAIT_TIMEOUT do
      Application.ProcessMessages;
    Result := True;
  finally
    CloseHandle(PI.hProcess);
    CloseHandle(PI.hThread);
  end;
end;

procedure TfrmDemoMain.tvSamplesChange(Sender: TObject; Node: TTreeNode);
var
  D: TReportDemoDef;
begin
  if SelectedDemo(D) then
  begin
    LoadDemoInfo(D);
    btnDesign.Enabled := True;
    btnPreview.Enabled := True;
    btnOpenFolder.Enabled := True;
  end
  else
  begin
    lblTitle.Caption := 'Select a report sample';
    lblReportFile.Caption := '';
    mmoDescription.Clear;
    btnDesign.Enabled := False;
    btnPreview.Enabled := False;
    btnOpenFolder.Enabled := False;
  end;
end;

procedure TfrmDemoMain.btnDesignClick(Sender: TObject);
var
  D: TReportDemoDef;
  DesignerExe: string;
  InFile: string;
  OutFile: string;
begin
  if not SelectedDemo(D) then
    Exit;

  EnsureReportFileExists(D);
  DesignerExe := FindDesignerExe;
  if DesignerExe = '' then
    raise Exception.Create('VittixDesigner.exe not found. Build it first.');

  InFile := DemoReportPath(D);
  OutFile := TPath.Combine(TPath.GetTempPath,
    Format('VittixRptDemo_out_%d.vrt', [GetTickCount]));

  if TFile.Exists(OutFile) then
    TFile.Delete(OutFile);

  LaunchAndWait(Format('"%s" "%s" "%s"', [DesignerExe, InFile, OutFile]));

  if TFile.Exists(OutFile) then
  begin
    TFile.Copy(OutFile, InFile, True);
    TFile.Delete(OutFile);
    StatusBar1.SimpleText := 'Report updated: ' + ExtractFileName(InFile);
  end
  else
    StatusBar1.SimpleText := 'Designer closed without saving.';

  lblReportFile.Caption := InFile;
end;

procedure TfrmDemoMain.btnPreviewClick(Sender: TObject);
var
  D: TReportDemoDef;
  Path: string;
begin
  if not SelectedDemo(D) then
    Exit;

  EnsureReportFileExists(D);
  Path := DemoReportPath(D);

  PrepareDataForDemo(D);
  FReport.LoadFromFile(Path);
  FReport.Execute;
end;

procedure TfrmDemoMain.btnOpenFolderClick(Sender: TObject);
var
  D: TReportDemoDef;
  Path: string;
begin
  if not SelectedDemo(D) then
    Exit;

  EnsureReportFileExists(D);
  Path := DemoReportPath(D);

  ShellExecute(Handle, 'open', PChar('explorer.exe'),
    PChar('/select,"' + Path + '"'), nil, SW_SHOWNORMAL);
end;

end.
