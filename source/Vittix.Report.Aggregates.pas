unit Vittix.Report.Aggregates;

{ Exact decimal paths use checked coefficient arithmetic through 64 digits
  and 64 fractional places. Unsupported precision raises EConvertError;
  floating fields retain the historical Double evaluation path. }

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
  Data.FmtBcd,
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
  TExactDecimal = record
    Digits: string;  // unsigned coefficient, without a decimal separator
    Scale: Integer;
    Negative: Boolean;
  end;

  { One factor of an exact-decimal aggregate expression. }
  TAggFactorKind = (afField, afLiteral);
  TAggFactor = record
    Kind: TAggFactorKind;
    Fld: TField;
    Lit: TExactDecimal;
  end;

  { One additive term: Sign * Product(Factors). }
  TAggTerm = record
    Neg: Boolean;
    Factors: TArray<TAggFactor>;
  end;

const
  { Integral and decimal field types can be read as exact decimal text.
    Anything else (notably floats) keeps the historical Double path. }
  CExactDecimalFieldTypes = [ftBcd, ftFMTBcd, ftCurrency, ftInteger,
    ftSmallint, ftWord, ftLargeint, ftByte, ftAutoInc];
  CMaxExactDecimalDigits = 64;

procedure RaiseDecimalCapacityError;
begin
  raise EConvertError.Create(
    'Exact aggregate decimal arithmetic exceeds the supported 64-digit precision or scale');
end;

procedure NormalizeDecimal(var AValue: TExactDecimal);
begin
  while (Length(AValue.Digits) > 1) and (AValue.Digits[1] = '0') do
    Delete(AValue.Digits, 1, 1);
  while (AValue.Scale > 0) and (Length(AValue.Digits) > 1) and
        (AValue.Digits[Length(AValue.Digits)] = '0') do
  begin
    Delete(AValue.Digits, Length(AValue.Digits), 1);
    Dec(AValue.Scale);
  end;
  if (AValue.Digits = '') or (AValue.Digits = '0') then
  begin
    AValue.Digits := '0';
    AValue.Scale := 0;
    AValue.Negative := False;
  end;
  if (AValue.Scale > CMaxExactDecimalDigits) or
     (Length(AValue.Digits) > CMaxExactDecimalDigits) then
    RaiseDecimalCapacityError;
end;

function DecimalIsZero(const AValue: TExactDecimal): Boolean;
begin
  Result := (AValue.Digits = '0');
end;

function DecimalFromText(const AText: string;
  const AFormat: TFormatSettings): TExactDecimal;
var
  S: string;
  I, DotAt: Integer;
  C: Char;
begin
  S := Trim(AText);
  Result.Digits := '';
  Result.Scale := 0;
  Result.Negative := False;
  if S = '' then
    raise EConvertError.Create('Empty numeric value in exact aggregate expression');
  if S[1] = '-' then
  begin
    Result.Negative := True;
    Delete(S, 1, 1);
  end;
  if (S <> '') and (S[1] = '+') then
    Delete(S, 1, 1);
  DotAt := 0;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if (C = '.') or (C = AFormat.DecimalSeparator) then
    begin
      if DotAt <> 0 then
        raise EConvertError.CreateFmt('Invalid exact decimal value "%s"', [AText]);
      DotAt := I;
    end
    else if CharInSet(C, ['0'..'9']) then
      Result.Digits := Result.Digits + C
    else
      raise EConvertError.CreateFmt('Invalid exact decimal value "%s"', [AText]);
  end;
  if Result.Digits = '' then
    raise EConvertError.CreateFmt('Invalid exact decimal value "%s"', [AText]);
  if DotAt > 0 then
    Result.Scale := Length(S) - DotAt;
  NormalizeDecimal(Result);
end;

function DecimalToText(const AValue: TExactDecimal): string;
var
  D: string;
  I: Integer;
begin
  D := AValue.Digits;
  if AValue.Scale > 0 then
  begin
    while Length(D) <= AValue.Scale do
      D := '0' + D;
    I := Length(D) - AValue.Scale;
    Insert('.', D, I + 1);
  end;
  if AValue.Negative and not DecimalIsZero(AValue) then
    D := '-' + D;
  Result := D;
end;

function CompareUnsigned(const A, B: string): Integer;
begin
  if Length(A) < Length(B) then Exit(-1);
  if Length(A) > Length(B) then Exit(1);
  Result := CompareStr(A, B);
end;

function AddUnsigned(const A, B: string): string;
var
  I, J, Carry, N: Integer;
begin
  I := Length(A);
  J := Length(B);
  Carry := 0;
  Result := '';
  while (I > 0) or (J > 0) or (Carry > 0) do
  begin
    N := Carry;
    if I > 0 then begin Inc(N, Ord(A[I]) - Ord('0')); Dec(I); end;
    if J > 0 then begin Inc(N, Ord(B[J]) - Ord('0')); Dec(J); end;
    Carry := N div 10;
    Result := Char(Ord('0') + N mod 10) + Result;
  end;
  if Result = '' then Result := '0';
end;

function SubtractUnsigned(const A, B: string): string;
var
  I, J, Borrow, N: Integer;
begin
  // Requires A >= B.
  I := Length(A);
  J := Length(B);
  Borrow := 0;
  Result := '';
  while I > 0 do
  begin
    N := Ord(A[I]) - Ord('0') - Borrow;
    if J > 0 then begin Dec(N, Ord(B[J]) - Ord('0')); Dec(J); end;
    Borrow := 0;
    if N < 0 then begin Inc(N, 10); Borrow := 1; end;
    Result := Char(Ord('0') + N) + Result;
    Dec(I);
  end;
  while (Length(Result) > 1) and (Result[1] = '0') do
    Delete(Result, 1, 1);
end;

procedure AlignDecimals(var A, B: TExactDecimal);
var
  TargetScale: Integer;
begin
  TargetScale := A.Scale;
  if B.Scale > TargetScale then TargetScale := B.Scale;
  A.Digits := A.Digits + StringOfChar('0', TargetScale - A.Scale);
  B.Digits := B.Digits + StringOfChar('0', TargetScale - B.Scale);
  A.Scale := TargetScale;
  B.Scale := TargetScale;
end;

function AddDecimals(const A, B: TExactDecimal): TExactDecimal;
var
  Left, Right: TExactDecimal;
  Cmp: Integer;
begin
  Left := A;
  Right := B;
  AlignDecimals(Left, Right);
  Result.Scale := Left.Scale;
  if Left.Negative = Right.Negative then
  begin
    Result.Digits := AddUnsigned(Left.Digits, Right.Digits);
    Result.Negative := Left.Negative;
  end
  else
  begin
    Cmp := CompareUnsigned(Left.Digits, Right.Digits);
    if Cmp >= 0 then
    begin
      Result.Digits := SubtractUnsigned(Left.Digits, Right.Digits);
      Result.Negative := Left.Negative;
    end
    else
    begin
      Result.Digits := SubtractUnsigned(Right.Digits, Left.Digits);
      Result.Negative := Right.Negative;
    end;
  end;
  NormalizeDecimal(Result);
end;

function CompareDecimalValues(const A, B: TExactDecimal): Integer;
var
  Left, Right: TExactDecimal;
begin
  if DecimalIsZero(A) and DecimalIsZero(B) then Exit(0);
  if A.Negative <> B.Negative then
  begin
    if A.Negative then Exit(-1) else Exit(1);
  end;
  Left := A;
  Right := B;
  AlignDecimals(Left, Right);
  Result := CompareUnsigned(Left.Digits, Right.Digits);
  if A.Negative then Result := -Result;
end;

function MultiplyDecimals(const A, B: TExactDecimal): TExactDecimal;
var
  Digits: TArray<Integer>;
  I, J, K, Carry: Integer;
begin
  SetLength(Digits, Length(A.Digits) + Length(B.Digits));
  for I := 1 to Length(A.Digits) do
    for J := 1 to Length(B.Digits) do
    begin
      K := I + J - 1;
      Inc(Digits[K], (Ord(A.Digits[I]) - Ord('0')) *
        (Ord(B.Digits[J]) - Ord('0')));
    end;
  for K := High(Digits) downto 1 do
  begin
    Carry := Digits[K] div 10;
    Digits[K] := Digits[K] mod 10;
    Inc(Digits[K - 1], Carry);
  end;
  Result.Digits := '';
  for I := 0 to High(Digits) do
    Result.Digits := Result.Digits + Char(Ord('0') + Digits[I]);
  Result.Scale := A.Scale + B.Scale;
  Result.Negative := A.Negative xor B.Negative;
  NormalizeDecimal(Result);
end;

function DivideDecimalByInt(const A: TExactDecimal; ADivisor: Integer): TExactDecimal;
var
  Quotient, Fraction: string;
  Remainder, Digit: Int64;
  I, ExtraDigits: Integer;
  RoundUp: Boolean;
begin
  if ADivisor <= 0 then
    raise EConvertError.Create('Invalid divisor in exact AVG aggregate');
  Remainder := 0;
  Quotient := '';
  for I := 1 to Length(A.Digits) do
  begin
    Remainder := Remainder * 10 + Ord(A.Digits[I]) - Ord('0');
    Digit := Remainder div ADivisor;
    Remainder := Remainder mod ADivisor;
    Quotient := Quotient + Char(Ord('0') + Digit);
  end;
  while (Length(Quotient) > 1) and (Quotient[1] = '0') do
    Delete(Quotient, 1, 1);
  Fraction := '';
  ExtraDigits := CMaxExactDecimalDigits - A.Scale;
  if ExtraDigits > 10 then ExtraDigits := 10;
  if ExtraDigits < 0 then ExtraDigits := 0;
  for I := 1 to ExtraDigits + 1 do
  begin
    Remainder := Remainder * 10;
    Digit := Remainder div ADivisor;
    Remainder := Remainder mod ADivisor;
    Fraction := Fraction + Char(Ord('0') + Digit);
  end;
  RoundUp := (Length(Fraction) > ExtraDigits) and
    (Fraction[ExtraDigits + 1] >= '5');
  if Length(Fraction) > ExtraDigits then
    Delete(Fraction, ExtraDigits + 1, 1);
  Result.Digits := Quotient + Fraction;
  Result.Scale := A.Scale + ExtraDigits;
  Result.Negative := A.Negative;
  if RoundUp then
  begin
    I := Length(Result.Digits);
    while (I > 0) and (Result.Digits[I] = '9') do
    begin
      Result.Digits[I] := '0';
      Dec(I);
    end;
    if I = 0 then
      Result.Digits := '1' + Result.Digits
    else
      Result.Digits[I] := Char(Ord(Result.Digits[I]) + 1);
  end;
  NormalizeDecimal(Result);
end;

function DecimalVariant(const AValue: TExactDecimal): Variant;
var
  C: Currency;
  B: TBcd;
  S: string;
begin
  S := DecimalToText(AValue);
  if (AValue.Scale <= 4) and TryStrToCurr(S, C, TFormatSettings.Invariant) then
  begin
    Result := C;
    Exit;
  end;
  B := StrToBcd(S, TFormatSettings.Invariant);
  Result := VarFMTBcdCreate(B);
end;

{ Parses an exact-decimal aggregate inner expression: a sum/difference of
  products of [Field] tokens and numeric literals, e.g.
  [Qty]*[Rate] or [Qty]*[Rate]+[Bonus]*2.  Division, function calls,
  parentheses and any field outside CExactDecimalFieldTypes make the
  parse fail so the caller keeps the historical Double evaluation.
  Returns False for a bare single token as well - the existing
  single-field path already covers that cheaper case. }
function TryParseExactDecimalAggExpr(ADataSet: TDataSet; const AExpr: string;
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
    AFactor.Lit := DecimalFromText('0', TFormatSettings.Invariant);
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
      if not Assigned(Fld) or not (Fld.DataType in CExactDecimalFieldTypes) then
        Exit;
      if (Fld.DataType in [ftBcd, ftFMTBcd]) and
         (Fld.Size > CMaxExactDecimalDigits) then
        RaiseDecimalCapacityError;
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
      AFactor.Lit := DecimalFromText(Copy(S, Start, P - Start),
        TFormatSettings.Invariant);
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

{ Evaluates the parsed terms for the current row with checked decimal
  coefficient arithmetic. Returns
  False when any field operand is NULL (the row is skipped, as before). }
function EvalExactDecimalAggTerms(const ATerms: TArray<TAggTerm>;
  out AValue: TExactDecimal): Boolean;
var
  Term: TAggFactor;
  I, J: Integer;
  TermVal, FactorVal: TExactDecimal;
begin
  Result := False;
  AValue := DecimalFromText('0', TFormatSettings.Invariant);
  for I := 0 to High(ATerms) do
  begin
    TermVal := DecimalFromText('1', TFormatSettings.Invariant);
    for J := 0 to High(ATerms[I].Factors) do
    begin
      Term := ATerms[I].Factors[J];
      if Term.Kind = afField then
      begin
        if Term.Fld.IsNull then
          Exit;
        FactorVal := DecimalFromText(Term.Fld.AsString,
          TFormatSettings.Create);
      end
      else
        FactorVal := Term.Lit;
      TermVal := MultiplyDecimals(TermVal, FactorVal);
    end;
    if ATerms[I].Neg then
      if not DecimalIsZero(TermVal) then
        TermVal.Negative := not TermVal.Negative;
    AValue := AddDecimals(AValue, TermVal);
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
  SumDecimal, ValDecimal, MinDecimal, MaxDecimal: TExactDecimal;
  AverageCurrency: Currency;
  UseDecimal: Boolean;
  ExactFieldBound: Boolean;
  AggFld: TField;
  AggTerms: TArray<TAggTerm>;
  TermsParsed: Boolean;
  RowHasValue: Boolean;
  FieldName: string;

  { Adds one non-null exact decimal value to the aggregate accumulators. }
  procedure AccumulateDecimalValue(const AVal: TExactDecimal);
  begin
    if Func = 'SUM' then
      SumDecimal := AddDecimals(SumDecimal, AVal)
    else if Func = 'AVG' then
    begin
      SumDecimal := AddDecimals(SumDecimal, AVal);
      Inc(Count);
    end
    else if Func = 'MIN' then
    begin
      if FirstVal or (CompareDecimalValues(AVal, MinDecimal) < 0) then
        MinDecimal := AVal;
    end
    else if Func = 'MAX' then
    begin
      if FirstVal or (CompareDecimalValues(AVal, MaxDecimal) > 0) then
        MaxDecimal := AVal;
    end;
    if Func <> 'COUNT' then FirstVal := False;
  end;

  function ReadDecimalValue: TExactDecimal;
  begin
    Result := DecimalFromText(AggFld.AsString, TFormatSettings.Create);
  end;

  function ContainsUnsupportedHighScaleBcd(const S: string): Boolean;
  var
    I, J: Integer;
    Name: string;
    F: TField;
  begin
    Result := False;
    I := 1;
    while I <= Length(S) do
    begin
      if S[I] <> '[' then
      begin
        Inc(I);
        Continue;
      end;
      J := I + 1;
      while (J <= Length(S)) and (S[J] <> ']') do Inc(J);
      if J > Length(S) then Exit;
      Name := Copy(S, I + 1, J - I - 1);
      if (Name <> '') and (Pos('.', Name) = 0) then
      begin
        F := Context.DataSet.FindField(Name);
        if Assigned(F) and (F.DataType in [ftBcd, ftFMTBcd]) and
         (F.Size > 4) then
          Exit(True);
      end;
      I := J + 1;
    end;
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

  // Exact-decimal mode for bare BCD/Currency fields. Integer and decimal
  // fields in supported computed expressions use the parser below.
  ExactFieldBound := False;
  AggFld := nil;
  FieldName := '';
  if (Length(InnerExpr) >= 3) and (InnerExpr[1] = '[') and
     (InnerExpr[Length(InnerExpr)] = ']') then
  begin
    FieldName := Copy(InnerExpr, 2, Length(InnerExpr) - 2);
    if (FieldName <> '') and (Pos('.', FieldName) = 0) then
    begin
      AggFld := Context.DataSet.FindField(FieldName);
      ExactFieldBound := Assigned(AggFld) and
        (AggFld.DataType in [ftCurrency, ftBcd, ftFMTBcd]);
      if Assigned(AggFld) and (AggFld.DataType in [ftBcd, ftFMTBcd]) and
         (AggFld.Size > CMaxExactDecimalDigits) then
        RaiseDecimalCapacityError;
    end;
  end;

  // A sum/difference of products of exact fields and literals (the invoice
  // case SUM([Qty]*[Rate])) stays decimal throughout; float fields keep the
  // historical Double route.
  TermsParsed := False;
  if not ExactFieldBound then
    TermsParsed := TryParseExactDecimalAggExpr(Context.DataSet, InnerExpr, AggTerms);
  if not ExactFieldBound and not TermsParsed and
     ContainsUnsupportedHighScaleBcd(InnerExpr) then
    raise EConvertError.Create(
      'Computed BCD aggregates above scale 4 require a supported exact-decimal expression');

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
    SumDecimal  := DecimalFromText('0', TFormatSettings.Invariant);
    MinDecimal  := DecimalFromText('0', TFormatSettings.Invariant);
    MaxDecimal  := DecimalFromText('0', TFormatSettings.Invariant);
    MinVal      := 0.0;
    MaxVal      := 0.0;
    FirstVal    := True;
    UseDecimal  := ExactFieldBound or TermsParsed;
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

      if ExactFieldBound or TermsParsed then
      begin
        // Exact BCD row value (bare BCD/Currency field or a parsed product);
        // NULL operands skip the row as before.
        RowHasValue := False;
        if ExactFieldBound then
        begin
          if not AggFld.IsNull then
          begin
            ValDecimal := ReadDecimalValue;
            RowHasValue := True;
          end;
        end
        else
          RowHasValue := EvalExactDecimalAggTerms(AggTerms, ValDecimal);

        if RowHasValue then
        begin
          if Func = 'COUNT' then
            Inc(Count)
          else
            AccumulateDecimalValue(ValDecimal);
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
            // Preserve exact Currency Variants through the decimal
            // accumulator; floating and other numeric values remain Double.
            if VarType(ValVar) = varCurrency then
            begin
              try
                ValDecimal := DecimalFromText(VarToStr(ValVar),
                  TFormatSettings.Create);
                UseDecimal := True;
                AccumulateDecimalValue(ValDecimal);
              except
                // Ignore values that cannot be converted to exact decimal.
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
      if UseDecimal then Value := DecimalVariant(SumDecimal)
      else Value := Sum;
    end
    else if Func = 'AVG'  then
    begin
      if Count > 0 then
      begin
        if UseDecimal then
        begin
          // Preserve historical Double precision when the exact sum fits
          // Currency. Wider sums use exact decimal division with ten guard
          // places (or the remaining supported scale when nearer capacity).
          if (SumDecimal.Scale <= 4) and
             TryStrToCurr(DecimalToText(SumDecimal), AverageCurrency,
               TFormatSettings.Invariant) then
            Value := Double(AverageCurrency) / Count
          else
            Value := DecimalVariant(DivideDecimalByInt(SumDecimal, Count));
        end
        else Value := Sum / Count;
      end
      else Value := 0;
    end
    else if Func = 'MIN'  then
    begin
      if FirstVal then Value := 0
      else if UseDecimal then Value := DecimalVariant(MinDecimal)
      else Value := MinVal;
    end
    else if Func = 'MAX'  then
    begin
      if FirstVal then Value := 0
      else if UseDecimal then Value := DecimalVariant(MaxDecimal)
      else Value := MaxVal;
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
