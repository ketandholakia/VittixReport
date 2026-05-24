unit Vittix.Report.Export.VectorPDF;

interface

uses
  System.Classes,
  System.SysUtils,
  Vittix.Report.Export.Commands;

type
  TReportVectorPDFExporter = class
  public
    class procedure ExportDocument(
      ADocument: TReportExportDocument;
      const AFileName: string); static;
  end;

implementation

class procedure TReportVectorPDFExporter.ExportDocument(
  ADocument: TReportExportDocument;
  const AFileName: string);
var
  Stream: TFileStream;
  Offsets: TArray<Int64>;
  ObjectCount: Integer;
  I: Integer;
  PageIndex: Integer;
  ObjNo: Integer;
  ContentObjNo: Integer;
  XRefOffset: Int64;

  procedure WriteAnsi(const S: AnsiString);
  begin
    if S <> '' then
      Stream.WriteBuffer(PAnsiChar(S)^, Length(S));
  end;

  procedure BeginObject(AObjectNo: Integer);
  begin
    Offsets[AObjectNo] := Stream.Position;
    WriteAnsi(AnsiString(IntToStr(AObjectNo) + ' 0 obj' + #10));
  end;

  procedure EndObject;
  begin
    WriteAnsi('endobj' + #10);
  end;

  function PageObjectNo(APageIndex: Integer): Integer;
  begin
    Result := 3 + (APageIndex * 2);
  end;

  function PageContentObjectNo(APageIndex: Integer): Integer;
  begin
    Result := PageObjectNo(APageIndex) + 1;
  end;

begin
  if not Assigned(ADocument) then
    raise EArgumentNilException.Create('ADocument');
  if AFileName = '' then
    raise EArgumentException.Create('AFileName is required');

  ObjectCount := 2 + (ADocument.Pages.Count * 2);
  SetLength(Offsets, ObjectCount + 1);

  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    WriteAnsi('%PDF-1.4' + #10);

    BeginObject(1);
    WriteAnsi('<< /Type /Catalog /Pages 2 0 R >>' + #10);
    EndObject;

    BeginObject(2);
    WriteAnsi('<< /Type /Pages /Count ' +
      AnsiString(IntToStr(ADocument.Pages.Count)) + ' /Kids [');
    for PageIndex := 0 to ADocument.Pages.Count - 1 do
      WriteAnsi(AnsiString(IntToStr(PageObjectNo(PageIndex)) + ' 0 R '));
    WriteAnsi('] >>' + #10);
    EndObject;

    for PageIndex := 0 to ADocument.Pages.Count - 1 do
    begin
      ObjNo := PageObjectNo(PageIndex);
      ContentObjNo := PageContentObjectNo(PageIndex);

      BeginObject(ObjNo);
      WriteAnsi('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ' +
        AnsiString(IntToStr(ADocument.Pages[PageIndex].Width)) + ' ' +
        AnsiString(IntToStr(ADocument.Pages[PageIndex].Height)) +
        '] /Contents ' + AnsiString(IntToStr(ContentObjNo)) + ' 0 R >>' + #10);
      EndObject;

      BeginObject(ContentObjNo);
      WriteAnsi('<< /Length 0 >>' + #10);
      WriteAnsi('stream' + #10);
      WriteAnsi('endstream' + #10);
      EndObject;
    end;

    XRefOffset := Stream.Position;
    WriteAnsi('xref' + #10);
    WriteAnsi(AnsiString('0 ' + IntToStr(ObjectCount + 1) + #10));
    WriteAnsi('0000000000 65535 f ' + #10);
    for I := 1 to ObjectCount do
      WriteAnsi(AnsiString(Format('%.10d 00000 n ', [Offsets[I]]) + #10));
    WriteAnsi('trailer' + #10);
    WriteAnsi(AnsiString('<< /Size ' + IntToStr(ObjectCount + 1) +
      ' /Root 1 0 R >>' + #10));
    WriteAnsi('startxref' + #10);
    WriteAnsi(AnsiString(IntToStr(XRefOffset) + #10));
    WriteAnsi('%%EOF' + #10);
  finally
    Stream.Free;
  end;
end;

end.
