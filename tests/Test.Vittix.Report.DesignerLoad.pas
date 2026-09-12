unit Test.Vittix.Report.DesignerLoad;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.JSON,
  Vittix.Report.Model,
  Vittix.Report.Serializer,
  Vittix.Report.DesignerControl,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Objects.Unknown;

type
  [TestFixture]
  TReportDesignerLoadTests = class
  public
    [Test] procedure Test_FailedLoad_GetReportJSON_ReturnsOriginalInput;
    [Test] procedure Test_FailedLoad_DoesNotReplaceCurrentModel;
    [Test] procedure Test_FailedLoad_ThenSuccessfulLoad_RestoresCleanState;
    [Test] procedure Test_SuccessfulLoad_ThenSave_Unchanged;
    [Test] procedure Test_UnknownClass_Strict_Raises;
    [Test] procedure Test_UnknownClass_Tolerant_PreservesAndWarns;
    [Test] procedure Test_UnknownClass_Tolerant_KnownObjectsSurvive;
    [Test] procedure Test_UnknownClass_Tolerant_OrderingPreserved;
    [Test] procedure Test_UnknownClass_Tolerant_MultipleUnknownsReported;
    [Test] procedure Test_UnknownClass_Tolerant_EmptyAndMissingObjects;
    [Test] procedure Test_UnknownChild_Tolerant_Preserved;
    [Test] procedure Test_UnknownChild_Strict_Fails;
    [Test] procedure Test_UnknownChild_Tolerant_SaveReload_RawPreserved;
  end;

implementation

uses
  System.Classes,
  System.Types,
  System.StrUtils;

function BuildValidReportJSON(const ATitle: string): string;
var
  Model: TReportModel;
begin
  Model := TReportModel.Create;
  try
    Model.Title := ATitle;
    Result := TReportSerializer.SaveToJSON(Model);
  finally
    Model.Free;
  end;
end;

function BuildUnknownClassJSON(const AUnknownClass: string): string;
var
  Root, Obj: TJSONObject;
  Arr: TJSONArray;
begin
  Root := TJSONObject.Create;
  Root.AddPair('Version', TJSONNumber.Create(2));
  Root.AddPair('Title', 'NewerReport');
  Arr := TJSONArray.Create;
  Obj := TJSONObject.Create;
  Obj.AddPair('Class', AUnknownClass);
  Obj.AddPair('Name', 'FutureObject');
  Arr.AddElement(Obj);
  Root.AddPair('Objects', Arr);
  Result := Root.Format(2);
  Root.Free;
end;

function BuildMixedJSON(const AClasses: array of string): string;
var
  Root, Obj: TJSONObject;
  Arr: TJSONArray;
  Cls: string;
begin
  Root := TJSONObject.Create;
  Root.AddPair('Version', TJSONNumber.Create(2));
  Root.AddPair('Title', 'Mixed');
  Arr := TJSONArray.Create;
  for Cls in AClasses do
  begin
    Obj := TJSONObject.Create;
    Obj.AddPair('Class', Cls);
    Obj.AddPair('Name', Cls);
    Arr.AddElement(Obj);
  end;
  Root.AddPair('Objects', Arr);
  Result := Root.Format(2);
  Root.Free;
end;

{ Builds a full v2 report envelope containing one band whose Children array
  is supplied verbatim as AChildrenJSON.  Used to pin the nested band-child
  loading policy (unknown preservation, strict failure, band ownership). }
function BuildBandWithChildrenJSON(const AChildrenJSON: string): string;
begin
  Result :=
    '{' +
    '  "Version": 2,' +
    '  "Title": "BandChildren",' +
    '  "Author": "",' +
    '  "Description": "",' +
    '  "PageSettings": {' +
    '    "PaperSize": 9,' +
    '    "Orientation": 0,' +
    '    "MarginLeft": 40,' +
    '    "MarginTop": 40,' +
    '    "MarginRight": 40,' +
    '    "MarginBottom": 40,' +
    '    "CustomWidth": 0,' +
    '    "CustomHeight": 0' +
    '  },' +
    '  "FieldNames": [],' +
    '  "DataSetNames": [],' +
    '  "Objects": [' +
    '    {' +
    '      "Class": "TReportBand",' +
    '      "BandType": 4,' +
    '      "Bounds": {"L":0,"T":0,"R":10,"B":10},' +
    '      "Children": ' + AChildrenJSON +
    '    }' +
    '  ]' +
    '}';
end;

procedure TReportDesignerLoadTests.Test_FailedLoad_GetReportJSON_ReturnsOriginalInput;
var
  D: TVittixReportDesigner;
  ValidJSON, BadJSON, Got: string;
begin
  D := TVittixReportDesigner.Create(nil);
  try
    ValidJSON := BuildValidReportJSON('Original');
    BadJSON := BuildUnknownClassJSON('FutureObjectFromNewerVersion');

    D.ReportJSON := ValidJSON;
    Assert.IsTrue(Assigned(D.Report), 'valid load should populate Report');

    D.ReportJSON := BadJSON;

    Got := D.ReportJSON;
    Assert.AreEqual(BadJSON, Got,
      'after a failed load GetReportJSON must return the original input, ' +
      'not a serialization of the stale model');
  finally
    D.Free;
  end;
end;

procedure TReportDesignerLoadTests.Test_FailedLoad_DoesNotReplaceCurrentModel;
var
  D: TVittixReportDesigner;
  ValidJSON, BadJSON: string;
begin
  D := TVittixReportDesigner.Create(nil);
  try
    ValidJSON := BuildValidReportJSON('Original');
    BadJSON := BuildUnknownClassJSON('FutureObjectFromNewerVersion');

    D.ReportJSON := ValidJSON;
    Assert.AreEqual('Original', D.Report.Title);

    D.ReportJSON := BadJSON;

    Assert.IsTrue(Assigned(D.Report), 'Report must remain assigned after failed load');
    Assert.AreEqual('Original', D.Report.Title,
      'failed load must not disturb the previously-loaded model');
  finally
    D.Free;
  end;
end;

procedure TReportDesignerLoadTests.Test_FailedLoad_ThenSuccessfulLoad_RestoresCleanState;
var
  D: TVittixReportDesigner;
  ValidJSON, BadJSON, Got: string;
begin
  D := TVittixReportDesigner.Create(nil);
  try
    ValidJSON := BuildValidReportJSON('Replacement');
    BadJSON := BuildUnknownClassJSON('FutureObjectFromNewerVersion');

    D.ReportJSON := BadJSON;
    D.ReportJSON := ValidJSON;

    Got := D.ReportJSON;
    Assert.AreEqual(ValidJSON, Got,
      'a subsequent successful load must establish a clean serializable state');
    Assert.AreEqual('Replacement', D.Report.Title);
  finally
    D.Free;
  end;
end;

procedure TReportDesignerLoadTests.Test_SuccessfulLoad_ThenSave_Unchanged;
var
  D: TVittixReportDesigner;
  ValidJSON, Got: string;
begin
  D := TVittixReportDesigner.Create(nil);
  try
    ValidJSON := BuildValidReportJSON('Persisted');
    D.ReportJSON := ValidJSON;

    Got := D.ReportJSON;
    Assert.AreEqual(ValidJSON, Got,
      'successful load + save must round-trip the report unchanged');
  finally
    D.Free;
  end;
end;

procedure TReportDesignerLoadTests.Test_UnknownClass_Strict_Raises;
begin
  Assert.WillRaise(
    procedure begin
      var M := TReportSerializer.LoadFromJSON(
        BuildUnknownClassJSON('NoSuchThing'));
      M.Free;
    end,
    Exception, 'strict load must raise on unknown class');
end;

procedure TReportDesignerLoadTests.Test_UnknownClass_Tolerant_PreservesAndWarns;
var
  M: TReportModel;
  Warnings: TArray<string>;
  JSON: string;
begin
  // Tolerant policy contract (Phase 4I-18R): unknown classes are preserved
  // as TReportUnknownObject instances with a warning -- never silently
  // discarded.  (These assertions previously characterized the legacy
  // skip-and-drop behaviour; preservation is the mandated contract.)
  JSON := BuildMixedJSON(['TReportTextObject', 'FutureObject', 'TReportMemoObject']);
  M := TReportSerializer.LoadFromJSONTolerant(JSON, Warnings);
  try
    Assert.AreEqual(1, Length(Warnings), 'exactly one unknown object must be reported');
    Assert.IsTrue(ContainsText(Warnings[0], 'FutureObject'),
      'warning must name the unknown class');
    Assert.AreEqual(3, M.Objects.Count,
      'known objects must be loaded and the unknown one preserved');
    Assert.IsTrue(M.Objects[1] is TReportUnknownObject,
      'unknown object must be preserved as TReportUnknownObject');
  finally
    M.Free;
  end;
end;

procedure TReportDesignerLoadTests.Test_UnknownClass_Tolerant_KnownObjectsSurvive;
var
  M: TReportModel;
  Warnings: TArray<string>;
begin
  M := TReportSerializer.LoadFromJSONTolerant(
    BuildMixedJSON(['TReportTextObject', 'FutureObject', 'TReportMemoObject']), Warnings);
  try
    Assert.AreEqual('TReportTextObject', M.Objects[0].ClassName);
    Assert.IsTrue(M.Objects[1] is TReportUnknownObject,
      'unknown object must be preserved between the known ones');
    Assert.AreEqual('TReportMemoObject', M.Objects[2].ClassName);
  finally
    M.Free;
  end;
end;

procedure TReportDesignerLoadTests.Test_UnknownClass_Tolerant_OrderingPreserved;
var
  M: TReportModel;
  Warnings: TArray<string>;
begin
  M := TReportSerializer.LoadFromJSONTolerant(
    BuildMixedJSON(['TReportTextObject', 'FutureObject', 'TReportMemoObject']), Warnings);
  try
    Assert.AreEqual('TReportTextObject', M.Objects[0].ClassName);
    Assert.IsTrue(M.Objects[1] is TReportUnknownObject,
      'unknown object must stay in its original position');
    Assert.AreEqual('TReportMemoObject', M.Objects[2].ClassName,
      'relative order of known objects must be preserved');
  finally
    M.Free;
  end;
end;

procedure TReportDesignerLoadTests.Test_UnknownClass_Tolerant_MultipleUnknownsReported;
var
  M: TReportModel;
  Warnings: TArray<string>;
begin
  M := TReportSerializer.LoadFromJSONTolerant(
    BuildMixedJSON(['UnknownA', 'TReportTextObject', 'UnknownB']), Warnings);
  try
    Assert.AreEqual(2, Length(Warnings), 'both unknowns must be reported');
    Assert.IsTrue(ContainsText(Warnings[0], 'UnknownA'));
    Assert.IsTrue(ContainsText(Warnings[1], 'UnknownB'));
    Assert.AreEqual(3, M.Objects.Count,
      'unknown objects preserved, known object loads');
    Assert.IsTrue(M.Objects[0] is TReportUnknownObject,
      'first unknown preserved in place');
    Assert.AreEqual('TReportTextObject', M.Objects[1].ClassName,
      'known object loads between the unknowns');
    Assert.IsTrue(M.Objects[2] is TReportUnknownObject,
      'second unknown preserved in place');
  finally
    M.Free;
  end;
end;

procedure TReportDesignerLoadTests.Test_UnknownClass_Tolerant_EmptyAndMissingObjects;
var
  M: TReportModel;
  Warnings: TArray<string>;
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  Root.AddPair('Version', TJSONNumber.Create(2));
  Root.AddPair('Title', 'Empty');
  Root.AddPair('Objects', TJSONArray.Create);
  M := TReportSerializer.LoadFromJSONTolerant(Root.Format(2), Warnings);
  try
    Assert.AreEqual(0, M.Objects.Count);
    Assert.AreEqual(0, Length(Warnings));
  finally
    M.Free;
    Root.Free;
  end;

  Root := TJSONObject.Create;
  Root.AddPair('Version', TJSONNumber.Create(2));
  Root.AddPair('Title', 'NoObjects');
  M := TReportSerializer.LoadFromJSONTolerant(Root.Format(2), Warnings);
  try
    Assert.AreEqual(0, M.Objects.Count);
    Assert.AreEqual(0, Length(Warnings));
  finally
    M.Free;
    Root.Free;
  end;
end;

procedure TReportDesignerLoadTests.Test_UnknownChild_Tolerant_Preserved;
var
  M: TReportModel;
  Warnings: TArray<string>;
  U: TReportUnknownObject;
begin
  // Finding C repair: an unknown object inside band Children must be
  // preserved through the same policy-aware path as top-level objects,
  // without disturbing the band hierarchy.
  M := TReportSerializer.LoadFromJSONTolerant(
    BuildBandWithChildrenJSON(
      '[' +
      '{"Class":"TReportTextObject","Name":"KnownChild","Text":"Hi"},' +
      '{"Class":"com.acme.FutureWidget","Name":"Z1","CustomNumber":42,' +
      '"Nested":{"Alpha":1},"NullProp":null,"Tags":["x","y"]}' +
      ']'), Warnings);
  try
    // Band hierarchy invariant: the band is the only top-level object.
    Assert.AreEqual(1, M.Objects.Count, 'band must be the only top-level object');
    Assert.IsTrue(M.Objects[0] is TReportBand, 'top-level object must be the band');
    Assert.AreEqual(2, TReportBand(M.Objects[0]).Children.Count,
      'both children must belong to the band');
    Assert.IsTrue(TReportBand(M.Objects[0]).Children[0] is TReportTextObject,
      'known child must load normally');
    Assert.IsTrue(TReportBand(M.Objects[0]).Children[1] is TReportUnknownObject,
      'unknown child must be preserved as TReportUnknownObject');

    U := TReportUnknownObject(TReportBand(M.Objects[0]).Children[1]);
    Assert.AreEqual('com.acme.FutureWidget', U.OriginalClassName,
      'unknown child must keep its original discriminator');
    Assert.Contains(U.RawJSON, '"CustomNumber":42');
    Assert.Contains(U.RawJSON, '"Nested":{"Alpha":1}');
    Assert.Contains(U.RawJSON, '"NullProp":null');

    Assert.AreEqual(1, Length(Warnings), 'exactly one unknown-child warning');
    Assert.IsTrue(ContainsText(Warnings[0], 'com.acme.FutureWidget'),
      'warning must name the unknown child class');
  finally
    M.Free;
  end;
end;

procedure TReportDesignerLoadTests.Test_UnknownChild_Strict_Fails;
begin
  // Strict contract: an unknown object inside band Children fails the load
  // with the documented unknown-class error (no silent discard).
  Assert.WillRaise(
    procedure
    var
      M: TReportModel;
    begin
      M := TReportSerializer.LoadFromJSON(
        BuildBandWithChildrenJSON(
          '[' +
          '{"Class":"TReportTextObject","Name":"KnownChild"},' +
          '{"Class":"com.acme.FutureWidget","Name":"Z1"}' +
          ']'));
      M.Free;
    end,
    Exception, 'strict load must fail on unknown band child');
end;

procedure TReportDesignerLoadTests.Test_UnknownChild_Tolerant_SaveReload_RawPreserved;
var
  M, M2: TReportModel;
  Warnings, Warnings2: TArray<string>;
  Saved: string;
  U, U2: TReportUnknownObject;
begin
  M := TReportSerializer.LoadFromJSONTolerant(
    BuildBandWithChildrenJSON(
      '[' +
      '{"Class":"TReportTextObject","Name":"KnownChild","Text":"Hi"},' +
      '{"Class":"com.acme.FutureWidget","Name":"Z1","CustomNumber":42,' +
      '"Nested":{"Alpha":1},"NullProp":null,"Tags":["x","y"]}' +
      ']'), Warnings);
  try
    Saved := TReportSerializer.SaveToJSON(M);

    M2 := TReportSerializer.LoadFromJSONTolerant(Saved, Warnings2);
    try
      Assert.AreEqual(1, M2.Objects.Count,
        'band must remain the only top-level object after save/reload');
      Assert.AreEqual(2, TReportBand(M2.Objects[0]).Children.Count,
        'children must survive the save/reload round-trip');
      Assert.AreEqual('KnownChild',
        TReportBand(M2.Objects[0]).Children[0].Name,
        'known child and ordering must be preserved');
      Assert.IsTrue(TReportBand(M2.Objects[0]).Children[1] is TReportUnknownObject,
        'unknown child must survive the round-trip');

      U := TReportUnknownObject(TReportBand(M.Objects[0]).Children[1]);
      U2 := TReportUnknownObject(TReportBand(M2.Objects[0]).Children[1]);
      Assert.AreEqual(U.OriginalClassName, U2.OriginalClassName,
        'unknown child discriminator must survive the round-trip');
      Assert.AreEqual(U.RawJSON, U2.RawJSON,
        'raw JSON of the nested unknown object must be preserved');
    finally
      M2.Free;
    end;
  finally
    M.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TReportDesignerLoadTests);

end.