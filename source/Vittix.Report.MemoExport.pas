unit Vittix.Report.MemoExport;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  Winapi.Windows;

type
  TMemoRun = record
    Text: string;
    Style: TFontStyles;
    Color: TColor;
    FontName: string;
    Size: Integer;
    IsBreak: Boolean;
  end;

procedure ParseMemoRuns(const S: string; const BaseStyle: TFontStyles;
  BaseColor: TColor; const BaseFontName: string; BaseSize: Integer;
  AllowHTML: Boolean; out Runs: TArray<TMemoRun>);

implementation

function DecodeHtmlEntities(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll]);
end;

procedure AddMemoRun(var Runs: TArray<TMemoRun>; const AText: string;
  const AStyle: TFontStyles; AColor: TColor; const AFontName: string; ASize: Integer; AIsBreak: Boolean);
var
  L: Integer;
begin
  if (AText = '') and (not AIsBreak) then Exit;
  L := Length(Runs);
  SetLength(Runs, L + 1);
  Runs[L].Text := AText;
  Runs[L].Style := AStyle;
  Runs[L].Color := AColor;
  Runs[L].FontName := AFontName;
  Runs[L].Size := ASize;
  Runs[L].IsBreak := AIsBreak;
end;

procedure ParseMemoRuns(const S: string; const BaseStyle: TFontStyles;
  BaseColor: TColor; const BaseFontName: string; BaseSize: Integer;
  AllowHTML: Boolean; out Runs: TArray<TMemoRun>);
type
  TMemoState = record
    Style: TFontStyles;
    Color: TColor;
    FontName: string;
    Size: Integer;
  end;
var
  I, J, K: Integer;
  Buf: string;
  Tag: string;
  StateStack: TArray<TMemoState>;
  CurState: TMemoState;

  procedure PushState;
  begin
    SetLength(StateStack, Length(StateStack) + 1);
    StateStack[High(StateStack)] := CurState;
  end;

  procedure PopState;
  begin
    if Length(StateStack) > 0 then
    begin
      CurState := StateStack[High(StateStack)];
      SetLength(StateStack, Length(StateStack) - 1);
    end;
  end;

  function ParseColor(const S: string): TColor;
  var
    L: string;
  begin
    if S = '' then Exit(BaseColor);
    if (Length(S) > 0) and (S[1] = '#') then
    begin
      if Length(S) = 7 then
        Result := RGB(StrToIntDef('$' + Copy(S, 2, 2), 0),
                      StrToIntDef('$' + Copy(S, 4, 2), 0),
                      StrToIntDef('$' + Copy(S, 6, 2), 0))
      else
        Result := BaseColor;
    end
    else
    begin
      L := LowerCase(S);
      if L = 'red' then Result := clRed
      else if L = 'blue' then Result := clBlue
      else if L = 'green' then Result := clGreen
      else if L = 'black' then Result := clBlack
      else if L = 'white' then Result := clWhite
      else if L = 'yellow' then Result := clYellow
      else Result := StringToColor(S);
    end;
  end;

begin
  SetLength(Runs, 0);
  SetLength(StateStack, 0);
  CurState.Style := BaseStyle;
  CurState.Color := BaseColor;
  CurState.FontName := BaseFontName;
  CurState.Size := BaseSize;

  I := 1;
  while I <= Length(S) do
  begin
    if AllowHTML and (S[I] = '<') then
    begin
      J := I + 1;
      while (J <= Length(S)) and (S[J] <> '>') do Inc(J);
      if J <= Length(S) then
      begin
        AddMemoRun(Runs, DecodeHtmlEntities(Buf), CurState.Style, CurState.Color, CurState.FontName, CurState.Size, False);
        Buf := '';

        Tag := Trim(Copy(S, I + 1, J - I - 1));
        var OrigTag := Tag;
        Tag := LowerCase(Tag);

        if (Tag = 'b') or (Tag = 'strong') then
        begin
          PushState;
          Include(CurState.Style, fsBold);
        end
        else if (Tag = '/b') or (Tag = '/strong') then
          PopState
        else if (Tag = 'i') or (Tag = 'em') then
        begin
          PushState;
          Include(CurState.Style, fsItalic);
        end
        else if (Tag = '/i') or (Tag = '/em') then
          PopState
        else if (Tag = 'u') then
        begin
          PushState;
          Include(CurState.Style, fsUnderline);
        end
        else if (Tag = '/u') then
         PopState
        else if Copy(Tag, 1, 5) = 'font ' then
        begin
          PushState;
          var LPos: Integer;
          K := Pos('color=', OrigTag);
          if K > 0 then
          begin
            LPos := K + 6;
            while (LPos <= Length(OrigTag)) and (OrigTag[LPos] <> ' ') do Inc(LPos);
            CurState.Color := ParseColor(StringReplace(Copy(OrigTag, K + 6, LPos - K - 6), '"', '', [rfReplaceAll]));
          end;
          K := Pos('face=', OrigTag);
          if K > 0 then
          begin
            LPos := K + 5;
            while (LPos <= Length(OrigTag)) and (OrigTag[LPos] <> ' ') do Inc(LPos);
            CurState.FontName := StringReplace(Copy(OrigTag, K + 5, LPos - K - 5), '"', '', [rfReplaceAll]);
          end;
          K := Pos('size=', OrigTag);
          if K > 0 then
          begin
            LPos := K + 5;
            while (LPos <= Length(OrigTag)) and (OrigTag[LPos] <> ' ') do Inc(LPos);
            CurState.Size := StrToIntDef(StringReplace(Copy(OrigTag, K + 5, LPos - K - 5), '"', '', [rfReplaceAll]), BaseSize);
          end;
        end
        else if Tag = '/font' then
          PopState;

        I := J + 1;
        Continue;
      end;
    end;

    if (S[I] = #13) or (S[I] = #10) then
    begin
      AddMemoRun(Runs, DecodeHtmlEntities(Buf), CurState.Style, CurState.Color, CurState.FontName, CurState.Size, False);
      Buf := '';
      AddMemoRun(Runs, '', CurState.Style, CurState.Color, CurState.FontName, CurState.Size, True);
      if (S[I] = #13) and (I < Length(S)) and (S[I + 1] = #10) then
        Inc(I);
    end
    else
      Buf := Buf + S[I];

    Inc(I);
  end;

  AddMemoRun(Runs, DecodeHtmlEntities(Buf), CurState.Style, CurState.Color, CurState.FontName, CurState.Size, False);
end;

end.
