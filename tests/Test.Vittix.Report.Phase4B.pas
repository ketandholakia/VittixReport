unit Test.Vittix.Report.Phase4B;

{
  Phase 4B-1 — compatibility evaluator tests.

  These tests lock the replaced evaluator implementation
  (Vittix.Report.Expressions.Compat, reached through the unchanged
  TReportExpression.Evaluate boundary) to the Phase 4A behavioral contract, and
  prove differentially that it still behaves exactly like the frozen legacy
  reference implementation (Test.Vittix.Report.ExpressionLegacyReference).

  Every assertion here describes CURRENT behavior.  Nothing in this unit is a
  statement about what a modern expression language should do; see
  docs/Phase4A-Expression-Compatibility-Contract.md.
}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.Variants,
  System.Hash,
  System.IOUtils,
  System.Generics.Collections,
  Data.DB,
  Datasnap.DBClient,
  Vcl.Graphics,
  DUnitX.TestFramework,
  Vittix.Report.Context,
  Vittix.Report.Expressions,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Engine,
  Vittix.Report.Serializer,
  Vittix.Report.Export.Commands,
  Vittix.Report.Export.Text,
  Vittix.Report.TraversalDiagnostics,
  Test.Vittix.Report.ExpressionLegacyReference;

type
  [TestFixture]
  TPhase4BCompatibilityEvaluatorTests = class
  private
    FDataSet: TClientDataSet;
    FParameters: TStringList;
    FVariables: TStringList;
    FContext: TExpressionContext;

    procedure BuildDataSet;
    function  Eval(const AExpr: string): Variant;
    procedure AssertDifferential(const AExpr: string);
    function  DifferentialCorpus: TArray<string>;
    function  FindReportsDirectory: string;
    function  RepresentativeFixtures: TArray<string>;
    procedure CollectExpressions(AObject: TReportObject; const AList: TStrings);
    function  CollectFixtureExpressions(const AFileName: string): TStrings;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure Test_Differential_Corpus_LegacyAndCompatMatch;
    [Test] procedure Test_Arithmetic_SimpleOperators;
    [Test] procedure Test_Arithmetic_MixedOperators_AreFlatLeftToRight;
    [Test] procedure Test_Arithmetic_SignedNumbers;
    [Test] procedure Test_Arithmetic_DivisionByZero_KeepsAccumulator;
    [Test] procedure Test_Arithmetic_Malformed_ReturnsPartialOrZero;
    [Test] procedure Test_Parentheses_LegacyZeroAndTruncation;
    [Test] procedure Test_Comparison_AllOperatorForms_ReturnBoolean;
    [Test] procedure Test_Comparison_TextIsCaseInsensitive;
    [Test] procedure Test_Comparison_NumericOperands_UseDouble;
    [Test] procedure Test_Comparison_OperatorsInsideQuotes_AreLiteral;
    [Test] procedure Test_UnsupportedOperators_AND_OR_NOT_NotEquals;
    [Test] procedure Test_Fields_NormalStringNumericNullMissing;
    [Test] procedure Test_Fields_RepeatedAndQualifiedTokens;
    [Test] procedure Test_Fields_WhenDataSetMissing_TokenFallsBackToZeroText;
    [Test] procedure Test_Parameters_NumericStringAndMissing;
    [Test] procedure Test_Variables_CaseInsensitiveAndMissing;
    [Test] procedure Test_SystemTokens_PageRowTitleAndRecordNumber;
    [Test] procedure Test_Strings_SingleQuotedLiteralForms;
    [Test] procedure Test_Strings_DoubleQuotesRemainLiteralCharacters;
    [Test] procedure Test_Strings_ComparisonWithFieldValue;
    [Test] procedure Test_Aggregate_SimpleFunctions;
    [Test] procedure Test_Aggregate_GroupBookmarkRange;
    [Test] procedure Test_Aggregate_PrefixEarlyReturn_SwallowsTrailingArithmetic;
    [Test] procedure Test_Aggregate_InnerExpression_PerRowEvaluator;
    [Test] procedure Test_Aggregate_Phase3Cache_RepeatedEvaluation_AndCursor;
    [Test] procedure Test_Malformed_IncompleteAndUnknownTokens;
    [Test] procedure Test_Malformed_OperatorAndAggregateForms;
    [Test] procedure Test_Malformed_UnsupportedFunctionFallsBackToText;
    [Test] procedure Test_Consumer_TextObjectExpression;
    [Test] procedure Test_Consumer_ObjectPrintWhen_AndConditionalFormatting;
    [Test] procedure Test_Consumer_BandPrintWhen_EngineRendering;
    [Test] procedure Test_Consumer_TextExport;
    [Test] procedure Test_Consumer_BarcodePrintWhen_EngineRendering;
    [Test] procedure Test_Consumer_AggregateInSummaryBand;
    [Test] procedure Test_Fixtures_RepresentativeReports_ExpressionsAreCompatible;
    [Test] procedure Test_Fixtures_RepresentativeReports_RenderWithoutModification;
  end;

implementation

const
  CRepresentativeFixtures: array[0..11] of string = (
    '17_object_printwhen_core.vrt',
    '18_barcode_printwhen.vrt',
    '20_printwhen_boolean_coercion.vrt',
    '21_condition_color_boolean_coercion.vrt',
    '22_expression_usage_demo.vrt',
    '25_object_event_before_after_expression.vrt',
    '26_object_event_unsupported_cases.vrt',
    '27_object_event_image_cases.vrt',
    '28_object_event_band_object_order.vrt',
    '31_runtime_parameter_values.vrt',
    '34_reportdata_contract.vrt',
    '37_report_variables.vrt');

function VariantText(const V: Variant): string;
begin
  if VarIsNull(V) then
    Exit('NULL');
  if VarIsEmpty(V) then
    Exit('EMPTY');
  Result := VarToStr(V);
end;

{ Text commands captured by the export document, in page order. }
function CollectDocumentTexts(ADoc: TReportExportDocument): TArray<string>;
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

function CollectCommandCount(ADoc: TReportExportDocument): Integer;
var
  Page: TReportExportPage;
begin
  Result := 0;
  for Page in ADoc.Pages do
    Inc(Result, Page.Commands.Count);
end;

procedure TPhase4BCompatibilityEvaluatorTests.Setup;
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

procedure TPhase4BCompatibilityEvaluatorTests.TearDown;
begin
  FVariables.Free;
  FParameters.Free;
  FDataSet.Free;
end;

procedure TPhase4BCompatibilityEvaluatorTests.BuildDataSet;
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
  FDataSet.FieldDefs.Add('ItemName', ftString, 40);
  FDataSet.CreateDataSet;
  FDataSet.AppendRecord([1, 10.5, 'Alice', 'under_score', Null, 2, 3.5, 'Labels', 'Acme Corp', 'Widget']);
  FDataSet.AppendRecord([2, 20.0, 'Bob', 'other', Null, 4, 1.25, 'Labels', 'Beta Ltd', 'Gadget']);
  FDataSet.AppendRecord([3, 5.0, 'Carol', 'third', Null, 10, 2.0, 'Other', 'Gamma Inc', 'Bolt']);
  FDataSet.First;
end;

function TPhase4BCompatibilityEvaluatorTests.Eval(const AExpr: string): Variant;
begin
  Result := TReportExpression.Evaluate(AExpr, FContext);
end;

{ Differential characterization: the frozen legacy reference and the
  production compatibility evaluator must agree on Variant type, Variant value
  and failure behavior for the same expression and the same context. }
procedure TPhase4BCompatibilityEvaluatorTests.AssertDifferential(const AExpr: string);
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
  if LegacyFailed then
    Exit;

  Assert.AreEqual(Integer(VarType(LegacyValue)), Integer(VarType(CompatValue)),
    Format('Variant type differs for "%s" (legacy %d / compat %d)',
      [AExpr, VarType(LegacyValue), VarType(CompatValue)]));
  Assert.AreEqual(VariantText(LegacyValue), VariantText(CompatValue),
    Format('Variant value differs for "%s"', [AExpr]));
end;

{ Expression corpus used by the differential harness.  It combines the Phase 4A
  contract examples, the legacy expression unit's examples, the expression
  strings found in the representative .vrt fixtures, and malformed forms. }
function TPhase4BCompatibilityEvaluatorTests.DifferentialCorpus: TArray<string>;
begin
  Result := TArray<string>.Create(
    // arithmetic, left to right
    '1 + 2', '10 - 3', '4 * 5', '20 / 4', '1+2', '  7  -  2  ',
    '1 + 2 * 3', '10 - 2 * 3', '10 / 2 + 3', '2 * 3 + 4 + 5',
    '-5 + 3', '+5 - 2', '2 + -3', '2 - -3', '3.5 * 2', '1.5 + 2.5',
    '10 / 0', '0 / 0', '1 / 2 / 2', '1 +', '+', '-', '*', '/', '1 + + 2',
    '1,5 + 1',
    // parentheses (characterized as unsupported)
    '(1 + 2)', '(1 + 2) * 3', '1 + (2 * 3)', '((1))', ')', '(', '(1) + 2',
    // comparisons
    '1 = 1', '1 = 2', '1 <> 2', '1 <> 1', '1 < 2', '2 > 1', '2 >= 2',
    '1 >= 2', '2 <= 2', '3 <= 2', '10 = 10.0', '= 1', '1 =', '=',
    '''a'' = ''A''', '''a'' = ''b''', '''a'' <> ''b''', '''a'' < ''b''',
    '''b'' > ''a''', '''a'' <= ''A''', '''a'' >= ''A''',
    '''ALICE'' = [Name]', '[Name] = ''Alice''', '[Name] = ''alice''',
    '[Amount] > 5', '[Amount] < 5', '[Qty] > 5', '[MissingField] > 0',
    '[MissingField] >', '''a=b'' = ''a=b''', '''a>b'' = ''a>b''',
    '''a<>b'' = ''a<>b''',
    // unsupported boolean operators and "!="
    '1 = 1 AND 2 = 2', '1 = 2 OR 2 = 2', 'NOT (1 = 2)', 'not(1=2)',
    '1 != 2', '2 != 2', 'TRUE = True',
    // fields
    '[ID]', '[Amount]', '[Name]', '[Qty]', '[Rate]', '[GroupName]',
    '[MissingField]', '[NullText]', '[Under_Score]', '[CustomerName]',
    '[NullText] + 1', '[Amount] + [ID]', '[Name] + [ID]', '[ID] - [ID]',
    '[Qty] * [Rate]', '[MissingField] + 1', '[DataSet.Name]',
    '[Customers."Name"]', '[Customers.''Name'']', '[]', '[', '[ID',
    '[ID] ]', 'x[ID]y', '[ID][ID]', 'Total: [Amount]', '[Amount] [ID]',
    'A[ID]B',
    // parameters, variables, system tokens
    '[Param.Number]', '[param.number]', '[PARAM.Number]', '[Parameters.Number]',
    '[Parameter.Label]', '[Param.Missing]', '[Param.]', '[Param.Number] + 1',
    '[Multiplier]', '[Caption]', '[caption]', '[MissingVar]',
    '[PageNo]', '[Page]', '[Page#]', '[TotalPages]', '[TotalPages#]',
    '[RowNumber]', '[RecNo]', '[Line]', '[Line#]', '[ReportTitle]',
    '[ReportDate]', '[Date]', '[Time]', '[DateTime]', '[ PageNo ]',
    '[ReportTitle] + 1',
    // strings and literals
    '''hello''', '''a+b''', '"hello"', '''a''b''', '''''', '''', 'a''b',
    'NULL', 'null', 'true', 'false', 'TRUE', 'abc',
    // aggregates and malformed aggregate shapes
    'SUM([Amount])', 'SUM([Amount]) + 1', 'COUNT([NullText])', 'COUNT([ID])',
    'AVG([Amount])', 'MIN([Amount])', 'MAX([Amount])', 'SUM()', 'SUM(  )',
    'sum([Amount])', 'SUM([Amount]', 'SUM(', 'SUM([MissingField])',
    'COUNT([MissingField])', 'AVG([NullText])', 'MIN([Name])', 'MAX([Name])',
    ' SUM([Amount])', 'TOTAL([Amount])', 'SUM([Qty] * [Rate])',
    'COUNT([ID]) + 1',
    // malformed and fallbacks
    '', '   ', 'unknown_field', 'invalid_function(1)');
end;

// ---------------------------------------------------------------------------
// Differential characterization
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Differential_Corpus_LegacyAndCompatMatch;
var
  Expr: string;
begin
  for Expr in DifferentialCorpus do
    AssertDifferential(Expr);
end;

// ---------------------------------------------------------------------------
// Arithmetic
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Arithmetic_SimpleOperators;
begin
  Assert.AreEqual(3.0, Double(Eval('1 + 2')), 0.0001);
  Assert.AreEqual(7.0, Double(Eval('10 - 3')), 0.0001);
  Assert.AreEqual(20.0, Double(Eval('4 * 5')), 0.0001);
  Assert.AreEqual(5.0, Double(Eval('20 / 4')), 0.0001);
  Assert.AreEqual(Integer(varDouble), Integer(VarType(Eval('1 + 2'))),
    'Arithmetic returns a Double Variant.');
  Assert.AreEqual('', VariantText(Eval('')), 'An empty expression stays empty text.');
  Assert.AreEqual(Integer(varUString), Integer(VarType(Eval(''))),
    'Empty input resolves to a UnicodeString Variant.');
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Arithmetic_MixedOperators_AreFlatLeftToRight;
begin
  Assert.AreEqual(9.0, Double(Eval('1 + 2 * 3')), 0.0001);
  Assert.AreEqual(24.0, Double(Eval('10 - 2 * 3')), 0.0001);
  Assert.AreEqual(8.0, Double(Eval('10 / 2 + 3')), 0.0001);
  Assert.AreEqual(15.0, Double(Eval('2 * 3 + 4 + 5')), 0.0001);
  Assert.AreEqual(10.0, Double(Eval('100 / 5 / 2')), 0.0001);
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Arithmetic_SignedNumbers;
begin
  Assert.AreEqual(-2.0, Double(Eval('-5 + 3')), 0.0001);
  Assert.AreEqual(3.0, Double(Eval('+5 - 2')), 0.0001);
  Assert.AreEqual(-1.0, Double(Eval('2 + -3')), 0.0001);
  Assert.AreEqual(5.0, Double(Eval('2 - -3')), 0.0001);
  Assert.AreEqual(7.0, Double(Eval('3.5 * 2')), 0.0001);
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Arithmetic_DivisionByZero_KeepsAccumulator;
begin
  Assert.AreEqual(10.0, Double(Eval('10 / 0')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('0 / 0')), 0.0001);
  Assert.AreEqual(25.0, Double(Eval('20 / 0 + 5')), 0.0001);
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Arithmetic_Malformed_ReturnsPartialOrZero;
begin
  Assert.AreEqual(1.0, Double(Eval('1 +')), 0.0001, 'Trailing operator truncates the accumulator.');
  Assert.AreEqual(0.0, Double(Eval('+')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('*')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('/')), 0.0001);
  Assert.AreEqual('', VariantText(Eval('   ')), 'Whitespace-only input resolves to empty text.');
end;

// ---------------------------------------------------------------------------
// Parentheses (characterized as unsupported)
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Parentheses_LegacyZeroAndTruncation;
begin
  Assert.AreEqual(0.0, Double(Eval('(1 + 2)')), 0.0001,
    'A leading parenthesis makes the number scan fail, so the result is zero.');
  Assert.AreEqual(0.0, Double(Eval('(1 + 2) * 3')), 0.0001);
  Assert.AreEqual(1.0, Double(Eval('1 + (2 * 3)')), 0.0001,
    'The scan stops at the parenthesized operand and keeps the accumulator.');
  Assert.AreEqual(0.0, Double(Eval('(1) + 2')), 0.0001);
  // Without any arithmetic character there is nothing to scan at all.
  Assert.AreEqual('((1))', VariantText(Eval('((1))')));
  Assert.AreEqual(')', VariantText(Eval(')')));
end;

// ---------------------------------------------------------------------------
// Comparisons
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Comparison_AllOperatorForms_ReturnBoolean;
begin
  Assert.IsTrue(Boolean(Eval('1 = 1')));
  Assert.IsFalse(Boolean(Eval('1 = 2')));
  Assert.IsTrue(Boolean(Eval('1 <> 2')));
  Assert.IsFalse(Boolean(Eval('1 <> 1')));
  Assert.IsTrue(Boolean(Eval('1 < 2')));
  Assert.IsFalse(Boolean(Eval('2 < 1')));
  Assert.IsTrue(Boolean(Eval('2 > 1')));
  Assert.IsFalse(Boolean(Eval('1 > 2')));
  Assert.IsTrue(Boolean(Eval('2 >= 2')));
  Assert.IsFalse(Boolean(Eval('1 >= 2')));
  Assert.IsTrue(Boolean(Eval('2 <= 2')));
  Assert.IsFalse(Boolean(Eval('3 <= 2')));
  Assert.AreEqual(Integer(varBoolean), Integer(VarType(Eval('1 = 1'))),
    'A comparison result is a Boolean Variant.');
  // Legacy edge cases: an empty side is compared as text.
  Assert.IsFalse(Boolean(Eval('= 1')));
  Assert.IsFalse(Boolean(Eval('1 =')));
  Assert.IsTrue(Boolean(Eval('=')));
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Comparison_TextIsCaseInsensitive;
begin
  Assert.IsTrue(Boolean(Eval('''a'' = ''A''')));
  Assert.IsTrue(Boolean(Eval('''ALICE'' = [Name]')));
  Assert.IsTrue(Boolean(Eval('[Name] = ''alice''')));
  Assert.IsFalse(Boolean(Eval('''a'' <> ''A''')));
  Assert.IsTrue(Boolean(Eval('''a'' < ''b''')));
  Assert.IsTrue(Boolean(Eval('''B'' > ''a''')));
  Assert.IsTrue(Boolean(Eval('''a'' <= ''A''')));
  Assert.IsTrue(Boolean(Eval('''a'' >= ''A''')));
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Comparison_NumericOperands_UseDouble;
begin
  // A text comparison would reject '10' vs '10.0'; the Double comparison accepts it.
  Assert.IsTrue(Boolean(Eval('10 = 10.0')));
  Assert.IsTrue(Boolean(Eval('1 = 1.0')));
  Assert.IsTrue(Boolean(Eval('10.5 > 10')));
  Assert.IsTrue(Boolean(Eval('[Amount] > 5')));
  Assert.IsFalse(Boolean(Eval('[Amount] < 5')));
  // The current row has Qty = 2, so "[Qty] > 5" is false for it.
  Assert.IsFalse(Boolean(Eval('[Qty] > 5')));
  Assert.IsTrue(Boolean(Eval('[Qty] < 5')));
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Comparison_OperatorsInsideQuotes_AreLiteral;
begin
  Assert.AreEqual('a=b', VariantText(Eval('''a=b''')));
  Assert.AreEqual('a<>b', VariantText(Eval('''a<>b''')));
  Assert.AreEqual('a<=b', VariantText(Eval('''a<=b''')));
  Assert.AreEqual('a>b', VariantText(Eval('''a>b''')));
  Assert.AreEqual('a+b', VariantText(Eval('''a+b''')));
  Assert.IsTrue(Boolean(Eval('''a=b'' = ''a=b''')));
end;

// ---------------------------------------------------------------------------
// Unsupported boolean operators
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_UnsupportedOperators_AND_OR_NOT_NotEquals;
begin
  // AND is not an operator: the "=" scan stops at the first "=" and the rest of
  // the text becomes the right operand.
  Assert.IsFalse(Boolean(Eval('1 = 1 AND 2 = 2')));
  Assert.IsFalse(Boolean(Eval('1 = 2 OR 2 = 2')));
  Assert.IsFalse(Boolean(Eval('NOT (1 = 2)')));
  Assert.IsFalse(Boolean(Eval('not(1=2)')));
  // "!=" is not inequality: it degrades to "=" with a left operand of "1 !".
  Assert.IsFalse(Boolean(Eval('1 != 2')));
  Assert.IsFalse(Boolean(Eval('2 != 2')));
  Assert.AreEqual(Integer(varBoolean), Integer(VarType(Eval('1 = 1 AND 2 = 2'))));
end;

// ---------------------------------------------------------------------------
// Fields
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Fields_NormalStringNumericNullMissing;
begin
  Assert.AreEqual('Alice', VariantText(Eval('[Name]')));
  Assert.AreEqual('under_score', VariantText(Eval('[Under_Score]')));
  Assert.AreEqual(1.0, Double(Eval('[ID]')), 0.0001);
  Assert.AreEqual(10.5, Double(Eval('[Amount]')), 0.0001);
  // Null field text: AsString is empty, and it is NOT a numeric zero.
  Assert.AreEqual('', VariantText(Eval('[NullText]')));
  Assert.AreEqual(Integer(varUString), Integer(VarType(Eval('[NullText]'))));
  // A resolved empty token makes the arithmetic scan fail, so the accumulator
  // stays at zero (this is the characterized Phase 4A result).
  Assert.AreEqual(0.0, Double(Eval('[NullText] + 1')), 0.0001);
  // A missing field falls back to the TEXT '0'.  Because a lone token takes
  // the single-token value path, that text is then converted to a Double.
  Assert.AreEqual('0', VariantText(Eval('[MissingField]')));
  Assert.AreEqual(Integer(varDouble), Integer(VarType(Eval('[MissingField]'))),
    'A lone [MissingField] token resolves the fallback text through the numeric path.');
  Assert.AreEqual(1.0, Double(Eval('[MissingField] + 1')), 0.0001);
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Fields_RepeatedAndQualifiedTokens;
begin
  Assert.AreEqual('Alice', VariantText(Eval('[Name]')));
  Assert.AreEqual(0.0, Double(Eval('[Name] - [Name]')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('[ID] - [ID]')), 0.0001);
  Assert.AreEqual(11.0, Double(Eval('[ID][ID]')), 0.0001);
  // A dataset qualifier is discarded; the current dataset is still read.
  Assert.AreEqual('Alice', VariantText(Eval('[DataSet.Name]')));
  Assert.AreEqual('Alice', VariantText(Eval('[Customers."Name"]')));
  Assert.AreEqual('Alice', VariantText(Eval('[Customers.''Name'']')));
  // An unterminated bracket token still consumes and resolves the rest of the
  // text; only an empty '[]' token falls back to '0'.
  Assert.AreEqual('0', VariantText(Eval('[]')));
  Assert.AreEqual('1', VariantText(Eval('[ID')),
    'An unterminated token resolves the remaining text as its token name.');
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Fields_WhenDataSetMissing_TokenFallsBackToZeroText;
var
  NoDataContext: TExpressionContext;
begin
  NoDataContext := Default(TExpressionContext);
  Assert.AreEqual('0', VarToStr(TReportExpression.Evaluate('[Amount]', NoDataContext)));
  Assert.AreEqual(0.0, Double(TReportExpression.Evaluate('[Amount]', NoDataContext)), 0.0001);
  Assert.AreEqual('SUM(0)', VarToStr(TReportExpression.Evaluate('SUM([Amount])', NoDataContext)),
    'An unavailable data source keeps the legacy SUM(<resolved text>) fallback.');

  // An inactive dataset follows the same '0' fallback branch.
  FDataSet.DisableControls;
  try
    FDataSet.Active := False;
    try
      Assert.AreEqual('0', VariantText(Eval('[Name]')));
    finally
      FDataSet.Active := True;
      FDataSet.First;
    end;
  finally
    FDataSet.EnableControls;
  end;
end;

// ---------------------------------------------------------------------------
// Parameters, variables and system tokens
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Parameters_NumericStringAndMissing;
begin
  Assert.AreEqual(12.5, Double(Eval('[Param.Number]')), 0.0001);
  Assert.AreEqual('Acme', VariantText(Eval('[Parameter.Label]')));
  Assert.AreEqual(12.5, Double(Eval('[Parameters.Number]')), 0.0001);
  // Parameter names are case-insensitive.
  Assert.AreEqual(12.5, Double(Eval('[param.number]')), 0.0001);
  Assert.AreEqual(12.5, Double(Eval('[PARAM.NUMBER]')), 0.0001);
  // A missing parameter resolves to empty text, not to the '0' fallback.
  Assert.AreEqual('', VariantText(Eval('[Param.Missing]')));
  Assert.AreEqual('', VariantText(Eval('[Param.]')));
  Assert.AreEqual(13.5, Double(Eval('[Param.Number] + 1')), 0.0001);
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Variables_CaseInsensitiveAndMissing;
begin
  Assert.AreEqual(2.0, Double(Eval('[Multiplier]')), 0.0001);
  Assert.AreEqual('Legacy', VariantText(Eval('[Caption]')));
  Assert.AreEqual('Legacy', VariantText(Eval('[caption]')));
  // An unknown variable name falls through to the field lookup and then to '0'.
  Assert.AreEqual('0', VariantText(Eval('[MissingVar]')));
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_SystemTokens_PageRowTitleAndRecordNumber;
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
  Assert.AreEqual('Seven', VariantText(Eval('Seven')));
  Assert.AreEqual('Title', VariantText(Eval('[ReportTitle]')));
  Assert.AreEqual(DateToStr(FContext.ReportDate), VariantText(Eval('[ReportDate]')));
  Assert.AreEqual(DateToStr(FContext.ReportDate), VariantText(Eval('[Date]')));
  Assert.AreEqual(TimeToStr(FContext.ReportDate), VariantText(Eval('[Time]')));
  Assert.AreEqual(DateTimeToStr(FContext.ReportDate), VariantText(Eval('[DateTime]')));

  // [RecNo] prefers RowNumber, otherwise the dataset record number.
  PageContext := FContext;
  SavedRowNumber := PageContext.RowNumber;
  PageContext.RowNumber := 0;
  FDataSet.First;
  FDataSet.Next;
  Assert.AreEqual('2', VarToStr(TReportExpression.Evaluate('[RecNo]', PageContext)));
  Assert.AreEqual('2', VarToStr(TReportExpression.Evaluate('[Line]', PageContext)));
  PageContext.RowNumber := SavedRowNumber;

  // An unknown token text is not case-folded away: it is a plain fallback.
  Assert.AreEqual('0', VariantText(Eval('[ PageNo ]')),
    'Token text is used exactly as written between the brackets.');
end;

// ---------------------------------------------------------------------------
// Strings and literals
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Strings_SingleQuotedLiteralForms;
begin
  Assert.AreEqual('hello', VariantText(Eval('''hello''')));
  Assert.AreEqual('a+b', VariantText(Eval('''a+b''')));
  Assert.AreEqual('a''b', VariantText(Eval('''a''b''')));
  Assert.AreEqual('', VariantText(Eval('''''')));
  Assert.AreEqual(Integer(varUString), Integer(VarType(Eval('''hello'''))));
  // Literal NULL is text, not a NULL Variant.
  Assert.AreEqual('NULL', VariantText(Eval('NULL')));
  Assert.IsFalse(VarIsNull(Eval('NULL')));
  Assert.AreEqual('null', VariantText(Eval('null')));
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Strings_DoubleQuotesRemainLiteralCharacters;
begin
  Assert.AreEqual('"hello"', VariantText(Eval('"hello"')));
  Assert.AreEqual('"hello"', VariantText(Eval('"hello"')));
  Assert.AreEqual(Integer(varUString), Integer(VarType(Eval('"hello"'))));
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Strings_ComparisonWithFieldValue;
begin
  Assert.IsTrue(Boolean(Eval('''Alice'' = [Name]')));
  Assert.IsTrue(Boolean(Eval('[Name] = ''Alice''')));
  Assert.IsFalse(Boolean(Eval('[Name] = ''Bob''')));
  Assert.IsTrue(Boolean(Eval('''Acme Corp'' = [CustomerName]')));
end;

// ---------------------------------------------------------------------------
// Aggregates
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Aggregate_SimpleFunctions;
begin
  // Amounts: 10.5 + 20.0 + 5.0
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount])')), 0.0001);
  Assert.AreEqual(Integer(varInteger), Integer(VarType(Eval('COUNT([ID])'))));
  Assert.AreEqual(3.0, Double(Eval('COUNT([ID])')), 0.0001);
  // A null field becomes empty text, so the aggregate still counts the row.
  Assert.AreEqual(3.0, Double(Eval('COUNT([NullText])')), 0.0001);
  Assert.AreEqual(3.0, Double(Eval('COUNT([MissingField])')), 0.0001);
  Assert.AreEqual(5.0, Double(Eval('MIN([Amount])')), 0.0001);
  Assert.AreEqual(20.0, Double(Eval('MAX([Amount])')), 0.0001);
  Assert.AreEqual(35.5 / 3, Double(Eval('AVG([Amount])')), 0.0001);
  // Non-numeric aggregate input contributes nothing (AVG leaves the count at 0).
  Assert.AreEqual(0.0, Double(Eval('AVG([Name])')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('MIN([Name])')), 0.0001);
  // The aggregate function name is matched case-insensitively.
  Assert.AreEqual(35.5, Double(Eval('sum([Amount])')), 0.0001);
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Aggregate_GroupBookmarkRange;
var
  GroupContext: TExpressionContext;
  GroupStart, GroupEnd: TBookmark;
begin
  FDataSet.First;
  GroupStart := FDataSet.GetBookmark;
  FDataSet.Next;
  FDataSet.Next;
  Assert.AreEqual('Other', FDataSet.FieldByName('GroupName').AsString);
  GroupEnd := FDataSet.GetBookmark;
  try
    GroupContext := FContext;
    GroupContext.GroupStart := GroupStart;
    GroupContext.GroupEnd := GroupEnd;
    // Only the two 'Labels' rows are inside the bookmark range.
    Assert.AreEqual(30.5, Double(TReportExpression.Evaluate('SUM([Amount])', GroupContext)), 0.0001);
    Assert.AreEqual(2.0, Double(TReportExpression.Evaluate('COUNT([ID])', GroupContext)), 0.0001);
    // The cursor is restored to the row it was on before the aggregate ran.
    Assert.AreEqual('Other', FDataSet.FieldByName('GroupName').AsString);
  finally
    FDataSet.FreeBookmark(GroupEnd);
    FDataSet.FreeBookmark(GroupStart);
  end;
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Aggregate_PrefixEarlyReturn_SwallowsTrailingArithmetic;
begin
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount])')), 0.0001);
  // The trailing arithmetic is never evaluated: the aggregate result returns
  // immediately (Phase 4A contract).
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount]) + 1')), 0.0001);
  Assert.AreEqual(35.5, Double(Eval('SUM([Amount]) * 100')), 0.0001);
  Assert.AreEqual(3.0, Double(Eval('COUNT([ID]) + 1')), 0.0001);
  // A prefix that cannot be evaluated falls through to the normal token path.
  Assert.AreEqual('SUM(10.5)', VariantText(Eval(' SUM([Amount])')),
    'A leading space prevents the aggregate prefix match (raw text is matched).');
  Assert.AreEqual('SUM(10.5', VariantText(Eval('SUM([Amount]')),
    'A malformed aggregate start falls through to the token path.');
  Assert.AreEqual('SUM(', VariantText(Eval('SUM(')));
  Assert.AreEqual('TOTAL(10.5)', VariantText(Eval('TOTAL([Amount])')));
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Aggregate_InnerExpression_PerRowEvaluator;
begin
  // The aggregate calls the evaluator once per scanned row with the inner text.
  // Qty * Rate per row: 7.0 + 5.0 + 20.0
  Assert.AreEqual(32.0, Double(Eval('SUM([Qty] * [Rate])')), 0.0001);
  Assert.AreEqual(3.0, Double(Eval('COUNT([Qty] * [Rate])')), 0.0001);
  Assert.AreEqual(20.0, Double(Eval('MAX([Qty] * [Rate])')), 0.0001);
  Assert.AreEqual(5.0, Double(Eval('MIN([Qty] * [Rate])')), 0.0001);
  // A missing field resolves to text '0' per row, so SUM stays 0.
  Assert.AreEqual(0.0, Double(Eval('SUM([MissingField])')), 0.0001);
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Aggregate_Phase3Cache_RepeatedEvaluation_AndCursor;
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
        'The Phase 3 aggregate cache must still avoid the second scan.');
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

// ---------------------------------------------------------------------------
// Malformed input and error behavior
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Malformed_IncompleteAndUnknownTokens;
begin
  Assert.AreEqual('', VariantText(Eval('')));
  Assert.AreEqual('unknown_field', VariantText(Eval('unknown_field')));
  Assert.AreEqual('1 ]', VariantText(Eval('[ID] ]')));
  Assert.AreEqual('x1y', VariantText(Eval('x[ID]y')));
  Assert.AreEqual('A1B', VariantText(Eval('A[ID]B')));
  Assert.AreEqual('Total: 10.5', VariantText(Eval('Total: [Amount]')));
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Malformed_OperatorAndAggregateForms;
begin
  Assert.AreEqual(0.0, Double(Eval('*')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('/')), 0.0001);
  Assert.AreEqual('SUM(', VariantText(Eval('SUM(')));
  Assert.AreEqual(0.0, Double(Eval('SUM()')), 0.0001);
  Assert.AreEqual(0.0, Double(Eval('SUM(  )')), 0.0001);
  // No evaluator exception model exists: nothing above raised.
  Assert.AreEqual(1.0, Double(Eval('1 +')), 0.0001);
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Malformed_UnsupportedFunctionFallsBackToText;
begin
  Assert.AreEqual('invalid_function(1)', VariantText(Eval('invalid_function(1)')));
  Assert.AreEqual('TOTAL(10.5)', VariantText(Eval('TOTAL([Amount])')));
  Assert.AreEqual('SUM(10.5)', VariantText(Eval(' SUM([Amount])')));
  Assert.AreEqual('SUM(10.5', VariantText(Eval('SUM([Amount]')));
  // Numeric fallback, then string fallback.
  Assert.AreEqual(42.0, Double(Eval('42')), 0.0001);
  Assert.AreEqual(Integer(varDouble), Integer(VarType(Eval('42'))));
  Assert.AreEqual('abc', VariantText(Eval('abc')));
  Assert.AreEqual(Integer(varUString), Integer(VarType(Eval('abc'))));
end;

// ---------------------------------------------------------------------------
// Real consumers
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Consumer_TextObjectExpression;
var
  Text: TReportTextObject;
  Field: TReportFieldObject;
begin
  Text := TReportTextObject.Create;
  try
    Text.Expression := '[Name]';
    Assert.AreEqual('Alice', Text.ResolveDisplayText(FContext));

    Text.Expression := '[Qty] * [Rate]';
    Assert.AreEqual(7.0, StrToFloat(Text.ResolveDisplayText(FContext)), 0.0001);

    Text.Expression := '[MissingField]';
    Assert.AreEqual('0', Text.ResolveDisplayText(FContext));

    Text.Expression := '';
    Text.Text := 'Row [ID] of [PageNo]';
    Assert.AreEqual('Row 1 of 3', Text.ResolveDisplayText(FContext));
  finally
    Text.Free;
  end;

  Field := TReportFieldObject.Create;
  try
    Field.DataField := 'Name';
    Assert.AreEqual('Alice', Field.ResolveDisplayText(FContext));
  finally
    Field.Free;
  end;
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Consumer_ObjectPrintWhen_AndConditionalFormatting;
var
  Text: TReportTextObject;
  FontColor, Background, BorderColor: TColor;
begin
  Text := TReportTextObject.Create;
  try
    Text.PrintWhen := '1 = 1';
    Assert.IsTrue(ShouldPrintObject(Text, FContext));
    Text.PrintWhen := '1 = 0';
    Assert.IsFalse(ShouldPrintObject(Text, FContext));
    Text.PrintWhen := '[Qty] > 5';
    Assert.IsFalse(ShouldPrintObject(Text, FContext), '[Qty] is 2 on the current row.');
    Text.PrintWhen := '[Qty] > 1';
    Assert.IsTrue(ShouldPrintObject(Text, FContext));
    Text.PrintWhen := '[MissingField] > 0';
    Assert.IsFalse(ShouldPrintObject(Text, FContext));
    Text.PrintWhen := '1';
    Assert.IsTrue(ShouldPrintObject(Text, FContext));
    Text.PrintWhen := '0';
    Assert.IsFalse(ShouldPrintObject(Text, FContext));
    Text.PrintWhen := 'true';
    Assert.IsTrue(ShouldPrintObject(Text, FContext));
    Text.PrintWhen := 'false';
    Assert.IsFalse(ShouldPrintObject(Text, FContext));
    Text.PrintWhen := 'abc';
    Assert.IsFalse(ShouldPrintObject(Text, FContext));
    Text.PrintWhen := '';
    Assert.IsTrue(ShouldPrintObject(Text, FContext), 'An empty PrintWhen means visible.');

    Text.FontColorCondition := '1 = 1';
    Text.FontColorOnTrue := clRed;
    Text.BackgroundCondition := '[Qty] > 1';
    Text.BackgroundOnTrue := clYellow;
    Text.BorderColorCondition := '1 = 0';
    Text.BorderColorOnTrue := clBlue;
    Text.ResolveTextStyle(FContext, FontColor, Background, BorderColor);
    Assert.AreEqual(Integer(clRed), Integer(FontColor), 'True condition applies the color.');
    Assert.AreEqual(Integer(clYellow), Integer(Background));
    Assert.AreEqual(Integer(Text.BorderColor), Integer(BorderColor),
      'A false condition keeps the object border color.');
  finally
    Text.Free;
  end;
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Consumer_BandPrintWhen_EngineRendering;
var
  Model: TReportModel;
  Band: TReportBand;
  Text: TReportTextObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Texts: TArray<string>;
begin
  Model := TReportModel.Create;
  Doc := TReportExportDocument.Create;
  try
    Band := TReportBand.Create;
    Band.BandType := btMasterData;
    Band.Height := 20;
    Band.PrintWhen := '1 = 1';
    Text := TReportTextObject.Create;
    Text.Expression := '[Name]';
    Text.Bounds := Rect(5, 2, 200, 18);
    Band.Children.Add(Text);
    Model.Objects.Add(Band);

    Engine := TReportEngine.Create(Model, FDataSet, nil, nil);
    try
      Engine.ExportDocument := Doc;
      Engine.Prepare;
      Texts := CollectDocumentTexts(Doc);
      Assert.AreEqual(3, Length(Texts), 'A truthy band PrintWhen prints every data row.');
      Assert.AreEqual('Alice', Texts[0]);
      Assert.AreEqual('Carol', Texts[2]);
    finally
      Engine.Free;
    end;

    // A falsy band PrintWhen suppresses the band (and therefore its rows).
    Band.PrintWhen := '1 = 2';
    Doc.Pages.Clear;
    Engine := TReportEngine.Create(Model, FDataSet, nil, nil);
    try
      Engine.ExportDocument := Doc;
      Engine.Prepare;
      Texts := CollectDocumentTexts(Doc);
      Assert.AreEqual(0, Length(Texts), 'A falsy band PrintWhen prints no rows.');
      Assert.AreEqual(1, Doc.Pages.Count);
    finally
      Engine.Free;
    end;
  finally
    Doc.Free;
    Model.Free;
  end;
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Consumer_TextExport;
var
  Model: TReportModel;
  HeaderBand, MasterBand: TReportBand;
  HeaderText, RowText: TReportTextObject;
  FileName, Content: string;
begin
  Model := TReportModel.Create;
  FileName := TPath.Combine(TPath.GetTempPath, 'VittixPhase4BTextExport.txt');
  try
    HeaderBand := TReportBand.Create;
    HeaderBand.BandType := btPageHeader;
    HeaderBand.Height := 20;
    HeaderText := TReportTextObject.Create;
    HeaderText.Expression := '[Param.ReportTitle]';
    HeaderText.Bounds := Rect(5, 2, 300, 18);
    HeaderBand.Children.Add(HeaderText);
    Model.Objects.Add(HeaderBand);

    MasterBand := TReportBand.Create;
    MasterBand.BandType := btMasterData;
    MasterBand.Height := 20;
    RowText := TReportTextObject.Create;
    RowText.Expression := '[CustomerName]';
    RowText.Bounds := Rect(5, 2, 300, 18);
    MasterBand.Children.Add(RowText);
    Model.Objects.Add(MasterBand);

    TReportTextExporter.ExportToFile(Model, FDataSet, nil, FParameters, FileName);

    Assert.IsTrue(TFile.Exists(FileName), 'The text exporter wrote no file.');
    Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
    Assert.IsTrue(Pos('Compat Parameter Title', Content) > 0,
      'A parameter token must export its value.');
    Assert.IsTrue(Pos('Acme Corp', Content) > 0, 'Row 1 field value missing.');
    Assert.IsTrue(Pos('Beta Ltd', Content) > 0, 'Row 2 field value missing.');
    Assert.IsTrue(Pos('Gamma Inc', Content) > 0, 'Row 3 field value missing.');
  finally
    if TFile.Exists(FileName) then
      TFile.Delete(FileName);
    Model.Free;
  end;
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Consumer_BarcodePrintWhen_EngineRendering;
var
  Model: TReportModel;
  Band: TReportBand;
  Barcode: TReportBarcodeObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
begin
  Model := TReportModel.Create;
  Doc := TReportExportDocument.Create;
  try
    Band := TReportBand.Create;
    Band.BandType := btPageHeader;
    Band.Height := 80;
    Barcode := TReportBarcodeObject.Create;
    Barcode.Value := '1234567890';
    Barcode.Bounds := Rect(10, 5, 220, 60);
    Band.Children.Add(Barcode);
    Model.Objects.Add(Band);

    Barcode.PrintWhen := '1 = 1';
    Engine := TReportEngine.Create(Model, FDataSet, nil, nil);
    try
      Engine.ExportDocument := Doc;
      Engine.Prepare;
      Assert.IsTrue(CollectCommandCount(Doc) > 0, 'A truthy barcode PrintWhen must draw.');
    finally
      Engine.Free;
    end;

    Barcode.PrintWhen := '[Qty] > 5';
    Doc.Pages.Clear;
    Engine := TReportEngine.Create(Model, FDataSet, nil, nil);
    try
      Engine.ExportDocument := Doc;
      Engine.Prepare;
      Assert.AreEqual(0, CollectCommandCount(Doc),
        'The barcode PrintWhen path must suppress the object on a false condition.');
    finally
      Engine.Free;
    end;
  finally
    Doc.Free;
    Model.Free;
  end;
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Consumer_AggregateInSummaryBand;
var
  Model: TReportModel;
  MasterBand, SummaryBand: TReportBand;
  RowText, TotalText: TReportTextObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Texts: TArray<string>;
  I: Integer;
  FoundTotal: Boolean;
begin
  Model := TReportModel.Create;
  Doc := TReportExportDocument.Create;
  try
    MasterBand := TReportBand.Create;
    MasterBand.BandType := btMasterData;
    MasterBand.Height := 20;
    RowText := TReportTextObject.Create;
    RowText.Expression := '[Name]';
    RowText.Bounds := Rect(5, 2, 200, 18);
    MasterBand.Children.Add(RowText);
    Model.Objects.Add(MasterBand);

    SummaryBand := TReportBand.Create;
    SummaryBand.BandType := btReportSummary;
    SummaryBand.Height := 20;
    TotalText := TReportTextObject.Create;
    TotalText.Name := 'totalText';
    TotalText.Expression := 'SUM([Amount])';
    TotalText.Bounds := Rect(5, 2, 200, 18);
    SummaryBand.Children.Add(TotalText);
    Model.Objects.Add(SummaryBand);

    Engine := TReportEngine.Create(Model, FDataSet, nil, nil);
    try
      Engine.ExportDocument := Doc;
      Engine.Prepare;
      Texts := CollectDocumentTexts(Doc);

      FoundTotal := False;
      for I := 0 to High(Texts) do
        if Texts[I] = VarToStr(35.5) then
          FoundTotal := True;
      Assert.IsTrue(FoundTotal,
        Format('The summary band must render the aggregate result; rendered: %s',
          [string.Join('|', Texts)]));
    finally
      Engine.Free;
    end;
  finally
    Doc.Free;
    Model.Free;
  end;
end;

function TPhase4BCompatibilityEvaluatorTests.FindReportsDirectory: string;
var
  Candidate: string;
begin
  Candidate := TPath.Combine(GetCurrentDir, 'reports');
  if TDirectory.Exists(Candidate) then
    Exit(Candidate);

  Candidate := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\..\reports');
  Candidate := TPath.GetFullPath(Candidate);
  if TDirectory.Exists(Candidate) then
    Exit(Candidate);

  raise Exception.Create('Could not locate the repository reports directory.');
end;

function TPhase4BCompatibilityEvaluatorTests.RepresentativeFixtures: TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, Length(CRepresentativeFixtures));
  for I := Low(CRepresentativeFixtures) to High(CRepresentativeFixtures) do
    Result[I] := CRepresentativeFixtures[I];
end;

procedure TPhase4BCompatibilityEvaluatorTests.CollectExpressions(AObject: TReportObject;
  const AList: TStrings);
var
  Band: TReportBand;
  Text: TReportTextObject;
  I: Integer;
begin
  if not Assigned(AObject) then
    Exit;

  if Trim(AObject.PrintWhen) <> '' then
    AList.Add(AObject.PrintWhen);

  if AObject is TReportTextObject then
  begin
    Text := TReportTextObject(AObject);
    if Trim(Text.Expression) <> '' then
      AList.Add(Text.Expression)
    else if (Trim(Text.DataField) = '') and (Pos('[', Text.Text) > 0) then
      // Embedded tokens in the static text are evaluated by the same consumer.
      AList.Add(Text.Text);
  end;

  if AObject is TReportBand then
  begin
    Band := TReportBand(AObject);
    if Trim(Band.BackColorCondition) <> '' then
      AList.Add(Band.BackColorCondition);
    for I := 0 to Band.Children.Count - 1 do
      CollectExpressions(Band.Children[I], AList);
  end;
end;

function TPhase4BCompatibilityEvaluatorTests.CollectFixtureExpressions(
  const AFileName: string): TStrings;
var
  Model: TReportModel;
  Unique: TStringList;
  I: Integer;
begin
  Result := TStringList.Create;
  Unique := TStringList.Create;
  try
    Unique.Sorted := True;
    Unique.Duplicates := dupIgnore;
    Model := TReportSerializer.LoadFromFile(AFileName);
    try
      for I := 0 to Model.Objects.Count - 1 do
        CollectExpressions(Model.Objects[I], Unique);
    finally
      Model.Free;
    end;
    Result.Assign(Unique);
  finally
    Unique.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Representative .vrt fixtures
// ---------------------------------------------------------------------------

procedure TPhase4BCompatibilityEvaluatorTests.Test_Fixtures_RepresentativeReports_ExpressionsAreCompatible;
var
  FixtureName, FileName: string;
  Expressions: TStrings;
  I: Integer;
begin
  for FixtureName in RepresentativeFixtures do
  begin
    FileName := TPath.Combine(FindReportsDirectory, FixtureName);
    Assert.IsTrue(TFile.Exists(FileName), FixtureName + ' is missing from reports/.');
    Expressions := CollectFixtureExpressions(FileName);
    try
      for I := 0 to Expressions.Count - 1 do
        AssertDifferential(Expressions[I]);
    finally
      Expressions.Free;
    end;
  end;
end;

procedure TPhase4BCompatibilityEvaluatorTests.Test_Fixtures_RepresentativeReports_RenderWithoutModification;
var
  FixtureName, FileName, HashBefore, HashAfter: string;
  Model: TReportModel;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  PageCount: Integer;
begin
  for FixtureName in RepresentativeFixtures do
  begin
    FileName := TPath.Combine(FindReportsDirectory, FixtureName);
    Assert.IsTrue(TFile.Exists(FileName), FixtureName + ' is missing from reports/.');
    HashBefore := THashMD5.GetHashStringFromFile(FileName);

    Model := TReportSerializer.LoadFromFile(FileName);
    Doc := TReportExportDocument.Create;
    try
      Engine := TReportEngine.Create(Model, FDataSet, nil, nil);
      try
        Engine.Parameters.Assign(FParameters);
        Engine.ExportDocument := Doc;
        Engine.Prepare;
        PageCount := Doc.Pages.Count;
      finally
        Engine.Free;
      end;

      Assert.IsTrue(PageCount > 0, FixtureName + ': expected at least one rendered page.');
      HashAfter := THashMD5.GetHashStringFromFile(FileName);
      Assert.AreEqual(HashBefore, HashAfter,
        FixtureName + ' must not be modified by the test run.');
    finally
      Doc.Free;
      Model.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPhase4BCompatibilityEvaluatorTests);

end.
