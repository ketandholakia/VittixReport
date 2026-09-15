unit Test.Vittix.Report.Phase4A;

{ Phase 4A: executable contract for legacy expression behavior. }

interface

uses
  System.Classes,
  System.SysUtils,
  System.Variants,
  Data.DB,
  Datasnap.DBClient,
  DUnitX.TestFramework,
  Vittix.Report.Context,
  Vittix.Report.Expressions;

type
  [TestFixture]
  TPhase4AExpressionCompatibilityTests = class
  private
    FDataSet: TClientDataSet;
    FParameters: TStringList;
    FVariables: TStringList;
    FContext: TExpressionContext;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure TestLegacyArithmetic_IsFlatLeftToRight;
    [Test] procedure TestLegacyParentheses_AreNotParsed;
    [Test] procedure TestLegacyComparison_IsCaseInsensitive_AndReturnsBoolean;
    [Test] procedure TestLegacyBooleanKeywords_AreNotOperators;
    [Test] procedure TestLegacyNullAndMissingFields_BecomeTextOrZeroFallback;
    [Test] procedure TestLegacyTokens_ParametersVariablesAndQualifiedFields;
    [Test] procedure TestLegacyStrings_RequireSingleQuotes;
    [Test] procedure TestLegacyMalformedExpressions_SilentlyReturnPartialValues;
    [Test] procedure TestLegacyAggregatePrefix_SwallowsTrailingExpression;
  end;

implementation

procedure TPhase4AExpressionCompatibilityTests.Setup;
begin
  FDataSet := TClientDataSet.Create(nil);
  FDataSet.FieldDefs.Add('ID', ftInteger);
  FDataSet.FieldDefs.Add('Amount', ftFloat);
  FDataSet.FieldDefs.Add('Name', ftString, 30);
  FDataSet.FieldDefs.Add('Under_Score', ftString, 30);
  FDataSet.FieldDefs.Add('NullText', ftString, 30);
  FDataSet.CreateDataSet;
  FDataSet.AppendRecord([1, 10.5, 'Alice', 'under_score', Null]);
  FDataSet.AppendRecord([2, 20.0, 'Bob', 'other', Null]);
  FDataSet.First;

  FParameters := TStringList.Create;
  FParameters.Values['Number'] := '12.5';
  FParameters.Values['Label'] := 'Acme';
  FVariables := TStringList.Create;
  FVariables.Values['Multiplier'] := '2';
  FVariables.Values['Caption'] := 'Legacy';
  FContext := Default(TExpressionContext);
  FContext.DataSet := FDataSet;
  FContext.Parameters := FParameters;
  FContext.Variables := FVariables;
  FContext.PageNumber := 3;
  FContext.TotalPages := 9;
  FContext.RowNumber := 7;
  FContext.ReportTitle := 'Title';
end;

procedure TPhase4AExpressionCompatibilityTests.TearDown;
begin
  FVariables.Free;
  FParameters.Free;
  FDataSet.Free;
end;

procedure TPhase4AExpressionCompatibilityTests.TestLegacyArithmetic_IsFlatLeftToRight;
begin
  Assert.AreEqual(3.0, Double(TReportExpression.Evaluate('1 + 2', FContext)), 0.001);
  Assert.AreEqual(7.0, Double(TReportExpression.Evaluate('10 - 3', FContext)), 0.001);
  Assert.AreEqual(20.0, Double(TReportExpression.Evaluate('4 * 5', FContext)), 0.001);
  Assert.AreEqual(5.0, Double(TReportExpression.Evaluate('20 / 4', FContext)), 0.001);
  Assert.AreEqual(9.0, Double(TReportExpression.Evaluate('1 + 2 * 3', FContext)), 0.001);
  Assert.AreEqual(24.0, Double(TReportExpression.Evaluate('10 - 2 * 3', FContext)), 0.001);
  Assert.AreEqual(8.0, Double(TReportExpression.Evaluate('10 / 2 + 3', FContext)), 0.001);
end;

procedure TPhase4AExpressionCompatibilityTests.TestLegacyParentheses_AreNotParsed;
begin
  Assert.AreEqual(0.0, Double(TReportExpression.Evaluate('(1 + 2)', FContext)), 0.001);
  Assert.AreEqual(0.0, Double(TReportExpression.Evaluate('(1 + 2) * 3', FContext)), 0.001);
  Assert.AreEqual(1.0, Double(TReportExpression.Evaluate('1 + (2 * 3)', FContext)), 0.001);
  Assert.AreEqual(0.0, Double(TReportExpression.Evaluate('((1 + 2) * 3)', FContext)), 0.001);
end;

procedure TPhase4AExpressionCompatibilityTests.TestLegacyComparison_IsCaseInsensitive_AndReturnsBoolean;
begin
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('1 = 1', FContext)));
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('1 <> 2', FContext)));
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('2 > 1', FContext)));
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('1 < 2', FContext)));
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('2 >= 2', FContext)));
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('2 <= 2', FContext)));
  Assert.IsTrue(Boolean(TReportExpression.Evaluate('''ALICE'' = [Name]', FContext)));
end;

procedure TPhase4AExpressionCompatibilityTests.TestLegacyBooleanKeywords_AreNotOperators;
begin
  Assert.IsFalse(Boolean(TReportExpression.Evaluate('1 = 1 AND 2 = 2', FContext)));
  Assert.IsFalse(Boolean(TReportExpression.Evaluate('1 = 2 OR 2 = 2', FContext)));
  Assert.IsFalse(Boolean(TReportExpression.Evaluate('NOT (1 = 2)', FContext)));
end;

procedure TPhase4AExpressionCompatibilityTests.TestLegacyNullAndMissingFields_BecomeTextOrZeroFallback;
begin
  Assert.AreEqual('', VarToStr(TReportExpression.Evaluate('[NullText]', FContext)));
  Assert.AreEqual(0.0, Double(TReportExpression.Evaluate('[NullText] + 1', FContext)), 0.001);
  Assert.AreEqual('0', VarToStr(TReportExpression.Evaluate('[MissingField]', FContext)));
  Assert.AreEqual(1.0, Double(TReportExpression.Evaluate('[MissingField] + 1', FContext)), 0.001);
  Assert.AreEqual('NULL', VarToStr(TReportExpression.Evaluate('NULL', FContext)));
end;

procedure TPhase4AExpressionCompatibilityTests.TestLegacyTokens_ParametersVariablesAndQualifiedFields;
begin
  Assert.AreEqual(12.5, Double(TReportExpression.Evaluate('[Param.Number]', FContext)), 0.001);
  Assert.AreEqual('Acme', VarToStr(TReportExpression.Evaluate('[Parameter.Label]', FContext)));
  Assert.AreEqual('Legacy', VarToStr(TReportExpression.Evaluate('[Caption]', FContext)));
  Assert.AreEqual(2.0, Double(TReportExpression.Evaluate('[Multiplier]', FContext)), 0.001);
  Assert.AreEqual('Alice', VarToStr(TReportExpression.Evaluate('[DataSet.Name]', FContext)));
  Assert.AreEqual('under_score', VarToStr(TReportExpression.Evaluate('[Under_Score]', FContext)));
  Assert.AreEqual('3', VarToStr(TReportExpression.Evaluate('[Page#]', FContext)));
end;

procedure TPhase4AExpressionCompatibilityTests.TestLegacyStrings_RequireSingleQuotes;
begin
  Assert.AreEqual('hello', VarToStr(TReportExpression.Evaluate('''hello''', FContext)));
  Assert.AreEqual('a+b', VarToStr(TReportExpression.Evaluate('''a+b''', FContext)));
  Assert.AreEqual('"hello"', VarToStr(TReportExpression.Evaluate('"hello"', FContext)));
  Assert.AreEqual('a''b', VarToStr(TReportExpression.Evaluate('''a''b''', FContext)));
end;

procedure TPhase4AExpressionCompatibilityTests.TestLegacyMalformedExpressions_SilentlyReturnPartialValues;
begin
  Assert.AreEqual('', VarToStr(TReportExpression.Evaluate('', FContext)));
  Assert.AreEqual(1.0, Double(TReportExpression.Evaluate('1 +', FContext)), 0.001);
  Assert.AreEqual(0.0, Double(TReportExpression.Evaluate('*', FContext)), 0.001);
  Assert.AreEqual(0.0, Double(TReportExpression.Evaluate('/', FContext)), 0.001);
  Assert.AreEqual('unknown_field', VarToStr(TReportExpression.Evaluate('unknown_field', FContext)));
  Assert.AreEqual('invalid_function(1)', VarToStr(TReportExpression.Evaluate('invalid_function(1)', FContext)));
  Assert.AreEqual('SUM(', VarToStr(TReportExpression.Evaluate('SUM(', FContext)));
end;

procedure TPhase4AExpressionCompatibilityTests.TestLegacyAggregatePrefix_SwallowsTrailingExpression;
begin
  Assert.AreEqual(30.5, Double(TReportExpression.Evaluate('SUM([Amount])', FContext)), 0.001);
  Assert.AreEqual(30.5, Double(TReportExpression.Evaluate('SUM([Amount]) + 1', FContext)), 0.001);
  Assert.AreEqual(2.0, Double(TReportExpression.Evaluate('COUNT([NullText])', FContext)), 0.001);
end;

initialization
  TDUnitX.RegisterTestFixture(TPhase4AExpressionCompatibilityTests);

end.
