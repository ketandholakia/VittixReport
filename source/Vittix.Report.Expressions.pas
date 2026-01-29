unit Vittix.Report.Expressions;

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Variants,
  Data.DB,
  Vittix.Report.Aggregates,
  Vittix.Report.Context;

type
  TReportExpression = class
  public
    class function Evaluate(
      const Expr: string;
      const Context: TExpressionContext): Variant;
  end;

implementation

{ ================= Field Token Replace ================= }

function ResolveFieldTokens(
  const S: string;
  ADataSet: TDataSet): string;
var
  i, j: Integer;
  FieldName, Value: string;
begin
  Result := '';
  i := 1;

  while i <= Length(S) do
  begin
    if S[i] = '[' then
    begin
      j := i + 1;
      while (j <= Length(S)) and (S[j] <> ']') do Inc(j);

      FieldName := Copy(S, i+1, j-i-1);

      if Assigned(ADataSet)
         and ADataSet.Active
         and (ADataSet.FindField(FieldName) <> nil) then
        Value := ADataSet.FieldByName(FieldName).AsString
      else
        Value := '0';

      Result := Result + Value;
      i := j + 1;
    end
    else
    begin
      Result := Result + S[i];
      Inc(i);
    end;
  end;
end;

{ ================= Simple Math Parser ================= }

function EvalSimpleMath(const S: string): Double;
var
  Parts: TArray<string>;
  i: Integer;
  Acc: Double;
  Op: Char;
begin
  { normalize spacing }
  Parts := S.Replace('+',' + ')
            .Replace('-',' - ')
            .Replace('*',' * ')
            .Replace('/',' / ')
            .Split([' '], TStringSplitOptions.ExcludeEmpty);

  if Length(Parts) = 0 then
    Exit(0);

  Acc := StrToFloatDef(Parts[0], 0);
  i := 1;

  while i < Length(Parts)-1 do
  begin
    Op := Parts[i][1];

    case Op of
      '+': Acc := Acc + StrToFloatDef(Parts[i+1], 0);
      '-': Acc := Acc - StrToFloatDef(Parts[i+1], 0);
      '*': Acc := Acc * StrToFloatDef(Parts[i+1], 0);
      '/':
        if StrToFloatDef(Parts[i+1],0) <> 0 then
          Acc := Acc / StrToFloatDef(Parts[i+1], 1);
    end;

    Inc(i, 2);
  end;

  Result := Acc;
end;

{ ================= Main Evaluate ================= }

class function TReportExpression.Evaluate(
  const Expr: string;
  const Context: TExpressionContext): Variant;
var
  S: string;
  AggValue: Variant;
begin
  Result := '';

  if Trim(Expr) = '' then Exit;

  // Check for aggregate functions first
  // This assumes aggregate functions are of the form FUNC(expression, SCOPE)
  if StartsText('SUM(', Expr) or StartsText('COUNT(', Expr) or
     StartsText('AVG(', Expr) or StartsText('MIN(', Expr) or StartsText('MAX(', Expr) then
  begin
    if TReportAggregates.TryEvaluate(Expr, Context, AggValue) then
      Exit(AggValue);
  end;


  var DblValue: Double; // Declare a temporary Double variable
  if Trim(Expr) = '' then Exit;

  { step 1 — replace [Field] tokens }
  S := ResolveFieldTokens(Expr, Context.DataSet);
  S := Trim(S);

  { step 2 — quoted string literal }
  if (Length(S) >= 2)
     and (S[1] = '''')
     and (S[Length(S)] = '''') then
  begin
    Result := Copy(S, 2, Length(S)-2);
    Exit;
  end;

  { step 3 — math detection }
  if ContainsText(S,'+') or
     ContainsText(S,'-') or
     ContainsText(S,'*') or
     ContainsText(S,'/') then
  begin
    Result := EvalSimpleMath(S);
    Exit;
  end;

  { step 4 — numeric fallback }
  if TryStrToFloat(S, DblValue) then // Attempt conversion into DblValue
  begin
    Result := DblValue; // Assign DblValue to Variant Result
    Exit; // Exit if successful
  end;

  { step 5 — string fallback }
  Result := S;
end;

end.
