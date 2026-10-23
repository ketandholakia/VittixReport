unit Test.Vittix.Report.FirebirdIntegration;

{
  Firebird 5 + FireDAC integration tests (v1.0 freeze, [test]).

  The fixture requires explicit disposable-database confirmation and a
  database path that does not already exist. Existing databases are refused.

    VITTIX_FB_DATABASE  full path of a NEW disposable .fdb (must not exist)
    VITTIX_FB_DISPOSABLE=YES explicit confirmation that the path is disposable
    VITTIX_FB_CLIENT    full path of fbclient.dll (embedded) - optional
                        when a Firebird server is reachable via localhost
    VITTIX_FB_USER      optional, default SYSDBA (embedded mode only)
    VITTIX_FB_PASSWORD  optional, default masterkey (embedded mode only)
    VITTIX_FB_KEEP=1    retain the suite-created .fdb; default: delete it

  Missing or invalid configuration is a test failure, not a pass or skip.
  No credentials or paths are committed; FireDAC units are
  referenced ONLY here in the test project, never from source/ or the
  runtime package.

  Any Engine.Prepare access violation fails on its first occurrence. The
  fixture logs the exception, stack, field metadata, dataset state, and
  report-model state; it does not retry or skip.

  Covered: BLOB SUB_TYPE 0 logos (default fetch and with fiBlobs
  excluded - the outcome of each mode is written to the test output),
  exact NUMERIC(18,2) money totals incl. SUM([QTY]*[RATE]), the recorded
  NUMERIC(18,6) FireDAC mapping, the unidirectional-cursor Prepare
  guard, three master-detail link variants with identical output,
  Gujarati/Devanagari round-trip, BOOLEAN/TIMESTAMP formatting, and a
  read-only snapshot transaction isolating a concurrent insert.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Variants,
  System.Generics.Collections,
  System.DateUtils,
  System.TypInfo,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Script,
  FireDAC.Comp.ScriptCommands,
  FireDAC.Stan.Def,
  FireDAC.Stan.Option,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys.FB,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Export.Commands,
  Vittix.Report.Export.VectorPDF;

type
  [TestFixture]
  [Category('FirebirdIntegration')]
  TFirebirdIntegrationTests = class
  private
    FDBPath: string;
    FClientDLL: string;
    FUser: string;
    FPassword: string;
    FAvailable: Boolean;
    FCreatedDatabase: Boolean;
    FSharedConn: TFDConnection;
    FConnectMode: string;
    function MakeConn: TFDConnection;
    procedure EnsureDatabaseAndData;
    procedure SeedData(AConn: TFDConnection);
    function RunInvoiceQuery(AConn: TFDConnection; const ASQL: string;
      AUnidirectional: Boolean = False): TFDQuery;
    function BuildInvoiceReportModel: TReportModel;
    function CaptureInvoiceOutput(AConn: TFDConnection;
      AVariant: Integer): TStringList;
    function ExpectedInvoiceOutput: TStringList;
    function MakePngLogo: TBytes;
    function MakeJpegLogo: TBytes;
    procedure RequireFirebird;
    procedure RecordDiagnostic(const ALine: string);
    procedure RecordPrepareFailure(AException: Exception; ADataSet: TFDQuery;
      AModel: TReportModel; AEngine: TReportEngine);
    procedure AssertPerLine(AGot, AExpected: TStringList; const AVariant: string);
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;

    [Test] procedure Test_BlobLogos_DefaultFetch_PerCustomer;
    [Test] procedure Test_BlobLogos_WithoutFiBlobs_PerCustomer;
    [Test] procedure Test_Money_SumRate_Block_IsExact;
    [Test] procedure Test_Money_SumQtyTimesRate_IsExact;
    [Test] procedure Test_Money_NUMERIC18_6_MappingRecorded;
    [Test] procedure Test_Unidirectional_Guard_Raises;
    [Test] procedure Test_MasterDetail_Parameterized_MasterSource;
    [Test] procedure Test_MasterDetail_MasterSource_IndexFieldNames;
    [Test] procedure Test_MasterDetail_EngineSide_Fields;
    [Test] procedure Test_Unicode_Names_RoundTrip;
    [Test] procedure Test_Boolean_And_Timestamp_Formatting;
    [Test] procedure Test_SnapshotTransaction_IsolatesConcurrentInsert;
  end;

implementation

uses
  System.Types,
  System.IOUtils,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg;

const
  { Invoice seeding: I = 0..199, customer = (I mod 5) + 1 (40 each).
    Block A (I < 100): QTY=1, RATE=0.10; block B: QTY=3, RATE=19.99.
    Known totals: SUM(RATE) = 2009.00; SUM(RATE) block A = 10.00;
    SUM([QTY]*[RATE]) = 6007.00; SUM(RATE6) = 246.90. }
  InvoiceCount = 200;
  CustomerCount = 5;

{ ---------------- fixture lifecycle ---------------- }

procedure TFirebirdIntegrationTests.SetupFixture;
begin
  FDBPath := GetEnvironmentVariable('VITTIX_FB_DATABASE');
  FClientDLL := GetEnvironmentVariable('VITTIX_FB_CLIENT');
  FUser := GetEnvironmentVariable('VITTIX_FB_USER');
  FPassword := GetEnvironmentVariable('VITTIX_FB_PASSWORD');
  FAvailable := False;
  FCreatedDatabase := False;

  if FDBPath = '' then
    raise Exception.Create('Set VITTIX_FB_DATABASE to a new disposable database path');
  FDBPath := TPath.GetFullPath(FDBPath);
  if GetEnvironmentVariable('VITTIX_FB_DISPOSABLE') <> 'YES' then
    raise Exception.Create('Set VITTIX_FB_DISPOSABLE=YES to confirm the database path is disposable');
  if FUser = '' then
    FUser := 'SYSDBA';     // defaults are only safe for embedded mode
  if FPassword = '' then
    FPassword := 'masterkey';

  EnsureDatabaseAndData;
  FAvailable := True;
end;

procedure TFirebirdIntegrationTests.TearDownFixture;
begin
  if Assigned(FSharedConn) then
  begin
    FSharedConn.Close;
    FreeAndNil(FSharedConn);
  end;
  if FCreatedDatabase and (GetEnvironmentVariable('VITTIX_FB_KEEP') <> '1') and
     FileExists(FDBPath) then
    TFile.Delete(FDBPath);
end;

procedure TFirebirdIntegrationTests.RequireFirebird;
begin
  if not FAvailable then
    Assert.Fail('Firebird fixture setup did not complete.');
end;

procedure TFirebirdIntegrationTests.RecordDiagnostic(const ALine: string);
var
  OutputPath: string;
begin
  OutputPath := GetEnvironmentVariable('VITTIX_FB_DIAGNOSTICS');
  if OutputPath <> '' then
    TFile.AppendAllText(OutputPath, ALine + sLineBreak, TEncoding.UTF8)
  else
    Writeln(ALine);
end;

procedure TFirebirdIntegrationTests.RecordPrepareFailure(
  AException: Exception; ADataSet: TFDQuery; AModel: TReportModel;
  AEngine: TReportEngine);
var
  FieldDef: TFieldDef;
  I, FieldPrecision, FieldSize: Integer;
  FieldRequired: Boolean;
begin
  RecordDiagnostic(Format('FBIT PREPARE FAILURE: %s: %s address=%s',
    [AException.ClassName, AException.Message,
     IntToHex(NativeUInt(ExceptAddr), SizeOf(Pointer) * 2)]));
  RecordDiagnostic('FBIT EXCEPTION STACK: ' + AException.StackTrace);
  RecordDiagnostic(Format('FBIT DATASET AT FAILURE: class=%s active=%s recno=%d recordcount=%d fields=%d',
    [ADataSet.ClassName, BoolToStr(ADataSet.Active, True), ADataSet.RecNo,
     ADataSet.RecordCount, ADataSet.FieldCount]));
  for I := 0 to ADataSet.FieldCount - 1 do
  begin
    FieldDef := ADataSet.FieldDefs.Find(ADataSet.Fields[I].FieldName);
    FieldPrecision := -1;
    FieldSize := ADataSet.Fields[I].Size;
    FieldRequired := False;
    if Assigned(FieldDef) then
    begin
      FieldPrecision := FieldDef.Precision;
      FieldSize := FieldDef.Size;
      FieldRequired := FieldDef.Required;
    end;
    RecordDiagnostic(Format(
      'FBIT FIELD AT FAILURE[%d]: name=%s class=%s datatype=%s precision=%d size_or_scale=%d required=%s is_null=%s vartype=%d value=%s',
      [I, ADataSet.Fields[I].FieldName, ADataSet.Fields[I].ClassName,
       GetEnumName(TypeInfo(TFieldType), Ord(ADataSet.Fields[I].DataType)),
       FieldPrecision, FieldSize, BoolToStr(FieldRequired, True),
       BoolToStr(ADataSet.Fields[I].IsNull, True),
       VarType(ADataSet.Fields[I].Value), ADataSet.Fields[I].AsString]));
  end;
  RecordDiagnostic(Format(
    'FBIT ENGINE STATE: model_objects=%d twopass=%s pages=%d exportdoc=%s',
    [AModel.Objects.Count, BoolToStr(AEngine.TwoPassRendering, True),
     AEngine.PageCount, BoolToStr(Assigned(AEngine.ExportDocument), True)]));
end;

function TFirebirdIntegrationTests.MakeConn: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.LoginPrompt := False;
  Result.DriverName := 'FB';
  Result.Params.Values['Database'] := FDBPath;
  Result.Params.Values['User_Name'] := FUser;
  Result.Params.Values['Password'] := FPassword;
  Result.Params.Values['CharacterSet'] := 'UTF8';
  if FClientDLL <> '' then
    Result.Params.Values['VendorLib'] := FClientDLL;
  Result.FetchOptions.RowsetSize := 256;
end;

procedure TFirebirdIntegrationTests.EnsureDatabaseAndData;
var
  Conn: TFDConnection;
  Script: TFDScript;
  CreateStmt: TStringList;
  Q: TFDQuery;
begin
  // This fixture may only create a new file. It never opens, mutates,
  // cleans, or deletes an existing database supplied by the caller.
  if FileExists(FDBPath) or DirectoryExists(FDBPath) then
    raise Exception.CreateFmt('Refusing pre-existing database path: %s', [FDBPath]);
  begin
    Conn := MakeConn;
    Script := TFDScript.Create(nil);
    CreateStmt := TStringList.Create;
    try
      Script.Connection := Conn;
      CreateStmt.Text := 'CREATE DATABASE ''' + FDBPath + '''' +
        ' USER ''' + FUser + ''' PASSWORD ''' + FPassword + '''';
      Script.ExecuteScript(CreateStmt);
      FCreatedDatabase := FileExists(FDBPath);
      if not FCreatedDatabase then
        raise Exception.Create('CREATE DATABASE completed without creating the requested file');
    finally
      CreateStmt.Free;
      Script.Free;
      Conn.Free;
    end;
  end;

  if not Assigned(FSharedConn) then
  begin
    FSharedConn := MakeConn;
    try
      FSharedConn.Open;
    except
      on E: Exception do
      begin
        // Embedded failed but a server may be listening on 3050.
        FreeAndNil(FSharedConn);
        if FClientDLL = '' then
          raise;
        FSharedConn := MakeConn;
        FSharedConn.Params.Values['VendorLib'] := '';
        FSharedConn.Params.Values['Server'] := 'localhost';
        FSharedConn.Open;
        FConnectMode := 'tcp-localhost';
      end;
    end;
    if FConnectMode = '' then
      FConnectMode := 'embedded';
  end;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FSharedConn;

    Q.SQL.Text :=
      'CREATE TABLE CUSTOMER (ID INTEGER NOT NULL PRIMARY KEY, ' +
      'NAME VARCHAR(100) CHARACTER SET UTF8, LOGO BLOB SUB_TYPE 0)';
    try
      Q.ExecSQL;
    except
      on E: Exception do
        if Pos('exists', E.Message) = 0 then
          raise;
    end;

    Q.SQL.Text :=
      'CREATE TABLE INVOICE (ID INTEGER NOT NULL PRIMARY KEY, ' +
      'CUSTOMER_ID INTEGER, QTY INTEGER, RATE NUMERIC(18,2), ' +
      'TOTAL NUMERIC(18,2), RATE6 NUMERIC(18,6), ' +
      'POSTED_AT TIMESTAMP, IS_PAID BOOLEAN)';
    try
      Q.ExecSQL;
    except
      on E: Exception do
        if Pos('exists', E.Message) = 0 then
          raise;
    end;

    Q.SQL.Text :=
      'CREATE TABLE NOTES (ID INTEGER NOT NULL PRIMARY KEY, ' +
      'BODY BLOB SUB_TYPE TEXT CHARACTER SET UTF8)';
    try
      Q.ExecSQL;
    except
      on E: Exception do
        if Pos('exists', E.Message) = 0 then
          raise;
    end;

    Q.SQL.Text := 'DELETE FROM INVOICE';
    Q.ExecSQL;
    Q.SQL.Text := 'DELETE FROM CUSTOMER';
    Q.ExecSQL;
    Q.SQL.Text := 'DELETE FROM NOTES';
    Q.ExecSQL;

    SeedData(FSharedConn);
  finally
    Q.Free;
  end;
end;

function TFirebirdIntegrationTests.MakePngLogo: TBytes;
var
  Bmp: TBitmap;
  Png: TPngImage;
  Ms: TMemoryStream;
begin
  Bmp := TBitmap.Create;
  Png := TPngImage.Create;
  Ms := TMemoryStream.Create;
  try
    Bmp.SetSize(24, 16);
    Bmp.Canvas.Brush.Color := clLime;
    Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
    Png.Assign(Bmp);
    Png.SaveToStream(Ms);
    SetLength(Result, Ms.Size);
    if Ms.Size > 0 then
      Move(Ms.Memory^, Result[0], Ms.Size);
  finally
    Ms.Free;
    Png.Free;
    Bmp.Free;
  end;
end;

function TFirebirdIntegrationTests.MakeJpegLogo: TBytes;
var
  Bmp: TBitmap;
  Jpeg: TJPEGImage;
  Ms: TMemoryStream;
begin
  Bmp := TBitmap.Create;
  Jpeg := TJPEGImage.Create;
  Ms := TMemoryStream.Create;
  try
    Bmp.SetSize(24, 16);
    Bmp.Canvas.Brush.Color := clRed;
    Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
    Jpeg.Assign(Bmp);
    Jpeg.SaveToStream(Ms);
    SetLength(Result, Ms.Size);
    if Ms.Size > 0 then
      Move(Ms.Memory^, Result[0], Ms.Size);
  finally
    Ms.Free;
    Jpeg.Free;
    Bmp.Free;
  end;
end;

procedure TFirebirdIntegrationTests.SeedData(AConn: TFDConnection);
var
  Q: TFDQuery;
  I: Integer;
  Logo: TBytes;
  Bs: TBytesStream;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := AConn;

    // 5 customers: 1 = PNG logo, 2 = JPEG logo, 3 = NULL logo;
    // customers 1/4 carry Gujarati, 2/5 Devanagari text.
    Q.SQL.Text :=
      'INSERT INTO CUSTOMER (ID, NAME, LOGO) VALUES (:ID, :NAME, :LOGO)';
    for I := 1 to CustomerCount do
    begin
      Q.Params[0].AsInteger := I;
      Q.Params[1].DataType := ftWideString;
      case I of
        1: Q.Params[1].AsString := 'Customer ' + #$0A85#$0AB0#$0AC1#$0A9C#$0AB0#$0ABE#$0AA4#$0AC0;
        2: Q.Params[1].AsString := 'Customer ' + #$0926#$0947#$0935#$0928#$093E#$0917#$0930#$0940;
        3: Q.Params[1].AsString := 'Customer Three (no logo)';
        4: Q.Params[1].AsString := #$0A97#$0AC1#$0A9C#$0AB0#$0ABE#$0AA4;
        5: Q.Params[1].AsString := #$0926#$0947#$0935;
      end;
      if I = 1 then
      begin
        Logo := MakePngLogo;
        Bs := TBytesStream.Create(Logo);
        try
          Q.Params[2].LoadFromStream(Bs, ftBlob);
        finally
          Bs.Free;
        end;
      end
      else if I = 2 then
      begin
        Logo := MakeJpegLogo;
        Bs := TBytesStream.Create(Logo);
        try
          Q.Params[2].LoadFromStream(Bs, ftBlob);
        finally
          Bs.Free;
        end;
      end
      else
        Q.Params[2].Clear;
      Q.ExecSQL;
    end;

    Q.SQL.Text :=
      'INSERT INTO INVOICE (ID, CUSTOMER_ID, QTY, RATE, TOTAL, RATE6, ' +
      'POSTED_AT, IS_PAID) VALUES (:ID, :CID, :QTY, :RATE, :TOTAL, ' +
      ':RATE6, :POSTED, :PAID)';
    for I := 0 to InvoiceCount - 1 do
    begin
      Q.Params[0].AsInteger := I + 1;
      Q.Params[1].AsInteger := (I mod CustomerCount) + 1;
      if I < 100 then
      begin
        Q.Params[2].AsInteger := 1;
        Q.Params[3].AsCurrency := 0.10;
        Q.Params[4].AsCurrency := 0.10;
      end
      else
      begin
        Q.Params[2].AsInteger := 3;
        Q.Params[3].AsCurrency := 19.99;
        Q.Params[4].AsCurrency := 59.97;
      end;
      Q.Params[5].AsCurrency := 1.2345;
      Q.Params[6].AsDateTime := EncodeDateTime(2026, 1, 15, 10, 30, 0, 0);
      Q.Params[7].AsBoolean := (I mod 2) = 0;
      Q.ExecSQL;
    end;

    Q.SQL.Text := 'INSERT INTO NOTES (ID, BODY) VALUES (1, :BODY)';
    Q.Params[0].AsString := 'note';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

{ ---------------- helpers ---------------- }

function TFirebirdIntegrationTests.RunInvoiceQuery(AConn: TFDConnection;
  const ASQL: string; AUnidirectional: Boolean): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := AConn;
  Result.SQL.Text := ASQL;
  if AUnidirectional then
    Result.FetchOptions.Unidirectional := True
  else
  begin
    // Deterministic fetch: the report reads an in-memory row set.
    Result.FetchOptions.Mode := fmAll;
    Result.FetchOptions.RowsetSize := 256;
  end;
  Result.Open;
end;

function TFirebirdIntegrationTests.BuildInvoiceReportModel: TReportModel;
var
  MasterBand, DetailBand: TReportBand;
  Txt: TReportTextObject;
begin
  Result := TReportModel.Create;
  MasterBand := TReportBand.Create;
  MasterBand.BandType := btMasterData;
  MasterBand.Height := 20;
  Txt := TReportTextObject.Create;
  Txt.DataField := 'NAME';
  Txt.Bounds := Rect(2, 2, 300, 18);
  MasterBand.Children.Add(Txt);
  Result.Objects.Add(MasterBand);

  DetailBand := TReportBand.Create;
  DetailBand.BandType := btDetail;
  DetailBand.Height := 14;
  DetailBand.DataSetName := 'Inv';
  Txt := TReportTextObject.Create;
  Txt.DataField := 'TOTAL';
  Txt.Bounds := Rect(2, 1, 120, 12);
  DetailBand.Children.Add(Txt);
  Result.Objects.Add(DetailBand);
end;

function TFirebirdIntegrationTests.CaptureInvoiceOutput(AConn: TFDConnection;
  AVariant: Integer): TStringList;
var
  Master: TFDQuery;
  Detail: TFDQuery;
  DS: TDataSource;
  Model: TReportModel;
  Engine: TReportEngine;
  Named: TDictionary<string, TDataSet>;
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
begin
  // Variant 1: parameterized detail through MasterSource (no IndexFieldNames).
  // Variant 2: MasterSource + MasterFields + IndexFieldNames, unfiltered SQL.
  // Variant 3: engine-side MasterField/DetailField on an unlinked query.
  Result := TStringList.Create;
  Master := RunInvoiceQuery(AConn,
    'SELECT ID, NAME FROM CUSTOMER ORDER BY ID');
  Detail := TFDQuery.Create(nil);
  DS := TDataSource.Create(nil);
  Named := TDictionary<string, TDataSet>.Create;
  Doc := TReportExportDocument.Create;
  try
    DS.DataSet := Master;
    Detail.Connection := AConn;
    Detail.FetchOptions.Mode := fmAll;
    Detail.FetchOptions.RowsetSize := 256;
    case AVariant of
      1:
        begin
          Detail.MasterSource := DS;
          Detail.SQL.Text := 'SELECT ID, CUSTOMER_ID, TOTAL FROM INVOICE ' +
            'WHERE CUSTOMER_ID = :ID ORDER BY ID';
        end;
      2:
        begin
          Detail.MasterSource := DS;
          Detail.MasterFields := 'ID';
          Detail.IndexFieldNames := 'CUSTOMER_ID';
          Detail.SQL.Text := 'SELECT ID, CUSTOMER_ID, TOTAL FROM INVOICE ORDER BY ID';
        end;
    else
      Detail.SQL.Text := 'SELECT ID, CUSTOMER_ID, TOTAL FROM INVOICE ORDER BY ID';
    end;
    Detail.Open;

    Model := BuildInvoiceReportModel;
    try
      Named.Add('Inv', Detail);
      Engine := TReportEngine.Create(Model, Master, Named, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        if AVariant = 3 then
        begin
          (Model.Objects[1] as TReportBand).MasterField := 'ID';
          (Model.Objects[1] as TReportBand).DetailField := 'CUSTOMER_ID';
        end;
        Engine.Prepare;

        for Page in Doc.Pages do
          for Cmd in Page.Commands do
            if (Cmd is TReportExportTextCommand) and
               (Trim(TReportExportTextCommand(Cmd).Text) <> '') then
              Result.Add(Trim(TReportExportTextCommand(Cmd).Text));
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    Doc.Free;
    Named.Free;
    DS.Free;
    Detail.Free;
    Master.Free;
  end;
end;

function TFirebirdIntegrationTests.ExpectedInvoiceOutput: TStringList;
var
  Total: string;
begin
  // Master rows by ID, each followed by its 40 invoice TOTALs by ID -
  // analytically derived from the seeding.  FireDAC's TBCDField.AsString
  // renders NUMERIC(18,2) without trailing zeros ('0.1', '59.97').
  Result := TStringList.Create;
  for var C := 1 to CustomerCount do
  begin
    case C of
      1: Result.Add('Customer ' + #$0A85#$0AB0#$0AC1#$0A9C#$0AB0#$0ABE#$0AA4#$0AC0);
      2: Result.Add('Customer ' + #$0926#$0947#$0935#$0928#$093E#$0917#$0930#$0940);
      3: Result.Add('Customer Three (no logo)');
      4: Result.Add(#$0A97#$0AC1#$0A9C#$0AB0#$0ABE#$0AA4);
      5: Result.Add(#$0926#$0947#$0935);
    end;
    for var I := 0 to InvoiceCount - 1 do
    begin
      if ((I mod CustomerCount) + 1) <> C then
        Continue;
      if I < 100 then
        Total := '0.1'
      else
        Total := '59.97';
      Result.Add(Total);
    end;
  end;
end;

procedure TFirebirdIntegrationTests.AssertPerLine(AGot, AExpected: TStringList;
  const AVariant: string);
var
  I: Integer;
begin
  Assert.AreEqual(AExpected.Count, AGot.Count,
    'variant (' + AVariant + ') row count');
  for I := 0 to AExpected.Count - 1 do
    Assert.AreEqual(AExpected[I], AGot[I],
      'variant (' + AVariant + ') line ' + IntToStr(I));
end;

{ ---------------- tests ---------------- }

procedure TFirebirdIntegrationTests.Test_BlobLogos_DefaultFetch_PerCustomer;
var
  Conn: TFDConnection;
  Q: TFDQuery;
  Model: TReportModel;
  Band: TReportBand;
  Img: TReportImageObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  ImageCount, PdfCount, P: Integer;
  Ms: TBytesStream;
  Pdf: AnsiString;
begin
  RequireFirebird;
  Conn := MakeConn;
  try
    Conn.Open;
    Q := RunInvoiceQuery(Conn, 'SELECT ID, NAME, LOGO FROM CUSTOMER ORDER BY ID');
    try
      Writeln('Firebird blob fetch mode (default FetchOptions, fiBlobs in Items = ' +
        BoolToStr(fiBlobs in Q.FetchOptions.Items, True) + ')');

      Model := TReportModel.Create;
      Band := TReportBand.Create;
      Band.BandType := btMasterData;
      Band.Height := 40;
      Img := TReportImageObject.Create;
      Img.DataField := 'LOGO';
      Img.Bounds := Rect(2, 2, 60, 30);
      Band.Children.Add(Img);
      Model.Objects.Add(Band);

      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Q, nil, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        Engine.Prepare;

        ImageCount := 0;
        for Page in Doc.Pages do
          for Cmd in Page.Commands do
            if Cmd.Kind = eckImage then
            begin
              Inc(ImageCount);
              Assert.IsTrue(Length(TReportExportImageCommand(Cmd).Bytes) > 8,
                'each logo must travel as bytes');
            end;
        Assert.AreEqual(2, ImageCount,
          'customers 1 and 2 carry logos; 3 is NULL and prints nothing');

        Ms := TBytesStream.Create;
        try
          TReportVectorPDFExporter.ExportDocument(Doc, Ms);
          SetLength(Pdf, Ms.Size);
          if Ms.Size > 0 then
            for P := 0 to Ms.Size - 1 do
              Pdf[P + 1] := AnsiChar(Ms.Bytes[P]);
          PdfCount := 0;
          for P := 1 to Length(Pdf) - 14 do
            if Copy(Pdf, P, 15) = '/Subtype /Image' then
              Inc(PdfCount);
          Assert.AreEqual(2, PdfCount,
            'PDF must contain exactly the two logo XObjects');
        finally
          Ms.Free;
        end;
      finally
        Engine.Free;
        Doc.Free;
        Model.Free;
      end;
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_BlobLogos_WithoutFiBlobs_PerCustomer;
var
  Conn: TFDConnection;
  Q: TFDQuery;
  Model: TReportModel;
  Band: TReportBand;
  Img: TReportImageObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  ImageCount: Integer;
  St: TStream;
begin
  RequireFirebird;
  Conn := MakeConn;
  try
    Conn.Open;
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Conn;
      Q.SQL.Text := 'SELECT ID, NAME, LOGO FROM CUSTOMER ORDER BY ID';
      // Exclude blobs from the (on-demand) prefetch items: the engine's
      // TField.CreateBlobStream must trigger the deferred blob fetch.
      Q.FetchOptions.Items := Q.FetchOptions.Items - [fiBlobs];
      Q.Open;
      while not Q.Eof do
      begin
        St := Q.CreateBlobStream(Q.FieldByName('LOGO'), bmRead);
        try
          Writeln('Firebird no-fiBlobs blob read: customer ' +
            Q.FieldByName('ID').AsString + ' bytes=' + IntToStr(St.Size));
        finally
          St.Free;
        end;
        Q.Next;
      end;
      Q.First;

      Model := TReportModel.Create;
      Band := TReportBand.Create;
      Band.BandType := btMasterData;
      Band.Height := 40;
      Img := TReportImageObject.Create;
      Img.DataField := 'LOGO';
      Img.Bounds := Rect(2, 2, 60, 30);
      Band.Children.Add(Img);
      Model.Objects.Add(Band);

      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Q, nil, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        Engine.Prepare;

        ImageCount := 0;
        for Page in Doc.Pages do
          for Cmd in Page.Commands do
            if Cmd.Kind = eckImage then
              Inc(ImageCount);
        // Correct EITHER WAY: CreateBlobStream triggers on-demand blob
        // fetch even with fiBlobs excluded from the prefetch items.
        Assert.AreEqual(2, ImageCount,
          'engine blob reading must work with fiBlobs excluded too');
      finally
        Engine.Free;
        Doc.Free;
        Model.Free;
      end;
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_Money_SumRate_Block_IsExact;
var
  Conn: TFDConnection;
  Q: TFDQuery;
  Model: TReportModel;
  Band: TReportBand;
  Txt: TReportTextObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  Texts: TStringList;
begin
  RequireFirebird;
  Conn := MakeConn;
  try
    Conn.Open;
    Q := RunInvoiceQuery(Conn,
      'SELECT RATE FROM INVOICE WHERE RATE = 0.10 ORDER BY ID');
    try
      Model := TReportModel.Create;
      Band := TReportBand.Create;
      Band.BandType := btReportSummary;
      Band.Height := 20;
      Txt := TReportTextObject.Create;
      Txt.Expression := 'SUM([RATE])';
      Band.Children.Add(Txt);
      Model.Objects.Add(Band);

      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Q, nil, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        Engine.Prepare;

        Texts := TStringList.Create;
        try
          for Page in Doc.Pages do
            for Cmd in Page.Commands do
              if (Cmd is TReportExportTextCommand) and
                 (Trim(TReportExportTextCommand(Cmd).Text) <> '') then
                Texts.Add(Trim(TReportExportTextCommand(Cmd).Text));
          // SQL: SELECT SUM(RATE) FROM INVOICE WHERE RATE = 0.10 -> 10.00
          Assert.AreEqual(1, Texts.Count, 'one summary text');
          Assert.AreEqual('10', Texts[0],
            'SUM(RATE) of the 0.10 block must be exactly 10.00');
        finally
          Texts.Free;
        end;
      finally
        Engine.Free;
        Doc.Free;
        Model.Free;
      end;
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_Money_SumQtyTimesRate_IsExact;
var
  Conn: TFDConnection;
  Q: TFDQuery;
  Model: TReportModel;
  Band: TReportBand;
  Txt: TReportTextObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  Texts: TStringList;
begin
  RequireFirebird;
  Conn := MakeConn;
  try
    Conn.Open;
    Q := RunInvoiceQuery(Conn, 'SELECT QTY, RATE FROM INVOICE ORDER BY ID');
    try
      Model := TReportModel.Create;
      Band := TReportBand.Create;
      Band.BandType := btReportSummary;
      Band.Height := 20;
      Txt := TReportTextObject.Create;
      Txt.Expression := 'SUM([QTY]*[RATE])';
      Band.Children.Add(Txt);
      Model.Objects.Add(Band);

      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Q, nil, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        Engine.Prepare;

        Texts := TStringList.Create;
        try
          for Page in Doc.Pages do
            for Cmd in Page.Commands do
              if (Cmd is TReportExportTextCommand) and
                 (Trim(TReportExportTextCommand(Cmd).Text) <> '') then
                Texts.Add(Trim(TReportExportTextCommand(Cmd).Text));
          // SQL: SELECT SUM(QTY*RATE) FROM INVOICE -> 6007.00
          Assert.AreEqual(1, Texts.Count, 'one summary text');
          Assert.AreEqual('6007', Texts[0],
            'SUM([QTY]*[RATE]) must be exactly 6007.00');
        finally
          Texts.Free;
        end;
      finally
        Engine.Free;
        Doc.Free;
        Model.Free;
      end;
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_Money_NUMERIC18_6_MappingRecorded;
var
  Conn: TFDConnection;
  Q: TFDQuery;
  Fld: TField;
  FieldDef: TFieldDef;
  Model: TReportModel;
  Band: TReportBand;
  Txt: TReportTextObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  Texts: TStringList;
  FieldDefInfo: string;
begin
  RequireFirebird;
  Conn := MakeConn;
  try
    Conn.Open;
    Q := RunInvoiceQuery(Conn, 'SELECT RATE6 FROM INVOICE ORDER BY ID');
    try
      Fld := Q.FieldByName('RATE6');
      FieldDef := Q.FieldDefs.Find('RATE6');
      if Assigned(FieldDef) then
        FieldDefInfo := Format('FieldDefPrecision=%d FieldDefSize=%d',
          [FieldDef.Precision, FieldDef.Size])
      else
        FieldDefInfo := 'FieldDef=<missing>';
      RecordDiagnostic('Firebird NUMERIC(18,6) mapping: DataType=' +
        GetEnumName(TypeInfo(TFieldType), Ord(Fld.DataType)) +
        ' FieldClass=' + Fld.ClassName +
        ' ValueVarType=' + IntToStr(VarType(Fld.Value)) +
        ' ' + FieldDefInfo);

      // Exactness assert applies only to mappings that keep the decimal
      // representation (BCD family).  A Double mapping loses NUMERIC(18,6)
      // fidelity in general and must fail with the mapping named.
      if Fld.DataType = ftFloat then
        Assert.Fail(
          'FireDAC maps NUMERIC(18,6) as ftFloat (Double): exactness is lost. ' +
          'Adjust FireDAC FormatOptions.MapRules (map to dtBCD/dtCurrency) ' +
          'or accept double rounding; field class ' + Fld.ClassName);

      Model := TReportModel.Create;
      Band := TReportBand.Create;
      Band.BandType := btReportSummary;
      Band.Height := 20;
      Txt := TReportTextObject.Create;
      Txt.Expression := 'SUM([RATE6])';
      Band.Children.Add(Txt);
      Model.Objects.Add(Band);

      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Q, nil, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        Engine.Prepare;

        Texts := TStringList.Create;
        try
          for Page in Doc.Pages do
            for Cmd in Page.Commands do
              if (Cmd is TReportExportTextCommand) and
                 (Trim(TReportExportTextCommand(Cmd).Text) <> '') then
                Texts.Add(Trim(TReportExportTextCommand(Cmd).Text));
          // RATE6 = 1.2345 for 200 rows; SQL SUM = 246.9000.  The engine
          // accumulates in Currency, so the exact decimal total survives.
          Assert.AreEqual(1, Texts.Count, 'one summary text');
          Assert.AreEqual('246.9', Texts[0],
            'SUM(RATE6) must be exactly 246.90 under the recorded mapping');
        finally
          Texts.Free;
        end;
      finally
        Engine.Free;
        Doc.Free;
        Model.Free;
      end;
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_Unidirectional_Guard_Raises;
var
  Conn: TFDConnection;
  Q: TFDQuery;
  Model: TReportModel;
  Band: TReportBand;
  Txt: TReportTextObject;
  Engine: TReportEngine;
  Raised: Boolean;
begin
  RequireFirebird;
  Conn := MakeConn;
  try
    Conn.Open;
    Q := RunInvoiceQuery(Conn,
      'SELECT ID, TOTAL FROM INVOICE ORDER BY ID', True);
    try
      Model := TReportModel.Create;
      Band := TReportBand.Create;
      Band.BandType := btReportSummary;
      Band.Height := 20;
      Txt := TReportTextObject.Create;
      Txt.Expression := 'SUM([TOTAL])';
      Band.Children.Add(Txt);
      Model.Objects.Add(Band);

      Engine := TReportEngine.Create(Model, Q, nil, nil);
      try
        Raised := False;
        try
          Engine.Prepare;
        except
          on E: Exception do
            if E is EReportException then
            begin
              Raised := True;
              Assert.Contains(E.Message, 'Unidirectional',
                'the guard message must name the fix');
            end;
        end;
        Assert.IsTrue(Raised,
          'unidirectional cursor + aggregates must raise at Prepare');
      finally
        Engine.Free;
      end;
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_MasterDetail_Parameterized_MasterSource;
var
  Conn: TFDConnection;
  Got, Expected: TStringList;
begin
  RequireFirebird;
  Conn := MakeConn;
  try
    Conn.Open;
    Got := CaptureInvoiceOutput(Conn, 1);
    Expected := ExpectedInvoiceOutput;
    try
      AssertPerLine(Got, Expected, 'a');
    finally
      Expected.Free;
      Got.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_MasterDetail_MasterSource_IndexFieldNames;
var
  Conn: TFDConnection;
  Got, Expected: TStringList;
begin
  RequireFirebird;
  Conn := MakeConn;
  try
    Conn.Open;
    Got := CaptureInvoiceOutput(Conn, 2);
    Expected := ExpectedInvoiceOutput;
    try
      AssertPerLine(Got, Expected, 'b');
    finally
      Expected.Free;
      Got.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_MasterDetail_EngineSide_Fields;
var
  Conn: TFDConnection;
  Got, Expected: TStringList;
begin
  RequireFirebird;
  Conn := MakeConn;
  try
    Conn.Open;
    Got := CaptureInvoiceOutput(Conn, 3);
    Expected := ExpectedInvoiceOutput;
    try
      AssertPerLine(Got, Expected, 'c');
    finally
      Expected.Free;
      Got.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_Unicode_Names_RoundTrip;
var
  Conn: TFDConnection;
  Got: TStringList;
begin
  RequireFirebird;
  Conn := MakeConn;
  try
    Conn.Open;
    Got := CaptureInvoiceOutput(Conn, 3);
    try
      Assert.IsTrue(Pos(#$0A85#$0AB0#$0AC1#$0A9C#$0AB0#$0ABE#$0AA4#$0AC0,
        Got.Text) > 0, 'Gujarati name must round-trip into the capture');
      Assert.IsTrue(Pos(#$0926#$0947#$0935#$0928#$093E#$0917#$0930#$0940,
        Got.Text) > 0, 'Devanagari name must round-trip into the capture');
      Assert.IsFalse(Pos('????', Got.Text) > 0, 'no replacement-char mojibake');
    finally
      Got.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_Boolean_And_Timestamp_Formatting;
var
  Conn: TFDConnection;
  Q: TFDQuery;
  Model: TReportModel;
  Band: TReportBand;
  Fld: TReportFieldObject;
  Txt: TReportTextObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  Texts: TStringList;
  FoundDate, FoundTrue, FoundFalse: Boolean;
  S: string;
  I, FieldPrecision, FieldSize: Integer;
  FieldDef: TFieldDef;
  FieldRequired: Boolean;
begin
  RequireFirebird;
  FoundDate := False;
  FoundTrue := False;
  FoundFalse := False;
  Conn := MakeConn;
  try
    Conn.Open;
    Q := RunInvoiceQuery(Conn,
      'SELECT POSTED_AT, IS_PAID FROM INVOICE ORDER BY ID');
    try
      Model := TReportModel.Create;
      Band := TReportBand.Create;
      Band.BandType := btMasterData;
      Band.Height := 20;
      Fld := TReportFieldObject.Create;
      Fld.DataField := 'POSTED_AT';
      Fld.DisplayFormat := 'yyyy-mm-dd';
      Fld.Bounds := Rect(2, 2, 120, 16);
      Band.Children.Add(Fld);
      Txt := TReportTextObject.Create;
      Txt.DataField := 'IS_PAID';
      Txt.Bounds := Rect(130, 2, 220, 16);
      Band.Children.Add(Txt);
      Model.Objects.Add(Band);

      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Q, nil, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        RecordDiagnostic(Format(
          'FBIT PREPARE INPUT: test=BOOLEAN/TIMESTAMP dataset=%s active=%s recno=%d recordcount=%d fields=%d model_objects=%d two_pass=%s',
          [Q.ClassName, BoolToStr(Q.Active, True), Q.RecNo, Q.RecordCount,
           Q.FieldCount, Model.Objects.Count, BoolToStr(Engine.TwoPassRendering, True)]));
        for I := 0 to Q.FieldCount - 1 do
        begin
          FieldDef := Q.FieldDefs.Find(Q.Fields[I].FieldName);
          FieldPrecision := -1;
          FieldSize := Q.Fields[I].Size;
          FieldRequired := False;
          if Assigned(FieldDef) then
          begin
            FieldPrecision := FieldDef.Precision;
            FieldSize := FieldDef.Size;
            FieldRequired := FieldDef.Required;
          end;
          RecordDiagnostic(Format(
            'FBIT FIELD[%d]: name=%s class=%s datatype=%s precision=%d size_or_scale=%d required=%s is_null=%s vartype=%d value=%s',
            [I, Q.Fields[I].FieldName, Q.Fields[I].ClassName,
             GetEnumName(TypeInfo(TFieldType), Ord(Q.Fields[I].DataType)),
             FieldPrecision, FieldSize, BoolToStr(FieldRequired, True),
             BoolToStr(Q.Fields[I].IsNull, True), VarType(Q.Fields[I].Value),
             Q.Fields[I].AsString]));
        end;
        try
          Engine.Prepare;
        except
          on E: Exception do
          begin
            RecordPrepareFailure(E, Q, Model, Engine);
            raise;
          end;
        end;

        Texts := TStringList.Create;
        try
          for Page in Doc.Pages do
            for Cmd in Page.Commands do
              if Cmd is TReportExportTextCommand then
              begin
                S := Trim(TReportExportTextCommand(Cmd).Text);
                if S = '2026-01-15' then
                  FoundDate := True
                else if S = 'True' then
                  FoundTrue := True
                else if S = 'False' then
                  FoundFalse := True;
              end;
          Assert.IsTrue(FoundDate,
            'TIMESTAMP must print in the invariant format the report specifies');
          Assert.IsTrue(FoundTrue and FoundFalse,
            'BOOLEAN must print True/False for both stored states');
        finally
          Texts.Free;
        end;
      finally
        Engine.Free;
        Doc.Free;
        Model.Free;
      end;
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TFirebirdIntegrationTests.Test_SnapshotTransaction_IsolatesConcurrentInsert;
var
  Conn, Conn2: TFDConnection;
  Txn: TFDTransaction;
  Q: TFDQuery;
  Ins: TFDQuery;
  Model: TReportModel;
  Band: TReportBand;
  Txt: TReportTextObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  Texts: TStringList;
begin
  RequireFirebird;
  Conn := MakeConn;
  Conn2 := MakeConn;
  Txn := TFDTransaction.Create(nil);
  try
    Conn.Open;
    Conn2.Open;
    Txn.Connection := Conn;
    Txn.Options.ReadOnly := True;
    Txn.Options.Isolation := xiSnapshot;

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Conn;
      Q.Transaction := Txn;
      Q.SQL.Text := 'SELECT ID, TOTAL FROM INVOICE ORDER BY ID';
      Q.FetchOptions.Mode := fmAll;
      Txn.StartTransaction;
      Q.Open;
      Assert.AreEqual(InvoiceCount, Q.RecordCount,
        'snapshot sees exactly the seeded rows');

      // Concurrent insert from a second connection, committed while the
      // snapshot transaction stays open.
      Ins := TFDQuery.Create(nil);
      try
        Ins.Connection := Conn2;
        Ins.SQL.Text :=
          'INSERT INTO INVOICE (ID, CUSTOMER_ID, QTY, RATE, TOTAL, RATE6, ' +
          'POSTED_AT, IS_PAID) VALUES (9999, 1, 1, 1.0, 1.0, 1.0, ' +
          'CAST(''2026-01-01'' AS TIMESTAMP), FALSE)';
        Ins.ExecSQL;
        Conn2.Commit;
      finally
        Ins.Free;
      end;

      // The report runs on the materialized snapshot rows only.
      Model := TReportModel.Create;
      Band := TReportBand.Create;
      Band.BandType := btMasterData;
      Band.Height := 20;
      Txt := TReportTextObject.Create;
      Txt.DataField := 'TOTAL';
      Txt.Bounds := Rect(2, 2, 120, 16);
      Band.Children.Add(Txt);
      Model.Objects.Add(Band);

      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Q, nil, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        Engine.Prepare;

        Texts := TStringList.Create;
        try
          for Page in Doc.Pages do
            for Cmd in Page.Commands do
              if (Cmd is TReportExportTextCommand) and
                 (Trim(TReportExportTextCommand(Cmd).Text) <> '') then
                Texts.Add(Trim(TReportExportTextCommand(Cmd).Text));
          Assert.AreEqual(InvoiceCount, Texts.Count,
            'the concurrent committed insert must NOT appear in the report');
        finally
          Texts.Free;
        end;
      finally
        Engine.Free;
        Doc.Free;
        Model.Free;
      end;
      Q.Close;
      Txn.Rollback;
    finally
      Q.Free;
    end;
  finally
    Txn.Free;
    Conn2.Free;
    Conn.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TFirebirdIntegrationTests);

end.
