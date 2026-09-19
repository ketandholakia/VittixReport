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
    class function TempPdfPath(const AReportTitle: string): string;
    class procedure SendEmailWithAttachment(const APdfFile: string;
      const AReportTitle: string);
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
  Vcl.Dialogs,
  Vittix.Report.Export.PDF,
  Vittix.Report.Export.VectorPDF;

{ TReportEmailExporter }

class function TReportEmailExporter.TempPdfPath(
  const AReportTitle: string): string;
var
  SafeTitle: string;
begin
  // Ensure title is safe for a filename
  SafeTitle := AReportTitle;
  if SafeTitle = '' then
    SafeTitle := 'Report';
  for var c in TPath.GetInvalidFileNameChars do
    SafeTitle := SafeTitle.Replace(c, '_');

  Result := TPath.Combine(TPath.GetTempPath, SafeTitle + '.pdf');
end;

class procedure TReportEmailExporter.SendEmailWithAttachment(
  const APdfFile: string; const AReportTitle: string);
var
  MapiMsg: TMapiMessage;
  FileDesc: TMapiFileDesc;
  MapiResult: Cardinal;
begin
  try
    // Prepare the MAPI message
    FillChar(MapiMsg, SizeOf(TMapiMessage), 0);
    MapiMsg.lpszSubject := PAnsiChar(AnsiString('Report: ' + AReportTitle));
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
      ShowMessage('Failed to send email. MAPI error code: ' + IntToStr(MapiResult));
    end;

  finally
    // MAPI is mostly synchronous if MAPI_DIALOG is used, but some clients
    // return immediately and process sending in the background. We can try to
    // delete the file, but if it fails (locked by Outlook), we just swallow the exception.
    try
      if TFile.Exists(APdfFile) then
        TFile.Delete(APdfFile);
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
