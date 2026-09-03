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
    [Test] procedure Test_GetClass_GraphicClassesRegistered;
    [Test] procedure Test_PictureRoundTrip_PNG;
    [Test] procedure Test_PictureRoundTrip_BMP;
    [Test] procedure Test_PictureRoundTrip_JPEG;
    [Test] procedure Test_Picture_UnknownClass_SkipsSilently;
    [Test] procedure Test_Picture_CorruptData_LeavesEmptyAndLoads;
    [Test] procedure Test_Picture_MissingKeys_LeavesEmpty;
  end;

implementation

uses
  System.StrUtils,
  System.Types,
  System.UITypes,
  System.IOUtils,
  System.NetEncoding,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  Vcl.Imaging.Jpeg,
  Vittix.Report.Bands,
  Vittix.Report.Model,
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

{ Writes a small real image of the given format to a temp file and loads it
  into the image object's Picture.  Real encoder output, not fabricated bytes. }
procedure LoadRealImage(Img: TReportImageObject; const AFormat: string);
var
  Bmp: TBitmap;
  TempFile: string;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(24, 16);
    Bmp.Canvas.Brush.Color := clBlue;
    Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
    Bmp.Canvas.Brush.Color := clYellow;
    Bmp.Canvas.FillRect(Rect(4, 4, 8, 8));
    TempFile := TPath.Combine(TPath.GetTempPath,
      'vittix_4i5_rt_' + TGUID.NewGuid.ToString + '.' + AFormat);
    if AFormat = 'bmp' then
      Bmp.SaveToFile(TempFile)
    else if AFormat = 'png' then
    begin
      var Png := TPngImage.Create;
      try
        Png.Assign(Bmp);
        Png.SaveToFile(TempFile);
      finally
        Png.Free;
      end;
    end
    else
    begin
      var Jpg := TJPEGImage.Create;
      try
        Jpg.Assign(Bmp);
        Jpg.SaveToFile(TempFile);
      finally
        Jpg.Free;
      end;
    end;
  finally
    Bmp.Free;
  end;
  Img.Picture.LoadFromFile(TempFile);
  TFile.Delete(TempFile);
end;


{ Builds a real model containing one image object (no picture), serializes it,
  and injects the given PictureData/PictureClass pairs into the image object's
  JSON - producing a valid report with exact control over the embedded-picture
  keys.  Returns the modified JSON text. }
function BuildImageReportJSON(const APicData, APicClass: string): string;
var
  M: TReportModel;
  Band: TReportBand;
  Img: TReportImageObject;
  Root, Obj: TJSONObject;
begin
  M := TReportModel.Create;
  try
    Band := TReportBand.Create;
    Band.BandType := btPageHeader;
    Img := TReportImageObject.Create;
    Img.Name := 'imgX';
    Img.DataField := '';
    Band.Children.Add(Img);
    M.Objects.Add(Band);
    Result := TReportSerializer.SaveToJSON(M);
  finally
    M.Free;
  end;

  Root := TJSONObject.ParseJSONValue(Result) as TJSONObject;
  try
    Obj := (((Root.GetValue('Objects') as TJSONArray).Items[0]
      as TJSONObject).GetValue('Children') as TJSONArray).Items[0] as TJSONObject;
    if APicData <> '' then
      Obj.AddPair('PictureData', APicData);
    if APicClass <> '' then
      Obj.AddPair('PictureClass', APicClass);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_GetClass_GraphicClassesRegistered;
begin
  // Serializer initialization must make the streaming registry resolve the
  // graphic classes it serializes through PictureClass.
  Assert.IsNotNull(GetClass('TBitmap'), 'TBitmap not registered');
  Assert.IsNotNull(GetClass('TPNGImage'), 'TPNGImage not registered');
  Assert.IsNotNull(GetClass('TJPEGImage'), 'TJPEGImage not registered');
end;

procedure TSerializerRegistryTests.Test_PictureRoundTrip_PNG;
var
  Img, Loaded: TReportImageObject;
  JSON: string;
  List: TArray<TReportObject>;
begin
  Img := TReportImageObject.Create;
  try
    Img.DataField := '';
    LoadRealImage(Img, 'png');
    Assert.AreEqual('TPngImage', Img.Picture.Graphic.ClassName);
    JSON := TReportSerializer.SerializeObjectListToJSON([Img]);

    List := TReportSerializer.DeserializeObjectListFromJSON(JSON);
    try
      Loaded := List[0] as TReportImageObject;
      Assert.IsTrue(Assigned(Loaded.Picture.Graphic), 'picture lost');
      Assert.IsFalse(Loaded.Picture.Graphic.Empty);
      Assert.AreEqual('TPngImage', Loaded.Picture.Graphic.ClassName);
      Assert.AreEqual(24, Loaded.Picture.Width);
      Assert.AreEqual(16, Loaded.Picture.Height);
    finally
      for var I := 0 to High(List) do
        List[I].Free;
    end;
  finally
    Img.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_PictureRoundTrip_BMP;
var
  Img, Loaded: TReportImageObject;
  JSON: string;
  List: TArray<TReportObject>;
begin
  Img := TReportImageObject.Create;
  try
    Img.DataField := '';
    LoadRealImage(Img, 'bmp');
    Assert.AreEqual('TBitmap', Img.Picture.Graphic.ClassName);
    JSON := TReportSerializer.SerializeObjectListToJSON([Img]);

    List := TReportSerializer.DeserializeObjectListFromJSON(JSON);
    try
      Loaded := List[0] as TReportImageObject;
      Assert.IsTrue(Assigned(Loaded.Picture.Graphic), 'picture lost');
      Assert.AreEqual('TBitmap', Loaded.Picture.Graphic.ClassName);
      Assert.AreEqual(24, Loaded.Picture.Width);
      Assert.AreEqual(16, Loaded.Picture.Height);
    finally
      for var I := 0 to High(List) do
        List[I].Free;
    end;
  finally
    Img.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_PictureRoundTrip_JPEG;
var
  Img, Loaded: TReportImageObject;
  JSON: string;
  List: TArray<TReportObject>;
begin
  Img := TReportImageObject.Create;
  try
    Img.DataField := '';
    LoadRealImage(Img, 'jpg');
    Assert.AreEqual('TJPEGImage', Img.Picture.Graphic.ClassName);
    JSON := TReportSerializer.SerializeObjectListToJSON([Img]);

    List := TReportSerializer.DeserializeObjectListFromJSON(JSON);
    try
      Loaded := List[0] as TReportImageObject;
      Assert.IsTrue(Assigned(Loaded.Picture.Graphic), 'picture lost');
      Assert.AreEqual('TJPEGImage', Loaded.Picture.Graphic.ClassName);
      Assert.IsTrue(Loaded.Picture.Width > 0);
      Assert.IsTrue(Loaded.Picture.Height > 0);
    finally
      for var I := 0 to High(List) do
        List[I].Free;
    end;
  finally
    Img.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_Picture_UnknownClass_SkipsSilently;
var
  M2: TReportModel;
  Band: TReportBand;
  Loaded: TReportImageObject;
begin
  // Unknown PictureClass must be skipped (forward compatibility), the
  // object must still load, and the picture stays empty.
  M2 := TReportSerializer.LoadFromJSON(BuildImageReportJSON('AAAA', 'TUnknownGraphic'));
  try
    Band := M2.Objects[0] as TReportBand;
    Loaded := Band.Children[0] as TReportImageObject;
    Assert.AreEqual('imgX', Loaded.Name);
    Assert.IsFalse(Assigned(Loaded.Picture.Graphic) and
      not Loaded.Picture.Graphic.Empty, 'unknown class must leave picture empty');
  finally
    M2.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_Picture_CorruptData_LeavesEmptyAndLoads;
var
  M2: TReportModel;
  Band: TReportBand;
  Loaded: TReportImageObject;
begin
  // Registered class (TPNGImage) with invalid bytes: the report must load,
  // the picture stays empty, and a sibling object still deserializes.
  M2 := TReportSerializer.LoadFromJSON(
    BuildImageReportJSON(
      TNetEncoding.Base64.EncodeBytesToString(TBytes.Create(0,1,2,3,4,5,6,7)),
      'TPNGImage'));
  try
    Band := M2.Objects[0] as TReportBand;
    Loaded := Band.Children[0] as TReportImageObject;
    Assert.AreEqual('imgX', Loaded.Name);
    Assert.IsFalse(Assigned(Loaded.Picture.Graphic) and
      not Loaded.Picture.Graphic.Empty, 'corrupt data must leave picture empty');
    // The rest of the report (band, page settings, object properties) still
    // loaded correctly around the failed image data.
    Assert.AreEqual(btPageHeader, Band.BandType);
    Assert.IsTrue(Loaded.Stretch, 'sibling property defaults still loaded');
  finally
    M2.Free;
  end;
end;

procedure TSerializerRegistryTests.Test_Picture_MissingKeys_LeavesEmpty;
var
  M2: TReportModel;
  Loaded: TReportImageObject;
begin
  // No PictureData/PictureClass at all: existing default behavior.
  M2 := TReportSerializer.LoadFromJSON(BuildImageReportJSON('', ''));
  try
    Loaded := (M2.Objects[0] as TReportBand).Children[0] as TReportImageObject;
    Assert.AreEqual('imgX', Loaded.Name);
    Assert.IsFalse(Assigned(Loaded.Picture.Graphic) and
      not Loaded.Picture.Graphic.Empty);
  finally
    M2.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSerializerRegistryTests);

end.
