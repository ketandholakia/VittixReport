unit Test.Vittix.Runner.Resources;

{
  Phase 3F-4: focused tests for the extracted resource measurement unit
  (Vittix.Runner.Resources). Only deterministic/pure aspects are asserted:

    - TProcessResourceSnapshot default semantics (zeroed record)
    - record copy semantics (value type, no reference behavior)

  Note: the raw counter values themselves (GDI/USER/memory) are
  environment-dependent OS/delphi-runtime readings and are deliberately
  NOT asserted here; in particular AllocMemSize reads 0 in this Delphi 12
  runtime (the runner has always printed "Memory Alloc: 0 KB -> 0 KB"),
  so no meaningful deterministic invariant exists for it. No fake leak
  conditions, no report execution, no canonical report or baseline access,
  no global process state changes.
}

interface

uses
  DUnitX.TestFramework,
  Vittix.Runner.Resources;

type
  [TestFixture]
  TProcessResourceTests = class
  public
    [Test] procedure Test_DefaultSnapshot_IsZeroed;
    [Test] procedure Test_SnapshotCopy_PreservesValues;
  end;

implementation

procedure TProcessResourceTests.Test_DefaultSnapshot_IsZeroed;
var
  S: TProcessResourceSnapshot;
begin
  S := Default(TProcessResourceSnapshot);
  Assert.AreEqual(Cardinal(0), S.GDI);
  Assert.AreEqual(Cardinal(0), S.User);
  Assert.AreEqual(Int64(0), S.MemoryBytes);
end;

procedure TProcessResourceTests.Test_SnapshotCopy_PreservesValues;
var
  A, B: TProcessResourceSnapshot;
begin
  A := Default(TProcessResourceSnapshot);
  A.GDI := 11;
  A.User := 22;
  A.MemoryBytes := 334455;

  // Record assignment must behave as a value copy.
  B := A;
  A.GDI := 99;
  A.User := 98;
  A.MemoryBytes := 97;

  Assert.AreEqual(Cardinal(11), B.GDI);
  Assert.AreEqual(Cardinal(22), B.User);
  Assert.AreEqual(Int64(334455), B.MemoryBytes);
end;

initialization
  TDUnitX.RegisterTestFixture(TProcessResourceTests);

end.