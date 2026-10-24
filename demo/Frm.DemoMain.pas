unit Frm.DemoMain;

// =============================================================================
//  VittixReport Demo  –  Northwind SQLite edition
//  Database : northwind.db  (jpwhite3/northwind-SQLite3)
//  Place the DB at:  <project>\demo\db\northwind.db
//  Report files (.vrt) are stored under: <project>\demo\vrt\
// =============================================================================

interface

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.TypInfo,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.FileCtrl,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Data.DB,
  System.IniFiles,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.VCLUI.Wait,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.DApt,
  Vittix.Report.Component,
  Vittix.Report.UserDataSet,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Export.Commands,
  Vittix.Report.Renderer,
  Vittix.Report.Preview,
  Vittix.Report.Serializer;

type
  TReportDemoDef = record
    Category    : string;
    Title       : string;
    Key         : string;
    Description : string;
    ReportFile  : string;
    MainSQL     : string;
  end;

  TfrmDemoMain = class(TForm)
    pnlLeft     : TPanel;
    tvSamples   : TTreeView;
    pnlRight    : TPanel;
    lblTitle    : TLabel;
    lblReportFileCaption : TLabel;
    lblReportFile        : TLabel;
    mmoDescription : TMemo;
    pnlButtons  : TPanel;
    btnDesign   : TButton;
    btnPreview  : TButton;
    btnOpenFolder : TButton;
    btnVrtFolder  : TButton;
    StatusBar1  : TStatusBar;
    Splitter1   : TSplitter;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tvSamplesChange(Sender: TObject; Node: TTreeNode);
    procedure btnDesignClick(Sender: TObject);
    procedure btnPreviewClick(Sender: TObject);
    procedure btnOpenFolderClick(Sender: TObject);
    procedure btnVrtFolderClick(Sender: TObject);
  public
    procedure ValidateAcceptanceFixtureForTest;
    function AcceptanceValidationEvidence: string;
  private
    FConn            : TFDConnection;
    FMainQuery       : TFDQuery;
    FMoneyAcceptanceDataSet: TFDMemTable;
    FUserDataSet     : TVittixUserDataSet;   // FastReport-style bridge
    FMainDataRegistered: Boolean;
    FAcceptanceValidationEvidence: string;
    FMasterDetailRenderCount: Integer;
    FMasterDetailRenderEvidence: string;
    FVrtRootPath: string;
    FVrtRootInitialized: Boolean;
    FReport          : TVittixReport;
    FSQLiteDriverLink: TFDPhysSQLiteDriverLink;
    FDemos           : TList<TReportDemoDef>;

    procedure InitDatabase;
    function  DbFilePath: string;
    function  VrtFolderPath: string;
    function  DemoSettingsFilePath: string;
    procedure SaveVrtFolderPath(const APath: string);
    function  ReportTemplateErrorText(const ADemo: TReportDemoDef): string;
    procedure BuildDemoCatalog;
    procedure PopulateTree;
    function  SelectedDemo(out ADemo: TReportDemoDef): Boolean;
    function  DemoReportPath(const ADemo: TReportDemoDef): string;
    procedure LoadDemoInfo(const ADemo: TReportDemoDef);
    procedure PrepareDataForDemo(const ADemo: TReportDemoDef);
    procedure ValidateMoneyAcceptanceBinding;
    procedure RenderMoneyAcceptance(AShowPreview: Boolean);
    procedure PopulateFieldNames(R: TReportModel; const ADemo: TReportDemoDef);
    procedure EnsureReportFileExists(const ADemo: TReportDemoDef);
    function  FindDesignerExe: string;
    function  LaunchAndWait(const ACmdLine: string): Boolean;
  end;

var
  frmDemoMain: TfrmDemoMain;

implementation

{$R *.dfm}

// ---------------------------------------------------------------------------
//  Form lifetime
// ---------------------------------------------------------------------------

procedure TfrmDemoMain.FormCreate(Sender: TObject);
begin
  FSQLiteDriverLink := TFDPhysSQLiteDriverLink.Create(Self);

  FDemos := TList<TReportDemoDef>.Create;
  InitDatabase;
  BuildDemoCatalog;
  PopulateTree;
  StatusBar1.SimpleText := 'Ready  –  Northwind database';
end;

procedure TfrmDemoMain.FormDestroy(Sender: TObject);
begin
  FDemos.Free;
  FSQLiteDriverLink.Free;
end;

// ---------------------------------------------------------------------------
//  Database
// ---------------------------------------------------------------------------

procedure TfrmDemoMain.InitDatabase;
var
  DBPath: string;
  RateDef: TFieldDef;
begin
  DBPath := DbFilePath;
  if not TFile.Exists(DBPath) then
    raise Exception.CreateFmt(
      'Northwind database not found: %s'           + sLineBreak +
      'Download northwind.db from:'                + sLineBreak +
      '  https://github.com/jpwhite3/northwind-SQLite3' + sLineBreak +
      'and copy it to that location.',
      [DBPath]);

  FConn := TFDConnection.Create(Self);
  FConn.LoginPrompt := False;
  FConn.Params.Clear;
  FConn.Params.Values['DriverID'] := 'SQLite';
  FConn.Params.Values['Database'] := DBPath;
  FConn.Connected := True;

  FMainQuery := TFDQuery.Create(Self);
  FMainQuery.Connection := FConn;

  // Dedicated acceptance fixture: keep Rate in an exact-decimal field rather
  // than sourcing it from SQLite's floating-point numeric representation.
  FMoneyAcceptanceDataSet := TFDMemTable.Create(Self);
  FMoneyAcceptanceDataSet.FieldDefs.Add('Qty', ftInteger);
  RateDef := FMoneyAcceptanceDataSet.FieldDefs.AddFieldDef;
  RateDef.Name := 'Rate';
  RateDef.DataType := ftFMTBCD;
  RateDef.Precision := 18;
  RateDef.Size := 3;

  // FastReport-style UserDataSet: wraps the query, registered with the report.
  // The engine resolves it by component Name (here 'MainData') or as primary.
  FUserDataSet         := TVittixUserDataSet.Create(Self);
  FUserDataSet.Name    := 'MainData';
  FUserDataSet.DataSet := FMainQuery;

  FReport := TVittixReport.Create(Self);
  FReport.RegisterUserDataSet(FUserDataSet);
  FMainDataRegistered := True;
end;

function TfrmDemoMain.DbFilePath: string;
const
  // The DB is distributed as  northwind.db  (lowercase)
  DB_NAME = 'northwind.db';
  REL_CANDIDATES: array[0..3] of string = (
    '..\..\db\' + DB_NAME,
    '..\db\'    + DB_NAME,
    'db\'       + DB_NAME,
    '..\..\..\demo\db\' + DB_NAME
  );
var
  BaseDir, Candidate, Rel, ConfiguredPath: string;
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(DemoSettingsFilePath);
  try
    ConfiguredPath := Trim(Ini.ReadString('Database', 'NorthwindPath', ''));
  finally
    Ini.Free;
  end;
  if ConfiguredPath <> '' then
  begin
    Result := TPath.GetFullPath(ConfiguredPath);
    if not TFile.Exists(Result) then
      raise EFileNotFoundException.CreateFmt(
        'Configured Northwind database not found:%s%s%s%s' +
        'Update [Database] NorthwindPath in %s.',
        [sLineBreak, Result, sLineBreak, sLineBreak, DemoSettingsFilePath]);
    Exit;
  end;

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
const
  RELATIVE_CANDIDATES: array[0..2] of string = (
    'vrt',
    '..\..\vrt',
    '..\..\..\demo\vrt'
  );
var
  Ini: TIniFile;
  ConfiguredPath, Candidate, ExeDir, Rel: string;
begin
  if FVrtRootInitialized then
    Exit(FVrtRootPath);

  FVrtRootInitialized := True;
  Ini := TIniFile.Create(DemoSettingsFilePath);
  try
    ConfiguredPath := Trim(Ini.ReadString('Reports', 'VrtPath', ''));
  finally
    Ini.Free;
  end;

  if ConfiguredPath <> '' then
  begin
    // An explicit but invalid setting is intentionally preserved as the
    // selected root; do not hide the problem by silently using another folder.
    FVrtRootPath := TPath.GetFullPath(ConfiguredPath);
    Exit(FVrtRootPath);
  end;

  ExeDir := ExtractFilePath(ParamStr(0));
  for Rel in RELATIVE_CANDIDATES do
  begin
    Candidate := TPath.GetFullPath(TPath.Combine(ExeDir, Rel));
    if TDirectory.Exists(Candidate) then
    begin
      FVrtRootPath := Candidate;
      Exit(FVrtRootPath);
    end;
  end;

  // Return the preferred candidate so any missing-template message names a
  // concrete path. Do not create the directory or an empty report in it.
  FVrtRootPath := TPath.GetFullPath(TPath.Combine(ExeDir, 'vrt'));
  Result := FVrtRootPath;
end;

function TfrmDemoMain.DemoSettingsFilePath: string;
var
  AppData: string;
begin
  AppData := GetEnvironmentVariable('APPDATA');
  if AppData = '' then
    AppData := TPath.GetHomePath;
  Result := TPath.Combine(AppData, 'VittixReportDemo\settings.ini');
end;

procedure TfrmDemoMain.SaveVrtFolderPath(const APath: string);
var
  IniPath: string;
  Ini: TIniFile;
begin
  IniPath := DemoSettingsFilePath;
  TDirectory.CreateDirectory(ExtractFilePath(IniPath));
  Ini := TIniFile.Create(IniPath);
  try
    Ini.WriteString('Reports', 'VrtPath', TPath.GetFullPath(APath));
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
  FVrtRootPath := TPath.GetFullPath(APath);
  FVrtRootInitialized := True;
end;

function TfrmDemoMain.ReportTemplateErrorText(
  const ADemo: TReportDemoDef): string;
var
  Root, Path: string;
begin
  Root := VrtFolderPath;
  Path := TPath.Combine(Root, ADemo.ReportFile);
  Result := Format(
    'Report template not found:' + sLineBreak + sLineBreak +
    '%s' + sLineBreak + sLineBreak +
    'Current template folder:' + sLineBreak +
    '%s' + sLineBreak + sLineBreak +
    'Use the Template Folder... button to select the correct folder.',
    [Path, Root]);
end;

// ---------------------------------------------------------------------------
//  Demo catalog  –  ALL queries use Northwind tables / columns
//
//  jpwhite3/northwind-SQLite3 exact schema:
//    Customers    : CustomerID(TEXT), CompanyName, ContactName, ContactTitle,
//                   Address, City, Region, PostalCode, Country, Phone, Fax
//    Orders       : OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate,
//                   ShippedDate, ShipVia, Freight, ShipName, ShipAddress,
//                   ShipCity, ShipRegion, ShipPostalCode, ShipCountry
//    OrderDetails : OrderID, ProductID, UnitPrice, Quantity, Discount
//                   (table name is "Order Details" with a space)
//    Products     : ProductID, ProductName, SupplierID, CategoryID,
//                   QuantityPerUnit, UnitPrice, UnitsInStock, UnitsOnOrder,
//                   ReorderLevel, Discontinued
//    Categories   : CategoryID, CategoryName, Description
//    Suppliers    : SupplierID, CompanyName, ContactName, ContactTitle,
//                   Address, City, Region, PostalCode, Country, Phone, Fax
//    Employees    : EmployeeID, LastName, FirstName, Title, TitleOfCourtesy,
//                   BirthDate, HireDate, Address, City, Region, PostalCode,
//                   Country, HomePhone, Extension, ReportsTo
//    Shippers     : ShipperID, CompanyName, Phone
// ---------------------------------------------------------------------------

procedure TfrmDemoMain.BuildDemoCatalog;

  procedure AddDemo(const ACategory, ATitle, AKey, ADescription, ASQL: string);
  var
    D: TReportDemoDef;
  begin
    D.Category   := ACategory;
    D.Title      := ATitle;
    D.Key        := AKey;
    D.Description:= ADescription;
    D.ReportFile := AKey + '.vrt';
    D.MainSQL    := ASQL;
    FDemos.Add(D);
  end;

begin
  FDemos.Clear;

  // ── Basic reports ─────────────────────────────────────────────────────────

  AddDemo('Basic reports', 'Simple list', 'simple_list',
    'Flat customer list ordered by company name.',
    'SELECT CustomerID, CompanyName, ContactName, City, Country, Phone ' +
    'FROM Customers ' +
    'ORDER BY CompanyName');

  AddDemo('Basic reports', 'Simple group', 'simple_group',
    'Customers grouped by country, then city.',
    'SELECT Country, City, CompanyName, ContactName, Phone ' +
    'FROM Customers ' +
    'ORDER BY Country, City, CompanyName');

  AddDemo('Basic reports', 'Nested group', 'nested_group',
    'Three-level nesting: Country → Customer → Order header.',
    'SELECT c.Country, c.CompanyName AS CustomerName, ' +
    '       o.OrderID, o.OrderDate, o.Freight, o.ShipCity ' +
    'FROM Customers c ' +
    'JOIN Orders o ON o.CustomerID = c.CustomerID ' +
    'ORDER BY c.Country, c.CompanyName, o.OrderDate');

  AddDemo('Basic reports', 'Master-Detail-SubDetail', 'master_detail_subdetail',
    'Order → line items → product category: three nested levels.',
    'SELECT o.OrderID, c.CompanyName AS CustomerName, o.OrderDate, ' +
    '       cat.CategoryName, p.ProductName, ' +
    '       od.UnitPrice, od.Quantity, od.Discount, ' +
    '       ROUND(od.UnitPrice * od.Quantity * (1 - od.Discount), 2) AS LineTotal ' +
    'FROM Orders o ' +
    'JOIN Customers c            ON c.CustomerID = o.CustomerID ' +
    'JOIN "Order Details" od     ON od.OrderID   = o.OrderID ' +
    'JOIN Products p             ON p.ProductID  = od.ProductID ' +
    'LEFT JOIN Categories cat    ON cat.CategoryID = p.CategoryID ' +
    'ORDER BY o.OrderID, cat.CategoryName, od.ProductID');

  AddDemo('Basic reports', 'Master-Detail-Detail', 'master_detail_detail',
    'Order master with each line item – classic invoice layout.',
    'SELECT o.OrderID, c.CompanyName AS CustomerName, ' +
    '       o.OrderDate, o.ShipCity, o.Freight, ' +
    '       p.ProductName, od.UnitPrice, od.Quantity, od.Discount, ' +
    '       ROUND(od.UnitPrice * od.Quantity * (1 - od.Discount), 2) AS LineTotal ' +
    'FROM Orders o ' +
    'JOIN Customers c        ON c.CustomerID = o.CustomerID ' +
    'JOIN "Order Details" od ON od.OrderID   = o.OrderID ' +
    'JOIN Products p         ON p.ProductID  = od.ProductID ' +
    'ORDER BY o.OrderID, od.ProductID');

  AddDemo('Basic reports', 'Multi-column list', 'multi_column_list',
    'Product catalogue – short rows for multi-column layout testing.',
    'SELECT p.ProductID, p.ProductName, cat.CategoryName, ' +
    '       p.UnitPrice, p.UnitsInStock, p.Discontinued ' +
    'FROM Products p ' +
    'LEFT JOIN Categories cat ON cat.CategoryID = p.CategoryID ' +
    'ORDER BY p.ProductName');

  AddDemo('Basic reports', 'Multi-column band', 'multi_column_band',
    'Products ordered by ID – for column-band design experiments.',
    'SELECT p.ProductID, p.ProductName, cat.CategoryName, p.UnitPrice ' +
    'FROM Products p ' +
    'LEFT JOIN Categories cat ON cat.CategoryID = p.CategoryID ' +
    'ORDER BY p.ProductID');

  AddDemo('Basic reports', 'Memos and pictures', 'memos_pictures',
    'Products with generated memo text and image-placeholder hints.',
    'SELECT p.ProductID, p.ProductName, cat.CategoryName, ' +
    '       s.CompanyName AS SupplierName, p.UnitPrice, p.QuantityPerUnit, ' +
    '       (p.ProductName || '' is supplied by '' || s.CompanyName || ' +
    '        '' in '' || cat.CategoryName || '' category. '' || ' +
    '        ''Unit price: $'' || CAST(p.UnitPrice AS TEXT) || ''.'') AS Notes, ' +
    '       (''[image:'' || LOWER(REPLACE(p.ProductName, '' '', ''_'')) || ''.png]'') AS PictureHint ' +
    'FROM Products p ' +
    'LEFT JOIN Categories cat ON cat.CategoryID = p.CategoryID ' +
    'LEFT JOIN Suppliers s    ON s.SupplierID   = p.SupplierID ' +
    'ORDER BY p.ProductID');

  AddDemo('Basic reports', 'Split bands', 'split_bands',
    'Orders with memo field – tests can-grow / can-shrink / split across pages.',
    'SELECT o.OrderID, c.CompanyName AS CustomerName, ' +
    '       o.OrderDate, o.ShippedDate, o.Freight, ' +
    '       sh.CompanyName AS ShipperName, ' +
    '       (''Ship to: '' || o.ShipName || '', '' || o.ShipCity || ' +
    '        '', '' || o.ShipCountry || ''. '' || ' +
    '        ''Freight: $'' || CAST(ROUND(o.Freight, 2) AS TEXT) || ''.'') AS MemoText ' +
    'FROM Orders o ' +
    'JOIN Customers c     ON c.CustomerID = o.CustomerID ' +
    'LEFT JOIN Shippers sh ON sh.ShipperID = o.ShipVia ' +
    'ORDER BY o.OrderID');

  AddDemo('Basic reports', 'Subreports', 'subreports',
    'Customer sales summary – typical source for an embedded subreport.',
    'SELECT c.CustomerID, c.CompanyName AS CustomerName, c.City, c.Country, ' +
    '       COUNT(o.OrderID) AS OrderCount, ' +
    '       ROUND(IFNULL(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 0), 2) AS SalesTotal ' +
    'FROM Customers c ' +
    'LEFT JOIN Orders o          ON o.CustomerID = c.CustomerID ' +
    'LEFT JOIN "Order Details" od ON od.OrderID  = o.OrderID ' +
    'GROUP BY c.CustomerID, c.CompanyName, c.City, c.Country ' +
    'ORDER BY c.CompanyName');

  AddDemo('Basic reports', 'Side-by-side subreports', 'side_by_side_subreports',
    'Top customers vs top suppliers – side-by-side panel layout source.',
    'SELECT cu.seq, cu.CustomerName, cu.SalesTotal, ' +
    '       su.SupplierName, su.ProductCount ' +
    'FROM ( ' +
    '  SELECT ROW_NUMBER() OVER (ORDER BY SalesTotal DESC) AS seq, ' +
    '         CustomerName, SalesTotal ' +
    '  FROM ( ' +
    '    SELECT c.CompanyName AS CustomerName, ' +
    '           ROUND(SUM(od.UnitPrice*od.Quantity*(1-od.Discount)),2) AS SalesTotal ' +
    '    FROM Customers c ' +
    '    JOIN Orders o            ON o.CustomerID = c.CustomerID ' +
    '    JOIN "Order Details" od  ON od.OrderID   = o.OrderID ' +
    '    GROUP BY c.CustomerID ' +
    '  ) ' +
    ') cu ' +
    'LEFT JOIN ( ' +
    '  SELECT ROW_NUMBER() OVER (ORDER BY ProductCount DESC) AS seq, ' +
    '         SupplierName, ProductCount ' +
    '  FROM ( ' +
    '    SELECT s.CompanyName AS SupplierName, COUNT(p.ProductID) AS ProductCount ' +
    '    FROM Suppliers s ' +
    '    JOIN Products p ON p.SupplierID = s.SupplierID ' +
    '    GROUP BY s.SupplierID ' +
    '  ) ' +
    ') su ON su.seq = cu.seq ' +
    'ORDER BY cu.seq');

  AddDemo('Basic reports', 'Report with title page', 'title_page_report',
    'One summary row for a report with a dedicated title page.',
    'SELECT ''Northwind Sales Overview'' AS ReportTitle, ' +
    '       COUNT(DISTINCT o.OrderID) AS OrderCount, ' +
    '       COUNT(DISTINCT o.CustomerID) AS CustomerCount, ' +
    '       ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS GrandTotal, ' +
    '       MIN(o.OrderDate) AS FromDate, MAX(o.OrderDate) AS ToDate ' +
    'FROM Orders o ' +
    'JOIN "Order Details" od ON od.OrderID = o.OrderID');

  AddDemo('Basic reports', 'Interactive report', 'interactive_report',
    'Orders with value band – conditional formatting and drill-link demo.',
    'SELECT o.OrderID, o.OrderDate, c.CompanyName AS CustomerName, c.Country, ' +
    '       ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS OrderTotal, ' +
    '       CASE ' +
    '         WHEN SUM(od.UnitPrice*od.Quantity*(1-od.Discount)) >= 5000 THEN ''High'' ' +
    '         WHEN SUM(od.UnitPrice*od.Quantity*(1-od.Discount)) >= 2000 THEN ''Medium'' ' +
    '         ELSE ''Low'' ' +
    '       END AS ValueBand ' +
    'FROM Orders o ' +
    'JOIN Customers c        ON c.CustomerID = o.CustomerID ' +
    'JOIN "Order Details" od ON od.OrderID   = o.OrderID ' +
    'GROUP BY o.OrderID, o.OrderDate, c.CompanyName, c.Country ' +
    'ORDER BY o.OrderDate DESC');

  AddDemo('Basic reports', 'Charts', 'charts',
    'Monthly order totals – ready for bar, line, and pie chart bands.',
    'SELECT SUBSTR(o.OrderDate, 1, 7) AS MonthKey, ' +
    '       COUNT(DISTINCT o.OrderID) AS OrderCount, ' +
    '       ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS MonthTotal ' +
    'FROM Orders o ' +
    'JOIN "Order Details" od ON od.OrderID = o.OrderID ' +
    'GROUP BY SUBSTR(o.OrderDate, 1, 7) ' +
    'ORDER BY MonthKey');

  // ── Cross Tabs ─────────────────────────────────────────────────────────────

  AddDemo('Cross Tabs', 'No rows', 'xtab_no_rows',
    'Single measure only – grand total sales.',
    'SELECT ''Sales Total'' AS Metric, ' +
    '       ROUND(SUM(UnitPrice * Quantity * (1 - Discount)), 2) AS Value ' +
    'FROM "Order Details"');

  AddDemo('Cross Tabs', 'No columns', 'xtab_no_columns',
    'Row dimension (Country) with one value bucket.',
    'SELECT c.Country, ' +
    '       ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS Value ' +
    'FROM Customers c ' +
    'JOIN Orders o            ON o.CustomerID = c.CustomerID ' +
    'JOIN "Order Details" od  ON od.OrderID   = o.OrderID ' +
    'GROUP BY c.Country ORDER BY c.Country');

  AddDemo('Cross Tabs', 'One row, one column', 'xtab_1r_1c',
    'Row: Country, Column: Year-Month. Value: total sales.',
    'SELECT c.Country, SUBSTR(o.OrderDate, 1, 7) AS MonthKey, ' +
    '       ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS Value ' +
    'FROM Customers c ' +
    'JOIN Orders o            ON o.CustomerID = c.CustomerID ' +
    'JOIN "Order Details" od  ON od.OrderID   = o.OrderID ' +
    'GROUP BY c.Country, SUBSTR(o.OrderDate, 1, 7) ' +
    'ORDER BY c.Country, MonthKey');

  AddDemo('Cross Tabs', 'Two rows, one column', 'xtab_2r_1c',
    'Row dims: Country, Customer. Column: Year-Month.',
    'SELECT c.Country, c.CompanyName AS CustomerName, ' +
    '       SUBSTR(o.OrderDate, 1, 7) AS MonthKey, ' +
    '       ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS Value ' +
    'FROM Customers c ' +
    'JOIN Orders o            ON o.CustomerID = c.CustomerID ' +
    'JOIN "Order Details" od  ON od.OrderID   = o.OrderID ' +
    'GROUP BY c.Country, c.CompanyName, SUBSTR(o.OrderDate, 1, 7) ' +
    'ORDER BY c.Country, CustomerName, MonthKey');

  AddDemo('Cross Tabs', 'Two columns, one row', 'xtab_2c_1r',
    'Row: Customer. Column dims: Year then Month.',
    'SELECT c.CompanyName AS CustomerName, ' +
    '       SUBSTR(o.OrderDate, 1, 4) AS YearKey, ' +
    '       SUBSTR(o.OrderDate, 6, 2) AS MonthKey, ' +
    '       ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS Value ' +
    'FROM Customers c ' +
    'JOIN Orders o            ON o.CustomerID = c.CustomerID ' +
    'JOIN "Order Details" od  ON od.OrderID   = o.OrderID ' +
    'GROUP BY c.CompanyName, SUBSTR(o.OrderDate,1,4), SUBSTR(o.OrderDate,6,2) ' +
    'ORDER BY CustomerName, YearKey, MonthKey');

  AddDemo('Cross Tabs', 'Two cell values', 'xtab_2values',
    'Row: Country, Column: Year-Month. Two measures: count + total.',
    'SELECT c.Country, SUBSTR(o.OrderDate, 1, 7) AS MonthKey, ' +
    '       COUNT(DISTINCT o.OrderID) AS OrderCount, ' +
    '       ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS SalesTotal ' +
    'FROM Customers c ' +
    'JOIN Orders o            ON o.CustomerID = c.CustomerID ' +
    'JOIN "Order Details" od  ON od.OrderID   = o.OrderID ' +
    'GROUP BY c.Country, SUBSTR(o.OrderDate, 1, 7) ' +
    'ORDER BY c.Country, MonthKey');

  // ── Northwind extras ───────────────────────────────────────────────────────

  AddDemo('Northwind', 'Employee sales', 'employee_sales',
    'Sales totals per employee – name, title, revenue.',
    'SELECT e.EmployeeID, ' +
    '       (e.FirstName || '' '' || e.LastName) AS EmployeeName, ' +
    '       e.Title, e.City, e.Country, ' +
    '       COUNT(DISTINCT o.OrderID) AS OrderCount, ' +
    '       ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS SalesTotal ' +
    'FROM Employees e ' +
    'JOIN Orders o            ON o.EmployeeID = e.EmployeeID ' +
    'JOIN "Order Details" od  ON od.OrderID   = o.OrderID ' +
    'GROUP BY e.EmployeeID, e.FirstName, e.LastName, e.Title, e.City, e.Country ' +
    'ORDER BY SalesTotal DESC');

  AddDemo('Northwind', 'Product inventory', 'product_inventory',
    'Stock levels with reorder alert flag.',
    'SELECT p.ProductID, p.ProductName, cat.CategoryName, ' +
    '       s.CompanyName AS Supplier, p.UnitPrice, ' +
    '       p.UnitsInStock, p.UnitsOnOrder, p.ReorderLevel, p.Discontinued, ' +
    '       CASE WHEN p.UnitsInStock <= p.ReorderLevel THEN ''Yes'' ELSE ''No'' END AS NeedsReorder ' +
    'FROM Products p ' +
    'LEFT JOIN Categories cat ON cat.CategoryID = p.CategoryID ' +
    'LEFT JOIN Suppliers s    ON s.SupplierID   = p.SupplierID ' +
    'ORDER BY cat.CategoryName, p.ProductName');

  AddDemo('Northwind', 'Orders by shipper', 'orders_by_shipper',
    'Orders grouped by shipping company.',
    'SELECT sh.CompanyName AS ShipperName, ' +
    '       o.OrderID, o.OrderDate, o.ShippedDate, ' +
    '       c.CompanyName AS CustomerName, ' +
    '       o.ShipCity, o.ShipCountry, ROUND(o.Freight, 2) AS Freight ' +
    'FROM Shippers sh ' +
    'JOIN Orders o    ON o.ShipVia      = sh.ShipperID ' +
    'JOIN Customers c ON c.CustomerID   = o.CustomerID ' +
    'ORDER BY sh.CompanyName, o.OrderDate');

  AddDemo('Northwind', 'Supplier products', 'supplier_products',
    'Supplier master with product detail lines.',
    'SELECT s.SupplierID, s.CompanyName AS SupplierName, ' +
    '       s.ContactName, s.City, s.Country, ' +
    '       p.ProductName, cat.CategoryName, ' +
    '       p.UnitPrice, p.UnitsInStock, p.Discontinued ' +
    'FROM Suppliers s ' +
    'JOIN Products p          ON p.SupplierID  = s.SupplierID ' +
    'LEFT JOIN Categories cat ON cat.CategoryID = p.CategoryID ' +
    'ORDER BY s.CompanyName, cat.CategoryName, p.ProductName');

  AddDemo('Northwind', 'Category sales summary', 'category_sales',
    'Revenue by product category – good pie/bar chart source.',
    'SELECT cat.CategoryName, ' +
    '       COUNT(DISTINCT p.ProductID) AS ProductCount, ' +
    '       COUNT(DISTINCT o.OrderID) AS OrderCount, ' +
    '       ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS TotalRevenue ' +
    'FROM Categories cat ' +
    'JOIN Products p          ON p.CategoryID  = cat.CategoryID ' +
    'JOIN "Order Details" od  ON od.ProductID  = p.ProductID ' +
    'JOIN Orders o            ON o.OrderID     = od.OrderID ' +
    'GROUP BY cat.CategoryID, cat.CategoryName ' +
    'ORDER BY TotalRevenue DESC');

  // ── Manual acceptance ─────────────────────────────────────────────────────
  AddDemo('Acceptance', 'GUI Acceptance - Exact Decimal', 'gui_acceptance_money',
    'Exact-decimal signed aggregate fixture. Rate is supplied by an in-memory FMTBCD dataset.',
    'SELECT 1 AS Qty, 0 AS Rate WHERE 1 = 0');
end;

// ---------------------------------------------------------------------------
//  Tree population
// ---------------------------------------------------------------------------

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
        CatNode.ImageIndex    := 0;
        CatNode.SelectedIndex := 0;
        CatNodes.Add(D.Category, CatNode);
      end;
      ItemNode := tvSamples.Items.AddChild(CatNode, D.Title);
      ItemNode.ImageIndex    := 1;
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

// ---------------------------------------------------------------------------
//  Selection helpers
// ---------------------------------------------------------------------------

function TfrmDemoMain.SelectedDemo(out ADemo: TReportDemoDef): Boolean;
var
  Node: TTreeNode;
  Idx: NativeInt;
begin
  Result := False;
  Node := tvSamples.Selected;
  if not Assigned(Node) or not Assigned(Node.Parent) then Exit;
  if Node.Data = nil then Exit;

  Idx := NativeInt(Node.Data) - 1;
  if (Idx < 0) or (Idx >= FDemos.Count) then Exit;

  ADemo  := FDemos[Idx];
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
  mmoDescription.Lines.Text :=
    ADemo.Description + sLineBreak + sLineBreak +
    'SQL:' + sLineBreak + ADemo.MainSQL;

  Path := DemoReportPath(ADemo);
  lblReportFile.Caption := Path;

  if TFile.Exists(Path) then
    StatusBar1.SimpleText := 'Report template found.'
  else
    StatusBar1.SimpleText := 'Report template not found under the current VRT folder.';
end;

procedure TfrmDemoMain.PrepareDataForDemo(const ADemo: TReportDemoDef);
  procedure AppendMoneyRow(AQty: Integer; const ARate: string);
  begin
    FMoneyAcceptanceDataSet.Append;
    FMoneyAcceptanceDataSet.FieldByName('Qty').AsInteger := AQty;
    FMoneyAcceptanceDataSet.FieldByName('Rate').AsString := ARate;
    FMoneyAcceptanceDataSet.Post;
  end;
begin
  if SameText(ADemo.Key, 'gui_acceptance_money') then
  begin
    // The UserDataSet aggregate compatibility path cannot evaluate the exact
    // aggregate expressions in this fixture. Remove the Northwind adapter and
    // prepare the acceptance table for the explicit named-TDataSet engine path.
    FMainQuery.Close;
    if FMainDataRegistered then
    begin
      FReport.UnregisterUserDataSet(FUserDataSet);
      FMainDataRegistered := False;
    end;
    FUserDataSet.DataSet := nil;
    FReport.DataSource := nil;
    if not FMoneyAcceptanceDataSet.Active then
      FMoneyAcceptanceDataSet.CreateDataSet
    else
      FMoneyAcceptanceDataSet.EmptyDataSet;
    AppendMoneyRow(1, '0.125');
    AppendMoneyRow(-2, '0.125');
    AppendMoneyRow(3, '0.250');
    FMoneyAcceptanceDataSet.First;
    Exit;
  end;

  if not FMainDataRegistered then
  begin
    FReport.RegisterUserDataSet(FUserDataSet);
    FMainDataRegistered := True;
  end;
  if FMoneyAcceptanceDataSet.Active then
    FMoneyAcceptanceDataSet.Close;
  FUserDataSet.DataSet := FMainQuery;
  FMainQuery.Close;
  FMainQuery.SQL.Text := ADemo.MainSQL;
  FMainQuery.Open;
end;

procedure TfrmDemoMain.ValidateMoneyAcceptanceBinding;
var
  QtyField, RateField: TField;
  Model: TReportModel;
  Obj: TReportObject;
  Band: TReportBand;
  RowIndex: Integer;
  ExpectedQty: array[0..2] of Integer;
  ExpectedRate: array[0..2] of Currency;
  FoundMaster, FoundSummary: Boolean;
begin
  if FMainDataRegistered then
    raise Exception.Create('Northwind MainData must be unregistered for acceptance preview');
  if FUserDataSet.DataSet <> nil then
    raise Exception.Create('Stale MainData dataset pointer remains during acceptance preview');
  if FMainQuery.Active then
    raise Exception.Create('Northwind query must be closed for acceptance preview');
  if Assigned(FReport.DataSource) then
    raise Exception.Create('Legacy default DataSource must be nil for acceptance preview');
  if not FMoneyAcceptanceDataSet.Active then
    raise Exception.Create('AcceptanceData is not active');
  if FMoneyAcceptanceDataSet.RecordCount <> 3 then
    raise Exception.CreateFmt('AcceptanceData expected 3 rows, found %d',
      [FMoneyAcceptanceDataSet.RecordCount]);

  QtyField := FMoneyAcceptanceDataSet.FieldByName('Qty');
  RateField := FMoneyAcceptanceDataSet.FieldByName('Rate');
  if QtyField.DataType <> ftInteger then
    raise Exception.Create('AcceptanceData.Qty must be ftInteger');
  if RateField.DataType <> ftFMTBCD then
    raise Exception.Create('AcceptanceData.Rate must be ftFMTBCD');
  if FMoneyAcceptanceDataSet.FieldDefs.Find('Rate').Precision <> 18 then
    raise Exception.Create('AcceptanceData.Rate precision must be 18');
  if RateField.Size <> 3 then
    raise Exception.CreateFmt('AcceptanceData.Rate scale must be 3, found %d',
      [RateField.Size]);

  FAcceptanceValidationEvidence := Format(
    'DataSet=AcceptanceData; Count=%d; Qty=%s; Rate=%s Precision=%d Scale=%d; ',
    [FMoneyAcceptanceDataSet.RecordCount, GetEnumName(TypeInfo(TFieldType), Ord(QtyField.DataType)),
     GetEnumName(TypeInfo(TFieldType), Ord(RateField.DataType)),
     FMoneyAcceptanceDataSet.FieldDefs.Find('Rate').Precision, RateField.Size]);

  ExpectedQty[0] := 1;
  ExpectedQty[1] := -2;
  ExpectedQty[2] := 3;
  ExpectedRate[0] := 0.125;
  ExpectedRate[1] := 0.125;
  ExpectedRate[2] := 0.250;
  FMoneyAcceptanceDataSet.First;
  for RowIndex := 0 to High(ExpectedQty) do
  begin
    if FMoneyAcceptanceDataSet.Eof then
      raise Exception.CreateFmt('AcceptanceData ended before row %d', [RowIndex + 1]);
    if (QtyField.AsInteger <> ExpectedQty[RowIndex]) or
       (RateField.AsCurrency <> ExpectedRate[RowIndex]) then
      raise Exception.CreateFmt(
        'AcceptanceData row %d mismatch: Qty=%d Rate=%s',
        [RowIndex + 1, QtyField.AsInteger, RateField.AsString]);
    FMoneyAcceptanceDataSet.Next;
  end;
  if not FMoneyAcceptanceDataSet.Eof then
    raise Exception.Create('AcceptanceData contains extra rows');
  FMoneyAcceptanceDataSet.First;

  Model := FReport.GetModel;
  try
    if Model.DataSetNames.IndexOf('AcceptanceData') < 0 then
      raise Exception.Create('VRT DataSetNames must include AcceptanceData');
    FoundMaster := False;
    FoundSummary := False;
    for Obj in Model.Objects do
      if Obj is TReportBand then
      begin
        Band := TReportBand(Obj);
        if Band.Name = 'BandMasterData' then
        begin
          FoundMaster := True;
          if Band.DataSetName <> 'AcceptanceData' then
            raise Exception.Create('VRT detail band must bind to AcceptanceData');
        end
        else if Band.Name = 'BandReportSummary' then
        begin
          FoundSummary := True;
          if Band.DataSetName <> 'AcceptanceData' then
            raise Exception.Create('VRT summary band must bind to AcceptanceData');
        end;
      end;
    if not FoundMaster then
      raise Exception.Create('VRT AcceptanceData detail band was not found');
    if not FoundSummary then
      raise Exception.Create('VRT AcceptanceData summary band was not found');
  finally
    Model.Free;
  end;
end;

procedure TfrmDemoMain.RenderMoneyAcceptance(AShowPreview: Boolean);
var
  Model: TReportModel;
  NamedDataSets: TDictionary<string, TDataSet>;
  Engine: TReportEngine;
  Renderer: TReportRenderer;
  ExportDoc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  ActualText: string;
  SignedTotalFound, ComputedTotalFound: Boolean;
  PreviewForm: TForm;
  PreviewControl: TVittixReportPreview;
  Toolbar: TPanel;
  CloseButton: TButton;
begin
  Model := FReport.GetModel;
  NamedDataSets := TDictionary<string, TDataSet>.Create;
  try
    NamedDataSets.Add('AcceptanceData', FMoneyAcceptanceDataSet);
    ExportDoc := TReportExportDocument.Create;
    Renderer := TReportRenderer.Create;
    try
      Renderer.ExportDocument := ExportDoc;
      Renderer.TwoPassRendering := FReport.TwoPassRendering;
      Engine := TReportEngine.Create(Model, FMoneyAcceptanceDataSet,
        NamedDataSets, nil);
      try
        Renderer.Render(Engine, Model.PageSettings.PageWidth,
          Model.PageSettings.PageHeight);
      finally
        Engine.DetachDataSet;
        Engine.Free;
      end;

      SignedTotalFound := False;
      ComputedTotalFound := False;
      for Page in ExportDoc.Pages do
        for Cmd in Page.Commands do
          if Cmd is TReportExportTextCommand then
          begin
            ActualText := Trim(TReportExportTextCommand(Cmd).Text);
            if ActualText = '0.625' then
              SignedTotalFound := True;
            if ActualText = '0.725' then
              ComputedTotalFound := True;
          end;
      if not SignedTotalFound then
        raise Exception.Create('Acceptance render did not produce signed total 0.625');
      if not ComputedTotalFound then
        raise Exception.Create('Acceptance render did not produce computed total 0.725');

      if AShowPreview then
      begin
        PreviewForm := TForm.Create(nil);
        try
          PreviewForm.Caption := Model.Title + ' - Preview';
          PreviewForm.Width := 900;
          PreviewForm.Height := 700;
          PreviewForm.Position := poScreenCenter;

          Toolbar := TPanel.Create(PreviewForm);
          Toolbar.Parent := PreviewForm;
          Toolbar.Align := alTop;
          Toolbar.Height := 40;
          Toolbar.BevelOuter := bvNone;

          CloseButton := TButton.Create(PreviewForm);
          CloseButton.Parent := Toolbar;
          CloseButton.Caption := 'Close';
          CloseButton.Left := 8;
          CloseButton.Top := 4;
          CloseButton.Width := 72;
          CloseButton.ModalResult := mrOk;

          PreviewControl := TVittixReportPreview.Create(PreviewForm);
          PreviewControl.Parent := PreviewForm;
          PreviewControl.Align := alClient;
          PreviewControl.LoadFromRenderer(Renderer);
          PreviewControl.SetMargins(Model.PageSettings.Margins);
          PreviewControl.ZoomPercent := 75;
          PreviewForm.ShowModal;
        finally
          PreviewForm.Free;
        end;
      end;
    finally
      Renderer.Free;
      ExportDoc.Free;
    end;
  finally
    NamedDataSets.Free;
    Model.Free;
  end;
end;

procedure TfrmDemoMain.ValidateAcceptanceFixtureForTest;
var
  I: Integer;
  Demo: TReportDemoDef;
  Found: Boolean;
  procedure RunNormalDemoHeadless(const AKey: string);
  var
    J: Integer;
    NormalDemo: TReportDemoDef;
    NormalFound: Boolean;
    NormalModel: TReportModel;
    NormalEngine: TReportEngine;
    NormalRenderer: TReportRenderer;
    NormalExportDoc: TReportExportDocument;
    RenderStart, RenderElapsed: UInt64;
  begin
    NormalFound := False;
    for J := 0 to FDemos.Count - 1 do
      if SameText(FDemos[J].Key, AKey) then
      begin
        NormalDemo := FDemos[J];
        NormalFound := True;
        Break;
      end;
    if not NormalFound then
      raise Exception.CreateFmt('Demo report "%s" is not registered', [AKey]);

    if not TDirectory.Exists(VrtFolderPath) or
       not TFile.Exists(DemoReportPath(NormalDemo)) then
      raise EFileNotFoundException.Create(ReportTemplateErrorText(NormalDemo));

    // Run through the real Northwind query/UserDataSet path without opening
    // a preview window, then verify the normal provider is active.
    PrepareDataForDemo(NormalDemo);
    if not FMainDataRegistered or (FUserDataSet.DataSet <> FMainQuery) or
       not FMainQuery.Active or FMoneyAcceptanceDataSet.Active then
      raise Exception.CreateFmt('Northwind dataset state was not active for "%s"', [AKey]);
    FReport.LoadFromFile(DemoReportPath(NormalDemo));
    NormalModel := FReport.GetModel;
    try
      NormalRenderer := TReportRenderer.Create;
      NormalExportDoc := TReportExportDocument.Create;
      try
        NormalRenderer.ExportDocument := NormalExportDoc;
        NormalRenderer.TwoPassRendering := FReport.TwoPassRendering;
        NormalEngine := FReport.CreateEngine(NormalModel);
        try
          RenderStart := GetTickCount64;
          NormalRenderer.Render(NormalEngine, NormalModel.PageSettings.PageWidth,
            NormalModel.PageSettings.PageHeight);
          RenderElapsed := GetTickCount64 - RenderStart;
          if NormalRenderer.Pages.Count = 0 then
            raise Exception.CreateFmt('Northwind report "%s" prepared without a page', [AKey]);
          if SameText(AKey, 'master_detail_subdetail') then
          begin
            Inc(FMasterDetailRenderCount);
            if FMasterDetailRenderEvidence <> '' then
              FMasterDetailRenderEvidence := FMasterDetailRenderEvidence + '; ';
            FMasterDetailRenderEvidence := FMasterDetailRenderEvidence + Format(
              'MasterDetailRender%d=PASS rows=%d pages=%d elapsed_ms=%d',
              [FMasterDetailRenderCount, FMainQuery.RecordCount,
               NormalRenderer.Pages.Count, RenderElapsed]);
          end;
        finally
          NormalEngine.DetachDataSet;
          NormalEngine.Free;
        end;
      finally
        NormalRenderer.Free;
        NormalExportDoc.Free;
      end;
    finally
      NormalModel.Free;
    end;
  end;
begin
  FMasterDetailRenderCount := 0;
  FMasterDetailRenderEvidence := '';
  Found := False;
  for I := 0 to FDemos.Count - 1 do
    if SameText(FDemos[I].Key, 'gui_acceptance_money') then
    begin
      Demo := FDemos[I];
      Found := True;
      Break;
    end;
  if not Found then
    raise Exception.Create('GUI acceptance report is not registered in the demo');

  RunNormalDemoHeadless('simple_list');
  RunNormalDemoHeadless('master_detail_subdetail');
  RunNormalDemoHeadless('master_detail_subdetail');
  RunNormalDemoHeadless('category_sales');
  EnsureReportFileExists(Demo);
  PrepareDataForDemo(Demo);
  FReport.LoadFromFile(DemoReportPath(Demo));
  ValidateMoneyAcceptanceBinding;
  RenderMoneyAcceptance(False);
  RunNormalDemoHeadless('simple_list');
  FAcceptanceValidationEvidence := FAcceptanceValidationEvidence +
    'Rows=(1,0.125),(-2,0.125),(3,0.250); ActualTotals=0.625,0.725; ' +
    'Reports=SimpleList,Master-Detail-SubDetail(x2),CategorySales PASS; ' +
    'Switching=SimpleList->Acceptance->SimpleList PASS; ' +
    FMasterDetailRenderEvidence;
end;

function TfrmDemoMain.AcceptanceValidationEvidence: string;
begin
  Result := FAcceptanceValidationEvidence;
end;

// ---------------------------------------------------------------------------
//  Populate R.FieldNames from a zero-row execution of ADemo.MainSQL.
//  We use a LIMIT 0 trick so no data is fetched — only column metadata.
// ---------------------------------------------------------------------------
procedure TfrmDemoMain.PopulateFieldNames(R: TReportModel;
  const ADemo: TReportDemoDef);
var
  Q: TFDQuery;
  I: Integer;
begin
  // Run a zero-row sub-select just to get column metadata — no data fetched.
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;
    Q.SQL.Text := 'SELECT * FROM (' + ADemo.MainSQL + ') __q LIMIT 0';
    try
      Q.Open;
      R.FieldNames.Clear;
      for I := 0 to Q.FieldCount - 1 do
        R.FieldNames.Add(Q.Fields[I].FieldName);
    except
      // Fallback: run the real SQL (still closes immediately after metadata)
      Q.Close;
      Q.SQL.Text := ADemo.MainSQL;
      Q.Open;
      R.FieldNames.Clear;
      for I := 0 to Q.FieldCount - 1 do
        R.FieldNames.Add(Q.Fields[I].FieldName);
    end;
  finally
    Q.Free;
  end;
end;

procedure PopulateDataSetNames(R: TReportModel; const ADemo: TReportDemoDef);
begin
  R.DataSetNames.Clear;
  if SameText(ADemo.Key, 'gui_acceptance_money') then
    R.DataSetNames.Add('AcceptanceData')
  else
    R.DataSetNames.Add('MainData');
end;

procedure TfrmDemoMain.EnsureReportFileExists(const ADemo: TReportDemoDef);
var
  Path: string;
  R: TReportModel;
begin
  Path := DemoReportPath(ADemo);
  if not TDirectory.Exists(VrtFolderPath) or not TFile.Exists(Path) then
    raise EFileNotFoundException.Create(ReportTemplateErrorText(ADemo));

  // Existing template only: update its field and dataset metadata, but never
  // silently manufacture a blank report when the configured root is wrong.
  R := TReportSerializer.LoadFromFile(Path);
  try
    PopulateDataSetNames(R, ADemo);
    PopulateFieldNames(R, ADemo);
    TReportSerializer.SaveToFile(R, Path);
  finally
    R.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Designer launch helpers
// ---------------------------------------------------------------------------

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
  SI.cb          := SizeOf(SI);
  SI.dwFlags     := STARTF_USESHOWWINDOW;
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

// ---------------------------------------------------------------------------
//  UI event handlers
// ---------------------------------------------------------------------------

procedure TfrmDemoMain.tvSamplesChange(Sender: TObject; Node: TTreeNode);
var
  D: TReportDemoDef;
begin
  if SelectedDemo(D) then
  begin
    LoadDemoInfo(D);
    btnDesign.Enabled     := True;
    btnPreview.Enabled    := True;
    btnOpenFolder.Enabled := True;
  end
  else
  begin
    lblTitle.Caption   := 'Select a report sample';
    lblReportFile.Caption := '';
    mmoDescription.Clear;
    btnDesign.Enabled     := False;
    btnPreview.Enabled    := False;
    btnOpenFolder.Enabled := False;
  end;
end;

procedure TfrmDemoMain.btnDesignClick(Sender: TObject);
var
  D: TReportDemoDef;
  DesignerExe, InFile, OutFile: string;
begin
  if not SelectedDemo(D) then Exit;

  try
    EnsureReportFileExists(D);
  except
    on E: Exception do
    begin
      MessageDlg(E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  DesignerExe := FindDesignerExe;
  if DesignerExe = '' then
    raise Exception.Create('VittixDesigner.exe not found. Build it first.');

  InFile  := DemoReportPath(D);
  OutFile := TPath.Combine(TPath.GetTempPath,
               Format('VittixRptDemo_out_%d.vrt', [GetTickCount]));

  if TFile.Exists(OutFile) then TFile.Delete(OutFile);

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
  if not SelectedDemo(D) then Exit;

  try
    EnsureReportFileExists(D);
  except
    on E: Exception do
    begin
      MessageDlg(E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  Path := DemoReportPath(D);

  PrepareDataForDemo(D);
  FReport.LoadFromFile(Path);
  if SameText(D.Key, 'gui_acceptance_money') then
  begin
    ValidateMoneyAcceptanceBinding;
    RenderMoneyAcceptance(True);
  end
  else
    FReport.Execute;
end;

procedure TfrmDemoMain.btnOpenFolderClick(Sender: TObject);
var
  D: TReportDemoDef;
  Path: string;
begin
  if not SelectedDemo(D) then Exit;

  try
    EnsureReportFileExists(D);
  except
    on E: Exception do
    begin
      MessageDlg(E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  Path := DemoReportPath(D);

  ShellExecute(Handle, 'open', PChar('explorer.exe'),
    PChar('/select,"' + Path + '"'), nil, SW_SHOWNORMAL);
end;

procedure TfrmDemoMain.btnVrtFolderClick(Sender: TObject);
var
  CurrentPath, SelectedPath: string;
  VrtFiles: TArray<string>;
  D: TReportDemoDef;
begin
  CurrentPath := VrtFolderPath;
  MessageDlg('Current report template folder:' + sLineBreak + CurrentPath +
    sLineBreak + sLineBreak + 'Select a folder containing the demo .vrt templates.',
    mtInformation, [mbOK], 0);

  SelectedPath := CurrentPath;
  if not SelectDirectory('Select Report Template Folder', '', SelectedPath,
    [sdNewFolder, sdShowEdit]) then
    Exit;

  SelectedPath := TPath.GetFullPath(SelectedPath);
  if not TDirectory.Exists(SelectedPath) then
  begin
    MessageDlg('The selected report template folder does not exist:' +
      sLineBreak + SelectedPath, mtError, [mbOK], 0);
    Exit;
  end;
  VrtFiles := TDirectory.GetFiles(SelectedPath, '*.vrt');
  if Length(VrtFiles) = 0 then
  begin
    MessageDlg('The selected folder contains no .vrt report templates:' +
      sLineBreak + SelectedPath, mtError, [mbOK], 0);
    Exit;
  end;

  SaveVrtFolderPath(SelectedPath);
  if SelectedDemo(D) then
    LoadDemoInfo(D);
  StatusBar1.SimpleText := 'Report template folder set to: ' + SelectedPath;
end;

end.
