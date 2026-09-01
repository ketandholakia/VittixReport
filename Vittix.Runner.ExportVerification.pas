unit Vittix.Runner.ExportVerification;

interface

uses
  System.SysUtils,
  System.Types,
  System.StrUtils,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  Data.DB,
  FireDAC.Comp.Client,
  Vittix.Report.Export.Commands;

function IsHtmlSmokeReport(const AReportName: string): Boolean;

{ Phase 3F-1: single source of truth for which report receives HTML export
  smoke verification. Previously hardcoded independently in
  Vittix.Runner.Console and Vittix.Runner.Execution; both now call this
  predicate so they cannot drift. }

function CountOccurrences(const Haystack, Needle: string): Integer;

function BytesContainAscii(const ABytes: TBytes; const AText: AnsiString): Boolean;

function CountAsciiOccurrences(const ABytes: TBytes; const AText: AnsiString): Integer;

function PdfPointNumber(AValue: Integer): AnsiString;

function ExportDocumentContainsText(ADocument: TReportExportDocument;
  const AText: string): Boolean;

procedure RequireExportText(ADocument: TReportExportDocument; const AText: string);

function CountExportTextCommands(ADocument: TReportExportDocument;
  const AText: string): Integer;

function ExportDocumentContainsImageSource(ADocument: TReportExportDocument;
  const ASource: string): Boolean;

function CountExportImageCommands(ADocument: TReportExportDocument): Integer;

procedure CreateVerificationPNG(const AFileName: string; const AColor: TColor);

function BuildImageBindingData(const ALogoFile, ASignatureFile,
  AMissingImageFile: string): TFDMemTable;

implementation

function IsHtmlSmokeReport(const AReportName: string): Boolean;
begin
  Result := SameText(AReportName, '38_export_html.vrt');
end;

function CountOccurrences(const Haystack, Needle: string): Integer;
var
  P: Integer;
  SearchFrom: Integer;
begin
  Result := 0;
  if (Haystack = '') or (Needle = '') then
    Exit;
  SearchFrom := 1;
  while True do
  begin
    P := PosEx(Needle, Haystack, SearchFrom);
    if P = 0 then
      Break;
    Inc(Result);
    SearchFrom := P + Length(Needle);
  end;
end;

function BytesContainAscii(const ABytes: TBytes; const AText: AnsiString): Boolean;
var
  I: Integer;
  J: Integer;
begin
  Result := False;
  if (Length(ABytes) = 0) or (Length(AText) = 0) or
     (Length(ABytes) < Length(AText)) then
    Exit;

  for I := 0 to Length(ABytes) - Length(AText) do
  begin
    Result := True;
    for J := 1 to Length(AText) do
      if ABytes[I + J - 1] <> Ord(AText[J]) then
      begin
        Result := False;
        Break;
      end;
    if Result then
      Exit;
  end;
end;

function CountAsciiOccurrences(const ABytes: TBytes; const AText: AnsiString): Integer;
var
  I: Integer;
  J: Integer;
  Match: Boolean;
begin
  Result := 0;
  if (Length(ABytes) = 0) or (Length(AText) = 0) or
     (Length(ABytes) < Length(AText)) then
    Exit;

  for I := 0 to Length(ABytes) - Length(AText) do
  begin
    Match := True;
    for J := 1 to Length(AText) do
      if ABytes[I + J - 1] <> Ord(AText[J]) then
      begin
        Match := False;
        Break;
      end;
    if Match then
      Inc(Result);
  end;
end;

function PdfPointNumber(AValue: Integer): AnsiString;
begin
  Result := AnsiString(StringReplace(
    FormatFloat('0.###', AValue * (72 / 96)),
    FormatSettings.DecimalSeparator,
    '.',
    []));
end;

function ExportDocumentContainsText(ADocument: TReportExportDocument;
  const AText: string): Boolean;
var
  Page: TReportExportPage;
  Command: TReportExportCommand;
begin
  Result := False;
  if not Assigned(ADocument) then
    Exit;

  for Page in ADocument.Pages do
    for Command in Page.Commands do
      if (Command is TReportExportTextCommand) and
         ContainsText(TReportExportTextCommand(Command).Text, AText) then
        Exit(True);
end;

procedure RequireExportText(ADocument: TReportExportDocument; const AText: string);
begin
  if not ExportDocumentContainsText(ADocument, AText) then
    raise Exception.CreateFmt('Expected rendered dataset value not found: %s', [AText]);
end;

function CountExportTextCommands(ADocument: TReportExportDocument;
  const AText: string): Integer;
var
  Page: TReportExportPage;
  Command: TReportExportCommand;
begin
  Result := 0;
  if not Assigned(ADocument) then
    Exit;

  for Page in ADocument.Pages do
    for Command in Page.Commands do
      if (Command is TReportExportTextCommand) and
         SameText(TReportExportTextCommand(Command).Text, AText) then
        Inc(Result);
end;

function ExportDocumentContainsImageSource(ADocument: TReportExportDocument;
  const ASource: string): Boolean;
var
  Page: TReportExportPage;
  Command: TReportExportCommand;
begin
  Result := False;
  if not Assigned(ADocument) then
    Exit;

  for Page in ADocument.Pages do
    for Command in Page.Commands do
      if (Command is TReportExportImageCommand) and
         SameText(TReportExportImageCommand(Command).Source, ASource) then
        Exit(True);
end;

function CountExportImageCommands(ADocument: TReportExportDocument): Integer;
var
  Page: TReportExportPage;
  Command: TReportExportCommand;
begin
  Result := 0;
  if not Assigned(ADocument) then
    Exit;

  for Page in ADocument.Pages do
    for Command in Page.Commands do
      if Command is TReportExportImageCommand then
        Inc(Result);
end;

procedure CreateVerificationPNG(const AFileName: string; const AColor: TColor);
var
  Bitmap: TBitmap;
  PNG: TPngImage;
begin
  Bitmap := TBitmap.Create;
  PNG := TPngImage.Create;
  try
    Bitmap.SetSize(16, 16);
    Bitmap.Canvas.Brush.Color := AColor;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    PNG.Assign(Bitmap);
    PNG.SaveToFile(AFileName);
  finally
    PNG.Free;
    Bitmap.Free;
  end;
end;

function BuildImageBindingData(const ALogoFile, ASignatureFile,
  AMissingImageFile: string): TFDMemTable;
begin
  Result := TFDMemTable.Create(nil);
  Result.FieldDefs.Add('LOGO_PATH', ftString, 260);
  Result.FieldDefs.Add('SIGNATURE_PATH', ftString, 260);
  Result.FieldDefs.Add('MISSING_IMAGE_PATH', ftString, 260);
  Result.CreateDataSet;
  Result.Append;
  Result.FieldByName('LOGO_PATH').AsString := ALogoFile;
  Result.FieldByName('SIGNATURE_PATH').AsString := ASignatureFile;
  Result.FieldByName('MISSING_IMAGE_PATH').AsString := AMissingImageFile;
  Result.Post;
  Result.First;
end;

end.