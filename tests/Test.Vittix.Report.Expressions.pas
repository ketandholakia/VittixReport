unit Test.Vittix.Report.Expressions;

{
  Phase 0 — Expression Engine Characterization Tests

  These tests document the CURRENT behavior of TReportExpression.Evaluate.
  They are NOT assertions about correct behavior.
  Several tests deliberately assert known-wrong results (e.g. operator
  precedence) so that a future fix can update the expected value and
  the diff makes the behavioral change explicit.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Variants,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Context,
  Vittix.Report.Expressions;

type
  [TestFixture]
  TTestExpressionEngine = class
  private
    FDataSet: TClientDataSet;
    FContext: TExpressionContext;
    procedure BuildContext;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- System tokens ---
    [Test]
    procedure Test_EmptyExpression_ReturnsEmptyString;
    [Test]
    procedure Test_SinglePageNoToken_ReturnsPageNumber;
    [Test]
    procedure Test_ReportTitleToken;
    [Test]
    procedure Test_ReportDateToken;
    [Test]
    procedure Test_RowNumberToken;

    // --- Field tokens ---
    [Test]
    procedure Test_SingleFieldToken_ReturnsFieldValue;
    [Test]
    procedure Test_SingleFieldToken_HyphenatedValue_ReturnsAsString;
    [Test]
    procedure Test_UnknownFieldToken_ReturnsZero;

    // --- Parameters ---
    [Test]
    procedure Test_ParamToken_ResolvedFromParameters;

    // --- Arithmetic (characterization of current precedence) ---
    [Test]
    procedure Test_Arithmetic_Addition;
    [Test]
    procedure Test_Arithmetic_Precedence_CurrentBehavior;
    [Test]
    procedure Test_Arithmetic_LeftToRight_CurrentBehavior;

    // --- Comparison ---
    [Test]
    procedure Test_Comparison_NumericGreaterThan;
    [Test]
    procedure Test_Comparison_StringEquality;
    [Test]
    procedure Test_Comparison_StringEquality_False;
    [Test]
    procedure Test_Comparison_FieldEqualsStringLiteral;

    // --- Boolean literals ---
    [Test]
    procedure Test_BooleanLiteral_True;
    [Test]
    procedure Test_BooleanLiteral_False;

    // --- Quoted strings ---
    [Test]
    procedure Test_QuotedStringLiteral;
    [Test]
    procedure Test_QuotedStringLiteral_OperatorsInsideQuotes_RemainLiteral;

    // --- Multi-token text with hyphens (BUG-007 characterization) ---
    [Test]
    procedure Test_MultiTokenText_HyphenBetweenFields_TriggersArithmetic;

    // --- Aggregates (characterization) ---
    [Test]
    procedure Test_Aggregate_SUM_WithDataSet;
    [Test]
    procedure Test_Aggregate_SUM_WithUserDataSetNil_NotConfirmed;

    // --- Variables ---
    [Test]
    procedure Test_VariableToken_ResolvedFromVariables;
  end;

implementation

uses
  Vittix.Report.UserDataSet;

{ TTestExpressionEngine }

procedure TTestExpressionEngine.Setup;
begin
  FDataSet := TClientDataSet.Create(nil);
  FDataSet.FieldDefs.Add('ID', ftInteger, 0, False);
  FDataSet.FieldDefs.Add('Name', ftString, 50, False);
  FDataSet.FieldDefs.Add('Amount', ftFloat, 0, False);
  FDataSet.FieldDefs.Add('PhoneNo', ftString, 20, False);
  FDataSet.CreateDataSet;

  FDataSet.AppendRecord([1, 'Alice', 100.0, '555-1234']);
  FDataSet.AppendRecord([2, 'Bob', 200.0, '555-5678']);
  FDataSet.AppendRecord([3, 'Charlie', 50.0, '555-9999']);
  FDataSet.First;

  BuildContext;
end;

procedure TTestExpressionEngine.TearDown;
begin
  FDataSet.Free;
end;

procedure TTestExpressionEngine.BuildContext;
begin
  FContext := Default(TExpressionContext);
  FContext.DataSet := FDataSet;
  FContext.PageNumber := 1;
  FContext.TotalPages := 5;
  FContext.RowNumber := 1;
  FContext.ReportTitle := 'Test Report';
  FContext.ReportDate := EncodeDate(2026, 1, 15);
  FContext.Parameters := TStringList.Create;
  FContext.Parameters.Values['CompanyName'] := 'Acme Corp';
  FContext.Variables := TStringList.Create;
  FContext.Variables.Values['ReportAuthor'] := 'Test Author';
end;

// --- System tokens ---

procedure TTestExpressionEngine.Test_EmptyExpression_ReturnsEmptyString;
begin
  Assert.AreEqual('', VarToStr(TReportExpression.Evaluate('', FContext)));
end;

procedure TTestExpressionEngine.Test_SinglePageNoToken_ReturnsPageNumber;
begin
  Assert.AreEqual('1', VarToStr(TReportExpression.Evaluate('[PageNo]', FContext)));
end;

procedure TTestExpressionEngine.Test_ReportTitleToken;
begin
  Assert.AreEqual('Test Report', VarToStr(TReportExpression.Evaluate('[ReportTitle]', FContext)));
end;

procedure TTestExpressionEngine.Test_ReportDateToken;
begin
  Assert.AreEqual(DateToStr(EncodeDate(2026, 1, 15)),
    VarToStr(TReportExpression.Evaluate('[ReportDate]', FContext)));
end;

procedure TTestExpressionEngine.Test_RowNumberToken;
begin
  Assert.AreEqual('1', VarToStr(TReportExpression.Evaluate('[RowNumber]', FContext)));
end;

// --- Field tokens ---

procedure TTestExpressionEngine.Test_SingleFieldToken_ReturnsFieldValue;
begin
  FDataSet.First;
  Assert.AreEqual('Alice', VarToStr(TReportExpression.Evaluate('[Name]', FContext)));
end;

procedure TTestExpressionEngine.Test_SingleFieldToken_HyphenatedValue_ReturnsAsString;
begin
  FDataSet.First;
  // Single token with hyphenated value: IsSingleTokenExpression guard
  // prevents arithmetic evaluation, so '555-1234' is returned as-is.
  Assert.AreEqual('555-1234', VarToStr(TReportExpression.Evaluate('[PhoneNo]', FContext)));
end;

procedure TTestExpressionEngine.Test_UnknownFieldToken_ReturnsZero;
begin
  // Unknown field tokens resolve to '0' (current behavior).
  Assert.AreEqual('0', VarToStr(TReportExpression.Evaluate('[NonExistent]', FContext)));
end;

// --- Parameters ---

procedure TTestExpressionEngine.Test_ParamToken_ResolvedFromParameters;
begin
  Assert.AreEqual('Acme Corp',
    VarToStr(TReportExpression.Evaluate('[Param.CompanyName]', FContext)));
end;

// --- Arithmetic (characterization of current precedence) ---

procedure TTestExpressionEngine.Test_Arithmetic_Addition;
begin
  Assert.AreEqual(Double(3.0), Double(TReportExpression.Evaluate('1 + 2', FContext)));
end;

procedure TTestExpressionEngine.Test_Arithmetic_Precedence_CurrentBehavior;
begin
  // CURRENT BEHAVIOR: EvalSimpleMath is left-to-right with no precedence.
  // 2 + 3 * 4 = (2 + 3) * 4 = 20  (WRONG — should be 14 with proper precedence)
  // This test documents the current wrong behavior.
  // After a fix, this test should be updated to assert 14.
  Assert.AreEqual(Double(20.0), Double(TReportExpression.Evaluate('2 + 3 * 4', FContext)));
end;

procedure TTestExpressionEngine.Test_Arithmetic_LeftToRight_CurrentBehavior;
begin
  // CURRENT BEHAVIOR: 10 - 2 * 3 = (10 - 2) * 3 = 24  (WRONG — should be 4)
  Assert.AreEqual(Double(24.0), Double(TReportExpression.Evaluate('10 - 2 * 3', FContext)));
end;

// --- Comparison ---

procedure TTestExpressionEngine.Test_Comparison_NumericGreaterThan;
begin
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('200 > 100', FContext)));
end;

procedure TTestExpressionEngine.Test_Comparison_StringEquality;
begin
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('''hello'' = ''hello''', FContext)));
end;

procedure TTestExpressionEngine.Test_Comparison_StringEquality_False;
begin
  Assert.IsFalse(Boolean(TReportExpression.Evaluate('''hello'' = ''world''', FContext)));
end;

procedure TTestExpressionEngine.Test_Comparison_FieldEqualsStringLiteral;
begin
  FDataSet.First;
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('[Name] = ''Alice''', FContext)));
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('''Alice'' = [Name]', FContext)));
  Assert.IsFalse(Boolean(TReportExpression.Evaluate('[Name] = ''Bob''', FContext)));
end;

// --- Boolean literals ---

procedure TTestExpressionEngine.Test_BooleanLiteral_True;
begin
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('true', FContext)));
end;

procedure TTestExpressionEngine.Test_BooleanLiteral_False;
begin
  Assert.IsFalse(Boolean(TReportExpression.Evaluate('false', FContext)));
end;

// --- Quoted strings ---

procedure TTestExpressionEngine.Test_QuotedStringLiteral;
begin
  Assert.AreEqual('hello', VarToStr(TReportExpression.Evaluate('''hello''', FContext)));
end;

procedure TTestExpressionEngine.Test_QuotedStringLiteral_OperatorsInsideQuotes_RemainLiteral;
begin
  // Operators inside single-quoted literals must not be treated as expression operators.
  Assert.AreEqual('a=b', VarToStr(TReportExpression.Evaluate('''a=b''', FContext)));
  Assert.AreEqual('a>b', VarToStr(TReportExpression.Evaluate('''a>b''', FContext)));
  Assert.AreEqual('a+b', VarToStr(TReportExpression.Evaluate('''a+b''', FContext)));
  Assert.AreEqual('a<=b', VarToStr(TReportExpression.Evaluate('''a<=b''', FContext)));
  Assert.AreEqual('a<>b', VarToStr(TReportExpression.Evaluate('''a<>b''', FContext)));
end;

// --- Multi-token text with hyphens (BUG-007 characterization) ---

procedure TTestExpressionEngine.Test_MultiTokenText_HyphenBetweenFields_TriggersArithmetic;
begin
  FDataSet.First;
  // [ID] - [ID] resolves to '1 - 1' then triggers EvalSimpleMath → 0
  // This is the expected arithmetic behavior for subtraction.
  Assert.AreEqual(Double(0.0), Double(TReportExpression.Evaluate('[ID] - [ID]', FContext)));
end;

// --- Aggregates (characterization) ---

procedure TTestExpressionEngine.Test_Aggregate_SUM_WithDataSet;
begin
  // SUM([Amount]) over the full dataset (no group bookmarks).
  // Amounts: 100 + 200 + 50 = 350
  Assert.AreEqual(Double(350.0), Double(TReportExpression.Evaluate('SUM([Amount])', FContext)));
end;

procedure TTestExpressionEngine.Test_Aggregate_SUM_WithUserDataSetNil_NotConfirmed;
var
  Ctx: TExpressionContext;
begin
  // Characterization: This test documents CURRENT behavior.
  // When no data source is available (DataSet and UserDataSet both nil),
  // the unresolved [Amount] token now uses the existing zero-value
  // fallback, so Evaluate returns 'SUM(0)'. Aggregates still do not
  // evaluate over a nil data source (BUG-005). This test does NOT assert
  // that 'SUM(0)' is the desired final behavior.
  Ctx := Default(TExpressionContext);
  Ctx.DataSet := nil;
  Ctx.UserDataSet := nil;
  Assert.AreEqual('SUM(0)', VarToStr(TReportExpression.Evaluate('SUM([Amount])', Ctx)));
end;

// --- Variables ---

procedure TTestExpressionEngine.Test_VariableToken_ResolvedFromVariables;
begin
  Assert.AreEqual('Test Author',
    VarToStr(TReportExpression.Evaluate('[ReportAuthor]', FContext)));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestExpressionEngine);

end.
