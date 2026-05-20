unit Frm.Main.SampleDataHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.StorageJSON,
  Vittix.Report.DesignerControl;

procedure CreateSampleDataSet(AOwner: TComponent; var ASampleDataSet: TFDMemTable);
procedure ReloadSampleDataSet(AOwner: TComponent; var ASampleDataSet: TFDMemTable; const AGetRegressionReportPath: TFunc<string, string>);
procedure UseSampleDataSet(
  AOwner: TComponent;
  var ASampleDataSet: TFDMemTable;
  ADataSource: TDataSource;
  ADesigner: TVittixReportDesigner;
  const ARefreshFieldList: TProc;
  const AGetRegressionReportPath: TFunc<string, string>);

implementation

uses
  System.IOUtils,
  System.DateUtils;

procedure CreateSampleDataSet(AOwner: TComponent; var ASampleDataSet: TFDMemTable);
begin
  if not Assigned(ASampleDataSet) then
    ASampleDataSet := TFDMemTable.Create(AOwner);

  with ASampleDataSet.FieldDefs do
  begin
    Clear;
    Add('CustomerName', ftString, 80);
    Add('InvoiceNo', ftString, 30);
    Add('InvoiceDate', ftDate);
    Add('ItemName', ftString, 80);
    Add('Qty', ftInteger);
    Add('Rate', ftCurrency);
    Add('Amount', ftCurrency);
    Add('GroupName', ftString, 40);
    Add('ImagePath', ftString, 260);
    Add('BarcodeValue', ftString, 80);
    Add('Remarks', ftMemo);
  end;
  ASampleDataSet.CreateDataSet;
end;

procedure ReloadSampleDataSet(AOwner: TComponent; var ASampleDataSet: TFDMemTable; const AGetRegressionReportPath: TFunc<string, string>);
const
  SampleRowCount = 150;
  ImagePathHint = 'D:\test\sample.bmp';
  ImagePathHint2 = 'D:\test\sample2.bmp';
  Customers: array[0..19] of string = (
    'Acme Retail', 'Northwind Foods', 'BluePeak Pharma', 'GreenLeaf Traders',
    'Sunrise Packaging', 'Metro Stationers', 'Delta Logistics', 'Orchid Prints',
    'Crown Labels', 'Polar Cold Chain', 'Silverline Office', 'Rapid Supplies',
    'BrightKart', 'Nimbus Distribution', 'Vertex Stores', 'Prime Exports',
    'Urban Cart', 'EverFresh Foods', 'Galaxy Wholesale', 'Trident Industries'
  );
  Items: array[0..29] of string = (
    'A4 Paper Ream', 'A3 Paper Ream', 'Laser Toner Black', 'Laser Toner Cyan',
    'Thermal Label Roll', 'Barcode Sticker Sheet', 'Cold Storage Box', 'Bubble Wrap Roll',
    'Packing Tape 2inch', 'Corrugated Carton L', 'Corrugated Carton M', 'Inkjet Ink Set',
    'Offset Plate 0.30', 'CTP Plate Standard', 'Flexo Plate 1.14', 'Leaflet Gloss 130gsm',
    'Flyer Matte 170gsm', 'Business Card 300gsm', 'Shipping Label 4x6', 'QR Label 2x2',
    'Poly Mailer Medium', 'Shrink Film Roll', 'Invoice Book 2-Ply', 'Receipt Roll 80mm',
    'Catalog Print A5', 'Poster Print A2', 'Sticker Vinyl Sheet', 'Ribbon Wax 110mm',
    'Pallet Tag Set', 'Misc Consumables Kit'
  );
  Groups: array[0..9] of string = (
    'Stationery', 'Packaging', 'Printing', 'Cold Chain', 'Labels',
    'Leaflets', 'Flexo Plates', 'Offset CTP', 'Digital Print', 'Miscellaneous'
  );
var
  I: Integer;
  Qty: Integer;
  Rate: Currency;
  Amount: Currency;
  CustomerName: string;
  ItemName: string;
  GroupName: string;
  InvoiceNo: string;
  InvoiceDate: TDateTime;
  ImagePath: string;
  BarcodeValue: string;
  Remarks: string;
  JsonFile: string;
begin
  if not Assigned(ASampleDataSet) then
    ASampleDataSet := TFDMemTable.Create(AOwner);

  if not ASampleDataSet.Active then
    CreateSampleDataSet(AOwner, ASampleDataSet);

  if not Assigned(AGetRegressionReportPath) then
    Exit;

  JsonFile := AGetRegressionReportPath('sample_data.json');

  if TFile.Exists(JsonFile) then
  begin
    ASampleDataSet.LoadFromFile(JsonFile, sfJSON);
    Exit;
  end;

  ASampleDataSet.DisableControls;
  try
    if ASampleDataSet.Active then
      ASampleDataSet.EmptyDataSet;

    for I := 1 to SampleRowCount do
    begin
      CustomerName := Customers[(I - 1) mod Length(Customers)];
      ItemName := Items[((I * 3) - 1) mod Length(Items)];
      GroupName := Groups[((I * 2) - 1) mod Length(Groups)];
      InvoiceNo := Format('INV-2026-%.4d', [I]);
      InvoiceDate := EncodeDate(2026, 1, 1) + ((I * 3) mod 180);
      Qty := 1 + ((I * 7) mod 24);
      Rate := 75.00 + ((I * 37) mod 2400) / 10;
      Amount := Qty * Rate;

      if (I mod 15 = 0) then
        ImagePath := ''
      else if (I mod 17 = 0) then
        ImagePath := ImagePathHint2
      else if (I mod 10 = 0) then
        ImagePath := ImagePathHint
      else
        ImagePath := '';

      if (I mod 13 = 0) then
        BarcodeValue := ''
      else if (I mod 17 = 0) then
        BarcodeValue := '890123459999'
      else if (I mod 29 = 0) then
        BarcodeValue := '890123450007'
      else
        BarcodeValue := Format('89012345%.4d', [I]);

      if (I mod 11 = 0) then
        Remarks := ''
      else if (I mod 7 = 0) then
        Remarks := 'Long remarks: customer requested staggered delivery, temperature-safe stacking, barcode scan verification at dispatch and arrival, and carton-level recount before final invoice closure.'
      else if (I mod 5 = 0) then
        Remarks := 'Medium remarks: prioritize packing and dispatch in second half of the day.'
      else
        Remarks := 'Short remarks: standard handling.';

      ASampleDataSet.AppendRecord([
        CustomerName,
        InvoiceNo,
        InvoiceDate,
        ItemName,
        Qty,
        Rate,
        Amount,
        GroupName,
        ImagePath,
        BarcodeValue,
        Remarks
      ]);
    end;
  finally
    ASampleDataSet.EnableControls;
  end;

  ASampleDataSet.SaveToFile(JsonFile, sfJSON);
  ASampleDataSet.First;
end;

procedure UseSampleDataSet(
  AOwner: TComponent;
  var ASampleDataSet: TFDMemTable;
  ADataSource: TDataSource;
  ADesigner: TVittixReportDesigner;
  const ARefreshFieldList: TProc;
  const AGetRegressionReportPath: TFunc<string, string>);
begin
  ReloadSampleDataSet(AOwner, ASampleDataSet, AGetRegressionReportPath);
  if Assigned(ADataSource) then
    ADataSource.DataSet := ASampleDataSet;
  if Assigned(ADesigner) then
    ADesigner.DataSet := ASampleDataSet;
  if Assigned(ARefreshFieldList) then
    ARefreshFieldList();
end;

end.
