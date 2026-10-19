unit Vittix.Report.Aggregates;

{
  Vittix.Report.Aggregates
  ========================
  Evaluates aggregate functions (SUM, COUNT, AVG, MIN, MAX) over a dataset
  range defined by the group bookmarks in TExpressionContext.

  Bug fixes in this revision
  --------------------------
  â€¢ BookmarkLeak: The while-loop previously called GetBookmark every row for
    the group-end boundary check but never freed the returned bookmark.
    Fix: capture in a local variable (RowBM) and free it after the comparison.
}

interface

uses
  System.SysUtils,
  System.Variants,
  Data.DB,
  Vittix.Report.Context,
  Vittix.Report.Expressions,
  Vittix.Report.TraversalDiagnostics;

type
  TReportAggregates = class
  public
    class function TryEvaluate(
      const Expr: string;
      const Context: TExpressionContext;
      out Value: Variant): Boolean;
  end;

implementation

type
  { One factor of a Currency-safe aggregate expression: either a field
    read through AsCurrency or a numeric literal. }
  TAggFactorKind = (afField, afLiteral);
  TAggFactor = record
    Kind: TAggFactorKind;
    Fld: TField;
    Lit: Currency;
  end;

  { One additive term: Sign * Product(Factors). }
  TAggTerm = record
    Neg: Boolean;
    Factors: TArray<TAggFactor>;
  end;

const
  { Field types whose AsCurrency read is exact (integer-exact or decimal
    with scale <= 4).  Anything else (floats) keeps the Double path. }
  CCurrencyExactFieldTypes = [ftBcd, ftFMTBcd, ftCurrency, ftInteger,
    ftSmallint, ftWord, ftLargeint, ftByte, ftAutoInc];

{ Multiplies two Currency values exactly at scale 8 and rounds the
  product to Currency's scale 4 with round-half-AWAY-from-zero (money
  convention; NOT banker's rounding).  Uses exact 64-bit scaled
  arithmetic while the product cannot overflow, and falls back to a
  Double product with the same explicit rounding for magnitudes beyond
  the 64-bit scaled range (documented in DEVELOPER_MANUAL.md). }
function CurrScaled(const A: Currency): Int64; inline;
begin
  // Currency is a scaled 64-bit integer (value * 10000); read that
  // representation directly - Int64() would be a value conversion.
  Result := PInt64(@A)^;
end;

procedure SetCurrScaled(var A: Currency; AValue: Int64); inline;
begin
  // Inverse of CurrScaled: store the scaled representation bit-exact
  // (an Int64 -> Currency cast would be a value conversion).
  PInt64(@A)^ := AValue;
end;

function MulCurrencyHalfAway(const A, B: Currency): Currency;
var
  P, Q, R: Int64;
begin
  if (Abs(CurrScaled(A)) <= 3037000499) and (Abs(CurrScaled(B)) <= 3037000499) then
    P := CurrScaled(A) * CurrScaled(B)                    // exact, scale 8
  else
    P := Round(CurrScaled(A) / 10000.0 * CurrScaled(B));  // magnitude fallback
  if P >= 0 then
  begin
    Q := P div 10000;
    R := P mod 10000;
    if R >= 5000 then Inc(Q);
  end
  else
  begin
    Q := -((-P) div 10000);
    R := (-P) mod 10000;
    if R >= 5000 then Dec(Q);
  end;
  SetCurrScaled(Result, Q);
end;

{ Parses a Currency-safe aggregate inner expression: a sum/difference of
  products of [Field] tokens and numeric literals, e.g.
  [Qty]*[Rate] or [Qty]*[Rate]+[Bonus]*2.  Division, function calls,
  parentheses and any field outside CCurrencyExactFieldTypes make the
  parse fail so the caller keeps the historical Double evaluation.
  Returns False for a bare single token as well - the existing
  single-field path already covers that cheaper case. }
function TryParseCurrencyAggExpr(ADataSet: TDataSet; const AExpr: string;
  out ATerms: TArray<TAggTerm>): Boolean;
var
  S: string;
  P: Integer;

  procedure SkipSpaces;
  begin
    while (P <= Length(S)) and (S[P] = ' ') do
      Inc(P);
  end;

  function ParseFactor(out AFactor: TAggFactor): Boolean;
  var
    Start: Integer;
    Name: string;
    Fld: TField;
  begin
    Result := False;
    AFactor.Kind := afLiteral;
    AFactor.Fld := nil;
    AFactor.Lit := 0;
    SkipSpaces;
    if P > Length(S) then
      Exit;
    if S[P] = '[' then
    begin
      Start := P + 1;
      while (P <= Length(S)) and (S[P] <> ']') do
        Inc(P);
      if (P > Length(S)) or (P = Start) then
        Exit;
      Name := Copy(S, Start, P - Start);
      Inc(P); // ']'
      if Pos('.', Name) > 0 then
        Exit; // qualified tokens keep the Double path
      Fld := ADataSet.FindField(Name);
      if not Assigned(Fld) or not (Fld.DataType in CCurrencyExactFieldTypes) then
        Exit;
      AFactor.Kind := afField;
      AFactor.Fld := Fld;
      Result := True;
    end
    else
    begin
      Start := P;
      while (P <= Length(S)) and CharInSet(S[P], ['0'..'9', '.']) do
        Inc(P);
      // plain unsigned number (sign handled by term/factor grammar)
      if P = Start then
        Exit;
      if not TryStrToCurr(Copy(S, Start, P - Start), AFactor.Lit) then
        Exit;
      AFactor.Kind := afLiteral;
      Result := True;
    end;
  end;

  function ParseTerm(out ATerm: TAggTerm): Boolean;
  var
    Factor: TAggFactor;
  begin
    Result := False;
    SetLength(ATerm.Factors, 0);
    ATerm.Neg := False;
    SkipSpaces;
    if (P <= Length(S)) and (S[P] = '-') then
    begin
      ATerm.Neg := True;
      Inc(P);
    end;
    if not ParseFactor(Factor) then
      Exit;
    ATerm.Factors := ATerm.Factors + [Factor];
    SkipSpaces;
    while (P <= Length(S)) and (S[P] = '*') do
    begin
      Inc(P);
      if not ParseFactor(Factor) then
        Exit;
      ATerm.Factors := ATerm.Factors + [Factor];
      SkipSpaces;
    end;
    Result := True;
  end;

var
  Term: TAggTerm;
  Ops, I, J: Integer;
begin
  Result := False;
  SetLength(ATerms, 0);
  S := Trim(AExpr);
  // A bare token or anything with '/' stays on the existing paths.
  if (S = '') or (Pos('/', S) > 0) then
    Exit;

  P := 1;
  Ops := 0;
  repeat
    if not ParseTerm(Term) then
      Exit;
    if Length(ATerms) > 0 then
      Term.Neg := Term.Neg xor (S[Ops] = '-');
    ATerms := ATerms + [Term];
    SkipSpaces;
    if P <= Length(S) then
    begin
      if not CharInSet(S[P], ['+', '-']) then
        Exit;
      Ops := P;
      Inc(P);
    end
    else
      Break;
  until False;

  // Require at least one operator (a bare [Field] uses the cheaper
  // single-field path) and at least one field factor.
  if Length(ATerms) < 2 then
  begin
    if (Length(ATerms) = 1) and (Length(ATerms[0].Factors) > 1) then
      Result := True   // a pure product like [Qty]*[Rate]
    else
      Exit;
  end
  else
    Result := True;
  for I := 0 to High(ATerms) do
    for J := 0 to High(ATerms[I].Factors) do
      if ATerms[I].Factors[J].Kind = afField then
        Exit(True); // at least one field: good
  Result := False; // literals only: let the Double path handle it
end;

{ Evaluates the parsed terms for the current row in Currency.  Returns
  False when any field operand is NULL (the row is skipped, as before). }
function EvalCurrencyAggTerms(const ATerms: TArray<TAggTerm>;
  out AValue: Currency): Boolean;
var
  Term: TAggFactor;
  I, J: Integer;
  TermVal, FactorVal: Currency;
begin
  Result := False;
  AValue := 0;
  for I := 0 to High(ATerms) do
  begin
    TermVal := 1;
    for J := 0 to High(ATerms[I].Factors) do
    begin
      Term := ATerms[I].Factors[J];
      if Term.Kind = afField then
      begin
        if Term.Fld.IsNull then
          Exit;
        FactorVal := Term.Fld.AsCurrency;
      end
      else
        FactorVal := Term.Lit;
      TermVal := MulCurrencyHalfAway(TermVal, FactorVal);
    end;
    if ATerms[I].Neg then
      AValue := AValue - TermVal
    else
      AValue := AValue + TermVal;
  end;
  Result := True;
end;



class function TReportAggregates.TryEvaluate(
  const Expr: string;
  const Context: TExpressionContext;
  out Value: Variant): Boolean;
var
  Func, InnerExpr: string;
  P1, P2: Integer;
  SaveBM, RowBM: TBookmark;    // SaveBM = restore point; RowBM = per-row boundary check
  Count: Integer;
  Sum, ValFloat: Double;
  ValVar: Variant;
  FirstVal: Boolean;
  MinVal, MaxVal: Double;
  AtGroupEnd: Boolean;
  { Currency-safe accumulation for NUMERIC(18,x) columns (FireDAC
    ftBCD/ftFMTBCD, TCurrencyField): SUM/AVG/MIN/MAX accumulate in Currency,
    which is a scaled 64-bit integer and therefore EXACT for the 4 decimal
    places those columns carry - the SQL SUM() comparison no longer drifts.
    Chosen over TBcd: Currency covers NUMERIC up to scale 4 (the dominant
    money layout) with plain arithmetic and no FMTBcd dependency, while
    values with scale > 4 arrive from the field/evaluator as Double anyway,
    where a BCD accumulator would only add rounding steps without gaining
    exactness.  Double accumulation is kept for every other input so float
    sums with more than 4 decimals behave exactly as before. }
  SumC, ValCur, MinC, MaxC: Currency;
  UseCurrency: Boolean;
  FieldBound, BcdBound: Boolean;
  BcdScale, Pw: Integer;
  ScaleMul: Double;
  SumScaled, ScaledI, MinScaled, MaxScaled: Int64;
  AggFld: TField;
  AggTerms: TArray<TAggTerm>;
  TermsParsed: Boolean;
  RowHasValue: Boolean;
  FieldName: string;

  { Adds one non-null value to the Currency accumulators (SUM/AVG/MIN/MAX). }
  procedure AccumulateCurrencyValue(AVal: Currency);
  begin
    if Func = 'SUM' then
      SumC := SumC + AVal
    else if Func = 'AVG' then
    begin
      SumC := SumC + AVal;
      Inc(Count);
    end
    else if Func = 'MIN' then
    begin
      if FirstVal or (AVal < MinC) then MinC := AVal;
    end
    else if Func = 'MAX' then
    begin
      if FirstVal or (AVal > MaxC) then MaxC := AVal;
    end;
    if Func <> 'COUNT' then FirstVal := False;
  end;

  { Adds one non-null value to the scaled-integer accumulators used for
    BCD columns whose scale exceeds Currency's 4 decimals. }
  procedure AccumulateScaledValue(AVal: Int64);
  begin
    if Func = 'SUM' then
      SumScaled := SumScaled + AVal
    else if Func = 'AVG' then
    begin
      SumScaled := SumScaled + AVal;
      Inc(Count);
    end
    else if Func = 'MIN' then
    begin
      if FirstVal or (AVal < MinScaled) then MinScaled := AVal;
    end
    else if Func = 'MAX' then
    begin
      if FirstVal or (AVal > MaxScaled) then MaxScaled := AVal;
    end;
    if Func <> 'COUNT' then FirstVal := False;
  end;

  { Converts a value scaled by ScaleMul (10^BcdScale, integral) to Double
    as intPart + fraction/ScaleMul - the nearest-double decomposition of
    the exact decimal, avoiding one large Int64/Double division that can
    round away from the decimal value (e.g. 10000100000/1e6). }
  function ScaledToDouble(AValue: Int64): Double;
  var
    ScaleI: Int64;
    IntPart: Int64;
  begin
    ScaleI := Trunc(ScaleMul);
    IntPart := AValue div ScaleI;
    Result := IntPart + (AValue - IntPart * ScaleI) / ScaleI;
  end;

  { Parses the field's exact BCD string form ('-1234.5678') into an Int64
    scaled by AScale digits.  False when the text is not a clean decimal
    in range (the row is then skipped, like a failed conversion today). }
  function ReadScaledInt64(const AText: string; out AValue: Int64): Boolean;
  var
    T, IntPart, FracPart: string;
    Dot, Frac: Integer;
    Neg: Boolean;
  begin
    Result := False;
    T := Trim(AText);
    Neg := (T <> '') and (T[1] = '-');
    if Neg then
      Delete(T, 1, 1)
    else if (T <> '') and (T[1] = '+') then
      Delete(T, 1, 1);
    Dot := Pos('.', T);
    if Dot = 0 then
    begin
      IntPart := T;
      FracPart := '';
    end
    else
    begin
      IntPart := Copy(T, 1, Dot - 1);
      FracPart := Copy(T, Dot + 1, MaxInt);
    end;
    if IntPart = '' then
      IntPart := '0';
    // The field's BCD string never carries more fraction digits than its
    // declared scale; anything longer cannot come from this column.
    Frac := Length(FracPart);
    if Frac > BcdScale then
      Exit;
    while Frac < BcdScale do
    begin
      FracPart := FracPart + '0';
      Inc(Frac);
    end;
    if (IntPart = '') or (Length(IntPart) + BcdScale > 18) then
      Exit; // outside Int64 safety: caller falls back to the Currency row value
    try
      AValue := StrToInt64(IntPart + FracPart);
    except
      Exit;
    end;
    if Neg then
      AValue := -AValue;
    Result := True;
  end;

begin
  Result := False;
  Value := Null;

  P1 := Pos('(', Expr);
  P2 := LastDelimiter(')', Expr);

  if (P1 <= 1) or (P2 <= P1) then Exit;

  Func      := UpperCase(Trim(Copy(Expr, 1, P1 - 1)));
  InnerExpr := Copy(Expr, P1 + 1, P2 - P1 - 1);

  if (Func <> 'SUM') and (Func <> 'COUNT') and (Func <> 'AVG') and
     (Func <> 'MIN') and (Func <> 'MAX') then Exit;

  if not Assigned(Context.DataSet) or not Context.DataSet.Active then Exit;

  // Currency-mode probe: a bare [Field] token bound to a BCD/currency
  // column is read via Field.AsCurrency per row - no Double round trip.
  FieldBound := False;
  BcdBound := False;
  AggFld := nil;
  FieldName := '';
  if (Length(InnerExpr) >= 3) and (InnerExpr[1] = '[') and
     (InnerExpr[Length(InnerExpr)] = ']') then
  begin
    FieldName := Copy(InnerExpr, 2, Length(InnerExpr) - 2);
    if (FieldName <> '') and (Pos('.', FieldName) = 0) then
    begin
      AggFld := Context.DataSet.FindField(FieldName);
      FieldBound := Assigned(AggFld) and
        ((AggFld.DataType = ftCurrency) or
         ((AggFld.DataType in [ftBcd, ftFMTBcd]) and
          (AggFld.Size in [0..4])));
      BcdBound := Assigned(AggFld) and not FieldBound and
        (AggFld.DataType in [ftBcd, ftFMTBcd]) and (AggFld.Size > 4);
      if BcdBound then
      begin
        BcdScale := AggFld.Size;
        ScaleMul := 1.0;
        for Pw := 1 to BcdScale do
          ScaleMul := ScaleMul * 10.0;
      end;
    end;
  end;

  // Currency-mode probe 2: a sum/difference of products of exact fields
  // and literals (the invoice case SUM([Qty]*[Rate])).  Evaluated per row
  // in Currency with round-half-away-from-zero at 4 decimals; division,
  // floats, qualified tokens or anything unparsable keep the Double path.
  TermsParsed := False;
  if not FieldBound then
    TermsParsed := TryParseCurrencyAggExpr(Context.DataSet, InnerExpr, AggTerms);

  TReportTraversalDiagnostics.AggregateEvaluationStarted;
  if Assigned(Context.Hooks) and
     Context.Hooks.TryGetAggregateCache(Expr, Context, Value) then
  begin
    TReportTraversalDiagnostics.AggregateCacheHit;
    Exit(True);
  end;
  TReportTraversalDiagnostics.AggregateCacheMiss;

  SaveBM := Context.DataSet.GetBookmark;
  Context.DataSet.DisableControls;
  try
    if Context.GroupStart <> nil then
      Context.DataSet.GotoBookmark(Context.GroupStart)
    else
      Context.DataSet.First;

    Count       := 0;
    Sum         := 0.0;
    SumC        := 0;
    SumScaled   := 0;
    MinScaled   := 0;
    MaxScaled   := 0;
    MinVal      := 0.0;
    MaxVal      := 0.0;
    MinC        := 0;
    MaxC        := 0;
    FirstVal    := True;
    UseCurrency := FieldBound or TermsParsed;
    TReportTraversalDiagnostics.AggregateTraversalStarted;

    while not Context.DataSet.Eof do
    begin
      TReportTraversalDiagnostics.AggregateRowVisited;
      // --- Group-end boundary check (fixed bookmark leak) ---
      AtGroupEnd := False;
      if Context.GroupEnd <> nil then
      begin
        RowBM := Context.DataSet.GetBookmark;  // allocate
        try
          AtGroupEnd :=
            (Context.DataSet.CompareBookmarks(RowBM, Context.GroupEnd) = 0);
        finally
          Context.DataSet.FreeBookmark(RowBM); // always free
        end;
      end;

      if AtGroupEnd then Break;
      // ------------------------------------------------------

      if BcdBound then
      begin
        // NUMERIC(x, scale>4): accumulate EXACTLY at the field's own
        // scale; the Double conversion happens once, at the result.
        if not AggFld.IsNull then
        begin
          if ReadScaledInt64(AggFld.AsString, ScaledI) then
          begin
            if Func = 'COUNT' then
              Inc(Count)
            else
              AccumulateScaledValue(ScaledI);
          end
        end;
      end
      else if FieldBound or TermsParsed then
      begin
        // Exact Currency row value (bare BCD/currency field or a parsed
        // sum-of-products); NULL operands skip the row as before.
        RowHasValue := False;
        if FieldBound then
        begin
          if not AggFld.IsNull then
          begin
            ValCur := AggFld.AsCurrency;
            RowHasValue := True;
          end;
        end
        else
          RowHasValue := EvalCurrencyAggTerms(AggTerms, ValCur);

        if RowHasValue then
        begin
          if Func = 'COUNT' then
            Inc(Count)
          else
            AccumulateCurrencyValue(ValCur);
        end;
      end
      else
      begin
        ValVar := TReportExpression.Evaluate(InnerExpr, Context);

        if not VarIsNull(ValVar) then
        begin
          if Func = 'COUNT' then
            Inc(Count)
          else
          begin
            // A varCurrency value (modern-mode field token, TCurrencyField)
            // also switches to the exact accumulator.
            if not UseCurrency and (VarType(ValVar) = varCurrency) then
              UseCurrency := True;

            if UseCurrency then
            begin
              try
                ValCur := ValVar;
                AccumulateCurrencyValue(ValCur);
              except
                // Ignore non-numeric values for math aggregates
              end;
            end
            else
            begin
              try
                ValFloat := ValVar;

                if Func = 'SUM' then
                  Sum := Sum + ValFloat
                else if Func = 'AVG' then
                begin
                  Sum := Sum + ValFloat;
                  Inc(Count);
                end
                else if Func = 'MIN' then
                begin
                  if FirstVal or (ValFloat < MinVal) then MinVal := ValFloat;
                end
                else if Func = 'MAX' then
                begin
                  if FirstVal or (ValFloat > MaxVal) then MaxVal := ValFloat;
                end;

                if Func <> 'COUNT' then FirstVal := False;
              except
                // Ignore non-numeric values for math aggregates
              end;
            end;
          end;
        end;
      end;

      Context.DataSet.Next;
    end;

    if Func = 'COUNT'     then Value := Count
    else if Func = 'SUM'  then
    begin
      if BcdBound then Value := ScaledToDouble(SumScaled)
      else if UseCurrency then Value := SumC else Value := Sum;
    end
    else if Func = 'AVG'  then
    begin
      if Count > 0 then
      begin
        // AVG stays a Double (historical result type/scale); the Currency
        // numerator is exact, only the final division is floating point.
        if BcdBound then Value := ScaledToDouble(SumScaled) / Count
        else if UseCurrency then Value := Double(SumC) / Count
        else Value := Sum / Count;
      end
      else Value := 0;
    end
    else if Func = 'MIN'  then
    begin
      if FirstVal then Value := MinVal
      else if BcdBound then Value := ScaledToDouble(MinScaled)
      else if UseCurrency then Value := MinC else Value := MinVal;
    end
    else if Func = 'MAX'  then
    begin
      if FirstVal then Value := MaxVal
      else if BcdBound then Value := ScaledToDouble(MaxScaled)
      else if UseCurrency then Value := MaxC else Value := MaxVal;
    end;

    Result := True;
    if Assigned(Context.Hooks) then
      Context.Hooks.StoreAggregateCache(Expr, Context, Value);
  finally
    if Context.DataSet.Active and Context.DataSet.BookmarkValid(SaveBM) then
      Context.DataSet.GotoBookmark(SaveBM);
    Context.DataSet.FreeBookmark(SaveBM);
    Context.DataSet.EnableControls;
  end;
end;

end.
