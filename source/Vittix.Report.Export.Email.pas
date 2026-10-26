unit Vittix.Report.Export.Email;

{
  Vittix.Report.Export.Email
  ==========================

  LEGACY / DEPRECATED (v1.0.1): the user-facing Designer and component
  preview actions no longer call this unit. They save a Vector PDF to a
  user-selected file instead. This unit remains only for source compatibility
  with existing Delphi consumers; new code should use
  TReportVectorPDFExporter.ExportDocumentAtomic and its own Save dialog.

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
  {$IFDEF VITTIX_REPORT_TESTS}
  TReportEmailExportCallback = procedure(const APdfFile: string) of object;
  TReportEmailMapiCallback = function(const APdfFile,
    AReportTitle: string): Cardinal of object;
  TReportEmailDeleteCallback = procedure(const AFolder: string) of object;
  {$ENDIF}

  TReportEmailExporter = class
  private
    type
      TEmailOperation = reference to procedure;
    class procedure SendEmailWithAttachment(const APdfFile: string;
      const AReportTitle: string);
    class procedure CleanupTempPdf(const APdfFile: string);
    class procedure ExportAndSend(const APdfFile, AReportTitle: string;
      const AExport: TEmailOperation);
    {$IFDEF VITTIX_REPORT_TESTS}
    class var FTestTempRoot: string;
    class var FTestPrinterExport: TReportEmailExportCallback;
    class var FTestVectorExport: TReportEmailExportCallback;
    class var FTestMapiSend: TReportEmailMapiCallback;
    class var FTestDeleteFolder: TReportEmailDeleteCallback;
    {$ENDIF}
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

    {$IFDEF VITTIX_REPORT_TESTS}
    { Test-build-only dependency seam. Not present in production builds. }
    class procedure SetTestHooks(const ATempRoot: string;
      APrinterExport, AVectorExport: TReportEmailExportCallback;
      AMapiSend: TReportEmailMapiCallback;
      ADeleteFolder: TReportEmailDeleteCallback); static;
    class procedure ResetTestHooks; static;
    class procedure TestCleanupTempPdf(const APdfFile: string); static;
    {$ENDIF}
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
  GuidText, Folder, TempRoot: string;
begin
  // A fresh GUID folder per export: the exporter only ever writes into and
  // deletes from its own directory, never from a path derived directly
  // from the report title (which could collide with a user file in %TEMP%).
  GuidText := TGUID.NewGuid.ToString;
  GuidText := StringReplace(GuidText, '{', '', []).Replace('}', '');
  {$IFDEF VITTIX_REPORT_TESTS}
  if FTestTempRoot <> '' then
    TempRoot := FTestTempRoot
  else
  {$ENDIF}
    TempRoot := TPath.GetTempPath;
  Folder := TPath.Combine(TempRoot, 'VittixMail-' + GuidText);
  TDirectory.CreateDirectory(Folder);
  Result := TPath.Combine(Folder, SanitizeTitleToAscii(AReportTitle) + '.pdf');
end;

class procedure TReportEmailExporter.CleanupTempPdf(const APdfFile: string);
var
  TempPath, FolderPath, FolderName, GuidText: string;
  CanonicalGuid: string;
begin
  FolderPath := ExcludeTrailingPathDelimiter(
    TPath.GetFullPath(ExtractFilePath(APdfFile)));
  {$IFDEF VITTIX_REPORT_TESTS}
  if FTestTempRoot <> '' then
    TempPath := ExcludeTrailingPathDelimiter(TPath.GetFullPath(FTestTempRoot))
  else
  {$ENDIF}
    TempPath := ExcludeTrailingPathDelimiter(TPath.GetFullPath(TPath.GetTempPath));
  FolderName := ExtractFileName(FolderPath);

  // Delete only a direct, GUID-named VittixMail child of the system temp
  // directory. Never trust a path outside the exporter-owned namespace.
  if not SameText(ExtractFileDir(FolderPath), TempPath) or
     (Copy(FolderName, 1, Length('VittixMail-')) <> 'VittixMail-') then
    raise Exception.Create('Refusing to clean a PDF outside its exporter temp folder.');

  GuidText := Copy(FolderName, Length('VittixMail-') + 1, MaxInt);
  try
    CanonicalGuid := GUIDToString(StringToGUID('{' + GuidText + '}'));
  except
    raise Exception.Create('Refusing to clean an invalid exporter temp folder.');
  end;
  if CanonicalGuid = '' then
    raise Exception.Create('Refusing to clean an invalid exporter temp folder.');

  {$IFDEF VITTIX_REPORT_TESTS}
  if Assigned(FTestDeleteFolder) then
  begin
    FTestDeleteFolder(FolderPath);
    Exit;
  end;
  {$ENDIF}

  if TDirectory.Exists(FolderPath) then
    TDirectory.Delete(FolderPath, True);
end;

class procedure TReportEmailExporter.ExportAndSend(const APdfFile,
  AReportTitle: string; const AExport: TEmailOperation);
var
  OperationMessage, CleanupMessage: string;
begin
  try
    AExport();
    SendEmailWithAttachment(APdfFile, AReportTitle);
  except
    on OperationError: Exception do
    begin
      OperationMessage := OperationError.Message;
      try
        CleanupTempPdf(APdfFile);
      except
        on CleanupError: Exception do
        begin
          CleanupMessage := CleanupError.Message;
          raise Exception.CreateFmt(
            'Email export failed: %s; temporary cleanup also failed: %s',
            [OperationMessage, CleanupMessage]);
        end;
      end;
      raise;
    end;
  end;

  CleanupTempPdf(APdfFile);
end;

{$IFDEF VITTIX_REPORT_TESTS}
class procedure TReportEmailExporter.SetTestHooks(const ATempRoot: string;
  APrinterExport, AVectorExport: TReportEmailExportCallback;
  AMapiSend: TReportEmailMapiCallback;
  ADeleteFolder: TReportEmailDeleteCallback);
begin
  FTestTempRoot := ATempRoot;
  FTestPrinterExport := APrinterExport;
  FTestVectorExport := AVectorExport;
  FTestMapiSend := AMapiSend;
  FTestDeleteFolder := ADeleteFolder;
end;

class procedure TReportEmailExporter.ResetTestHooks;
begin
  FTestTempRoot := '';
  FTestPrinterExport := nil;
  FTestVectorExport := nil;
  FTestMapiSend := nil;
  FTestDeleteFolder := nil;
end;

class procedure TReportEmailExporter.TestCleanupTempPdf(
  const APdfFile: string);
begin
  CleanupTempPdf(APdfFile);
end;
{$ENDIF}

class procedure TReportEmailExporter.SendEmailWithAttachment(
  const APdfFile: string; const AReportTitle: string);
var
  MapiMsg: TMapiMessage;
  FileDesc: TMapiFileDesc;
  MapiResult: Cardinal;
begin
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

  // MAPI's documented contract copies file attachments into the message
  // before MAPISendMail returns. MAPI_DIALOG is modal; this does not imply
  // delivery completion, only that the source file is no longer required.
  {$IFDEF VITTIX_REPORT_TESTS}
  if Assigned(FTestMapiSend) then
    MapiResult := FTestMapiSend(APdfFile, AReportTitle)
  else
  {$ENDIF}
    MapiResult := MAPISendMail(0, 0, MapiMsg, MAPI_DIALOG or MAPI_LOGON_UI, 0);

  if (MapiResult <> SUCCESS_SUCCESS) and (MapiResult <> MAPI_USER_ABORT) then
  begin
    // A runtime unit must not hang non-interactive callers on a message
    // box; surface the failure to the caller instead (the VCL shows it
    // via Application.ShowException when nobody handles it).
    raise Exception.CreateFmt(
      'Failed to send email. MAPI error code: %d', [MapiResult]);
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

  ExportAndSend(TempFile, AReportTitle,
    procedure
    begin
      {$IFDEF VITTIX_REPORT_TESTS}
      if Assigned(FTestPrinterExport) then
      begin
        FTestPrinterExport(TempFile);
        Exit;
      end;
      {$ENDIF}
      TReportPDFExporter.ExportToFile(Pages, TempFile);
    end);
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

  ExportAndSend(TempFile, AReportTitle,
    procedure
    begin
      {$IFDEF VITTIX_REPORT_TESTS}
      if Assigned(FTestVectorExport) then
      begin
        FTestVectorExport(TempFile);
        Exit;
      end;
      {$ENDIF}
      TReportVectorPDFExporter.ExportDocument(ADocument, TempFile);
    end);
end;

end.
