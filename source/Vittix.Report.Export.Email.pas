unit Vittix.Report.Export.Email;

{
  Vittix.Report.Export.Email
  ==========================

  Attaches a rendered report to an outgoing mail message via MAPI (the default
  desktop mail client, e.g. Outlook).

  Two PDF producers feed the same attachment machinery:

    SendEmailWithReport(Pages, Title)      -> printer-backed PDF
                                              (compatibility path; needs
                                              "Microsoft Print to PDF")
    SendEmailWithReport(Document, Title)   -> Vector PDF
                                              (no printer dependency)

  Scope note: this is a DESKTOP, interactive feature.  MAPI with MAPI_DIALOG
  opens the mail client UI, so the second overload removes the *printer*
  dependency from "Send as Email (PDF)" but does NOT make e-mail export
  server-capable.  See docs/ADR-Export-PDF.md.
}

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vittix.Report.Export.Commands;

type
  TReportEmailExporter = class
  private
    class procedure SendEmailWithAttachment(const APdfFile: string;
      const AReportTitle: string);
  public
    { Reduces a report title to a safe ASCII file-name/subject fragment:
      ASCII letters, digits, spaces, '-' and '_' survive; every non-ASCII
      character (e.g. Gujarati/Hindi titles) and every other filename
      hazard is dropped.  Falls back to 'Report' when nothing survives, so
      the result is never empty. }
    class function SanitizeTitleToAscii(const AReportTitle: string): string; static;

    { Creates a NEW GUID-named folder under %TEMP% and returns
      <folder>\<sanitized title>.pdf inside it.  Each call gets its own
      folder, so two exports never collide and nothing outside the new
      folder is ever written or later deleted. }
    class function TempPdfPath(const AReportTitle: string): string; static;
  public
    /// <summary>
    ///   Compatibility path: exports the report pages to a temporary PDF file
    ///   using the printer-based exporter, then opens the default MAPI mail
    ///   client with the PDF attached.
    /// </summary>
    class procedure SendEmailWithReport(
      const Pages: TObjectList<TMetafile>;
      const AReportTitle: string); overload;

    /// <summary>
    ///   Preferred path: exports the semantic export document to a temporary
    ///   PDF file using the native Vector PDF writer (no printer driver), then
    ///   opens the default MAPI mail client with the PDF attached.
    /// </summary>
    class procedure SendEmailWithReport(
      const ADocument: TReportExportDocument;
      const AReportTitle: string); overload;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  Winapi.Mapi,
  Vittix.Report.Export.PDF,
  Vittix.Report.Export.VectorPDF;

{ TReportEmailExporter }

class function TReportEmailExporter.SanitizeTitleToAscii(
  const AReportTitle: string): string;
var
  C: Char;
begin
  Result := '';
  for C in Trim(AReportTitle) do
    if (Ord(C) >= 32) and (Ord(C) < 127) and
       (CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', ' ', '-', '_'])) then
      Result := Result + C;
  Result := Trim(Result);
  if Result = '' then
    Result := 'Report';
end;

class function TReportEmailExporter.TempPdfPath(
  const AReportTitle: string): string;
var
  GuidText, Folder: string;
begin
  // A fresh GUID folder per export: the exporter only ever writes into and
  // deletes from its own directory, never from a path derived directly
  // from the report title (which could collide with a user file in %TEMP%).
  GuidText := TGUID.NewGuid.ToString;
  GuidText := StringReplace(GuidText, '{', '', []).Replace('}', '');
  Folder := TPath.Combine(TPath.GetTempPath, 'VittixMail-' + GuidText);
  TDirectory.CreateDirectory(Folder);
  Result := TPath.Combine(Folder, SanitizeTitleToAscii(AReportTitle) + '.pdf');
end;

class procedure TReportEmailExporter.SendEmailWithAttachment(
  const APdfFile: string; const AReportTitle: string);
var
  MapiMsg: TMapiMessage;
  FileDesc: TMapiFileDesc;
  MapiResult: Cardinal;
begin
  try
    // Prepare the MAPI message.  MAPI fields are ANSI, so the subject is
    // built from the ASCII-sanitized title (non-ASCII titles such as
    // Gujarati/Hindi no longer collapse to '?' runs).
    FillChar(MapiMsg, SizeOf(TMapiMessage), 0);
    MapiMsg.lpszSubject := PAnsiChar(AnsiString('Report: ' + SanitizeTitleToAscii(AReportTitle)));
    MapiMsg.lpszNoteText := PAnsiChar(AnsiString('Please find the attached report.'));

    // Attach the file
    FillChar(FileDesc, SizeOf(TMapiFileDesc), 0);
    FileDesc.nPosition := Cardinal($FFFFFFFF);
    FileDesc.lpszPathName := PAnsiChar(AnsiString(APdfFile));
    FileDesc.lpszFileName := PAnsiChar(AnsiString(ExtractFileName(APdfFile)));

    MapiMsg.nFileCount := 1;
    MapiMsg.lpFiles := @FileDesc;

    // Send the email, opening the MAPI dialog
    MapiResult := MAPISendMail(0, 0, MapiMsg, MAPI_DIALOG or MAPI_LOGON_UI, 0);

    if (MapiResult <> SUCCESS_SUCCESS) and (MapiResult <> MAPI_USER_ABORT) then
    begin
      // A runtime unit must not hang non-interactive callers on a message
      // box; surface the failure to the caller instead (the VCL shows it
      // via Application.ShowException when nobody handles it).
      raise Exception.CreateFmt(
        'Failed to send email. MAPI error code: %d', [MapiResult]);
    end;

  finally
    // MAPI is mostly synchronous if MAPI_DIALOG is used, but some clients
    // return immediately and process sending in the background. Delete
    // only this export's own GUID folder (best-effort; a locked PDF inside
    // it is simply left behind, never a user file).
    try
      TDirectory.Delete(ExtractFilePath(APdfFile), True);
    except
      // Ignore if locked by the mail client
    end;
  end;
end;

class procedure TReportEmailExporter.SendEmailWithReport(
  const Pages: TObjectList<TMetafile>;
  const AReportTitle: string);
var
  TempFile: string;
begin
  if not Assigned(Pages) or (Pages.Count = 0) then
    raise Exception.Create('Nothing to export: the page list is empty.');

  TempFile := TempPdfPath(AReportTitle);

  // Compatibility path: printer-based PDF generation.
  TReportPDFExporter.ExportToFile(Pages, TempFile);

  SendEmailWithAttachment(TempFile, AReportTitle);
end;

class procedure TReportEmailExporter.SendEmailWithReport(
  const ADocument: TReportExportDocument;
  const AReportTitle: string);
var
  TempFile: string;
begin
  if not Assigned(ADocument) or (ADocument.Pages.Count = 0) then
    raise Exception.Create('Nothing to export: the export document is empty.');

  TempFile := TempPdfPath(AReportTitle);

  // Preferred path: native Vector PDF generation (no printer driver).
  TReportVectorPDFExporter.ExportDocument(ADocument, TempFile);

  SendEmailWithAttachment(TempFile, AReportTitle);
end;

end.
