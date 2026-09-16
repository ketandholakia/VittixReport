unit Vittix.Report.Expression.Tokenizer;

{
  Vittix.Report.Expression.Tokenizer
  ==================================
  Real tokenizer for the modern expression language.
  Produces a stream of tokens with position information.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  System.Generics.Collections,
  Vittix.Report.Expression.Language,
  Vittix.Report.Expression.Diagnostics;

type
  TExpressionTokenizer = class
  private
    FText: string;
    FIndex: Integer;
    FLength: Integer;
    FDiagnostics: TExpressionDiagnostics;
    FLimits: TExpressionLimits;
    function PeekChar: Char;
    procedure Advance;
    procedure SkipWhitespace;
    function ReadNumber: TExpressionToken;
    function ReadString: TExpressionToken;
    function ReadBracketToken: TExpressionToken;
    function ReadIdentifierOrKeyword: TExpressionToken;
    function ReadOperator: TExpressionToken;
    function MatchKeyword(const AText: string): TExpressionTokenKind;
  public
    constructor Create(const ALimits: TExpressionLimits);
    destructor Destroy; override;

    function Tokenize(const AText: string; ADiagnostics: TExpressionDiagnostics): TArray<TExpressionToken>;
  end;

implementation

{ TExpressionTokenizer }

constructor TExpressionTokenizer.Create(const ALimits: TExpressionLimits);
begin
  inherited Create;
  FLimits := ALimits;
end;

destructor TExpressionTokenizer.Destroy;
begin
  inherited;
end;

function TExpressionTokenizer.PeekChar: Char;
begin
  if FIndex + 1 <= FLength then
    Result := FText[FIndex + 1]
  else
    Result := #0;
end;

procedure TExpressionTokenizer.Advance;
begin
  if FIndex <= FLength then
    Inc(FIndex);
end;

procedure TExpressionTokenizer.SkipWhitespace;
begin
  while (FIndex <= FLength) and (FText[FIndex] <= ' ') do
    Inc(FIndex);
end;

function TExpressionTokenizer.ReadNumber: TExpressionToken;
var
  StartPos: Integer;
  StartIndex: Integer;
  HasDecimal: Boolean;
  DigitsBefore: Integer;
  DigitsAfter: Integer;
  NumStr: string;
  NumValue: Double;
begin
  StartPos := FIndex;
  StartIndex := FIndex;
  HasDecimal := False;
  DigitsBefore := 0;
  DigitsAfter := 0;

  // Optional leading sign is handled by the parser (unary + / -)
  // Here we only read digits and optional single decimal point
  while (FIndex <= FLength) do
  begin
    if CharInSet(FText[FIndex], ['0'..'9']) then
    begin
      if HasDecimal then
        Inc(DigitsAfter)
      else
        Inc(DigitsBefore);
      Inc(FIndex);
    end
    else if (FText[FIndex] = '.') and not HasDecimal then
    begin
      HasDecimal := True;
      Inc(FIndex);
    end
    else
      Break;
  end;

  // Must have at least one digit
  if (DigitsBefore = 0) and (DigitsAfter = 0) then
  begin
    // Not a valid number, backtrack
    FIndex := StartIndex;
    Result := TExpressionToken.Create(tkIdentifier, '', StartPos, 0, Null);
    Exit;
  end;

  // Reject trailing decimal point with no digits after (e.g., "1." or ".5" - both rejected per spec)
  if HasDecimal and (DigitsAfter = 0) then
  begin
    FDiagnostics.AddError(InvalidNumber, StartPos, FIndex - StartPos, 'Number literal cannot end with decimal point');
    NumStr := Copy(FText, StartPos, FIndex - StartPos);
    if TryStrToFloat(NumStr, NumValue) then
      Result := TExpressionToken.Create(tkNumber, NumStr, StartPos, FIndex - StartPos, NumValue)
    else
      Result := TExpressionToken.Create(tkNumber, NumStr, StartPos, FIndex - StartPos, 0);
    Exit;
  end;

  // Reject leading decimal point with no digits before (e.g., ".5")
  if HasDecimal and (DigitsBefore = 0) then
  begin
    FDiagnostics.AddError(InvalidNumber, StartPos, FIndex - StartPos, 'Number literal cannot start with decimal point');
    NumStr := Copy(FText, StartPos, FIndex - StartPos);
    if TryStrToFloat(NumStr, NumValue) then
      Result := TExpressionToken.Create(tkNumber, NumStr, StartPos, FIndex - StartPos, NumValue)
    else
      Result := TExpressionToken.Create(tkNumber, NumStr, StartPos, FIndex - StartPos, 0);
    Exit;
  end;

  NumStr := Copy(FText, StartPos, FIndex - StartPos);
  if TryStrToFloat(NumStr, NumValue) then
    Result := TExpressionToken.Create(tkNumber, NumStr, StartPos, FIndex - StartPos, NumValue)
  else
    Result := TExpressionToken.Create(tkNumber, NumStr, StartPos, FIndex - StartPos, 0);
end;

function TExpressionTokenizer.ReadString: TExpressionToken;
var
  StartPos: Integer;
  Content: string;
  Ch: Char;
  Closed: Boolean;
begin
  StartPos := FIndex;
  Advance; // Skip opening quote
  Content := '';
  Closed := False;

  while FIndex <= FLength do
  begin
    Ch := FText[FIndex];
    if Ch = '''' then
    begin
      // Check for escaped quote
      if (FIndex + 1 <= FLength) and (FText[FIndex + 1] = '''') then
      begin
        Content := Content + '''';
        Inc(FIndex, 2);
      end
      else
      begin
        // Closing quote
        Advance;
        Closed := True;
        Break;
      end;
    end
    else
    begin
      Content := Content + Ch;
      Inc(FIndex);
    end;
  end;

  if not Closed then
    FDiagnostics.AddError(InvalidString, StartPos, FIndex - StartPos, 'Unterminated string literal');

  Result := TExpressionToken.Create(tkString, Content, StartPos, FIndex - StartPos, Content);
end;

function TExpressionTokenizer.ReadBracketToken: TExpressionToken;
var
  StartPos: Integer;
  Content: string;
  Closed: Boolean;
begin
  StartPos := FIndex;
  Advance; // Skip '['
  Content := '';
  Closed := False;

  while FIndex <= FLength do
  begin
    if FText[FIndex] = ']' then
    begin
      Advance;
      Closed := True;
      Break;
    end;
    Content := Content + FText[FIndex];
    Inc(FIndex);
  end;

  if not Closed then
    FDiagnostics.AddError(SyntaxError, StartPos, FIndex - StartPos, 'Unterminated bracket token');

  Result := TExpressionToken.Create(tkBracketToken, Content, StartPos, FIndex - StartPos, Content);
end;

function TExpressionTokenizer.MatchKeyword(const AText: string): TExpressionTokenKind;
begin
  if SameText(AText, 'AND') then Exit(tkAnd);
  if SameText(AText, 'OR') then Exit(tkOr);
  if SameText(AText, 'NOT') then Exit(tkNot);
  if SameText(AText, 'IS') then Exit(tkIs);
  if SameText(AText, 'NULL') then Exit(tkNull);
  if SameText(AText, 'TRUE') then Exit(tkTrue);
  if SameText(AText, 'FALSE') then Exit(tkFalse);
  Result := tkIdentifier;
end;

function TExpressionTokenizer.ReadIdentifierOrKeyword: TExpressionToken;
var
  StartPos: Integer;
  Ident: string;
  Kind: TExpressionTokenKind;
begin
  StartPos := FIndex;
  Ident := '';

  while FIndex <= FLength do
  begin
    if CharInSet(FText[FIndex], ['A'..'Z', 'a'..'z', '_', '0'..'9']) then
    begin
      Ident := Ident + FText[FIndex];
      Inc(FIndex);
    end
    else
      Break;
  end;

  if Ident = '' then
  begin
    Result := TExpressionToken.Create(tkIdentifier, '', StartPos, 0, Null);
    Exit;
  end;

  Kind := MatchKeyword(Ident);
  if Kind = tkTrue then
    Result := TExpressionToken.Create(tkTrue, Ident, StartPos, FIndex - StartPos, True)
  else if Kind = tkFalse then
    Result := TExpressionToken.Create(tkFalse, Ident, StartPos, FIndex - StartPos, False)
  else if Kind = tkNull then
    Result := TExpressionToken.Create(tkNull, Ident, StartPos, FIndex - StartPos, Null)
  else
    Result := TExpressionToken.Create(Kind, Ident, StartPos, FIndex - StartPos, Ident);
end;

function TExpressionTokenizer.ReadOperator: TExpressionToken;
var
  StartPos: Integer;
  Ch: Char;
  NextCh: Char;
begin
  StartPos := FIndex;
  Ch := FText[FIndex];

  case Ch of
    '+':
    begin
      Advance;
      Result := TExpressionToken.Create(tkPlus, '+', StartPos, 1, Null);
    end;
    '-':
    begin
      Advance;
      Result := TExpressionToken.Create(tkMinus, '-', StartPos, 1, Null);
    end;
    '*':
    begin
      Advance;
      Result := TExpressionToken.Create(tkMultiply, '*', StartPos, 1, Null);
    end;
    '/':
    begin
      Advance;
      Result := TExpressionToken.Create(tkDivide, '/', StartPos, 1, Null);
    end;
    '(':
    begin
      Advance;
      Result := TExpressionToken.Create(tkLeftParen, '(', StartPos, 1, Null);
    end;
    ')':
    begin
      Advance;
      Result := TExpressionToken.Create(tkRightParen, ')', StartPos, 1, Null);
    end;
    ',':
    begin
      Advance;
      Result := TExpressionToken.Create(tkComma, ',', StartPos, 1, Null);
    end;
    '=':
    begin
      Advance;
      Result := TExpressionToken.Create(tkEqual, '=', StartPos, 1, Null);
    end;
    '<':
    begin
      NextCh := PeekChar;
      if NextCh = '=' then
      begin
        Advance; Advance;
        Result := TExpressionToken.Create(tkLessEqual, '<=', StartPos, 2, Null);
      end
      else if NextCh = '>' then
      begin
        Advance; Advance;
        Result := TExpressionToken.Create(tkNotEqual, '<>', StartPos, 2, Null);
      end
      else
      begin
        Advance;
        Result := TExpressionToken.Create(tkLessThan, '<', StartPos, 1, Null);
      end;
    end;
    '>':
    begin
      NextCh := PeekChar;
      if NextCh = '=' then
      begin
        Advance; Advance;
        Result := TExpressionToken.Create(tkGreaterEqual, '>=', StartPos, 2, Null);
      end
      else
      begin
        Advance;
        Result := TExpressionToken.Create(tkGreaterThan, '>', StartPos, 1, Null);
      end;
    end;
    '!':
    begin
      NextCh := PeekChar;
      if NextCh = '=' then
      begin
        Advance; Advance;
        Result := TExpressionToken.Create(tkNotEqual, '!=', StartPos, 2, Null);
      end
      else
      begin
        Advance;
        FDiagnostics.AddError(SyntaxError, StartPos, 1, 'Unexpected character "!"');
        Result := TExpressionToken.Create(tkIdentifier, '!', StartPos, 1, Null);
      end;
    end;
  else
    Advance;
    FDiagnostics.AddError(SyntaxError, StartPos, 1, 'Unexpected character: ' + Ch);
    Result := TExpressionToken.Create(tkIdentifier, Ch, StartPos, 1, Null);
  end;
end;

function TExpressionTokenizer.Tokenize(const AText: string; ADiagnostics: TExpressionDiagnostics): TArray<TExpressionToken>;
var
  Tokens: TList<TExpressionToken>;
  Token: TExpressionToken;
begin
  FText := AText;
  FLength := Length(FText);
  FIndex := 1;
  FDiagnostics := ADiagnostics;

  if FLength > FLimits.MaxExpressionLength then
  begin
    ADiagnostics.AddError(ExpressionTooLong, 1, FLength, Format('Expression length %d exceeds maximum %d', [FLength, FLimits.MaxExpressionLength]));
    Result := nil;
    Exit;
  end;

  Tokens := TList<TExpressionToken>.Create;
  try
    while FIndex <= FLength do
    begin
      SkipWhitespace;
      if FIndex > FLength then Break;

      if FText[FIndex] = '''' then
        Token := ReadString
      else if FText[FIndex] = '[' then
        Token := ReadBracketToken
      else if CharInSet(FText[FIndex], ['0'..'9']) then
        Token := ReadNumber
      else if CharInSet(FText[FIndex], ['A'..'Z', 'a'..'z', '_']) then
        Token := ReadIdentifierOrKeyword
      else if CharInSet(FText[FIndex], ['+', '-', '*', '/', '(', ')', ',', '=', '<', '>', '!']) then
        Token := ReadOperator
      else
      begin
        FDiagnostics.AddError(SyntaxError, FIndex, 1, 'Unexpected character: ' + FText[FIndex]);
        Advance;
        Continue;
      end;

      Tokens.Add(Token);

      // Safety: prevent infinite loop
      if Tokens.Count > FLimits.MaxAstNodes * 2 then
      begin
        ADiagnostics.AddError(TooManyNodes, 1, FLength, 'Too many tokens');
        Break;
      end;
    end;

    // Add EOF token
    Tokens.Add(TExpressionToken.Create(tkEOF, '', FIndex, 0, Null));

    Result := Tokens.ToArray;
  finally
    Tokens.Free;
  end;
end;

end.