unit Test.Vittix.Runner.Baseline.Legacy;

{
  Phase 3E-4: tolerant (legacy / non-strict) baseline tests.

  TLegacyBaseline is a pure policy object. Tests use temporary files and
  directories only, always cleaned up with try/finally. The canonical
  reports directory and reports/regression_baselines.json are NEVER used
  as test input or output targets.
}

interface

uses
  DUnitX.TestFramework,
  Vittix.Runner.Baseline.Legacy;

type
  [TestFixture]
  TLegacyBaselineTests = class
  private
    function MakeTempDir: string;
    function MakeTempFile(const AContent: string): string;
    procedure WriteText(const AFileName, AContent: string);
    function ReadText(const AFileName: string): string;
  public
    // Load
    [Test] procedure Test_Load_ValidFile;
    [Test] procedure Test_Load_MissingFile_Empty;
    [Test] procedure Test_Load_MalformedJson_Empty;
    [Test] procedure Test_Load_EmptyFile_Empty;
    [Test] procedure Test_Load_ArrayRoot_Empty;
    [Test] procedure Test_Load_ScalarRoot_Empty;
    // Lookup
    [Test] procedure Test_Lookup_Existing;
    [Test] procedure Test_Lookup_CaseInsensitive;
    [Test] procedure Test_Lookup_Missing_False;
    [Test] procedure Test_Lookup_DuplicateKeys_LastWins;
    [Test] procedure Test_Lookup_NonNumericValue_False;
    [Test] procedure Test_Lookup_DoesNotModify;
    // Registration
    [Test] procedure Test_Register_StoresActualCount;
    [Test] procedure Test_Register_SetsModified;
    [Test] procedure Test_LoadOnly_NotModified;
    [Test] procedure Test_LookupThenRegister_SinglePair;
    [Test] procedure Test_Register_Multiple_PreservesOrder;
    // Save
    [Test] procedure Test_Save_Unmodified_FileUntouched;
    [Test] procedure Test_Save_Unmodified_NoFileCreated;
    [Test] procedure Test_Save_Modified_WritesFile;
    [Test] procedure Test_Save_Format2_ByteExact;
    [Test] procedure Test_Save_RoundTrip;
    [Test] procedure Test_Save_Utf8Encoding;
    // Ownership / leaks
    [Test] procedure Test_RepeatedLoadFree_NoLeak;
    [Test] procedure Test_SaveThenFree_NoLeak;
    [Test] procedure Test_DestroyWithoutSave_NoLeak;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  System.JSON;

function TLegacyBaselineTests.MakeTempDir: string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'vittix_legacy_' + TGuid.NewGuid.ToString);
  TDirectory.CreateDirectory(Result);
end;

function TLegacyBaselineTests.MakeTempFile(const AContent: string): string;
begin
  Result := TPath.Combine(MakeTempDir, 'baseline.json');
  WriteText(Result, AContent);
end;

procedure TLegacyBaselineTests.WriteText(const AFileName, AContent: string);
begin
  TFile.WriteAllText(AFileName, AContent, TEncoding.UTF8);
end;

function TLegacyBaselineTests.ReadText(const AFileName: string): string;
begin
  Result := TFile.ReadAllText(AFileName, TEncoding.UTF8);
end;

// ---------------------------------------------------------------------------
// Load
// ---------------------------------------------------------------------------

procedure TLegacyBaselineTests.Test_Load_ValidFile;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile(
    '{' + sLineBreak +
    '  "a.vrt": 5,' + sLineBreak +
    '  "b.vrt": 10' + sLineBreak +
    '}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsFalse(Baseline.Modified);
      Assert.IsTrue(Baseline.TryGetExpectedPages('a.vrt', Pages));
      Assert.AreEqual(5, Pages);
      Assert.IsTrue(Baseline.TryGetExpectedPages('b.vrt', Pages));
      Assert.AreEqual(10, Pages);
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Load_MissingFile_Empty;
var
  MissingFile: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  MissingFile := TPath.Combine(MakeTempDir, 'does_not_exist.json');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(MissingFile);
    try
      Assert.IsFalse(Baseline.Modified);
      // No entries: any lookup fails.
      Assert.IsFalse(Baseline.TryGetExpectedPages('a.vrt', Pages));
    finally
      Baseline.Free;
    end;
  finally
    TDirectory.Delete(TPath.GetDirectoryName(MissingFile), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Load_MalformedJson_Empty;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('{ this is not valid json');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsFalse(Baseline.Modified);
      Assert.IsFalse(Baseline.TryGetExpectedPages('a.vrt', Pages));
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;
procedure TLegacyBaselineTests.Test_Load_EmptyFile_Empty;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsFalse(Baseline.Modified);
      Assert.IsFalse(Baseline.TryGetExpectedPages('a.vrt', Pages));
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Load_ArrayRoot_Empty;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('[1,2,3]');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsFalse(Baseline.Modified);
      Assert.IsFalse(Baseline.TryGetExpectedPages('a.vrt', Pages));
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Load_ScalarRoot_Empty;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('42');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsFalse(Baseline.Modified);
      Assert.IsFalse(Baseline.TryGetExpectedPages('a.vrt', Pages));
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

// ---------------------------------------------------------------------------
// Lookup
// ---------------------------------------------------------------------------

procedure TLegacyBaselineTests.Test_Lookup_Existing;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('{"a.vrt": 7}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsTrue(Baseline.TryGetExpectedPages('a.vrt', Pages));
      Assert.AreEqual(7, Pages);
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Lookup_CaseInsensitive;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('{"My_Report.VRT": 3}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsTrue(Baseline.TryGetExpectedPages('my_report.vrt', Pages));
      Assert.AreEqual(3, Pages);
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Lookup_Missing_False;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('{"a.vrt": 1}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsFalse(Baseline.TryGetExpectedPages('nope.vrt', Pages));
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Lookup_DuplicateKeys_LastWins;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('{"r.vrt": 1, "r.vrt": 9}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsTrue(Baseline.TryGetExpectedPages('r.vrt', Pages));
      Assert.AreEqual(9, Pages);
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Lookup_NonNumericValue_False;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('{"s.vrt": "abc", "n.vrt": null}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsFalse(Baseline.TryGetExpectedPages('s.vrt', Pages));
      Assert.IsFalse(Baseline.TryGetExpectedPages('n.vrt', Pages));
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Lookup_DoesNotModify;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('{"a.vrt": 7}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsTrue(Baseline.TryGetExpectedPages('a.vrt', Pages));
      Assert.AreEqual(7, Pages);
      // Lookups must never mutate state.
      Assert.IsFalse(Baseline.Modified);
      Assert.IsTrue(Baseline.TryGetExpectedPages('a.vrt', Pages));
      Assert.AreEqual(7, Pages);
      Assert.IsFalse(Baseline.TryGetExpectedPages('missing.vrt', Pages));
      Assert.IsFalse(Baseline.Modified);
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;
// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

procedure TLegacyBaselineTests.Test_Register_StoresActualCount;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Pages: Integer;
begin
  FileName := MakeTempFile('{}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Baseline.RegisterReport('a.vrt', 7);
      Assert.IsTrue(Baseline.TryGetExpectedPages('a.vrt', Pages));
      Assert.AreEqual(7, Pages);
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Register_SetsModified;
var
  FileName: string;
  Baseline: TLegacyBaseline;
begin
  FileName := MakeTempFile('{}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsFalse(Baseline.Modified);
      Baseline.RegisterReport('a.vrt', 7);
      Assert.IsTrue(Baseline.Modified);
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_LoadOnly_NotModified;
var
  FileName: string;
  Baseline: TLegacyBaseline;
begin
  FileName := MakeTempFile('{"a.vrt": 1}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      // Load alone must not mark the baseline modified.
      Assert.IsFalse(Baseline.Modified);
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_LookupThenRegister_SinglePair;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Root: TJSONObject;
  Pages: Integer;
begin
  FileName := MakeTempFile('{"a.vrt": 1}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      // Reproduce the console flow: lookup first, register only when the
      // entry is missing. An existing entry must never be duplicated.
      Assert.IsTrue(Baseline.TryGetExpectedPages('a.vrt', Pages));
      Assert.AreEqual(1, Pages);
      Assert.IsFalse(Baseline.TryGetExpectedPages('b.vrt', Pages));
      Baseline.RegisterReport('b.vrt', 2);
      Assert.IsTrue(Baseline.TryGetExpectedPages('b.vrt', Pages));
      Assert.AreEqual(2, Pages);
      // Saved file must contain exactly two pairs (no duplicated a.vrt).
      Baseline.SaveToFile(FileName);
    finally
      Baseline.Free;
    end;

    Root := TJSONObject.ParseJSONValue(ReadText(FileName)) as TJSONObject;
    try
      Assert.IsNotNull(Root);
      Assert.AreEqual(2, Root.Count);
      Assert.AreEqual('a.vrt', Root.Pairs[0].JsonString.Value);
      Assert.AreEqual('b.vrt', Root.Pairs[1].JsonString.Value);
    finally
      Root.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Register_Multiple_PreservesOrder;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Root: TJSONObject;
begin
  FileName := MakeTempFile('{}');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Baseline.RegisterReport('a.vrt', 5);
      Baseline.RegisterReport('b.vrt', 6);
      Baseline.RegisterReport('c.vrt', 7);
      Baseline.SaveToFile(FileName);
    finally
      Baseline.Free;
    end;

    Root := TJSONObject.ParseJSONValue(ReadText(FileName)) as TJSONObject;
    try
      Assert.IsNotNull(Root);
      Assert.AreEqual(3, Root.Count);
      // AddPair preserves insertion order (legacy mutation contract).
      Assert.AreEqual('a.vrt', Root.Pairs[0].JsonString.Value);
      Assert.AreEqual(5, Root.Pairs[0].JsonValue.Value.ToInteger);
      Assert.AreEqual('b.vrt', Root.Pairs[1].JsonString.Value);
      Assert.AreEqual(6, Root.Pairs[1].JsonValue.Value.ToInteger);
      Assert.AreEqual('c.vrt', Root.Pairs[2].JsonString.Value);
      Assert.AreEqual(7, Root.Pairs[2].JsonValue.Value.ToInteger);
    finally
      Root.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;
// ---------------------------------------------------------------------------
// Save
// ---------------------------------------------------------------------------

procedure TLegacyBaselineTests.Test_Save_Unmodified_FileUntouched;
var
  FileName: string;
  Baseline: TLegacyBaseline;
  Original: string;
begin
  // A baseline already in the canonical Format(2) layout must be written
  // back byte-identically when re-saved (Console only saves when it is
  // truly Modified).
  Original := '{' + sLineBreak +
              '  "a.vrt": 1' + sLineBreak +
              '}';
  FileName := MakeTempFile(Original);
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
    try
      Assert.IsFalse(Baseline.Modified);
      Baseline.SaveToFile(FileName);
    finally
      Baseline.Free;
    end;
    Assert.AreEqual(Original, ReadText(FileName));
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Save_Unmodified_NoFileCreated;
var
  MissingFile: string;
  Baseline: TLegacyBaseline;
begin
  MissingFile := TPath.Combine(MakeTempDir, 'never_created.json');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(MissingFile);
    try
      // Load alone (even on a missing file) must not create the file; the
      // write decision lives in the console runner, not here.
      Assert.IsFalse(TFile.Exists(MissingFile));
      Assert.IsFalse(Baseline.Modified);
    finally
      Baseline.Free;
    end;
    Assert.IsFalse(TFile.Exists(MissingFile));
  finally
    TDirectory.Delete(TPath.GetDirectoryName(MissingFile), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Save_Modified_WritesFile;
var
  OutFile: string;
  Baseline: TLegacyBaseline;
  Root: TJSONObject;
begin
  OutFile := TPath.Combine(MakeTempDir, 'out.json');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(TPath.Combine(
      TPath.GetDirectoryName(OutFile), 'missing.json'));
    try
      Baseline.RegisterReport('a.vrt', 7);
      Baseline.SaveToFile(OutFile);
    finally
      Baseline.Free;
    end;
    Assert.IsTrue(TFile.Exists(OutFile));
    Root := TJSONObject.ParseJSONValue(ReadText(OutFile)) as TJSONObject;
    try
      Assert.IsNotNull(Root);
      Assert.AreEqual(1, Root.Count);
      Assert.AreEqual(7, StrToInt(Root.Pairs[0].JsonValue.Value));
    finally
      Root.Free;
    end;
  finally
    if TFile.Exists(OutFile) then
      TFile.Delete(OutFile);
    TDirectory.Delete(TPath.GetDirectoryName(OutFile), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Save_Format2_ByteExact;
var
  OutFile: string;
  Baseline: TLegacyBaseline;
  Expected: string;
begin
  OutFile := TPath.Combine(MakeTempDir, 'fmt.json');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(TPath.Combine(
      TPath.GetDirectoryName(OutFile), 'missing.json'));
    try
      Baseline.RegisterReport('a.vrt', 1);
      Baseline.SaveToFile(OutFile);
    finally
      Baseline.Free;
    end;

    // TJSONObject.Format(2) uses sLineBreak (\r\n on Windows) and
    // 2-space indentation. ReadAllText(..., UTF8) strips the BOM.
    Expected := '{' + sLineBreak +
                '  "a.vrt": 1' + sLineBreak +
                '}';
    Assert.AreEqual(Expected, ReadText(OutFile));
  finally
    if TFile.Exists(OutFile) then
      TFile.Delete(OutFile);
    TDirectory.Delete(TPath.GetDirectoryName(OutFile), True);
  end;
end;
procedure TLegacyBaselineTests.Test_Save_RoundTrip;
var
  OutFile: string;
  Baseline: TLegacyBaseline;
  Reloaded: TLegacyBaseline;
  Pages: Integer;
begin
  OutFile := TPath.Combine(MakeTempDir, 'roundtrip.json');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(TPath.Combine(
      TPath.GetDirectoryName(OutFile), 'missing.json'));
    try
      Baseline.RegisterReport('a.vrt', 3);
      Baseline.RegisterReport('b.vrt', 8);
      Baseline.SaveToFile(OutFile);
    finally
      Baseline.Free;
    end;

    Reloaded := TLegacyBaseline.LoadOrEmpty(OutFile);
    try
      Assert.IsFalse(Reloaded.Modified);
      Assert.IsTrue(Reloaded.TryGetExpectedPages('a.vrt', Pages));
      Assert.AreEqual(3, Pages);
      Assert.IsTrue(Reloaded.TryGetExpectedPages('b.vrt', Pages));
      Assert.AreEqual(8, Pages);
    finally
      Reloaded.Free;
    end;
  finally
    if TFile.Exists(OutFile) then
      TFile.Delete(OutFile);
    TDirectory.Delete(TPath.GetDirectoryName(OutFile), True);
  end;
end;

procedure TLegacyBaselineTests.Test_Save_Utf8Encoding;
var
  OutFile: string;
  Baseline: TLegacyBaseline;
  Bytes: TBytes;
  Reloaded: TLegacyBaseline;
  Pages: Integer;
begin
  OutFile := TPath.Combine(MakeTempDir, 'utf8.json');
  try
    Baseline := TLegacyBaseline.LoadOrEmpty(TPath.Combine(
      TPath.GetDirectoryName(OutFile), 'missing.json'));
    try
      Baseline.RegisterReport('r'#$00E9'p_ort.vrt', 4);
      Baseline.SaveToFile(OutFile);
    finally
      Baseline.Free;
    end;

    Bytes := TFile.ReadAllBytes(OutFile);
    // UTF-8 BOM (EF BB BF) must be present, as produced by
    // TFile.WriteAllText(..., TEncoding.UTF8).
    if Length(Bytes) < 3 then
      Assert.IsTrue(False, 'Saved file too short to contain a UTF-8 BOM');
    Assert.AreEqual($EF, Bytes[0]);
    Assert.AreEqual($BB, Bytes[1]);
    Assert.AreEqual($BF, Bytes[2]);

    Reloaded := TLegacyBaseline.LoadOrEmpty(OutFile);
    try
      Assert.IsTrue(Reloaded.TryGetExpectedPages('r'#$00E9'p_ort.vrt', Pages));
      Assert.AreEqual(4, Pages);
    finally
      Reloaded.Free;
    end;
  finally
    if TFile.Exists(OutFile) then
      TFile.Delete(OutFile);
    TDirectory.Delete(TPath.GetDirectoryName(OutFile), True);
  end;
end;

// ---------------------------------------------------------------------------
// Ownership / leaks
// ---------------------------------------------------------------------------

procedure TLegacyBaselineTests.Test_RepeatedLoadFree_NoLeak;
var
  FileName: string;
  I: Integer;
  Baseline: TLegacyBaseline;
begin
  FileName := MakeTempFile('{"a.vrt": 1, "b.vrt": 2}');
  try
    for I := 1 to 100 do
    begin
      Baseline := TLegacyBaseline.LoadOrEmpty(FileName);
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
    TDirectory.Delete(TPath.GetDirectoryName(FileName), True);
  end;
end;

procedure TLegacyBaselineTests.Test_SaveThenFree_NoLeak;
var
  OutFile: string;
  I: Integer;
  Baseline: TLegacyBaseline;
begin
  OutFile := TPath.Combine(MakeTempDir, 'leak.json');
  try
    for I := 1 to 50 do
    begin
      Baseline := TLegacyBaseline.LoadOrEmpty(TPath.Combine(
        TPath.GetDirectoryName(OutFile), 'missing.json'));
      try
        Baseline.RegisterReport('a.vrt', I);
        Baseline.SaveToFile(OutFile);
      finally
        Baseline.Free;
      end;
    end;
  finally
    if TFile.Exists(OutFile) then
      TFile.Delete(OutFile);
    TDirectory.Delete(TPath.GetDirectoryName(OutFile), True);
  end;
end;

procedure TLegacyBaselineTests.Test_DestroyWithoutSave_NoLeak;
var
  I: Integer;
  Baseline: TLegacyBaseline;
begin
  for I := 1 to 50 do
  begin
    Baseline := TLegacyBaseline.LoadOrEmpty(TPath.Combine(
      TPath.GetTempPath, 'vittix_legacy_never_exists.json'));
    try
      Baseline.RegisterReport('a.vrt', I);
    finally
      Baseline.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLegacyBaselineTests);

end.