import sys
content = open('source/Vittix.Report.Objects.pas', 'r', encoding='utf-8').read()

start_idx = content.find('procedure ParseMemoRuns(')
end_idx = content.find('function StyledTextWidth(')

new_func = '''procedure ParseMemoRuns(const S: string; const BaseStyle: TFontStyles;
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
  Attrs: TArray<string>;
  P: Integer;
  AName, AVal: string;
  TagL: string;

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

  function ParseColor(const SC: string): TColor;
  var 
    L: string;
  begin
    if SC = '' then Exit(BaseColor);
    if (Length(SC) > 0) and (SC[1] = '#') then
    begin
      if Length(SC) = 7 then
        Result := RGB(StrToIntDef('$' + Copy(SC, 2, 2), 0),
                      StrToIntDef('$' + Copy(SC, 4, 2), 0),
                      StrToIntDef('$' + Copy(SC, 6, 2), 0))
      else
        Result := BaseColor;
    end
    else
    begin
      L := LowerCase(SC);
      if L = 'red' then Result := clRed
      else if L = 'blue' then Result := clBlue
      else if L = 'green' then Result := clGreen
      else if L = 'black' then Result := clBlack
      else if L = 'white' then Result := clWhite
      else if L = 'yellow' then Result := clYellow
      else if L = 'gray' then Result := clGray
      else if L = 'silver' then Result := clSilver
      else if L = 'maroon' then Result := clMaroon
      else if L = 'olive' then Result := clOlive
      else if L = 'navy' then Result := clNavy
      else if L = 'purple' then Result := clPurple
      else if L = 'teal' then Result := clTeal
      else if L = 'fuchsia' then Result := clFuchsia
      else if L = 'aqua' then Result := clAqua
      else if Copy(L, 1, 2) = 'cl' then
        Result := StringToColor(SC)
      else
        Result := BaseColor;
    end;
  end;

begin
  SetLength(Runs, 0);
  SetLength(StateStack, 0);
  CurState.Style := BaseStyle;
  CurState.Color := BaseColor;
  CurState.FontName := BaseFontName;
  CurState.Size := BaseSize;
  Buf := '';
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
        TagL := LowerCase(Tag);

        if TagL = 'b' then
        begin
          PushState;
          Include(CurState.Style, fsBold);
        end
        else if TagL = '/b' then PopState
        else if TagL = 'i' then
        begin
          PushState;
          Include(CurState.Style, fsItalic);
        end
        else if TagL = '/i' then PopState
        else if TagL = 'u' then
        begin
          PushState;
          Include(CurState.Style, fsUnderline);
        end
        else if TagL = '/u' then PopState
        else if (TagL = 'br') or (TagL = 'br/') or (TagL = 'br /') then
          AddMemoRun(Runs, '', CurState.Style, CurState.Color, CurState.FontName, CurState.Size, True)
        else if (TagL = 'p') or (TagL = '/p') then
          AddMemoRun(Runs, '', CurState.Style, CurState.Color, CurState.FontName, CurState.Size, True)
        else if TagL = '/font' then PopState
        else if Copy(TagL, 1, 5) = 'font ' then
        begin
          PushState;
          Attrs := Tag.Substring(5).Split([' '], TStringSplitOptions.ExcludeEmpty);
          for K := 0 to High(Attrs) do
          begin
            P := Pos('=', Attrs[K]);
            if P > 0 then
            begin
              AName := LowerCase(Trim(Copy(Attrs[K], 1, P - 1)));
              AVal := Trim(Copy(Attrs[K], P + 1, Length(Attrs[K])));
              AVal := StringReplace(AVal, '"', '', [rfReplaceAll]);
              AVal := StringReplace(AVal, '''''''', '', [rfReplaceAll]);
              if AName = 'color' then CurState.Color := ParseColor(AVal)
              else if AName = 'face' then CurState.FontName := AVal
              else if AName = 'size' then CurState.Size := StrToIntDef(AVal, CurState.Size);
            end;
          end;
        end
        else
          Buf := Buf + Copy(S, I, J - I + 1);

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

'''

content = content[:start_idx] + new_func + content[end_idx:]

open('source/Vittix.Report.Objects.pas', 'w', encoding='utf-8').write(content)
