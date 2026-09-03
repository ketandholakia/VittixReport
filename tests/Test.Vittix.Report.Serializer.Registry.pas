unit Test.Vittix.Report.Serializer.Registry;

{
  Phase 4I-3: serializer registry and diagnostic tests.

  - Registry completeness: every registered report object class must
    serialize through a specialized serializer.  Detected behaviorally:
    a base-serializer fallback produces JSON containing only the common
    base properties, so any non-base key proves a specialized serializer
    was used.  This fails if a future object is registered without its
    serializer registration.
  - Unknown-class diagnostics: the error must name the discriminator
    value actually present ('Class' primary, 'Type' legacy), and must
    not raise a secondary JSON exception when only 'Type' (or neither
    key) is present.
  - Specialized round-trips (Chart, Barcode) pin that specialized
    properties survive SaveToJSON/LoadFromJSON.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.JSON,
  Vittix.Report.Objects,
  Vittix.Report.Serializer;

type
  [TestFixture]
  TSerializerRegistryTests = class
  private
    function NonBaseKeyCount(const AJSON: string): Integer;
  public
    [Test] procedure Test_RegistryCompleteness_AllClassesHaveSpecializedSerializer;
    [Test] procedure Test_UnknownClass_PrimaryDiscriminator_Message;
    [Test] procedure Test_UnknownClass_LegacyType_Message;
    [Test] procedure Test_MissingDiscriminator_FailsLoud;
    [Test] procedure Test_Chart_RoundTrip_SpecializedProperties;
    [Test] procedure Test_Barcode_RoundTrip_SpecializedProperties;
  end;

implementation

uses
  System.StrUtils,
  System.Types,
  System.UITypes,
  Vittix.Report.Objects.Chart,
  Vittix.Report.Objects.Barcode;

const
  { Common keys written by the base serializer for non-band objects. }
  BaseKeys: array [0..10] of string = (
    'Class', 'Name', 'Bounds', 'Visible', 'PrintWhen', 'AnchorRight',
    'AnchorBottom', 'PageBreakBefore', 'PageBreakAfter', 'Locked',
    'OnBeforePrint');

function BaseKeyCount(const AJSON: string): Integer;
var
  K: string;
begin
  Result := 0;
  for K in BaseKeys do
    if Pos('"' + K + '"', AJSON) > 0 then
      Inc(Result);
end;

function TSerializerRegistryTests.NonBaseKeyCount(const AJSON: string): Integer;
var
  JO: TJSONObject;
  Pair: TJSONPair;
  K: string;
  IsBase: Boolean;
begin
  JO := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  try
    Assert.IsNotNull(JO, 'serialized object is not valid JSON');
    Result := 0;
    for var I := 0 to JO.Count - 1 do
    begin
      Pair := JO.Pairs[I];
      IsBase := False;
      for K in BaseKeys do
        if Pair.JsonString.Value = K then
        begin
          IsBase := True;
          Break;
        end;
      if not IsBase then
        Inc(Result);
    end;
  finally
    JO.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_RegistryCompleteness_AllClassesHaveSpecializedSerializer;
var
  Cls: TReportObjectClass;
  Obj: TReportObject;
  JSON: string;
  NonBase: Integer;
begin
  for Cls in GetRegisteredReportObjects do
  begin
    Obj := Cls.Create;
    try
      JSON := TReportSerializer.SerializeObjectListToJSON([Obj]);
    finally
      Obj.Free;
    end;
    NonBase := NonBaseKeyCount(JSON);
    Assert.IsTrue(NonBase > 0,
      Format('%s serialized through the base serializer ' +
             '(only common properties, %d non-base keys) - ' +
             'serializer registration missing', [Cls.ClassName, NonBase]));
  end;
end;

procedure TSerializerRegistryTests.Test_UnknownClass_PrimaryDiscriminator_Message;
var
  Obj: TJSONObject;
  Msg: string;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('Class', 'NoSuchThing');
    try
      JSONToObject(Obj);
      Assert.Fail('unknown class must raise');
    except
      on E: Exception do
      begin
        Msg := E.Message;
        Assert.Contains(Msg, 'Unknown report object class: "NoSuchThing"');
        Assert.IsFalse(ContainsText(Msg, 'not found'),
          'secondary JSON exception replaced the diagnostic: ' + Msg);
      end;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_UnknownClass_LegacyType_Message;
var
  Obj: TJSONObject;
  Msg: string;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('Type', 'NoSuchThing');
    try
      JSONToObject(Obj);
      Assert.Fail('unknown legacy type must raise');
    except
      on E: Exception do
      begin
        Msg := E.Message;
        // The diagnostic must name the value from the legacy discriminator,
        // not fail with an unrelated missing-'Class' JSON error.
        Assert.Contains(Msg, 'Unknown report object class: "NoSuchThing"');
      end;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_MissingDiscriminator_FailsLoud;
var
  Obj: TJSONObject;
  Msg: string;
begin
  Obj := TJSONObject.Create;
  try
    try
      JSONToObject(Obj);
      Assert.Fail('missing discriminator must raise');
    except
      on E: Exception do
      begin
        Msg := E.Message;
        Assert.Contains(Msg, 'Unknown report object class:');
      end;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_Chart_RoundTrip_SpecializedProperties;
var
  Chart, Loaded: TReportChartObject;
  JSON: string;
  List: TArray<TReportObject>;
begin
  Chart := TReportChartObject.Create;
  try
    Chart.Name := 'chart1';
    Chart.ChartType := ctBar;
    Chart.DataSetName := 'dsSales';
    Chart.DataFieldLabel := 'Region';
    Chart.DataFieldValue := 'Amount';
    Chart.Title := 'Quarterly Sales';
    Chart.ShowLegend := False;
    JSON := TReportSerializer.SerializeObjectListToJSON([Chart]);

    List := TReportSerializer.DeserializeObjectListFromJSON(JSON);
    try
      Assert.AreEqual(1, Length(List));
      Loaded := List[0] as TReportChartObject;
      Assert.IsTrue(Loaded.ChartType = ctBar);
      Assert.AreEqual('dsSales', Loaded.DataSetName);
      Assert.AreEqual('Region', Loaded.DataFieldLabel);
      Assert.AreEqual('Amount', Loaded.DataFieldValue);
      Assert.AreEqual('Quarterly Sales', Loaded.Title);
      Assert.IsFalse(Loaded.ShowLegend);
    finally
      for var I := 0 to High(List) do
        List[I].Free;
    end;
  finally
    Chart.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_Barcode_RoundTrip_SpecializedProperties;
var
  Barcode, Loaded: TReportBarcodeObject;
  JSON: string;
  List: TArray<TReportObject>;
begin
  Barcode := TReportBarcodeObject.Create;
  try
    Barcode.Name := 'barcode1';
    Barcode.Symbology := bsCode128;
    Barcode.ErrorCorrection := qrHigh;
    Barcode.Value := 'HTTPS://EXAMPLE.COM/QR-4H2';
    JSON := TReportSerializer.SerializeObjectListToJSON([Barcode]);

    List := TReportSerializer.DeserializeObjectListFromJSON(JSON);
    try
      Assert.AreEqual(1, Length(List));
      Loaded := List[0] as TReportBarcodeObject;
      Assert.IsTrue(Loaded.Symbology = bsCode128);
      Assert.IsTrue(Loaded.ErrorCorrection = qrHigh);
      Assert.AreEqual('HTTPS://EXAMPLE.COM/QR-4H2', Loaded.Value);
    finally
      for var I := 0 to High(List) do
        List[I].Free;
    end;
  finally
    Barcode.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSerializerRegistryTests);

end.
