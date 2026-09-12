unit Test.Vittix.Report.ExpressionAudit;

{
  Phase 4I-19 — Expression Engine Correctness & Architecture Audit

  Characterization tests documenting CURRENT TReportExpression.Evaluate
  behavior.  These are NOT assertions of correct behavior; several assert
  known-defective results (aggregate composition truncation, missing
  precedence, missing parentheses, no AND/OR, no !=, accidental string
  comparisons) so that a future architectural change (Phase 4I-20) can flip
  the expected values in an explicit diff.

  All expectations below were derived from source analysis of
  Vittix.Report.Expressions.pas / Vittix.Report.Aggregates.pas and confirmed
  against the runtime.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Variants,
  Data.DB,
  Datasnap.DBclient,
  Vittix.Report.Context,
  Vittix.Report.Expressions;

type
  [TestFixture]
  TExpressionAuditTests = class
  private
    FDataSet: TClientDataSet;
    FContext: TExpressionContext;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure Audit_Precedence_AddMul_LeftToRight_CurrentBehavior;
    [Test] procedure Audit_Precedence_Parens_LeadingParen_EvalsZero_CurrentBehavior;
    [Test] procedure Audit_Precedence_SubSub_LeftToRight;
    [Test] procedure Audit_Precedence_DivMul_LeftToRight;

    [Test] procedure Audit_Compare_SimpleOps;
    [Test] procedure Audit_Compare_ArithmeticOperand_FallsToTextCompare_CurrentBehavior;
    [Test] procedure Audit_Compare_AndNotSupported_CurrentBehavior;
    [Test] procedure Audit_Compare_BangEquals_Unsupported_CurrentBehavior;

    [Test] procedure Audit_AggregateComposition_SumPlusOne_DiscardsTail_CurrentBehavior;
    [Test] procedure Audit_AggregateComposition_SumTimesTwo_DiscardsTail_CurrentBehavior;
    [Test] procedure Audit_AggregateComposition_OnePlusSum_DiscardsAggregate_CurrentBehavior;
    [Test] procedure Audit_AggregateComposition_SumPlusSum_DiscardsSecond_CurrentBehavior;

    [Test] procedure Audit_Aggregate_UserDataSet_ReturnsLiteralText_CurrentBehavior;

    [Test] procedure Audit_NULL_Literal_IsString_CurrentBehavior;
    [Test] procedure Audit_NULL_Plus_One_IsZero_CurrentBehavior;
    [Test] procedure Audit_NULL_Equals_NULL_TextCompare_True_CurrentBehavior;
    [Test] procedure Audit_FieldPlusNULL_TruncatesTail_CurrentBehavior;

    [Test] procedure Audit_Coercion_IntPlusFloat;
    [Test] procedure Audit_Coercion_DoubleQuotedString_Unsupported_CurrentBehavior;
    [Test] procedure Audit_Coercion_QuotedNumericPlus_Truncates_CurrentBehavior;

    [Test] procedure Audit_Quoted_ArithmeticInsideQuotes_StaysLiteral;
    [Test] procedure Audit_Quoted_CompareOpsInsideQuotes_StaysLiteral;

    [Test] procedure Audit_Malformed_TrailingOperator_SilentlyTruncates;
    [Test] procedure Audit_Malformed_LeadingPlus_AcceptedAsSign;
    [Test] procedure Audit_Malformed_UnbalancedClose_PartialEval;
    [Test] procedure Audit_Malformed_SumOpenParen_FallsToString;
    [Test] procedure Audit_Malformed_UnknownFunction_FallsToString;
    [Test] procedure Audit_Malformed_DoublePlus_TreatedAsSignSequence_CurrentBehavior;
    [Test] procedure Audit_Malformed_TrailingComparator_True;

    [Test] procedure Audit_Nesting_SumPlusParens_Truncates_CurrentBehavior;
    [Test] procedure Audit_Nesting_ParenGroupCompare_TextCompare_False_CurrentBehavior;
  end;

implementation

uses
  Vittix.Report.UserDataSet;

{ TExpressionAuditTests }

procedure TExpressionAuditTests.Setup;
begin
  FDataSet := TClientDataSet.Create(nil);
  FDataSet.FieldDefs.Add('ID', ftInteger, 0, False);
  FDataSet.FieldDefs.Add('Name', ftString, 50, False);
  FDataSet.FieldDefs.Add('Amount', ftFloat, 0, False);
  FDataSet.CreateDataSet;
  FDataSet.AppendRecord([1, 'Alice', 100.0]);
  FDataSet.AppendRecord([2, 'Bob',   200.0]);
  FDataSet.AppendRecord([3, 'Carol',  50.0]);
  FDataSet.First;

  FContext := Default(TExpressionContext);
  FContext.DataSet := FDataSet;
end;

procedure TExpressionAuditTests.TearDown;
begin
  FDataSet.Free;
end;

// --- §4 Precedence ---------------------------------------------------------

procedure TExpressionAuditTests.Audit_Precedence_AddMul_LeftToRight_CurrentBehavior;
begin
  // Flat left-to-right scan: ((1+2)*3)=9, mathematically expected 7.
  Assert.AreEqual(Double(9.0), Double(TReportExpression.Evaluate('1 + 2 * 3', FContext)));
end;

procedure TExpressionAuditTests.Audit_Precedence_Parens_LeadingParen_EvalsZero_CurrentBehavior;
begin
  // EvalSimpleMath cannot read '(' as a number -> returns 0.
  Assert.AreEqual(Double(0.0), Double(TReportExpression.Evaluate('(1 + 2) * 3', FContext)));
end;

procedure TExpressionAuditTests.Audit_Precedence_SubSub_LeftToRight;
begin
  Assert.AreEqual(Double(5.0), Double(TReportExpression.Evaluate('10 - 2 - 3', FContext)));
end;

procedure TExpressionAuditTests.Audit_Precedence_DivMul_LeftToRight;
begin
  Assert.AreEqual(Double(15.0), Double(TReportExpression.Evaluate('10 / 2 * 3', FContext)));
end;

// --- §5 Comparisons --------------------------------------------------------

procedure TExpressionAuditTests.Audit_Compare_SimpleOps;
begin
  // '1 + 2 > 2' -> TEXT compare '1 + 2' vs '2' -> lexically less -> False
  Assert.AreEqual(Boolean(False), Boolean(TReportExpression.Evaluate('1 + 2 > 2', FContext)));
  // '1 + 2 = 3' -> TEXT compare '1 + 2' vs '3' -> not equal -> False
  Assert.AreEqual(Boolean(False), Boolean(TReportExpression.Evaluate('1 + 2 = 3', FContext)));
end;

procedure TExpressionAuditTests.Audit_Compare_ArithmeticOperand_FallsToTextCompare_CurrentBehavior;
begin
  FDataSet.First;
  Assert.AreEqual(Boolean(False), Boolean(TReportExpression.Evaluate('[ID] + 1 > 10', FContext)));
  // '1 * 2 = 2' -> text compare '1 * 2' vs '2' -> False (mathematically true)
  Assert.AreEqual(Boolean(False), Boolean(TReportExpression.Evaluate('[ID] * 2 = 2', FContext)));
end;

procedure TExpressionAuditTests.Audit_Compare_AndNotSupported_CurrentBehavior;
begin
  // No AND/OR/NOT support.  Row 2 (ID=2, Amount=200) -> text
  // '2 > 1 AND 200 < 500'; '<' chosen by operator-type priority, split at
  // '200 < 500', TEXT compare '2 > 1 AND 200' vs '500' -> lexically less -> True.
  FDataSet.RecNo := 2;
  Assert.AreEqual(Boolean(True),
    Boolean(TReportExpression.Evaluate('[ID] > 1 AND [Amount] < 500', FContext)));
end;

procedure TExpressionAuditTests.Audit_Compare_BangEquals_Unsupported_CurrentBehavior;
begin
  // '!=' not in operator table; '=' found inside it, left operand becomes
  // '1 !' -> text compare -> False even though 1 != 2 is mathematically true.
  FDataSet.First;
  Assert.AreEqual(Boolean(False), Boolean(TReportExpression.Evaluate('[ID] != 2', FContext)));
end;

// --- §6/§14 Aggregate composition -----------------------------------------

procedure TExpressionAuditTests.Audit_AggregateComposition_SumPlusOne_DiscardsTail_CurrentBehavior;
begin
  // Aggregate shortcut returns SUM([Amount])=350 and EXITS; ' + 1' discarded.
  Assert.AreEqual(Double(350.0), Double(TReportExpression.Evaluate('SUM([Amount]) + 1', FContext)));
end;

procedure TExpressionAuditTests.Audit_AggregateComposition_SumTimesTwo_DiscardsTail_CurrentBehavior;
begin
  Assert.AreEqual(Double(350.0), Double(TReportExpression.Evaluate('SUM([Amount]) * 2', FContext)));
end;

procedure TExpressionAuditTests.Audit_AggregateComposition_OnePlusSum_DiscardsAggregate_CurrentBehavior;
begin
  // Not aggregate-prefixed: tokens -> '1 + SUM(100)' (current row) -> math
  // reads 1, '+', fails to read 'SUM(...)' -> stops -> 1.
  FDataSet.First;
  Assert.AreEqual(Double(1.0), Double(TReportExpression.Evaluate('1 + SUM([Amount])', FContext)));
end;

procedure TExpressionAuditTests.Audit_AggregateComposition_SumPlusSum_DiscardsSecond_CurrentBehavior;
begin
  // First '(' to LAST ')' -> inner '[Amount]) + SUM([ID]' -> per-row math
  // truncates to [Amount] -> SUM([Amount])=350. SUM([ID]) discarded.
  Assert.AreEqual(Double(350.0),
    Double(TReportExpression.Evaluate('SUM([Amount]) + SUM([ID])', FContext)));
end;

// --- §7 Aggregates over TVittixUserDataSet --------------------------------

procedure TExpressionAuditTests.Audit_Aggregate_UserDataSet_ReturnsLiteralText_CurrentBehavior;
var
  UDS: TVittixUserDataSet;
  Ctx: TExpressionContext;
begin
  // TReportAggregates.TryEvaluate requires Context.DataSet (TDataSet); with a
  // UserDataSet-only context it returns False, falls through, [Amount] is
  // replaced by the CURRENT row value and the literal text is returned.
  UDS := TVittixUserDataSet.Create(nil);
  try
    UDS.DataSet := FDataSet;
    Ctx := Default(TExpressionContext);
    Ctx.UserDataSet := UDS;
    FDataSet.First;
    Assert.AreEqual('SUM(100)',
      VarToStr(TReportExpression.Evaluate('SUM([Amount])', Ctx)));
  finally
    UDS.Free;
  end;
end;

// --- §8 NULL semantics -----------------------------------------------------

procedure TExpressionAuditTests.Audit_NULL_Literal_IsString_CurrentBehavior;
begin
  Assert.AreEqual('NULL', VarToStr(TReportExpression.Evaluate('NULL', FContext)));
end;

procedure TExpressionAuditTests.Audit_NULL_Plus_One_IsZero_CurrentBehavior;
begin
  // EvalSimpleMath cannot read 'NULL' as first number -> returns 0.
  Assert.AreEqual(Double(0.0), Double(TReportExpression.Evaluate('NULL + 1', FContext)));
end;

procedure TExpressionAuditTests.Audit_NULL_Equals_NULL_TextCompare_True_CurrentBehavior;
begin
  Assert.AreEqual(Boolean(True), Boolean(TReportExpression.Evaluate('NULL = NULL', FContext)));
end;

procedure TExpressionAuditTests.Audit_FieldPlusNULL_TruncatesTail_CurrentBehavior;
begin
  // '100 + NULL' -> math reads 100, '+', fails to read NULL -> stops -> 100.
  FDataSet.First;
  Assert.AreEqual(Double(100.0),
    Double(TReportExpression.Evaluate('[Amount] + NULL', FContext)));
end;

// --- §9 Type coercion ------------------------------------------------------

procedure TExpressionAuditTests.Audit_Coercion_IntPlusFloat;
begin
  Assert.AreEqual(Double(3.5), Double(TReportExpression.Evaluate('1 + 2.5', FContext)));
end;

procedure TExpressionAuditTests.Audit_Coercion_DoubleQuotedString_Unsupported_CurrentBehavior;
begin
  // Only single quotes are stripped; double quotes pass through verbatim.
  Assert.AreEqual('"hello"', VarToStr(TReportExpression.Evaluate('"hello"', FContext)));
end;

procedure TExpressionAuditTests.Audit_Coercion_QuotedNumericPlus_Truncates_CurrentBehavior;
begin
  // Outer quotes are stripped as a literal BEFORE arithmetic -> returns the
  // whole inner text (including the embedded quotes) as one string.
  Assert.AreEqual('10'' + ''5',
    VarToStr(TReportExpression.Evaluate('''10'' + ''5''', FContext)));
end;

// --- §10 Strings / quoting -------------------------------------------------

procedure TExpressionAuditTests.Audit_Quoted_ArithmeticInsideQuotes_StaysLiteral;
begin
  // Comparison search is quote-aware and finds no operator; the quoted
  // literal branch strips the outer quotes and exits with the literal.
  Assert.AreEqual('1 + 2', VarToStr(TReportExpression.Evaluate('''1 + 2''', FContext)));
end;

procedure TExpressionAuditTests.Audit_Quoted_CompareOpsInsideQuotes_StaysLiteral;
begin
  Assert.AreEqual('A > B', VarToStr(TReportExpression.Evaluate('''A > B''', FContext)));
  Assert.AreEqual('AND', VarToStr(TReportExpression.Evaluate('''AND''', FContext)));
  Assert.AreEqual('OR', VarToStr(TReportExpression.Evaluate('''OR''', FContext)));
end;

// --- §12 Malformed ---------------------------------------------------------

procedure TExpressionAuditTests.Audit_Malformed_TrailingOperator_SilentlyTruncates;
begin
  Assert.AreEqual(Double(1.0), Double(TReportExpression.Evaluate('1 +', FContext)));
end;

procedure TExpressionAuditTests.Audit_Malformed_LeadingPlus_AcceptedAsSign;
begin
  // Runtime-confirmed: ReadNumber consumes the '+' but TryStrToFloat('+') and
  // TryStrToFloat('+ 1') (sign separated from digits) both fail -> EvalSimpleMath
  // returns 0.  The malformed expression silently evaluates to 0.
  Assert.AreEqual(Double(0.0), Double(TReportExpression.Evaluate('+ 1', FContext)));
end;

procedure TExpressionAuditTests.Audit_Malformed_UnbalancedClose_PartialEval;
begin
  // '1 + 2)' -> arithmetic stops at ')' -> 3. The stray ')' is discarded.
  Assert.AreEqual(Double(3.0), Double(TReportExpression.Evaluate('1 + 2)', FContext)));
end;

procedure TExpressionAuditTests.Audit_Malformed_SumOpenParen_FallsToString;
begin
  // Aggregate parse fails, no tokens, falls through to string fallback.
  Assert.AreEqual('SUM(', VarToStr(TReportExpression.Evaluate('SUM(', FContext)));
end;

procedure TExpressionAuditTests.Audit_Malformed_UnknownFunction_FallsToString;
begin
  Assert.AreEqual('unknownFunction(1)',
    VarToStr(TReportExpression.Evaluate('unknownFunction(1)', FContext)));
end;

procedure TExpressionAuditTests.Audit_Malformed_DoublePlus_TreatedAsSignSequence_CurrentBehavior;
begin
  // Runtime-confirmed: after '+', ReadNumber consumes '+ 2' as a signed
  // number token but TryStrToFloat rejects the embedded space -> operand
  // read fails -> loop stops -> partial result 1.
  Assert.AreEqual(Double(1.0), Double(TReportExpression.Evaluate('1 + + 2', FContext)));
end;

procedure TExpressionAuditTests.Audit_Malformed_TrailingComparator_True;
begin
  // '[ID] >' -> right operand is '' -> text compare '1' vs '' -> greater -> True.
  FDataSet.First;
  Assert.AreEqual(Boolean(True), Boolean(TReportExpression.Evaluate('[ID] >', FContext)));
end;

// --- §13 Nesting -----------------------------------------------------------

procedure TExpressionAuditTests.Audit_Nesting_SumPlusParens_Truncates_CurrentBehavior;
begin
  // Aggregate shortcut swallows up to LAST ')' -> inner expr per row
  // truncates at ')' -> SUM([Amount])=350; '(1 * 2)' discarded.
  Assert.AreEqual(Double(350.0),
    Double(TReportExpression.Evaluate('SUM([Amount]) + (1 * 2)', FContext)));
end;

procedure TExpressionAuditTests.Audit_Nesting_ParenGroupCompare_TextCompare_False_CurrentBehavior;
begin
  // '(1 + 1) > 5' -> comparison split, left '(1 + 1)' non-numeric ->
  // text compare, '(' (#40) < '5' -> False.
  FDataSet.First;
  Assert.AreEqual(Boolean(False), Boolean(TReportExpression.Evaluate('([ID] + 1) > 5', FContext)));
end;

initialization
  TDUnitX.RegisterTestFixture(TExpressionAuditTests);

end.



