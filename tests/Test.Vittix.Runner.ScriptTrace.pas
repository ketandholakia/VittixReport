unit Test.Vittix.Runner.ScriptTrace;

{
  Phase 3E-5: focused tests for the extracted script-trace presentation
  unit (Vittix.Runner.ScriptTrace). Tests use in-memory report objects and
  a capturing writer (TStringList); no report files are touched.
}

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Scripting,
  Vittix.Report.ScriptHost.Adapter,
  Vittix.Runner.ScriptTrace;

type
  [TestFixture]
  TScriptTraceTests = class
  private
    FAdapter: TReportScriptHostAdapter;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure Test_NilObject_NoOutput;
    [Test] procedure Test_BeforeScript_RendersBeforeBlock;
    [Test] procedure Test_AfterScript_RendersAfterBlock;
    [Test] procedure Test_TraceMessage_ReIndented;
    [Test] procedure Test_NoScripts_NoOutput;
    [Test] procedure Test_Indentation_ByLevel;
    [Test] procedure Test_ObjectName_Quoted;
    [Test] procedure Test_ObjectName_Unnamed_UsesClassNameOnly;
    [Test] procedure Test_Tree_BandChildren_TraversedDepthFirst;
    [Test] procedure Test_Tree_NestedBands_MultiLevel;
  end;

implementation

procedure TScriptTraceTests.Setup;
begin
  FAdapter := TReportScriptHostAdapter.Create;
end;

procedure TScriptTraceTests.TearDown;
begin
  FreeAndNil(FAdapter);
end;

procedure TScriptTraceTests.Test_NilObject_NoOutput;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    WriteScriptTraceObject(FAdapter, nil, 2,
      procedure(const ALine: string)
      begin
        Lines.Add(ALine);
      end);
    Assert.AreEqual(0, Lines.Count, 'nil object must produce no output');
  finally
    Lines.Free;
  end;
end;

procedure TScriptTraceTests.Test_BeforeScript_RendersBeforeBlock;
var
  Obj: TReportTextObject;
  Lines: TStringList;
begin
  Obj := TReportTextObject.Create;
  try
    Obj.Name := 'Lbl1';
    Obj.OnBeforePrint := 'autosize:=True';
    Lines := TStringList.Create;
    try
      WriteScriptTraceObject(FAdapter, Obj, 2,
        procedure(const ALine: string)
        begin
          Lines.Add(ALine);
        end);
      Assert.AreEqual(3, Lines.Count, 'expected [Before] header, object and trace lines');
      Assert.AreEqual('    [Before] TReportTextObject "Lbl1"', Lines[0]);
      Assert.AreEqual('      TReportTextObject "Lbl1":', Lines[1]);
      Assert.AreEqual('        ScriptSetAutoSize: TReportTextObject "Lbl1" -> True', Lines[2]);
    finally
      Lines.Free;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TScriptTraceTests.Test_AfterScript_RendersAfterBlock;
var
  Obj: TReportTextObject;
  Lines: TStringList;
begin
  Obj := TReportTextObject.Create;
  try
    Obj.Name := 'Lbl1';
    Obj.OnAfterPrint := 'autosize:=True';
    Lines := TStringList.Create;
    try
      WriteScriptTraceObject(FAdapter, Obj, 2,
        procedure(const ALine: string)
        begin
          Lines.Add(ALine);
        end);
      Assert.AreEqual(3, Lines.Count, 'expected [After ] header, object and trace lines');
      Assert.AreEqual('    [After ] TReportTextObject "Lbl1"', Lines[0]);
      Assert.AreEqual('      TReportTextObject "Lbl1":', Lines[1]);
      Assert.AreEqual('        ScriptSetAutoSize: TReportTextObject "Lbl1" -> True', Lines[2]);
    finally
      Lines.Free;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TScriptTraceTests.Test_TraceMessage_ReIndented;
var
  Obj: TReportTextObject;
  Lines: TStringList;
begin
  Obj := TReportTextObject.Create;
  try
    Obj.Name := 'Lbl1';
    // Two statements produce a two-line TraceMessage (sLineBreak-joined),
    // which must be re-indented by Indent + two spaces (level 2 -> 6 spaces).
    Obj.OnBeforePrint := 'autosize:=True;wordwrap:=True';
    Lines := TStringList.Create;
    try
      WriteScriptTraceObject(FAdapter, Obj, 2,
        procedure(const ALine: string)
        begin
          Lines.Add(ALine);
        end);
      Assert.AreEqual(3, Lines.Count);
      Assert.Contains(Lines[2], 'ScriptSetAutoSize');
      Assert.Contains(Lines[2], sLineBreak, 'multiline trace message must be preserved');
      Assert.Contains(Lines[2], sLineBreak + '      ScriptSetWordWrap: TReportTextObject "Lbl1" -> True',
        'continuation lines must be re-indented with Indent + 2 spaces');
    finally
      Lines.Free;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TScriptTraceTests.Test_NoScripts_NoOutput;
var
  Obj: TReportTextObject;
  Lines: TStringList;
begin
  Obj := TReportTextObject.Create;
  try
    Obj.Name := 'Lbl1';
    Lines := TStringList.Create;
    try
      WriteScriptTraceObject(FAdapter, Obj, 2,
        procedure(const ALine: string)
        begin
          Lines.Add(ALine);
        end);
      Assert.AreEqual(0, Lines.Count, 'object without scripts must produce no output');
    finally
      Lines.Free;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TScriptTraceTests.Test_Indentation_ByLevel;
var
  Obj: TReportTextObject;
  Lines: TStringList;
begin
  Obj := TReportTextObject.Create;
  try
    Obj.Name := 'Lbl1';
    Obj.OnBeforePrint := 'autosize:=True';
    Lines := TStringList.Create;
    try
      WriteScriptTraceObject(FAdapter, Obj, 3,
        procedure(const ALine: string)
        begin
          Lines.Add(ALine);
        end);
      // Level 3 -> ALevel * 2 = 6 spaces of indentation.
      Assert.AreEqual('      [Before] TReportTextObject "Lbl1"', Lines[0]);
      Assert.AreEqual('        TReportTextObject "Lbl1":', Lines[1]);
      Assert.AreEqual('          ScriptSetAutoSize: TReportTextObject "Lbl1" -> True', Lines[2]);
    finally
      Lines.Free;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TScriptTraceTests.Test_ObjectName_Quoted;
var
  Obj: TReportTextObject;
  Lines: TStringList;
begin
  Obj := TReportTextObject.Create;
  try
    Obj.Name := 'MyLabel';
    Obj.OnBeforePrint := 'autosize:=True';
    Lines := TStringList.Create;
    try
      WriteScriptTraceObject(FAdapter, Obj, 2,
        procedure(const ALine: string)
        begin
          Lines.Add(ALine);
        end);
      Assert.StartsWith('    [Before] TReportTextObject "MyLabel"', Lines[0]);
    finally
      Lines.Free;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TScriptTraceTests.Test_ObjectName_Unnamed_UsesClassNameOnly;
var
  Obj: TReportTextObject;
  Lines: TStringList;
begin
  Obj := TReportTextObject.Create;
  try
    Obj.Name := '';
    Obj.OnBeforePrint := 'autosize:=True';
    Lines := TStringList.Create;
    try
      WriteScriptTraceObject(FAdapter, Obj, 2,
        procedure(const ALine: string)
        begin
          Lines.Add(ALine);
        end);
      Assert.StartsWith('    [Before] TReportTextObject', Lines[0]);
      Assert.DoesNotContain('"', Lines[0], 'unnamed object must not render quotes');
    finally
      Lines.Free;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TScriptTraceTests.Test_Tree_BandChildren_TraversedDepthFirst;
var
  Band: TReportBand;
  Child1, Child2: TReportTextObject;
  Lines: TStringList;
begin
  Band := TReportBand.Create;
  try
    Band.Name := 'Detail1';
    Child1 := TReportTextObject.Create;
    Child1.Name := 'Child1';
    Child1.OnBeforePrint := 'autosize:=True';
    Child2 := TReportTextObject.Create;
    Child2.Name := 'Child2';
    Child2.OnBeforePrint := 'autosize:=True';
    Band.Children.Add(Child1);
    Band.Children.Add(Child2);
    Lines := TStringList.Create;
    try
      WriteScriptTraceTree(FAdapter, Band, 2,
        procedure(const ALine: string)
        begin
          Lines.Add(ALine);
        end);
      // Band itself has no script; children rendered depth-first in
      // order, each child emitting a 3-line [Before] block.
      Assert.AreEqual(6, Lines.Count);
      Assert.StartsWith('      [Before] TReportTextObject "Child1"', Lines[0]);
      Assert.StartsWith('      [Before] TReportTextObject "Child2"', Lines[3]);
    finally
      Lines.Free;
    end;
  finally
    Band.Free;
  end;
end;

procedure TScriptTraceTests.Test_Tree_NestedBands_MultiLevel;
var
  Outer, Inner: TReportBand;
  Leaf: TReportTextObject;
  Lines: TStringList;
begin
  Outer := TReportBand.Create;
  try
    Outer.Name := 'Outer';
    Inner := TReportBand.Create;
    Inner.Name := 'Inner';
    Leaf := TReportTextObject.Create;
    Leaf.Name := 'Leaf';
    Leaf.OnBeforePrint := 'autosize:=True';
    Inner.Children.Add(Leaf);
    Outer.Children.Add(Inner);
    Lines := TStringList.Create;
    try
      WriteScriptTraceTree(FAdapter, Outer, 2,
        procedure(const ALine: string)
        begin
          Lines.Add(ALine);
        end);
      // Outer band at level 2 (4 spaces), inner band child at level 3
      // (6 spaces), leaf at level 4 (8 spaces). Bands without scripts
      // produce no output themselves; the leaf emits a 3-line block.
      Assert.AreEqual(3, Lines.Count);
      Assert.StartsWith('        [Before] TReportTextObject "Leaf"', Lines[0]);
    finally
      Lines.Free;
    end;
  finally
    Outer.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TScriptTraceTests);

end.
