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
  Vittix.Report.UserDataSet,
  Vittix.Report.Model,
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
    StatusBar1  : TStatusBar;
    Splitter1   : TSplitter;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tvSamplesChange(Sender: TObject; Node: TTreeNode);
    procedure btnDesignClick(Sender: TObject);
    procedure btnPreviewClick(Sender: TObject);
    procedure btnOpenFolderClick(Sender: TObject);
  private
    FConn            : TFDConnection;
    FMainQuery       : TFDQuery;
    FUserDataSet     : TVittixUserDataSet;   // FastReport-style bridge
    FReport          : TVittixReport;
    FSQLiteDriverLink: TFDPhysSQLiteDriverLink;
    FDemos           : TList<TReportDemoDef>;

    procedure InitDatabase;
    function  DbFilePath: string;
    function  VrtFolderPath: string;
    procedure BuildDemoCatalog;
    procedure PopulateTree;
    function  SelectedDemo(out ADemo: TReportDemoDef): Boolean;
    function  DemoReportPath(const ADemo: TReportDemoDef): string;
    procedure LoadDemoInfo(const ADemo: TReportDemoDef);
    procedure PrepareDataForDemo(const ADemo: TReportDemoDef);
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

  // FastReport-style UserDataSet: wraps the query, registered with the report.
  // The engine resolves it by component Name (here 'MainData') or as primary.
  FUserDataSet         := TVittixUserDataSet.Create(Self);
  FUserDataSet.Name    := 'MainData';
  FUserDataSet.DataSet := FMainQuery;

  FReport := TVittixReport.Create(Self);
  FReport.RegisterUserDataSet(FUserDataSet);
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
  BaseDir, Candidate, Rel: string;
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
  Result := TPath.GetFullPath(
              TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\vrt'));
  if not TDirectory.Exists(Result) then
    ForceDirectories(Result);
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
    StatusBar1.SimpleText := 'Report file found.'
  else
    StatusBar1.SimpleText := 'Report file not found yet – click Design to create it.';
end;

procedure TfrmDemoMain.PrepareDataForDemo(const ADemo: TReportDemoDef);
begin
  FMainQuery.Close;
  FMainQuery.SQL.Text := ADemo.MainSQL;
  FMainQuery.Open;
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

procedure PopulateDataSetNames(R: TReportModel);
begin
  R.DataSetNames.Clear;
  R.DataSetNames.Add('MainData');
end;

procedure TfrmDemoMain.EnsureReportFileExists(const ADemo: TReportDemoDef);
var
  Path: string;
  R: TReportModel;
begin
  Path := DemoReportPath(ADemo);

  ForceDirectories(ExtractFilePath(Path));

  if TFile.Exists(Path) then
  begin
    // File already exists — reload it, refresh the FieldNames, and re-save
    // so the designer always has current field metadata even if the SQL
    // was changed since the file was first created.
    R := TReportSerializer.LoadFromFile(Path);
    try
      PopulateDataSetNames(R);
      PopulateFieldNames(R, ADemo);
      TReportSerializer.SaveToFile(R, Path);
    finally
      R.Free;
    end;
  end
  else
  begin
    // Brand-new skeleton .vrt
    R := TReportModel.Create;
    try
      R.Title       := ADemo.Title;
      R.Author      := 'VittixReport Northwind Demo';
      R.Description := ADemo.Description;
      PopulateDataSetNames(R);
      PopulateFieldNames(R, ADemo);
      TReportSerializer.SaveToFile(R, Path);
    finally
      R.Free;
    end;
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

  EnsureReportFileExists(D);
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
  if not SelectedDemo(D) then Exit;

  EnsureReportFileExists(D);
  Path := DemoReportPath(D);

  ShellExecute(Handle, 'open', PChar('explorer.exe'),
    PChar('/select,"' + Path + '"'), nil, SW_SHOWNORMAL);
end;

end.
