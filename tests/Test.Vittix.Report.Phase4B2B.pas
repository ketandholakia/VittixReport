unit Test.Vittix.Report.Phase4B2B;

{
  Phase 4B-2B — Modern Expression Semantics: Contract & Characterization Tests.

  This unit establishes the executable contract for the planned modern
  expression language (docs/Phase4B2A-Modern-Expression-Semantics.md).
  Because no modern evaluator exists in this codebase yet, every test
  exercises the CURRENT legacy evaluator and documents the baseline
  behavior a future implementation must either preserve (compatibility)
  or deliberately change (modern semantics, flagged per the design doc).

  Coverage map (per task brief):
    A. Tokenizer / lexing          — bracket token shapes, string forms, keyword case
    B. Parser / AST shape          — single-token vs multi-token, flat evaluation
    C. Precedence                  — flat L→R characterization (no precedence in legacy)
    D. Boolean / NULL / Kleene     — NULL text, boolean coercion, truthiness
    E. Arithmetic                  — signed, division-by-zero, malformed
    F. Functions                    — none exist; unknown names fall through
    G. Aggregates / composition     — prefix truncation, composition, nested rejection
    H. Data resolution              — fields, params, vars, system tokens
    I. Diagnostics / limits         — no diagnostics in legacy; zero limits enforced
    J. Serialization mode           — .vrt has no ExpressionLanguageVersion key
    K. Compatibility default legacy  — two-arg Evaluate never consults mode
    L. Cache / mutation isolation   — Phase 3 cache survives Prepare; cursor restored

  No legacy behavior is changed. No legacy test, fixture, or source is
  modified. New files: this unit, this unit's modern fixtures, and the
  dpr registration line.
}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.IOUtils,
  System.Variants,
  System.Generics.Collections,
  Data.DB,
  Datasnap.DBClient,
  DUnitX.TestFramework,
  Vcl.Graphics,
  Vittix.Report.Context,
  Vittix.Report.Expressions,
  Vittix.Report.Expression.Mode,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Engine,
  Vittix.Report.Serializer,
  Vittix.Report.Export.Commands,
  Vittix.Report.Export.Text,
  Vittix.Report.TraversalDiagnostics,
  Vittix.Report.Utils,
  Vittix.Report.Expression.Evaluator,
  Vittix.Report.Expression.Language,
  Vittix.Report.Expression.Diagnostics,
  Vittix.Report.Expression.Migration,
  Vittix.Report.LoadResult,
  Test.Vittix.Report.ExpressionLegacyReference;

type
  [TestFixture]
  TPhase4B2BModernExpressionTests = class
  private
    FDataSet: TClientDataSet;
    FParameters: TStringList;
    FVariables: TStringList;
    FContext: TExpressionContext;
    FRow1ID: Integer;
    FRow1Amount: Double;
    FRow1Name: string;

    procedure BuildDataSet;
    function Eval(const AExpr: string): Variant;
    function VariantText(const V: Variant): string;
    function FindModernFixturesDir: string;
    function CollectDocumentTexts(ADoc: TReportExportDocument): TArray<string>;
    function CollectCommandCount(ADoc: TReportExportDocument): Integer;
    procedure AssertDifferential(const AExpr: string);
    function DifferentialCorpus: TArray<string>;
    procedure BuildModelAndEngine(out AModel: TReportModel; out AEngine: TReportEngine);
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    { A. Tokenizer / lexing }
    [Test] procedure Test_Tokenizer_BracketTokenShapes;
    [Test] procedure Test_Tokenizer_StringLiteralForms;
    [Test] procedure Test_Tokenizer_KeywordCaseInsensitive;

    { B. Parser / AST shape }
    [Test] procedure Test_ASTShape_SingleTokenVsMultiToken;
    [Test] procedure Test_ASTShape_FlatEvaluationPath;

    { C. Precedence }
    [Test] procedure Test_Precedence_LegacyFlatLeftToRight;

    { D. Boolean / NULL / Kleene }
    [Test] procedure Test_BooleanNULL_NullIsTextNotVariant;
    [Test] procedure Test_BooleanNULL_TruthinessMapping;
    [Test] procedure Test_BooleanNULL_KleeneNotImplemented;

    { E. Arithmetic }
    [Test] procedure Test_Arithmetic_SignedAndDivision;
    [Test] procedure Test_Arithmetic_MalformedFallback;

    { F. Functions }
    [Test] procedure Test_Functions_NoneExist_FallbackToText;

    { G. Aggregates / composition / nested rejection }
    [Test] procedure Test_Aggregate_PrefixTruncation;
    [Test] procedure Test_Aggregate_CompositionLegacyTruncates;
    [Test] procedure Test_Aggregate_NestedRejection;
    [Test] procedure Test_Aggregate_GroupRange;

    { H. Data resolution }
    [Test] procedure Test_DataResolution_Fields;
    [Test] procedure Test_DataResolution_Parameters;
    [Test] procedure Test_DataResolution_Variables;
    [Test] procedure Test_DataResolution_SystemTokens;

    { I. Diagnostics / limits }
    [Test] procedure Test_Diagnostics_LegacyHasNoDiagnostics;

    { J. Serialization mode }
    [Test] procedure Test_SerializationMode_NoExpressionLanguageVersion;

    { K. Compatibility default legacy }
    [Test] procedure Test_Compatibility_LegacyIsDefault;

    { L. Cache / mutation isolation }
    [Test] procedure Test_Cache_RepeatedAggregatePreservesCursor;
    [Test] procedure Test_Cache_ClearedPerPrepare;
    [Test] procedure Test_Cache_MutationDoesNotAffectLegacy;
  end;

  { Modern-mode evaluator tests: EXPLICIT emModern opt-in (Phase 4B-2B). }
  [TestFixture]
  TPhase4B2BModernEvaluatorTests = class
  private
    FDataSet: TClientDataSet;
    FParameters: TStringList;
    FVariables: TStringList;
    FContext: TExpressionContext;
    function EvalModern(const AExpr: string): Variant;
    function EvalModernRaises(const AExpr: string): string;
    function EvalModernCode(const AExpr: string; out ACode: TExpressionDiagnosticCode): Boolean;
    procedure BuildDataSet;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure Test_Modern_Precedence;
    [Test] procedure Test_Modern_NullArithmetic;
    [Test] procedure Test_Modern_Kleene;
    [Test] procedure Test_Modern_IsNull;
    [Test] procedure Test_Modern_Comparisons;
    [Test] procedure Test_Modern_Functions;
    [Test] procedure Test_Modern_DateFunctions;
    [Test] procedure Test_Modern_Aggregates;
    [Test] procedure Test_Modern_AggregateComposition;
    [Test] procedure Test_Modern_Diagnostics;
    [Test] procedure Test_Modern_DiagnosticCodes;
    [Test] procedure Test_Modern_Validate;
    [Test] procedure Test_Modern_DataResolution;
    [Test] procedure Test_Legacy_TwoArgUnchanged;

    { Cache Correctness Tests (Objective 1) }
    [Test] procedure Test_Cache_MutationParameterInvalidates;
    [Test] procedure Test_Cache_MutationVariableInvalidates;
    [Test] procedure Test_Cache_ModernModeIsolation;
    [Test] procedure Test_Cache_AggregateMutationInvalidates;
  end;

  { === End-to-End Modern Report Tests (Objective 3) === }
  [TestFixture]
  TPhase4B2BEndToEndTests = class
  private
    FFixturesDir: string;
    function FindFixturesDir: string;
    function LoadModernReport(const AFileName: string): TReportModel;
    function CreateTestDataSet: TClientDataSet;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure Test_EndToEnd_ModernPrecedence;
    [Test] procedure Test_EndToEnd_ModernNullSemantics;
    [Test] procedure Test_EndToEnd_ModernAggregateComposition;
    [Test] procedure Test_EndToEnd_FixtureLoadsWithModernVersion;
    [Test] procedure Test_EndToEnd_AllModernFixturesRender;
    [Test] procedure Test_EndToEnd_TextExporterUsesModernMode;
  end;

  { === Migration Analyzer Tests (Objective 5) === }
  [TestFixture]
  TPhase4B2BMigrationAnalyzerTests = class
  private
    FDataSet: TClientDataSet;
    FParameters: TStringList;
    FVariables: TStringList;
    FContext: TExpressionContext;
    procedure BuildDataSet;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure Test_Migration_SameResult;
    [Test] procedure Test_Migration_DifferentResult;
    [Test] procedure Test_Migration_TypeDifference;
    [Test] procedure Test_Migration_LegacyOnly;
    [Test] procedure Test_Migration_ModernErrorCode;
    [Test] procedure Test_Migration_PreservesCallerContext;
    [Test] procedure Test_Migration_AggregateDoesNotTouchCache;
  end;

implementation

const
  CModernFixturePrefix = 'modern_';

function TPhase4B2BModernExpressionTests.Eval(const AExpr: string): Variant;
begin
  Result := TReportExpression.Evaluate(AExpr, FContext);
end;

function TPhase4B2BModernExpressionTests.VariantText(const V: Variant): string;
begin
  if VarIsNull(V) then Exit('NULL');
  if VarIsEmpty(V) then Exit('EMPTY');
  Result := VarToStr(V);
end;

function TPhase4B2BModernExpressionTests.FindModernFixturesDir: string;
var
  Candidate: string;
begin
  Candidate := TPath.Combine(TPath.Combine(GetCurrentDir, 'tests'), 'fixtures', 'modern');
  if TDirectory.Exists(Candidate) then Exit(Candidate);
  Candidate := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\fixtures\modern');
  Candidate := TPath.GetFullPath(Candidate);
  if TDirectory.Exists(Candidate) then Exit(Candidate);
  raise Exception.Create('Could not locate tests/fixtures/modern directory.');
end;

function TPhase4B2BModernExpressionTests.CollectDocumentTexts(
  ADoc: TReportExportDocument): TArray<string>;
var
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  List: TList<string>;
begin
  List := TList<string>.Create;
  try
    for Page in ADoc.Pages do
      for Cmd in Page.Commands do
        if Cmd is TReportExportTextCommand then
          List.Add(TReportExportTextCommand(Cmd).Text);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TPhase4B2BModernExpressionTests.CollectCommandCount(
  ADoc: TReportExportDocument): Integer;
var
  Page: TReportExportPage;
begin
  Result := 0;
  for Page in ADoc.Pages do
    Inc(Result, Page.Commands.Count);
end;

procedure TPhase4B2BModernExpressionTests.AssertDifferential(
  const AExpr: string);
var
  LegacyValue, CompatValue: Variant;
  LegacyFailed, CompatFailed: Boolean;
  LegacyError, CompatError: string;
begin
  LegacyFailed := False;
  CompatFailed := False;
  LegacyError := '';
  CompatError := '';
  LegacyValue := Null;
  CompatValue := Null;
  FDataSet.First;
  try
    LegacyValue := TReportLegacyReferenceExpression.Evaluate(AExpr, FContext);
  except
    on E: Exception do
    begin
      LegacyFailed := True;
      LegacyError := E.ClassName + ': ' + E.Message;
    end;
  end;
  FDataSet.First;
  try
    CompatValue := TReportExpression.Evaluate(AExpr, FContext);
  except
    on E: Exception do
    begin
      CompatFailed := True;
      CompatError := E.ClassName + ': ' + E.Message;
    end;
  end;
  Assert.AreEqual(LegacyFailed, CompatFailed,
    Format('failure behavior differs for "%s" (legacy: %s / compat: %s)',
      [AExpr, LegacyError, CompatError]));
  if LegacyFailed then Exit;
  Assert.AreEqual(Integer(VarType(LegacyValue)), Integer(VarType(CompatValue)),
    Format('Variant type differs for "%s"', [AExpr]));
  Assert.AreEqual(VariantText(LegacyValue), VariantText(CompatValue),
    Format('Variant value differs for "%s"', [AExpr]));
end;

function TPhase4B2BModernExpressionTests.DifferentialCorpus: TArray<string>;
begin
  Result := TArray<string>.Create(
    '1 + 2', '10 - 3', '4 * 5', '20 / 4', '1+2', '  7  -  2  ',
    '1 + 2 * 3', '10 - 2 * 3', '10 / 2 + 3', '2 * 3 + 4 + 5',
    '-5 + 3', '+5 - 2', '2 + -3', '2 - -3', '3.5 * 2', '1.5 + 2.5',
    '10 / 0', '0 / 0', '1 / 2 / 2', '1 +', '+', '-', '*', '/',
    '1 + + 2', '1,5 + 1',
    '(1 + 2)', '(1 + 2) * 3', '1 + (2 * 3)', '((1))', ')', '(', '(1) + 2',
    '1 = 1', '1 = 2', '1 <> 2', '1 <> 1', '1 < 2', '2 > 1', '2 >= 2',
    '1 >= 2', '2 <= 2', '3 <= 2', '10 = 10.0', '= 1', '1 =', '=',
    '''a'' = ''A''', '''a'' = ''b''', '''a'' <> ''b''', '''a'' < ''b''',
    '''b'' > ''a''', '''a'' <= ''A''', '''a'' >= ''A''',
    '''ALICE'' = [Name]', '[Name] = ''Alice''', '[Name] = ''alice''',
    '[Amount] > 5', '[Amount] < 5', '[Qty] > 5', '[MissingField] > 0',
    '1 = 1 AND 2 = 2', '1 = 2 OR 2 = 2', 'NOT (1 = 2)', 'not(1=2)',
    '1 != 2', '2 != 2', 'TRUE = True',
    '[ID]', '[Amount]', '[Name]', '[Qty]', '[Rate]', '[GroupName]',
    '[MissingField]', '[NullText]', '[Under_Score]', '[CustomerName]',
    '[NullText] + 1', '[Amount] + [ID]', '[Name] + [ID]', '[ID] - [ID]',
    '[Qty] * [Rate]', '[MissingField] + 1', '[DataSet.Name]',
    '[Customers."Name"]', '[Customers.''Name'']', '[]', '[', '[ID',
    '[ID] ]', 'x[ID]y', '[ID][ID]', 'Total: [Amount]', '[Amount] [ID]',
    'A[ID]B',
    '[Param.Number]', '[param.number]', '[PARAM.Number]', '[Parameters.Number]',
    '[Parameter.Label]', '[Param.Missing]', '[Param.]', '[Param.Number] + 1',
    '[Multiplier]', '[Caption]', '[caption]', '[MissingVar]',
    '[PageNo]', '[Page]', '[Page#]', '[TotalPages]', '[TotalPages#]',
    '[RowNumber]', '[RecNo]', '[Line]', '[Line#]', '[ReportTitle]',
    '[ReportDate]', '[Date]', '[Time]', '[DateTime]', '[ PageNo ]',
    '''hello''', '''a+b''', '"hello"', '''a''b''', '''''', '''', 'a''b',
    'NULL', 'null', 'true', 'false', 'TRUE', 'abc',
    'SUM([Amount])', 'SUM([Amount]) + 1', 'COUNT([NullText])', 'COUNT([ID])',
    'AVG([Amount])', 'MIN([Amount])', 'MAX([Amount])', 'SUM()', 'SUM(  )',
    'sum([Amount])', 'SUM([Amount]', 'SUM(', 'SUM([MissingField])',
    'COUNT([MissingField])', 'AVG([NullText])', 'MIN([Name])', 'MAX([Name])',
    ' SUM([Amount])', 'TOTAL([Amount])', 'SUM([Qty] * [Rate])',
    'COUNT([ID]) + 1',
    '', '   ', 'unknown_field', 'invalid_function(1)');
end;

procedure TPhase4B2BModernExpressionTests.BuildDataSet;
begin
  FDataSet := TClientDataSet.Create(nil);
  FDataSet.FieldDefs.Add('ID', ftInteger);
  FDataSet.FieldDefs.Add('Amount', ftFloat);
  FDataSet.FieldDefs.Add('Name', ftString, 30);
  FDataSet.FieldDefs.Add('Under_Score', ftString, 30);
  FDataSet.FieldDefs.Add('NullText', ftString, 30);
  FDataSet.FieldDefs.Add('Qty', ftFloat);
  FDataSet.FieldDefs.Add('Rate', ftFloat);
  FDataSet.FieldDefs.Add('GroupName', ftString, 20);
  FDataSet.FieldDefs.Add('CustomerName', ftString, 40);
  FDataSet.CreateDataSet;
  FDataSet.AppendRecord([1, 10.5, 'Alice', 'under_score', Null, 2, 3.5, 'Labels', 'Acme Corp']);
  FDataSet.AppendRecord([2, 20.0, 'Bob', 'other', Null, 4, 1.25, 'Labels', 'Beta Ltd']);
  FDataSet.AppendRecord([3, 5.0, 'Carol', 'third', Null, 10, 2.0, 'Other', 'Gamma Inc']);
  FDataSet.First;
  FRow1ID := FDataSet.FieldByName('ID').AsInteger;
  FRow1Amount := FDataSet.FieldByName('Amount').AsFloat;
  FRow1Name := FDataSet.FieldByName('Name').AsString;
end;

procedure TPhase4B2BModernExpressionTests.BuildModelAndEngine(
  out AModel: TReportModel; out AEngine: TReportEngine);
begin
  AModel := TReportModel.Create;
  AEngine := nil;
end;

procedure TPhase4B2BModernExpressionTests.Setup;
begin
  BuildDataSet;
  FParameters := TStringList.Create;
  FParameters.Values['Number'] := '12.5';
  FParameters.Values['Label'] := 'Acme';
  FParameters.Values['ReportTitle'] := 'Compat Parameter Title';
  FVariables := TStringList.Create;
  FVariables.Values['Multiplier'] := '2';
  FVariables.Values['Caption'] := 'Legacy';
  FVariables.Values['CompanyName'] := 'Vittix Compat';
  FContext := Default(TExpressionContext);
  FContext.DataSet := FDataSet;
  FContext.Parameters := FParameters;
  FContext.Variables := FVariables;
  FContext.PageNumber := 3;
  FContext.TotalPages := 9;
  FContext.RowNumber := 7;
  FContext.ReportTitle := 'Title';
  FContext.ReportDate := 0;
end;

procedure TPhase4B2BModernExpressionTests.TearDown;
begin
  FVariables.Free;
  FParameters.Free;
  FDataSet.Free;
end;

{ === A. Tokenizer / lexing === }

procedure TPhase4B2BModernExpressionTests.Test_Tokenizer_BracketTokenShapes;
begin
  // A lone bracket token is a value lookup, not re-parsed.
  Assert.AreEqual('Alice', VariantText(Eval('[Name]')));
  Assert.AreEqual('under_score', VariantText(Eval('[Under_Score]')));
  // Qualified tokens: qualifier discarded, current dataset read.
  Assert.AreEqual('Alice', VariantText(Eval('[DataSet.Name]')));
  Assert.AreEqual('Alice', VariantText(Eval('[Customers."Name"]')));
  Assert.AreEqual('Alice', VariantText(Eval('[Customers.''Name'']')));
  // Empty brackets fall back to text '0'.
  Assert.AreEqual('0', VariantText(Eval('[]')));
  // Unterminated token consumes remaining text as the token name.
  Assert.AreEqual('1', VariantText(Eval('[ID')));
  // A leading char before the token: static text is preserved and the
  // evaluated token value is inserted between the surrounding characters.
  Assert.AreEqual('A1B', VariantText(Eval('A[ID]B')));
  // Embedded tokens in static text are evaluated.
  Assert.AreEqual('Total: 10.5', VariantText(Eval('Total: [Amount]')));
end;

procedure TPhase4B2BModernExpressionTests.Test_Tokenizer_StringLiteralForms;
begin
  // Single quotes are the only string literal syntax.
  Assert.AreEqual('hello', VariantText(Eval('''hello''')));
  Assert.AreEqual('a+b', VariantText(Eval('''a+b''')));
  Assert.AreEqual('a''b', VariantText(Eval('''a''b''')));
  Assert.AreEqual('', VariantText(Eval('''''')));
  // Double quotes remain literal characters, not delimiters.
  Assert.AreEqual('"hello"', VariantText(Eval('"hello"')));
  // Comparison operators inside quotes stay literal.
  Assert.AreEqual('a=b', VariantText(Eval('''a=b''')));
  Assert.AreEqual('a<>b', VariantText(Eval('''a<>b''')));
  Assert.AreEqual('a<=b', VariantText(Eval('''a<=b''')));
  Assert.AreEqual('a>b', VariantText(Eval('''a>b''')));
  // Literal NULL is text, not a NULL Variant.
  Assert.AreEqual('NULL', VariantText(Eval('NULL')));
  Assert.IsFalse(VarIsNull(Eval('NULL')));
end;

procedure TPhase4B2BModernExpressionTests.Test_Tokenizer_KeywordCaseInsensitive;
begin
  // Boolean literals are case-insensitive.
  Assert.IsTrue(Boolean(Eval('true')));
  Assert.IsFalse(Boolean(Eval('false')));
  Assert.IsTrue(Boolean(Eval('TRUE')));
  // Aggregate function names are case-insensitive.
  Assert.AreEqual(35.5, Double(Eval('sum([Amount])')), 0.0001);
  // Parameter names are case-insensitive.
  Assert.AreEqual(12.5, Double(Eval('[param.number]')), 0.0001);
  Assert.AreEqual(12.5, Double(Eval('[PARAM.NUMBER]')), 0.0001);
  // Variable names are case-insensitive.
  Assert.AreEqual('Legacy', VariantText(Eval('[caption]')));
end;

{ === B. Parser / AST shape === }

procedure TPhase4B2BModernExpressionTests.Test_ASTShape_SingleTokenVsMultiToken;
begin
  // A lone bracket token takes the single-token value path.
  Assert.AreEqual('0', VariantText(Eval('[MissingField]')));
  Assert.AreEqual(0.0, Double(Eval('[MissingField]')), 0.0001);
  // Same token in a larger expression falls through to the flat numeric
  // scan: missing field contributes 0, so the whole expression is 1.
  Assert.AreEqual('1', VariantText(Eval('[MissingField] + 1')));
  // A number-only expression goes through the numeric path.
  Assert.AreEqual(42.0, Double(Eval('42')), 0.0001);
  Assert.AreEqual(Integer(varDouble), Integer(VarType(Eval('42'))));
  // A bare identifier is text (no field lookup without brackets).
  Assert.AreEqual('abc', VariantText(Eval('abc')));
  Assert.AreEqual(Integer(varUString), Integer(VarType(Eval('abc'))));
end;

procedure TPhase4B2BModernExpressionTests.Test_ASTShape_FlatEvaluationPath;
begin
  // Legacy evaluation is a sequential 9-stage pipeline with no
  // AST construction. This test proves there is no intermediate
  // structure that could be cached or analyzed — the evaluator
  // is a pure text scanner.
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount])')), 0.0001);
  // Aggregate prefix detection is prefix-matched on RAW text.
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount]) + 1')), 0.0001);
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount]) * 100')), 0.0001);
  // Leading space prevents aggregate prefix match (raw text).
  Assert.AreEqual('SUM(10.5)', VariantText(Eval(' SUM([Amount])')));
  // A leading char before the aggregate prefix breaks it.
  Assert.AreEqual('SUM(10.5', VariantText(Eval('SUM([Amount]')));
  Assert.AreEqual('SUM(', VariantText(Eval('SUM(')));
end;

{ === C. Precedence === }

procedure TPhase4B2BModernExpressionTests.Test_Precedence_LegacyFlatLeftToRight;
begin
  // Legacy has NO operator precedence — strictly left-to-right.
  Assert.AreEqual(9.0, Double(Eval('1 + 2 * 3')), 0.0001);
  Assert.AreEqual(24.0, Double(Eval('10 - 2 * 3')), 0.0001);
  Assert.AreEqual(8.0, Double(Eval('10 / 2 + 3')), 0.0001);
  Assert.AreEqual(15.0, Double(Eval('2 * 3 + 4 + 5')), 0.0001);
  Assert.AreEqual(10.0, Double(Eval('100 / 5 / 2')), 0.0001);
  // Subtraction and division are also flat, not right-associative.
  Assert.AreEqual(5.0, Double(Eval('10 - 3 - 2')), 0.0001);
  Assert.AreEqual(15.0, Double(Eval('10 / 2 * 3')), 0.0001);
end;

{ === D. Boolean / NULL / Kleene === }

procedure TPhase4B2BModernExpressionTests.Test_BooleanNULL_NullIsTextNotVariant;
begin
  // NULL literal is the TEXT 'NULL', NOT a varNull Variant.
  Assert.AreEqual('NULL', VariantText(Eval('NULL')));
  Assert.IsFalse(VarIsNull(Eval('NULL')));
  Assert.AreEqual(Integer(varUString), Integer(VarType(Eval('NULL'))));
  // Null field AsString is empty text — NOT a numeric zero.
  Assert.AreEqual('', VariantText(Eval('[NullText]')));
  Assert.AreEqual(Integer(varUString), Integer(VarType(Eval('[NullText]'))));
  // A null field in arithmetic makes the scan fail → accumulator stays 0.
  Assert.AreEqual(0.0, Double(Eval('[NullText] + 1')), 0.0001);
end;

procedure TPhase4B2BModernExpressionTests.Test_BooleanNULL_TruthinessMapping;
begin
  // Boolean literals produce Boolean Variants.
  Assert.IsTrue(Boolean(Eval('true')));
  Assert.IsFalse(Boolean(Eval('false')));
  // Consumer truthiness mapping (ConditionVariantToBool):
  // 0/false/no/n/off → False; 1/true/yes/y/on → True; numeric ≠ 0;
  // Null/empty/anything else → False.
  Assert.IsTrue(Boolean(Eval('1')));
  Assert.IsFalse(Boolean(Eval('0')));
  Assert.IsTrue(Boolean(Eval('true')));
  Assert.IsFalse(Boolean(Eval('false')));
  // 'abc' is a UnicodeString Variant; direct Boolean conversion raises,
  // while the consumer-side ConditionVariantToBool maps it to False.
  Assert.IsFalse(ConditionVariantToBool(Eval('abc')));
  Assert.IsTrue(Boolean(Eval('1 = 1')));
  Assert.IsFalse(Boolean(Eval('1 = 2')));
end;

procedure TPhase4B2BModernExpressionTests.Test_BooleanNULL_KleeneNotImplemented;
begin
  // Legacy has NO Kleene three-valued logic and NO NULL propagation.
  // These are documented as defects (ExpressionAudit _CurrentBehavior).
  // Legacy: NULL + 1 = 0 (text NULL can't be scanned as number).
  Assert.AreEqual(0.0, Double(Eval('NULL + 1')), 0.0001);
  // Legacy: NULL = NULL → text compare 'NULL' vs 'NULL' → True.
  Assert.IsTrue(Boolean(Eval('NULL = NULL')));
  // Legacy: AND/OR/NOT are NOT operators; the whole expression
  // degrades to text comparison.
  FDataSet.First;
  Assert.IsFalse(Boolean(Eval('1 = 1 AND 2 = 2')));
  Assert.IsFalse(Boolean(Eval('1 = 2 OR 2 = 2')));
  Assert.IsFalse(Boolean(Eval('NOT (1 = 2)')));
  Assert.IsFalse(Boolean(Eval('not(1=2)')));
  // != is NOT inequality; degrades to "=" with left operand "1 !".
  Assert.IsFalse(Boolean(Eval('1 != 2')));
  Assert.IsFalse(Boolean(Eval('2 != 2')));
end;

{ === E. Arithmetic === }

procedure TPhase4B2BModernExpressionTests.Test_Arithmetic_SignedAndDivision;
begin
  Assert.AreEqual(-2.0, Double(Eval('-5 + 3')), 0.0001);
  Assert.AreEqual(3.0, Double(Eval('+5 - 2')), 0.0001);
  Assert.AreEqual(-1.0, Double(Eval('2 + -3')), 0.0001);
  Assert.AreEqual(5.0, Double(Eval('2 - -3')), 0.0001);
  Assert.AreEqual(7.0, Double(Eval('3.5 * 2')), 0.0001);
  // Division by zero leaves accumulator unchanged (legacy no-op).
  Assert.AreEqual(10.0, Double(Eval('10 / 0')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('0 / 0')), 0.0001);
  Assert.AreEqual(25.0, Double(Eval('20 / 0 + 5')), 0.0001);
  // Division result is Double.
  Assert.AreEqual(5.0, Double(Eval('20 / 4')), 0.0001);
end;

procedure TPhase4B2BModernExpressionTests.Test_Arithmetic_MalformedFallback;
begin
  // Trailing operator truncates the accumulator.
  Assert.AreEqual(1.0, Double(Eval('1 +')), 0.0001);
  // Leading non-number yields 0.
  Assert.AreEqual(0.0, Double(Eval('+')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('*')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('/')), 0.0001);
  // Whitespace-only input resolves to empty text.
  Assert.AreEqual('', VariantText(Eval('   ')));
  // Empty input stays empty text.
  Assert.AreEqual('', VariantText(Eval('')));
end;

{ === F. Functions === }

procedure TPhase4B2BModernExpressionTests.Test_Functions_NoneExist_FallbackToText;
begin
  // No function exists in the legacy language except aggregate prefixes.
  // Unknown names with parentheses fall through to text (no error).
  Assert.AreEqual('invalid_function(1)', VariantText(Eval('invalid_function(1)')));
  Assert.AreEqual('TOTAL(10.5)', VariantText(Eval('TOTAL([Amount])')));
  Assert.AreEqual('SUM(10.5)', VariantText(Eval(' SUM([Amount])')));
  Assert.AreEqual('SUM(10.5', VariantText(Eval('SUM([Amount]')));
  // A name without parentheses is a bare identifier → text.
  Assert.AreEqual('abc', VariantText(Eval('abc')));
end;

{ === G. Aggregates / composition / nested rejection === }

procedure TPhase4B2BModernExpressionTests.Test_Aggregate_PrefixTruncation;
begin
  // Aggregate prefix returns immediately; tail is never evaluated.
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount]) + 1')), 0.0001);
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount]) * 100')), 0.0001);
  Assert.AreEqual(3.0, Double(Eval('COUNT([ID]) + 1')), 0.0001);
  // Non-numeric aggregate input contributes nothing for AVG/MIN/MAX.
  Assert.AreEqual(0.0, Double(Eval('AVG([Name])')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('MIN([Name])')), 0.0001);
end;

procedure TPhase4B2BModernExpressionTests.Test_Aggregate_CompositionLegacyTruncates;
begin
  // Legacy: aggregate prefix truncation — second aggregate discarded.
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount]) + SUM([ID])')), 0.0001);
  // Legacy: 1 + SUM(x) → "1 + SUM(10.5)" → math reads 1, stops at 'SUM'.
  FDataSet.First;
  Assert.AreEqual(1.0, Double(Eval('1 + SUM([Amount])')), 0.0001);
  // Modern composition contract (future): SUM(x)+1 should be SUM+1.
  // Legacy behavior is documented as the defect to fix.
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount]) + 1')), 0.0001,
    'Legacy truncates; modern must return 36.5 (composition).');
end;

procedure TPhase4B2BModernExpressionTests.Test_Aggregate_NestedRejection;
begin
  // Legacy does NOT reject nested aggregates. Modern mode MUST reject
  // them with SyntaxError (section 16.5: "Aggregates inside an aggregate
  // argument list are rejected"). Legacy: SUM prefix consumes to the
  // last ')', inner expr evaluates per row.
  FDataSet.First;
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount]) + (1 * 2)')), 0.0001);
end;

procedure TPhase4B2BModernExpressionTests.Test_Aggregate_GroupRange;
var
  GroupContext: TExpressionContext;
  GroupStart, GroupEnd: TBookmark;
begin
  FDataSet.First;
  GroupStart := FDataSet.GetBookmark;
  FDataSet.Next;
  FDataSet.Next;
  Assert.AreEqual('Other', FDataSet.FieldByName('GroupName').AsString);
  // GroupEnd is the first row of the NEXT group (exclusive boundary);
  // legacy scans from GroupStart up to — but excluding — GroupEnd,
  // so this range covers rows 1..2.
  GroupEnd := FDataSet.GetBookmark;
  try
    GroupContext := FContext;
    GroupContext.GroupStart := GroupStart;
    GroupContext.GroupEnd := GroupEnd;
    Assert.AreEqual(30.5, Double(TReportExpression.Evaluate('SUM([Amount])', GroupContext)), 0.0001);
    Assert.AreEqual(2.0, Double(TReportExpression.Evaluate('COUNT([ID])', GroupContext)), 0.0001);
  finally
    FDataSet.FreeBookmark(GroupEnd);
    FDataSet.FreeBookmark(GroupStart);
  end;
end;

{ === H. Data resolution === }

procedure TPhase4B2BModernExpressionTests.Test_DataResolution_Fields;
begin
  Assert.AreEqual('Alice', VariantText(Eval('[Name]')));
  Assert.AreEqual('under_score', VariantText(Eval('[Under_Score]')));
  Assert.AreEqual(1.0, Double(Eval('[ID]')), 0.0001);
  Assert.AreEqual(10.5, Double(Eval('[Amount]')), 0.0001);
  // Repeated/qualified tokens.
  Assert.AreEqual(0.0, Double(Eval('[Name] - [Name]')), 0.0001);
  Assert.AreEqual(11.0, Double(Eval('[ID][ID]')), 0.0001);
  Assert.AreEqual('Alice', VariantText(Eval('[DataSet.Name]')));
  // A missing field falls back to text '0' (lone token → numeric path).
  Assert.AreEqual('0', VariantText(Eval('[MissingField]')));
  // A missing field contributes 0 in the flat scan, so 0 + 1 = 1.
  Assert.AreEqual(1.0, Double(Eval('[MissingField] + 1')), 0.0001);
end;

procedure TPhase4B2BModernExpressionTests.Test_DataResolution_Parameters;
begin
  Assert.AreEqual(12.5, Double(Eval('[Param.Number]')), 0.0001);
  Assert.AreEqual(12.5, Double(Eval('[Parameters.Number]')), 0.0001);
  Assert.AreEqual('Acme', VariantText(Eval('[Parameter.Label]')));
  // Case-insensitive parameter resolution.
  Assert.AreEqual(12.5, Double(Eval('[param.number]')), 0.0001);
  Assert.AreEqual(12.5, Double(Eval('[PARAM.NUMBER]')), 0.0001);
  // Missing parameter resolves to empty text (NOT '0').
  Assert.AreEqual('', VariantText(Eval('[Param.Missing]')));
  Assert.AreEqual('', VariantText(Eval('[Param.]')));
  Assert.AreEqual(13.5, Double(Eval('[Param.Number] + 1')), 0.0001);
end;

procedure TPhase4B2BModernExpressionTests.Test_DataResolution_Variables;
begin
  Assert.AreEqual(2.0, Double(Eval('[Multiplier]')), 0.0001);
  Assert.AreEqual('Legacy', VariantText(Eval('[Caption]')));
  Assert.AreEqual('Legacy', VariantText(Eval('[caption]')));
  // Unknown variable falls through to field lookup then '0'.
  Assert.AreEqual('0', VariantText(Eval('[MissingVar]')));
end;

procedure TPhase4B2BModernExpressionTests.Test_DataResolution_SystemTokens;
var
  PageContext: TExpressionContext;
  SavedRowNumber: Integer;
begin
  Assert.AreEqual('3', VariantText(Eval('[PageNo]')));
  Assert.AreEqual('3', VariantText(Eval('[Page]')));
  Assert.AreEqual('3', VariantText(Eval('[Page#]')));
  Assert.AreEqual('9', VariantText(Eval('[TotalPages]')));
  Assert.AreEqual('9', VariantText(Eval('[TotalPages#]')));
  Assert.AreEqual('7', VariantText(Eval('[RowNumber]')));
  Assert.AreEqual('Title', VariantText(Eval('[ReportTitle]')));
  Assert.AreEqual(DateToStr(FContext.ReportDate), VariantText(Eval('[ReportDate]')));
  Assert.AreEqual(DateToStr(FContext.ReportDate), VariantText(Eval('[Date]')));
  Assert.AreEqual(TimeToStr(FContext.ReportDate), VariantText(Eval('[Time]')));
  Assert.AreEqual(DateTimeToStr(FContext.ReportDate), VariantText(Eval('[DateTime]')));
  // [RecNo] prefers RowNumber, otherwise dataset RecNo.
  PageContext := FContext;
  SavedRowNumber := PageContext.RowNumber;
  PageContext.RowNumber := 0;
  FDataSet.First;
  FDataSet.Next;
  Assert.AreEqual('2', VarToStr(TReportExpression.Evaluate('[RecNo]', PageContext)));
  Assert.AreEqual('2', VarToStr(TReportExpression.Evaluate('[Line]', PageContext)));
  PageContext.RowNumber := SavedRowNumber;
  // Token text with spaces is used verbatim (does NOT match system token).
  Assert.AreEqual('0', VariantText(Eval('[ PageNo ]')));
end;

{ === I. Diagnostics / limits === }

procedure TPhase4B2BModernExpressionTests.Test_Diagnostics_LegacyHasNoDiagnostics;
begin
  // Legacy has no structured diagnostics. Malformed input silently
  // returns partial/zero/text values. There is no diagnostic object,
  // no error code, no position info, no limit enforcement.
  // These are all characterized as NO-ERROR behavior:
  Assert.AreEqual('', VariantText(Eval('')));
  Assert.AreEqual('unknown_field', VariantText(Eval('unknown_field')));
  Assert.AreEqual('1 ]', VariantText(Eval('[ID] ]')));
  Assert.AreEqual('x1y', VariantText(Eval('x[ID]y')));
  Assert.AreEqual('A1B', VariantText(Eval('A[ID]B')));
  // No evaluator exception model exists — nothing above raised.
  Assert.AreEqual('invalid_function(1)', VariantText(Eval('invalid_function(1)')));
  Assert.AreEqual('SUM(', VariantText(Eval('SUM(')));
  Assert.AreEqual('TOTAL(10.5)', VariantText(Eval('TOTAL([Amount])')));
end;

{ === J. Serialization mode === }

procedure TPhase4B2BModernExpressionTests.Test_SerializationMode_NoExpressionLanguageVersion;
var
  S: string;
  HasModeKey: Boolean;
begin
  // All 45 checked-in .vrt reports have "Version": 2 and NO
  // "ExpressionLanguageVersion" key — confirming legacy is the default.
  // This test proves the contract by loading a representative fixture
  // and checking the raw JSON has no modern mode key.
  S := TFile.ReadAllText('reports\17_object_printwhen_core.vrt', TEncoding.UTF8);
  HasModeKey := Pos('"ExpressionLanguageVersion"', S) > 0;
  Assert.IsFalse(HasModeKey,
    'No checked-in .vrt should carry ExpressionLanguageVersion ' +
    '(modern mode must be opt-in, not ambient).');
  // Also prove the serializer loads it (model is usable).
  Assert.IsTrue(S.Contains('"Version": 2'));
end;

{ === K. Compatibility default legacy === }

procedure TPhase4B2BModernExpressionTests.Test_Compatibility_LegacyIsDefault;
begin
  // The two-argument Evaluate(Expr, Context) is permanently legacy.
  // There is no mode parameter, no TExpressionContext.ExpressionsMode field,
  // and no TReportModel.ExpressionLanguageVersion property in the current API.
  // Every call site that exists today keeps legacy semantics by construction.
  FDataSet.First;
  // Legacy flat arithmetic: 1 + 2 * 3 = 9 (NOT 7).
  Assert.AreEqual(9.0, Double(Eval('1 + 2 * 3')), 0.0001);
  // Legacy parentheses: (1+2) = 0 (NOT 3).
  Assert.AreEqual(0.0, Double(Eval('(1 + 2)')), 0.0001);
  // Legacy aggregate truncation: SUM+1 = SUM (NOT SUM+1).
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount]) + 1')), 0.0001);
  // Differential corpus: legacy and compat agree on all ~180 expressions.
  var Expr: string;
  for Expr in DifferentialCorpus do
    AssertDifferential(Expr);
end;

{ === L. Cache / mutation isolation === }

procedure TPhase4B2BModernExpressionTests.Test_Cache_RepeatedAggregatePreservesCursor;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Context: TExpressionContext;
  Snapshot: TReportTraversalSnapshot;
  FirstValue, SecondValue: Variant;
begin
  DataSet := TClientDataSet.Create(nil);
  Model := TReportModel.Create;
  try
    DataSet.FieldDefs.Add('ID', ftInteger);
    DataSet.FieldDefs.Add('Amount', ftFloat);
    DataSet.CreateDataSet;
    DataSet.AppendRecord([1, 10.0]);
    DataSet.AppendRecord([2, 20.0]);
    DataSet.AppendRecord([3, 30.0]);
    DataSet.First;
    DataSet.Next;
    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Context := Default(TExpressionContext);
      Context.DataSet := DataSet;
      Context.Hooks := Engine;
      Context.Parameters := Engine.Parameters;
      Context.Variables := Model.Variables;
      TReportTraversalDiagnostics.Reset;
      FirstValue := TReportExpression.Evaluate('SUM([Amount])', Context);
      SecondValue := TReportExpression.Evaluate('SUM([Amount])', Context);
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      Assert.AreEqual(60.0, Double(FirstValue), 0.0001);
      Assert.AreEqual(VariantText(FirstValue), VariantText(SecondValue));
      Assert.AreEqual(2, Snapshot.AggregateEvaluations);
      Assert.AreEqual(1, Snapshot.AggregateCacheMisses);
      Assert.AreEqual(1, Snapshot.AggregateCacheHits);
      Assert.AreEqual(1, Snapshot.AggregateTraversals,
        'Phase 3 cache must still avoid the second scan.');
      Assert.AreEqual(3, Snapshot.AggregateRowsVisited);
      Assert.AreEqual(2, DataSet.FieldByName('ID').AsInteger,
        'A cache hit preserves the same caller cursor behavior as a miss.');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase4B2BModernExpressionTests.Test_Cache_ClearedPerPrepare;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Summary: TReportBand;
  Text1, Text2: TReportTextObject;
  Snapshot: TReportTraversalSnapshot;
begin
  DataSet := TClientDataSet.Create(nil);
  Model := TReportModel.Create;
  try
    DataSet.FieldDefs.Add('ID', ftInteger);
    DataSet.FieldDefs.Add('Amount', ftFloat);
    DataSet.CreateDataSet;
    DataSet.AppendRecord([1, 10.0]);
    DataSet.AppendRecord([2, 20.0]);
    DataSet.First;
    Summary := TReportBand.Create;
    Summary.BandType := btReportSummary;
    Summary.Height := 30;
    Text1 := TReportTextObject.Create;
    Text1.Expression := 'SUM([Amount])';
    Text1.Bounds := Rect(0, 0, 100, 14);
    Summary.Children.Add(Text1);
    Text2 := TReportTextObject.Create;
    Text2.Expression := 'SUM([Amount])';
    Text2.Bounds := Rect(0, 15, 100, 29);
    Summary.Children.Add(Text2);
    Model.Objects.Add(Summary);
    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Engine.TwoPassRendering := False;
      TReportTraversalDiagnostics.Reset;
      Engine.Prepare;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      Assert.AreEqual(1, Snapshot.AggregateTraversals);
      Assert.AreEqual(1, Snapshot.AggregateCacheHits);
      TReportTraversalDiagnostics.Reset;
      Engine.Prepare;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      Assert.AreEqual(1, Snapshot.AggregateTraversals,
        'A new Prepare execution must not reuse a previous cache.');
      Assert.AreEqual(1, Snapshot.AggregateCacheHits);
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase4B2BModernExpressionTests.Test_Cache_MutationDoesNotAffectLegacy;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Band: TReportBand;
  RowText: TReportTextObject;
  SummaryBand: TReportBand;
  TotalText: TReportTextObject;
  Doc: TReportExportDocument;
  Texts: TArray<string>;
  I: Integer;
  FoundTotal: Boolean;
begin
  DataSet := TClientDataSet.Create(nil);
  Doc := TReportExportDocument.Create;
  try
    DataSet.FieldDefs.Add('ID', ftInteger);
    DataSet.FieldDefs.Add('Amount', ftFloat);
    DataSet.CreateDataSet;
    DataSet.AppendRecord([1, 10.5]);
    DataSet.AppendRecord([2, 20.0]);
    DataSet.AppendRecord([3, 5.0]);
    DataSet.First;
    Model := TReportModel.Create;
    try
      Band := TReportBand.Create;
      Band.BandType := btMasterData;
      Band.Height := 20;
      RowText := TReportTextObject.Create;
      RowText.Expression := '[Name]';
      RowText.Bounds := Rect(5, 2, 200, 18);
      Band.Children.Add(RowText);
      Model.Objects.Add(Band);
      SummaryBand := TReportBand.Create;
      SummaryBand.BandType := btReportSummary;
      SummaryBand.Height := 20;
      TotalText := TReportTextObject.Create;
      TotalText.Name := 'totalText';
      TotalText.Expression := 'SUM([Amount])';
      TotalText.Bounds := Rect(5, 2, 200, 18);
      SummaryBand.Children.Add(TotalText);
      Model.Objects.Add(SummaryBand);
      Engine := TReportEngine.Create(Model, DataSet, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.Prepare;
        Texts := CollectDocumentTexts(Doc);
        FoundTotal := False;
        for I := 0 to High(Texts) do
          if Texts[I] = VarToStr(35.5) then
            FoundTotal := True;
        Assert.IsTrue(FoundTotal,
          Format('Summary band must render aggregate result; rendered: %s',
            [string.Join('|', Texts)]));
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    Doc.Free;
    DataSet.Free;
  end;
end;

{ === TPhase4B2BModernEvaluatorTests — modern mode (explicit opt-in) === }

procedure TPhase4B2BModernEvaluatorTests.BuildDataSet;
begin
  FDataSet := TClientDataSet.Create(nil);
  FDataSet.FieldDefs.Add('ID', ftInteger);
  FDataSet.FieldDefs.Add('Amount', ftFloat);
  FDataSet.FieldDefs.Add('Name', ftString, 30);
  FDataSet.FieldDefs.Add('NullText', ftString, 30);
  FDataSet.CreateDataSet;
  FDataSet.AppendRecord([1, 10.5, 'Alice', Null]);
  FDataSet.AppendRecord([2, 20.0, 'Bob', Null]);
  FDataSet.AppendRecord([3, 5.0, 'Carol', Null]);
  FDataSet.First;
end;

procedure TPhase4B2BModernEvaluatorTests.Setup;
begin
  BuildDataSet;
  FParameters := TStringList.Create;
  FParameters.Values['Number'] := '12.5';
  FVariables := TStringList.Create;
  FVariables.Values['Caption'] := 'Legacy';
  FContext := Default(TExpressionContext);
  FContext.DataSet := FDataSet;
  FContext.Parameters := FParameters;
  FContext.Variables := FVariables;
  FContext.PageNumber := 3;
  FContext.TotalPages := 9;
  FContext.RowNumber := 7;
  FContext.ReportTitle := 'Title';
  FContext.ReportDate := 0;
end;

procedure TPhase4B2BModernEvaluatorTests.TearDown;
begin
  FVariables.Free;
  FParameters.Free;
  FDataSet.Free;
end;

function TPhase4B2BModernEvaluatorTests.EvalModern(const AExpr: string): Variant;
begin
  Result := TReportExpression.Evaluate(AExpr, FContext, emModern);
end;

function TPhase4B2BModernEvaluatorTests.EvalModernRaises(
  const AExpr: string): string;
begin
  try
    TReportExpression.Evaluate(AExpr, FContext, emModern);
    Result := '';
  except
    on E: EVittixExpressionError do
      Result := E.Message;
    on E: Exception do
      Result := E.ClassName;
  end;
end;

function TPhase4B2BModernEvaluatorTests.EvalModernCode(
  const AExpr: string; out ACode: TExpressionDiagnosticCode): Boolean;
begin
  ACode := SyntaxError;
  try
    TReportExpression.Evaluate(AExpr, FContext, emModern);
    Result := False;
  except
    on E: EVittixExpressionError do
    begin
      ACode := E.Code;
      Result := True;
    end;
  end;
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_Precedence;
begin
  // Real operator precedence (Section 13), unlike the legacy flat scan.
  Assert.AreEqual(7.0, Double(EvalModern('1 + 2 * 3')), 0.0001);
  Assert.AreEqual(4.0, Double(EvalModern('10 - 2 * 3')), 0.0001);
  Assert.AreEqual(9.0, Double(EvalModern('(1 + 2) * 3')), 0.0001);
  Assert.AreEqual(8.0, Double(EvalModern('10 / 2 + 3')), 0.0001);
  Assert.AreEqual(5.0, Double(EvalModern('10 - 3 - 2')), 0.0001);
  Assert.AreEqual(-4.0, Double(EvalModern('-2 * 2')), 0.0001);
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_NullArithmetic;
begin
  // NULL arithmetic propagates NULL (OD-2).
  Assert.IsTrue(VarIsNull(EvalModern('NULL + 1')));
  Assert.IsTrue(VarIsNull(EvalModern('NULL - 1')));
  Assert.IsTrue(VarIsNull(EvalModern('NULL * 2')));
  Assert.IsTrue(VarIsNull(EvalModern('NULL / 2')));
  // A missing field resolves to NULL in modern mode.
  Assert.IsTrue(VarIsNull(EvalModern('[MissingField] + 1')));
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_Kleene;
begin
  // Kleene three-valued logic (Section 14).
  // UNKNOWN is expressed as NULL in the modern language.
  Assert.IsTrue(Boolean(EvalModern('TRUE AND TRUE')));
  Assert.IsFalse(Boolean(EvalModern('TRUE AND FALSE')));
  Assert.IsTrue(VarIsNull(EvalModern('TRUE AND NULL')));
  Assert.IsFalse(Boolean(EvalModern('FALSE AND NULL')));
  Assert.IsTrue(Boolean(EvalModern('TRUE OR NULL')));
  Assert.IsTrue(VarIsNull(EvalModern('FALSE OR NULL')));
  Assert.IsTrue(VarIsNull(EvalModern('NOT NULL')));
  Assert.IsTrue(VarIsNull(EvalModern('NULL AND TRUE')));
  Assert.IsFalse(Boolean(EvalModern('NULL AND FALSE')));
  // Short-circuit evaluation (Section 14).
  Assert.IsTrue(Boolean(EvalModern('TRUE OR (1 / 0 = 1)')));
  Assert.IsFalse(Boolean(EvalModern('FALSE AND (1 / 0 = 1)')));
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_IsNull;
begin
  Assert.IsTrue(Boolean(EvalModern('[MissingField] IS NULL')));
  Assert.IsFalse(Boolean(EvalModern('[Name] IS NULL')));
  Assert.IsFalse(Boolean(EvalModern('[MissingField] IS NOT NULL')));
  Assert.IsTrue(Boolean(EvalModern('[Name] IS NOT NULL')));
  Assert.IsTrue(Boolean(EvalModern('NULL IS NULL')));
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_Comparisons;
begin
  // NULL comparisons are UNKNOWN (NULL variant, Section 16).
  Assert.IsTrue(VarIsNull(EvalModern('NULL = 1')));
  Assert.IsTrue(VarIsNull(EvalModern('NULL = NULL')));
  // Text comparisons are case-insensitive.
  Assert.IsTrue(Boolean(EvalModern('''abc'' = ''ABC''')));
  Assert.IsTrue(Boolean(EvalModern('''Alice'' = [Name]')));
  Assert.IsTrue(Boolean(EvalModern('[Amount] > 5')));
  Assert.IsFalse(Boolean(EvalModern('[Amount] < 5')));
  // != is equivalent to <>.
  Assert.IsTrue(Boolean(EvalModern('1 != 2')));
  Assert.IsTrue(Boolean(EvalModern('1 <> 2')));
  // Numeric promotion of a string operand (Section 18).
  Assert.IsTrue(Boolean(EvalModern('''10'' + 5 = 15')));
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_DateFunctions;
var
  SavedDate: TDateTime;
begin
  SavedDate := FContext.ReportDate;
  try
    FContext.ReportDate := EncodeDate(2026, 9, 14);

    // OD-18: date extraction on a real DateTime value. [ReportDate] resolves
    // through the system-token path to MakeDateTime, so this exercises the
    // end-to-end value path rather than a synthetic one.
    Assert.AreEqual(2026.0, Double(EvalModern('YEAR([ReportDate])')), 0.001);
    Assert.AreEqual(9.0, Double(EvalModern('MONTH([ReportDate])')), 0.001);
    Assert.AreEqual(14.0, Double(EvalModern('DAY([ReportDate])')), 0.001);

    // Composable like any other scalar function.
    Assert.IsTrue(Boolean(EvalModern('MONTH([ReportDate]) = 9')));
    Assert.AreEqual(2027.0, Double(EvalModern('YEAR([ReportDate]) + 1')), 0.001);

    // NULL propagates rather than raising (Section 12.3).
    Assert.IsTrue(VarIsNull(EvalModern('YEAR(NULL)')),
      'A NULL operand must propagate NULL.');

    // A non-date operand is a diagnosed error, not a locale-dependent guess.
    Assert.Contains(EvalModernRaises('YEAR(''abc'')'), 'date value');
    Assert.Contains(EvalModernRaises('MONTH(1)'), 'date value');
    Assert.Contains(EvalModernRaises('DAY(TRUE)'), 'date value');

    // Arity is still checked.
    Assert.Contains(EvalModernRaises('YEAR(1, 2)'), 'expects 1 argument');
  finally
    FContext.ReportDate := SavedDate;
  end;
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_Functions;
begin
  Assert.AreEqual(15.0, Double(EvalModern('IF(1 = 1, 15, 99)')), 0.0001);
  Assert.AreEqual(99.0, Double(EvalModern('IF(1 = 2, 15, 99)')), 0.0001);
  Assert.AreEqual('x', VarToStr(EvalModern('COALESCE(NULL, NULL, ''x'')')));
  Assert.AreEqual(2.5, Double(EvalModern('ABS(-2.5)')), 0.0001);
  Assert.AreEqual(3.14, Double(EvalModern('ROUND(3.14159, 2)')), 0.0001);
  Assert.AreEqual(2.0, Double(EvalModern('LEAST(3, 2, 5)')), 0.0001);
  Assert.AreEqual(5.0, Double(EvalModern('GREATEST(3, 2, 5)')), 0.0001);
  Assert.AreEqual('ALICE', VarToStr(EvalModern('UPPER([Name])')));
  Assert.AreEqual('alice', VarToStr(EvalModern('LOWER(''ALICE'')')));
  Assert.AreEqual('a b', VarToStr(EvalModern('TRIM(''  a b  '')')));
  Assert.AreEqual(5.0, Double(EvalModern('LEN(''Alice'')')), 0.0001);
  Assert.AreEqual('lic', VarToStr(EvalModern('SUBSTR(''Alice'', 2, 3)')));
  Assert.IsTrue(Boolean(EvalModern('CONTAINS(''Hello World'', ''lo W'')')));
  Assert.IsTrue(Boolean(EvalModern('STARTSWITH(''Hello'', ''he'')')));
  Assert.IsTrue(Boolean(EvalModern('ENDSWITH(''Hello'', ''LO'')')));
  Assert.IsFalse(Boolean(EvalModern('CONTAINS(''Hello'', ''xyz'')')));
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_Aggregates;
var
  EmptyContext: TExpressionContext;
  EmptySet: TClientDataSet;
begin
  // Aggregates traverse the whole dataset (no group range here).
  Assert.AreEqual(35.5, Double(EvalModern('SUM([Amount])')), 0.0001);
  Assert.AreEqual(3.0, Double(EvalModern('COUNT([ID])')), 0.0001);
  // COUNT skips NULL (OD-3); NullText is NULL on every row.
  Assert.AreEqual(0.0, Double(EvalModern('COUNT([NullText])')), 0.0001);
  Assert.AreEqual(11.833333333333, Double(EvalModern('AVG([Amount])')), 0.0001);
  Assert.AreEqual(5.0, Double(EvalModern('MIN([Amount])')), 0.0001);
  Assert.AreEqual(20.0, Double(EvalModern('MAX([Amount])')), 0.0001);

  // OD-1: empty input -> SUM/AVG/MIN/MAX NULL, COUNT 0.
  EmptySet := TClientDataSet.Create(nil);
  try
    EmptySet.FieldDefs.Add('Amount', ftFloat);
    EmptySet.CreateDataSet;
    EmptyContext := FContext;
    EmptyContext.DataSet := EmptySet;
    Assert.IsTrue(VarIsNull(TReportExpression.Evaluate('SUM([Amount])', EmptyContext, emModern)));
    Assert.IsTrue(VarIsNull(TReportExpression.Evaluate('AVG([Amount])', EmptyContext, emModern)));
    Assert.IsTrue(VarIsNull(TReportExpression.Evaluate('MIN([Amount])', EmptyContext, emModern)));
    Assert.IsTrue(VarIsNull(TReportExpression.Evaluate('MAX([Amount])', EmptyContext, emModern)));
    Assert.AreEqual(0.0, Double(TReportExpression.Evaluate('COUNT([Amount])',
      EmptyContext, emModern)), 0.0001);
  finally
    EmptySet.Free;
  end;
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_AggregateComposition;
begin
  // Composition: aggregate result + rest of the expression (Section 20).
  Assert.AreEqual(36.5, Double(EvalModern('SUM([Amount]) + 1')), 0.0001);
  Assert.AreEqual(71.0, Double(EvalModern('SUM([Amount]) * 2')), 0.0001);
  // 35.5 + (1+2+3) = 41.5: aggregates are independent compositions.
  Assert.AreEqual(41.5, Double(EvalModern('SUM([Amount]) + SUM([ID])')), 0.0001);
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_Diagnostics;
begin
  // Structured diagnostics surface as EVittixExpressionError.
  Assert.Contains(EvalModernRaises('SUM(AVG([Amount]))'), 'Nested');
  Assert.Contains(EvalModernRaises('1 / 0'), 'Division by zero');
  Assert.Contains(EvalModernRaises('''a'' + 5'), 'operand');
  Assert.Contains(EvalModernRaises('1 < 2 < 3'), 'non-associative');
  Assert.Contains(EvalModernRaises('FOO(1)'), 'Unknown function');
  Assert.Contains(EvalModernRaises('Amount + 1'), 'data reference');
  Assert.Contains(EvalModernRaises('1 +'), 'expression');
  // Expression length limit (Section 25).
  Assert.Contains(EvalModernRaises('1' + StringOfChar(' ', 5000) + '+ 1'), 'exceeds');
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_DiagnosticCodes;
var
  Code: TExpressionDiagnosticCode;
  DeepExpr, ManyNodesExpr: string;
  I: Integer;
begin
  // Objective 4: granular diagnostic codes are reported precisely.
  Assert.IsTrue(EvalModernCode('1 < 2 < 3', Code));
  Assert.AreEqual(NonAssociativeComparison, Code, '1 < 2 < 3 code');

  Assert.IsTrue(EvalModernCode('FOO(1)', Code));
  Assert.AreEqual(UnknownFunction, Code, 'FOO(1) code');

  Assert.IsTrue(EvalModernCode('1 +', Code));
  Assert.AreEqual(UnexpectedEndOfExpression, Code, 'trailing + code');

  Assert.IsTrue(EvalModernCode('1 2', Code));
  Assert.AreEqual(UnexpectedToken, Code, 'trailing token code');

  Assert.IsTrue(EvalModernCode('''abc', Code));
  Assert.AreEqual(InvalidString, Code, 'unterminated string code');

  Assert.IsTrue(EvalModernCode('1.', Code));
  Assert.AreEqual(InvalidNumber, Code, 'trailing decimal point code');

  Assert.IsTrue(EvalModernCode('1 = ''abc''', Code));
  Assert.AreEqual(InvalidComparison, Code, 'number vs text comparison code');

  Assert.IsTrue(EvalModernCode('1' + StringOfChar(' ', 5000) + '+ 1', Code));
  Assert.AreEqual(ExpressionTooLong, Code, 'length limit code');

  // 10 nested parentheses exceed MaxParserDepth (32).
  DeepExpr := StringOfChar('(', 10) + '1' + StringOfChar(')', 10);
  Assert.IsTrue(EvalModernCode(DeepExpr, Code));
  Assert.AreEqual(ExpressionTooDeep, Code, 'parser depth code');

  // 300 literals + 299 binaries = 599 AST nodes > MaxAstNodes (512),
  // while the token count (600) stays under the tokenizer guard.
  ManyNodesExpr := '1';
  for I := 1 to 299 do
    ManyNodesExpr := ManyNodesExpr + ' + 1';
  Assert.IsTrue(EvalModernCode(ManyNodesExpr, Code));
  Assert.AreEqual(TooManyNodes, Code, 'AST node limit code');
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_Validate;
begin
  Assert.IsTrue(TReportExpression.Validate('1 + 2 * 3', emModern));
  Assert.IsTrue(TReportExpression.Validate('SUM([Amount]) + 1', emModern));
  Assert.IsTrue(TReportExpression.Validate('IF([Amount] > 5, ''hi'', ''lo'')', emModern));
  Assert.IsFalse(TReportExpression.Validate('1 +', emModern));
  Assert.IsFalse(TReportExpression.Validate('SUM(AVG([Amount]))', emModern));
  Assert.IsFalse(TReportExpression.Validate('FOO(1)', emModern));
  Assert.IsFalse(TReportExpression.Validate('1 < 2 < 3', emModern));
  // Legacy mode validation is always True (legacy has no diagnostics).
  Assert.IsTrue(TReportExpression.Validate('1 +', emLegacy));
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Modern_DataResolution;
begin
  Assert.AreEqual('Alice', VarToStr(EvalModern('[Name]')));
  Assert.AreEqual(1.0, Double(EvalModern('[ID]')), 0.0001);
  Assert.AreEqual(12.5, Double(EvalModern('[Parameter.Number]')), 0.0001);
  Assert.AreEqual('Legacy', VarToStr(EvalModern('[Variable.Caption]')));
  Assert.AreEqual('3', VarToStr(EvalModern('[PageNo]')));
  Assert.AreEqual('Title', VarToStr(EvalModern('[ReportTitle]')));
  // Bare identifiers are NOT fields (Section 11) - parse error.
  Assert.Contains(EvalModernRaises('Amount + 1'), 'data reference');
  // Unresolved qualified dataset reference is a structured diagnostic (Section 12).
  Assert.Contains(EvalModernRaises('[NoSuchDataset.Name]'), 'dataset');
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Legacy_TwoArgUnchanged;
begin
  // The two-arg overload keeps the exact legacy flat semantics.
  Assert.AreEqual(9.0, Double(TReportExpression.Evaluate('1 + 2 * 3', FContext)), 0.0001);
  Assert.AreEqual('NULL', VarToStr(TReportExpression.Evaluate('NULL', FContext)));
  Assert.AreEqual(35.5, Double(TReportExpression.Evaluate('SUM([Amount])', FContext)), 0.0001);
  // Explicit emLegacy matches the two-arg overload exactly.
  Assert.AreEqual(9.0, Double(TReportExpression.Evaluate('1 + 2 * 3', FContext, emLegacy)), 0.0001);
end;

{ === Cache Correctness Tests (Objective 1) === }

procedure TPhase4B2BModernEvaluatorTests.Test_Cache_MutationParameterInvalidates;
var
  Engine: TReportEngine;
  Model: TReportModel;
  Context: TExpressionContext;
  Value1, Value2: Variant;
begin
  // Objective 1: Prove parameter mutation invalidates aggregate cache.
  Model := TReportModel.Create;
  try
    FDataSet.First;
    Engine := TReportEngine.Create(Model, FDataSet, nil);
    try
      Context := Default(TExpressionContext);
      Context.DataSet := FDataSet;
      Context.Hooks := Engine;
      Context.Parameters := FParameters;
      Context.Variables := Model.Variables;

      // First evaluation with original parameter
      FParameters.Values['Number'] := '10';
      Value1 := TReportExpression.Evaluate('[Param.Number] + 1', Context, emModern);

      // Mutate parameter
      FParameters.Values['Number'] := '100';
      Value2 := TReportExpression.Evaluate('[Param.Number] + 1', Context, emModern);

      Assert.AreEqual(11.0, Double(Value1), 0.0001, 'Original param value failed');
      Assert.AreEqual(101.0, Double(Value2), 0.0001, 'Mutated param should return new value');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
  end;
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Cache_MutationVariableInvalidates;
var
  Engine: TReportEngine;
  Model: TReportModel;
  Context: TExpressionContext;
  Value1, Value2: Variant;
begin
  // Objective 1: Prove variable mutation invalidates aggregate cache.
  Model := TReportModel.Create;
  try
    FDataSet.First;
    Engine := TReportEngine.Create(Model, FDataSet, nil);
    try
      Context := Default(TExpressionContext);
      Context.DataSet := FDataSet;
      Context.Hooks := Engine;
      Context.Parameters := FParameters;
      Context.Variables := Model.Variables;

      // First evaluation with original variable
      Model.Variables.Values['Multiplier'] := '5';
      Value1 := TReportExpression.Evaluate('[Variable.Multiplier] + 1', Context, emModern);

      // Mutate variable
      Model.Variables.Values['Multiplier'] := '50';
      Value2 := TReportExpression.Evaluate('[Variable.Multiplier] + 1', Context, emModern);

      Assert.AreEqual(6.0, Double(Value1), 0.0001, 'Original variable value failed');
      Assert.AreEqual(51.0, Double(Value2), 0.0001, 'Mutated variable should return new value');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
  end;
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Cache_ModernModeIsolation;
var
  Engine: TReportEngine;
  Model: TReportModel;
  Context: TExpressionContext;
  ModernValue, LegacyValue: Variant;
begin
  // Objective 1: Prove modern and legacy modes produce different results
  // for the same expression (cache isolation via mode-prefixed keys).
  Model := TReportModel.Create;
  try
    FDataSet.First;
    Engine := TReportEngine.Create(Model, FDataSet, nil);
    try
      Context := Default(TExpressionContext);
      Context.DataSet := FDataSet;
      Context.Hooks := Engine;
      Context.Parameters := FParameters;
      Context.Variables := Model.Variables;

      // Modern mode: 1 + 2 * 3 = 7 (precedence)
      ModernValue := TReportExpression.Evaluate('1 + 2 * 3', Context, emModern);

      // Legacy mode: 1 + 2 * 3 = 9 (flat left-to-right)
      LegacyValue := TReportExpression.Evaluate('1 + 2 * 3', Context, emLegacy);

      Assert.AreEqual(7.0, Double(ModernValue), 0.0001, 'Modern should use precedence');
      Assert.AreEqual(9.0, Double(LegacyValue), 0.0001, 'Legacy should be flat left-to-right');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
  end;
end;

procedure TPhase4B2BModernEvaluatorTests.Test_Cache_AggregateMutationInvalidates;
var
  Engine: TReportEngine;
  Model: TReportModel;
  Context: TExpressionContext;
  Value1, Value2: Variant;
begin
  // Objective 1: Prove filter mutation invalidates the aggregate cache.
  // The cache identity includes DataSet.Filter/Filtered (see
  // TAggregateCacheEntry.Matches), so a filter change must re-scan.
  // Note: mid-pass row-data mutation is OUTSIDE the engine execution
  // contract — the cache is execution-local and cleared per pass
  // (ClearExecutionCaches in ExecutePass), so only supported context
  // mutations (params, vars, filter, page/row state) need invalidation.
  Model := TReportModel.Create;
  try
    FDataSet.First;
    FDataSet.Filtered := False;
    Engine := TReportEngine.Create(Model, FDataSet, nil);
    try
      Context := Default(TExpressionContext);
      Context.DataSet := FDataSet;
      Context.Hooks := Engine;
      Context.Parameters := FParameters;
      Context.Variables := Model.Variables;

      // First aggregate evaluation: unfiltered SUM = 10.5 + 20 + 5 = 35.5
      Value1 := TReportExpression.Evaluate('SUM([Amount])', Context, emModern);
      Assert.AreEqual(35.5, Double(Value1), 0.0001, 'Initial unfiltered SUM failed');

      // Mutate the filter so only Amount=5 remains visible
      FDataSet.Filter := 'Amount = 5';
      FDataSet.Filtered := True;

      // Re-evaluate — cache identity (filter/filtered) no longer matches,
      // so a fresh traversal must return 5.
      Value2 := TReportExpression.Evaluate('SUM([Amount])', Context, emModern);
      Assert.AreEqual(5.0, Double(Value2), 0.0001,
        'SUM after filter mutation must reflect the filtered view');

      // Restore
      FDataSet.Filtered := False;
      FDataSet.Filter := '';
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
  end;
end;

procedure TPhase4B2BEndToEndTests.Setup;
begin
  FFixturesDir := FindFixturesDir;
end;

procedure TPhase4B2BEndToEndTests.TearDown;
begin
  // Nothing to clean up
end;

function TPhase4B2BEndToEndTests.FindFixturesDir: string;
var
  Candidate: string;
begin
  Candidate := TPath.Combine(TPath.Combine(GetCurrentDir, 'tests'), 'fixtures', 'modern');
  if TDirectory.Exists(Candidate) then Exit(Candidate);
  Candidate := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\tests\fixtures\modern');
  Candidate := TPath.GetFullPath(Candidate);
  if TDirectory.Exists(Candidate) then Exit(Candidate);
  raise Exception.Create('Could not locate tests/fixtures/modern directory.');
end;

function TPhase4B2BEndToEndTests.LoadModernReport(const AFileName: string): TReportModel;
var
  LoadResult: TReportLoadResult;
  FilePath: string;
begin
  FilePath := TPath.Combine(FFixturesDir, AFileName);
  if not TFile.Exists(FilePath) then
    raise Exception.CreateFmt('Fixture not found: %s', [FilePath]);

  LoadResult := TReportSerializer.LoadFromFileEx(FilePath);
  try
    if not LoadResult.Success then
      raise Exception.CreateFmt('Failed to load fixture: %s', [LoadResult.Errors[0]]);

    if LoadResult.Model.ExpressionLanguageVersion <> 1 then
      raise Exception.Create('Fixture must have ExpressionLanguageVersion = 1');

    Result := LoadResult.ExtractModel;
  finally
    LoadResult.Free;
  end;
end;

function TPhase4B2BEndToEndTests.CreateTestDataSet: TClientDataSet;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.FieldDefs.Add('Amount', ftFloat);
  Result.FieldDefs.Add('Name', ftString, 30);
  Result.CreateDataSet;
  Result.AppendRecord([1, 10.5, 'Alice']);
  Result.AppendRecord([2, 20.0, 'Bob']);
  Result.AppendRecord([3, 5.0, 'Carol']);
  Result.First;
end;

procedure TPhase4B2BEndToEndTests.Test_EndToEnd_ModernPrecedence;
var
  Model: TReportModel;
  DS: TClientDataSet;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Texts: TArray<string>;
  FoundPrecedence: Boolean;
  I: Integer;
begin
  // Objective 3: Prove modern evaluator is selected through report pipeline.
  // Legacy: 1 + 2 * 3 = 9 (flat left-to-right)
  // Modern: 1 + 2 * 3 = 7 (precedence)
  Model := LoadModernReport('modern_precedence.vrt');
  DS := CreateTestDataSet;
  try
    Engine := TReportEngine.Create(Model, DS, nil);
    try
      Doc := TReportExportDocument.Create;
      try
        Engine.ExportDocument := Doc;
        Engine.Prepare;

        // Collect rendered text
        Texts := [];
        for var Page in Doc.Pages do
          for var Cmd in Page.Commands do
            if Cmd is TReportExportTextCommand then
            begin
              var ListHelper := TList<string>.Create;
              try
                ListHelper.AddRange(Texts);
                ListHelper.Add(TReportExportTextCommand(Cmd).Text);
                Texts := ListHelper.ToArray;
              finally
                ListHelper.Free;
              end;
            end;

        // Find the precedence result (should be "7" for modern)
        FoundPrecedence := False;
        for I := 0 to High(Texts) do
          if Texts[I] = '7' then
            FoundPrecedence := True;

        Assert.IsTrue(FoundPrecedence,
          Format('Modern precedence (1+2*3=7) not found in rendered output. Texts: %s',
            [string.Join('|', Texts)]));
      finally
        Doc.Free;
      end;
    finally
      Engine.Free;
    end;
  finally
    DS.Free;
    Model.Free;
  end;
end;

procedure TPhase4B2BEndToEndTests.Test_EndToEnd_ModernNullSemantics;
var
  Model: TReportModel;
  DS: TClientDataSet;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Texts: TArray<string>;
  I: Integer;
  FoundNullResult: Boolean;
begin
  // Objective 3: Prove NULL semantics through report pipeline.
  Model := LoadModernReport('modern_null.vrt');
  DS := CreateTestDataSet;
  try
    Engine := TReportEngine.Create(Model, DS, nil);
    try
      Doc := TReportExportDocument.Create;
      try
        Engine.ExportDocument := Doc;
        Engine.Prepare;

        // Collect rendered text
        Texts := [];
        for var Page in Doc.Pages do
          for var Cmd in Page.Commands do
            if Cmd is TReportExportTextCommand then
            begin
              var ListHelper := TList<string>.Create;
              try
                ListHelper.AddRange(Texts);
                ListHelper.Add(TReportExportTextCommand(Cmd).Text);
                Texts := ListHelper.ToArray;
              finally
                ListHelper.Free;
              end;
            end;

        // Modern NULL IS NULL should render as "true"
        FoundNullResult := False;
        for I := 0 to High(Texts) do
          if SameText(Texts[I], 'true') then
            FoundNullResult := True;

        Assert.IsTrue(FoundNullResult,
          Format('Modern NULL semantics not found in rendered output. Texts: %s',
            [string.Join('|', Texts)]));
      finally
        Doc.Free;
      end;
    finally
      Engine.Free;
    end;
  finally
    DS.Free;
    Model.Free;
  end;
end;

procedure TPhase4B2BEndToEndTests.Test_EndToEnd_ModernAggregateComposition;
var
  Model: TReportModel;
  DS: TClientDataSet;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Texts: TArray<string>;
  I: Integer;
  FoundComposition: Boolean;
begin
  // Objective 3: Prove aggregate composition through report pipeline.
  // SUM([Amount]) + 1 = 35.5 + 1 = 36.5 (modern)
  Model := LoadModernReport('modern_aggregate_composition.vrt');
  DS := CreateTestDataSet;
  try
    Engine := TReportEngine.Create(Model, DS, nil);
    try
      Doc := TReportExportDocument.Create;
      try
        Engine.ExportDocument := Doc;
        Engine.Prepare;

        // Collect rendered text
        Texts := [];
        for var Page in Doc.Pages do
          for var Cmd in Page.Commands do
            if Cmd is TReportExportTextCommand then
            begin
              var ListHelper := TList<string>.Create;
              try
                ListHelper.AddRange(Texts);
                ListHelper.Add(TReportExportTextCommand(Cmd).Text);
                Texts := ListHelper.ToArray;
              finally
                ListHelper.Free;
              end;
            end;

        // Modern SUM([Amount]) + 1 should render as "36.5"
        FoundComposition := False;
        for I := 0 to High(Texts) do
          if Texts[I] = '36.5' then
            FoundComposition := True;

        Assert.IsTrue(FoundComposition,
          Format('Modern aggregate composition not found. Expected 36.5, got: %s',
            [string.Join('|', Texts)]));
      finally
        Doc.Free;
      end;
    finally
      Engine.Free;
    end;
  finally
    DS.Free;
    Model.Free;
  end;
end;

procedure TPhase4B2BEndToEndTests.Test_EndToEnd_FixtureLoadsWithModernVersion;
begin
  // Objective 2: Prove modern fixtures load with ExpressionLanguageVersion = 1.
  var Model := LoadModernReport('modern_precedence.vrt');
  try
    Assert.AreEqual(1, Model.ExpressionLanguageVersion,
      'Modern fixture must load with ExpressionLanguageVersion = 1');
  finally
    Model.Free;
  end;
end;

procedure TPhase4B2BEndToEndTests.Test_EndToEnd_AllModernFixturesRender;
var
  FixtureFiles: TArray<string>;
  FixtureName: string;
  Model: TReportModel;
  LoadResult: TReportLoadResult;
  DS: TClientDataSet;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  TextCount: Integer;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
begin
  // Objective 2 + 14: EVERY fixture in the modern corpus must (a) carry
  // ExpressionLanguageVersion = 1, (b) load through the transactional
  // serializer, and (c) render through the normal engine pipeline with the
  // modern evaluator, producing text output. No fixture may need external
  // parameters, registered named datasets, or mutable state.
  FixtureFiles := TDirectory.GetFiles(FFixturesDir, '*.vrt');
  Assert.IsTrue(Length(FixtureFiles) >= 5,
    'modern fixture corpus must contain at least 5 reports');
  DS := CreateTestDataSet;
  try
    for FixtureName in FixtureFiles do
    begin
      LoadResult := TReportSerializer.LoadFromFileEx(FixtureName);
      try
        if not LoadResult.Success then
          Assert.Fail(Format('%s: load failed: %s',
            [FixtureName, string.Join('; ', LoadResult.Errors)]));
        Assert.AreEqual(1, LoadResult.Model.ExpressionLanguageVersion,
          Format('%s: must declare ExpressionLanguageVersion = 1', [FixtureName]));

        Model := LoadResult.ExtractModel;
        try
          Engine := TReportEngine.Create(Model, DS, nil);
          try
            Doc := TReportExportDocument.Create;
            try
              Engine.ExportDocument := Doc;
              Engine.Prepare;
              Assert.IsTrue(Doc.Pages.Count >= 1,
                Format('%s: engine must produce at least one page', [FixtureName]));

              TextCount := 0;
              for Page in Doc.Pages do
                for Cmd in Page.Commands do
                  if Cmd is TReportExportTextCommand then
                    Inc(TextCount);
              Assert.IsTrue(TextCount > 0,
                Format('%s: modern expressions must render text output', [FixtureName]));
            finally
              Doc.Free;
            end;
          finally
            Engine.Free;
          end;
        finally
          Model.Free;
        end;
      finally
        LoadResult.Free;
      end;
    end;
  finally
    DS.Free;
  end;
end;

{ === TPhase4B2BMigrationAnalyzerTests — Objective 5 === }

procedure TPhase4B2BMigrationAnalyzerTests.BuildDataSet;
begin
  FDataSet := TClientDataSet.Create(nil);
  FDataSet.FieldDefs.Add('ID', ftInteger);
  FDataSet.FieldDefs.Add('Amount', ftFloat);
  FDataSet.FieldDefs.Add('Name', ftString, 30);
  FDataSet.FieldDefs.Add('NullText', ftString, 30);
  FDataSet.CreateDataSet;
  FDataSet.AppendRecord([1, 10.5, 'Alice', Null]);
  FDataSet.AppendRecord([2, 20.0, 'Bob', Null]);
  FDataSet.AppendRecord([3, 5.0, 'Carol', Null]);
  FDataSet.First;
end;

procedure TPhase4B2BMigrationAnalyzerTests.Setup;
begin
  BuildDataSet;
  FParameters := TStringList.Create;
  FParameters.Values['Number'] := '12.5';
  FVariables := TStringList.Create;
  FVariables.Values['Caption'] := 'Legacy';
  FContext := Default(TExpressionContext);
  FContext.DataSet := FDataSet;
  FContext.Parameters := FParameters;
  FContext.Variables := FVariables;
  FContext.PageNumber := 1;
  FContext.TotalPages := 1;
  FContext.RowNumber := 1;
  FContext.ReportTitle := 'Title';
  FContext.ReportDate := 0;
end;

procedure TPhase4B2BMigrationAnalyzerTests.TearDown;
begin
  FVariables.Free;
  FParameters.Free;
  FDataSet.Free;
end;

procedure TPhase4B2BMigrationAnalyzerTests.Test_Migration_SameResult;
var
  Analysis: TExpressionMigrationAnalysis;
begin
  // '1 + 2' evaluates identically in both modes.
  Analysis := TExpressionMigrationAnalyzer.Analyze('1 + 2', FContext);
  Assert.IsTrue(Analysis.LegacySucceeded, 'legacy must succeed');
  Assert.IsTrue(Analysis.ModernSucceeded, 'modern must succeed');
  Assert.AreEqual(mdSameResult, Analysis.Difference, '1 + 2 category');
  Assert.AreEqual(3.0, Double(Analysis.LegacyValue), 0.0001);
  Assert.AreEqual(3.0, Double(Analysis.ModernValue), 0.0001);
end;

procedure TPhase4B2BMigrationAnalyzerTests.Test_Migration_DifferentResult;
var
  Analysis: TExpressionMigrationAnalysis;
begin
  // '1 + 2 * 3': legacy flat left-to-right = 9; modern precedence = 7.
  Analysis := TExpressionMigrationAnalyzer.Analyze('1 + 2 * 3', FContext);
  Assert.IsTrue(Analysis.LegacySucceeded);
  Assert.IsTrue(Analysis.ModernSucceeded);
  Assert.AreEqual(mdDifferentResult, Analysis.Difference, '1 + 2 * 3 category');
  Assert.AreEqual(9.0, Double(Analysis.LegacyValue), 0.0001);
  Assert.AreEqual(7.0, Double(Analysis.ModernValue), 0.0001);
end;

procedure TPhase4B2BMigrationAnalyzerTests.Test_Migration_TypeDifference;
var
  Analysis: TExpressionMigrationAnalysis;
begin
  // 'NULL': legacy produces the TEXT 'NULL'; modern produces a Null Variant.
  Analysis := TExpressionMigrationAnalyzer.Analyze('NULL', FContext);
  Assert.IsTrue(Analysis.LegacySucceeded);
  Assert.IsTrue(Analysis.ModernSucceeded);
  Assert.AreEqual(mdTypeDifference, Analysis.Difference, 'NULL category');
  Assert.AreEqual('NULL', VarToStr(Analysis.LegacyValue));
  Assert.IsTrue(VarIsNull(Analysis.ModernValue));

  // '[NullText]': legacy returns '' (field AsString); modern returns NULL.
  Analysis := TExpressionMigrationAnalyzer.Analyze('[NullText]', FContext);
  Assert.AreEqual(mdTypeDifference, Analysis.Difference, '[NullText] category');
  Assert.AreEqual('', VarToStr(Analysis.LegacyValue));
  Assert.IsTrue(VarIsNull(Analysis.ModernValue));
end;

procedure TPhase4B2BMigrationAnalyzerTests.Test_Migration_LegacyOnly;
var
  Analysis: TExpressionMigrationAnalysis;
begin
  // 'abc': legacy falls back to text; modern rejects bare identifiers.
  Analysis := TExpressionMigrationAnalyzer.Analyze('abc', FContext);
  Assert.IsTrue(Analysis.LegacySucceeded);
  Assert.IsFalse(Analysis.ModernSucceeded, 'modern must reject bare identifier');
  Assert.AreEqual(mdLegacyOnly, Analysis.Difference, 'abc category');
  Assert.AreEqual('abc', VarToStr(Analysis.LegacyValue));
  Assert.Contains(Analysis.ModernError, 'data reference');

  // 'SUM()': legacy degrades to text; modern raises InvalidArgumentCount.
  Analysis := TExpressionMigrationAnalyzer.Analyze('SUM()', FContext);
  Assert.AreEqual(mdLegacyOnly, Analysis.Difference, 'SUM() category');
end;

procedure TPhase4B2BMigrationAnalyzerTests.Test_Migration_ModernErrorCode;
var
  Analysis: TExpressionMigrationAnalysis;
begin
  // The analyzer preserves the structured modern diagnostic code.
  Analysis := TExpressionMigrationAnalyzer.Analyze('FOO(1)', FContext);
  Assert.AreEqual(mdLegacyOnly, Analysis.Difference);
  Assert.AreEqual(UnknownFunction, Analysis.ModernErrorCode, 'unknown function code');

  Analysis := TExpressionMigrationAnalyzer.Analyze('1 < 2 < 3', FContext);
  Assert.AreEqual(mdLegacyOnly, Analysis.Difference);
  Assert.AreEqual(NonAssociativeComparison, Analysis.ModernErrorCode,
    'non-associative comparison code');
end;

procedure TPhase4B2BMigrationAnalyzerTests.Test_Migration_PreservesCallerContext;
var
  Analysis: TExpressionMigrationAnalysis;
  SavedHooks: IReportRenderHooks;
begin
  // The analyzer must not mutate the caller's context: it analyzes on an
  // internal copy, so Hooks and ExpressionMode survive unchanged.
  SavedHooks := FContext.Hooks;
  FContext.Hooks := nil;
  FContext.ExpressionMode := emLegacy;
  Analysis := TExpressionMigrationAnalyzer.Analyze('1 + 2 * 3', FContext);
  Assert.AreEqual(mdDifferentResult, Analysis.Difference);
  Assert.IsFalse(Assigned(FContext.Hooks), 'Hooks must be untouched');
  Assert.AreEqual(emLegacy, FContext.ExpressionMode, 'mode must be untouched');
  FContext.Hooks := SavedHooks;
end;

procedure TPhase4B2BMigrationAnalyzerTests.Test_Migration_AggregateDoesNotTouchCache;
var
  Analysis: TExpressionMigrationAnalysis;
  Model: TReportModel;
  Engine: TReportEngine;
  Snapshot: TReportTraversalSnapshot;
begin
  // The analyzer runs hook-free: no aggregate-cache reads or writes may
  // occur (OD-15/OD-16 state untouched), and the legacy store path's
  // Assigned(Hooks) guard must hold.
  Model := TReportModel.Create;
  try
    FDataSet.First;
    Engine := TReportEngine.Create(Model, FDataSet, nil);
    try
      FContext.Hooks := Engine;
      TReportTraversalDiagnostics.Reset;
      Analysis := TExpressionMigrationAnalyzer.Analyze('SUM([Amount])', FContext);
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      Assert.AreEqual(mdSameResult, Analysis.Difference,
        'plain SUM agrees between modes');
      Assert.AreEqual(35.5, Double(Analysis.LegacyValue), 0.0001);
      Assert.AreEqual(35.5, Double(Analysis.ModernValue), 0.0001);
      Assert.AreEqual(0, Snapshot.AggregateCacheHits,
        'analyzer must never read the aggregate cache');
      // The engine cache still works normally afterwards. The first real
      // evaluation must MISS (proving the analyzer stored no entry) and the
      // second must HIT (proving normal cache operation).
      TReportTraversalDiagnostics.Reset;
      Assert.AreEqual(35.5, Double(TReportExpression.Evaluate('SUM([Amount])',
        FContext)), 0.0001);
      Assert.AreEqual(35.5, Double(TReportExpression.Evaluate('SUM([Amount])',
        FContext)), 0.0001);
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      Assert.AreEqual(1, Snapshot.AggregateCacheMisses,
        'first post-analysis evaluation must miss (analyzer stored nothing)');
      Assert.AreEqual(1, Snapshot.AggregateCacheHits,
        'second post-analysis evaluation must hit the cache');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    FContext.Hooks := nil;
  end;
end;

procedure TPhase4B2BEndToEndTests.Test_EndToEnd_TextExporterUsesModernMode;
var
  Model: TReportModel;
  DS: TClientDataSet;
  OutFile: string;
  Lines: string;
begin
  // Objective 15: Vittix.Report.Export.Text must propagate the expression
  // mode derived from ExpressionLanguageVersion. '1 + 2 * 3' renders as 7
  // under modern mode (legacy fallback would render 9).
  Model := LoadModernReport('modern_precedence.vrt');
  DS := CreateTestDataSet;
  try
    OutFile := TPath.Combine(TPath.GetTempPath,
      'vittix_modern_text_export_test.txt');
    try
      TReportTextExporter.ExportToFile(Model, DS, nil, nil, OutFile);
      Lines := TFile.ReadAllText(OutFile);
      Assert.Contains(Lines, '7',
        'text exporter must use modern precedence (1 + 2 * 3 = 7)');
      Assert.IsFalse(Lines.Contains('9'),
        'text exporter must not fall back to legacy flat evaluation (9)');
    finally
      if TFile.Exists(OutFile) then
        TFile.Delete(OutFile);
    end;
  finally
    DS.Free;
    Model.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPhase4B2BModernExpressionTests);
  TDUnitX.RegisterTestFixture(TPhase4B2BModernEvaluatorTests);
  TDUnitX.RegisterTestFixture(TPhase4B2BEndToEndTests);
  TDUnitX.RegisterTestFixture(TPhase4B2BMigrationAnalyzerTests);

end.
