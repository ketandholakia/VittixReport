unit Vittix.Runner.DataSetup;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  Vittix.Report.UserDataSet;

function CreateInvoiceContractTable(const AValueField, AValue: string): TFDMemTable;

procedure AddInvoiceContractDataSet(const AName, AValueField, AValue: string;
  ADataSets: TObjectList<TFDMemTable>;
  AUserDataSets: TObjectList<TVittixUserDataSet>;
  ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out AUserDataSet: TVittixUserDataSet);

procedure BuildInvoiceContractData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);

procedure BuildInvoicePaginationData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);

procedure BuildReportDataContractData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);

procedure BuildDetailBandsData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);

implementation

function CreateInvoiceContractTable(const AValueField, AValue: string): TFDMemTable;
begin
  Result := TFDMemTable.Create(nil);
  Result.FieldDefs.Add('INVOICE_ID', ftInteger);
  Result.FieldDefs.Add(AValueField, ftString, 80);
  Result.CreateDataSet;
  Result.Append;
  Result.FieldByName('INVOICE_ID').AsInteger := 101;
  Result.FieldByName(AValueField).AsString := AValue;
  Result.Post;
  Result.First;
end;

procedure AddInvoiceContractDataSet(const AName, AValueField, AValue: string;
  ADataSets: TObjectList<TFDMemTable>;
  AUserDataSets: TObjectList<TVittixUserDataSet>;
  ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out AUserDataSet: TVittixUserDataSet);
var
  DataSet: TFDMemTable;
begin
  DataSet := CreateInvoiceContractTable(AValueField, AValue);
  ADataSets.Add(DataSet);
  AUserDataSet := TVittixUserDataSet.Create(nil);
  AUserDataSet.Name := AName;
  AUserDataSet.DataSet := DataSet;
  AUserDataSets.Add(AUserDataSet);
  ANamedDataSets.Add(AName, AUserDataSet);
end;

procedure BuildInvoiceContractData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);
var
  UserDataSet: TVittixUserDataSet;
begin
  APrimaryDataSet := nil;
  ANamedDataSets := TDictionary<string, TVittixUserDataSet>.Create;
  ADataSets := TObjectList<TFDMemTable>.Create(True);
  AUserDataSets := TObjectList<TVittixUserDataSet>.Create(True);
  AddInvoiceContractDataSet('Invoice', 'INVOICE_NO_STR', 'VX-INVOICE-001',
    ADataSets, AUserDataSets, ANamedDataSets, APrimaryDataSet);
  AddInvoiceContractDataSet('Items', 'ITEM_NAME', 'VX-ITEM-LINE',
    ADataSets, AUserDataSets, ANamedDataSets, UserDataSet);
  AddInvoiceContractDataSet('Company', 'COMPANY_NAME', 'VX-COMPANY',
    ADataSets, AUserDataSets, ANamedDataSets, UserDataSet);
  AddInvoiceContractDataSet('Party', 'PARTY_NAME', 'VX-PARTY',
    ADataSets, AUserDataSets, ANamedDataSets, UserDataSet);
  AddInvoiceContractDataSet('InvoiceCustom', 'CUSTOM_TEXT', 'VX-INVOICE-CUSTOM',
    ADataSets, AUserDataSets, ANamedDataSets, UserDataSet);
  AddInvoiceContractDataSet('ItemCustom', 'CUSTOM_ITEM_TEXT', 'VX-ITEM-CUSTOM',
    ADataSets, AUserDataSets, ANamedDataSets, UserDataSet);
end;

procedure BuildInvoicePaginationData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);
var
  InvoiceDataSet: TFDMemTable;
  ItemsDataSet: TFDMemTable;
  ItemsUserDataSet: TVittixUserDataSet;
  I: Integer;
begin
  ANamedDataSets := TDictionary<string, TVittixUserDataSet>.Create;
  ADataSets := TObjectList<TFDMemTable>.Create(True);
  AUserDataSets := TObjectList<TVittixUserDataSet>.Create(True);

  InvoiceDataSet := CreateInvoiceContractTable('INVOICE_NO_STR', 'VX-PAGED-INVOICE');
  ADataSets.Add(InvoiceDataSet);
  APrimaryDataSet := TVittixUserDataSet.Create(nil);
  APrimaryDataSet.Name := 'Invoice';
  APrimaryDataSet.DataSet := InvoiceDataSet;
  AUserDataSets.Add(APrimaryDataSet);
  ANamedDataSets.Add('Invoice', APrimaryDataSet);

  ItemsDataSet := TFDMemTable.Create(nil);
  ItemsDataSet.FieldDefs.Add('INVOICE_ID', ftInteger);
  ItemsDataSet.FieldDefs.Add('ITEM_NAME', ftString, 80);
  ItemsDataSet.FieldDefs.Add('QTY', ftInteger);
  ItemsDataSet.CreateDataSet;
  for I := 1 to 80 do
  begin
    ItemsDataSet.Append;
    ItemsDataSet.FieldByName('INVOICE_ID').AsInteger := 101;
    ItemsDataSet.FieldByName('ITEM_NAME').AsString := Format('VX-PAGED-ITEM-%2.2d', [I]);
    ItemsDataSet.FieldByName('QTY').AsInteger := I;
    ItemsDataSet.Post;
  end;
  ItemsDataSet.First;
  ADataSets.Add(ItemsDataSet);
  ItemsUserDataSet := TVittixUserDataSet.Create(nil);
  ItemsUserDataSet.Name := 'Items';
  ItemsUserDataSet.DataSet := ItemsDataSet;
  AUserDataSets.Add(ItemsUserDataSet);
  ANamedDataSets.Add('Items', ItemsUserDataSet);
end;
procedure BuildReportDataContractData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);
var
  DataSet: TFDMemTable;
  I: Integer;
  RowValues: array[1..3] of string;
begin
  ANamedDataSets := TDictionary<string, TVittixUserDataSet>.Create;
  ADataSets := TObjectList<TFDMemTable>.Create(True);
  AUserDataSets := TObjectList<TVittixUserDataSet>.Create(True);

  DataSet := TFDMemTable.Create(nil);
  DataSet.FieldDefs.Add('PARTY_NAME', ftString, 80);
  DataSet.FieldDefs.Add('BALANCE_TEXT', ftString, 80);
  DataSet.CreateDataSet;
  RowValues[1] := 'VX-REPORTDATA-PARTY-A';
  RowValues[2] := 'VX-REPORTDATA-PARTY-B';
  RowValues[3] := 'VX-REPORTDATA-PARTY-C';
  for I := 1 to Length(RowValues) do
  begin
    DataSet.Append;
    DataSet.FieldByName('PARTY_NAME').AsString := RowValues[I];
    DataSet.FieldByName('BALANCE_TEXT').AsString := Format('VX-BALANCE-%d', [I]);
    DataSet.Post;
  end;
  DataSet.First;
  ADataSets.Add(DataSet);

  APrimaryDataSet := TVittixUserDataSet.Create(nil);
  APrimaryDataSet.Name := 'ReportData';
  APrimaryDataSet.DataSet := DataSet;
  AUserDataSets.Add(APrimaryDataSet);
  ANamedDataSets.Add('ReportData', APrimaryDataSet);
end;

procedure BuildDetailBandsData(out APrimaryDataSet: TVittixUserDataSet;
  out ANamedDataSets: TDictionary<string, TVittixUserDataSet>;
  out ADataSets: TObjectList<TFDMemTable>;
  out AUserDataSets: TObjectList<TVittixUserDataSet>);
var
  MasterDS, DetailDS: TFDMemTable;
  UserDS: TVittixUserDataSet;
  I, J: Integer;
begin
  ANamedDataSets := TDictionary<string, TVittixUserDataSet>.Create;
  ADataSets := TObjectList<TFDMemTable>.Create(True);
  AUserDataSets := TObjectList<TVittixUserDataSet>.Create(True);

  MasterDS := TFDMemTable.Create(nil);
  MasterDS.FieldDefs.Add('InvoiceNo', ftString, 20);
  MasterDS.FieldDefs.Add('CustomerName', ftString, 80);
  MasterDS.CreateDataSet;

  DetailDS := TFDMemTable.Create(nil);
  DetailDS.FieldDefs.Add('InvoiceNo', ftString, 20);
  DetailDS.FieldDefs.Add('ItemName', ftString, 80);
  DetailDS.FieldDefs.Add('Amount', ftFloat);
  DetailDS.CreateDataSet;

  for I := 1 to 5 do
  begin
    MasterDS.AppendRecord(['INV-' + IntToStr(I), 'Customer ' + IntToStr(I)]);
    for J := 1 to 3 do
      DetailDS.AppendRecord(['INV-' + IntToStr(I), 'Item ' + IntToStr(I) + '-' + IntToStr(J), I * 10.5 * J]);
  end;
  MasterDS.First;
  DetailDS.First;

  ADataSets.Add(MasterDS);
  ADataSets.Add(DetailDS);

  APrimaryDataSet := TVittixUserDataSet.Create(nil);
  APrimaryDataSet.Name := 'MasterData';
  APrimaryDataSet.DataSet := MasterDS;
  AUserDataSets.Add(APrimaryDataSet);
  ANamedDataSets.Add('MasterData', APrimaryDataSet);

  UserDS := TVittixUserDataSet.Create(nil);
  UserDS.Name := 'DetailData';
  UserDS.DataSet := DetailDS;
  AUserDataSets.Add(UserDS);
  ANamedDataSets.Add('DetailData', UserDS);
end;

end.