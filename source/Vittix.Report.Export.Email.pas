unit Vittix.Report.Export.Email;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vittix.Report.Export.PDF;

type
  TReportEmailExporter = class
  public
    /// <summary>
    ///   Exports the report pages to a temporary PDF file and opens the default MAPI
    ///   mail client (e.g., Outlook) with the PDF attached.
    /// </summary>
    class procedure SendEmailWithReport(
      const Pages: TObjectList<TMetafile>;
      const AReportTitle: string);
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  Winapi.Mapi,
  Vcl.Dialogs;

{ TReportEmailExporter }

class procedure TReportEmailExporter.SendEmailWithReport(
  const Pages: TObjectList<TMetafile>;
  const AReportTitle: string);
var
  TempDir, TempFile, SafeTitle: string;
  MapiMsg: TMapiMessage;
  FileDesc: TMapiFileDesc;
  MapiResult: Cardinal;
begin
  if not Assigned(Pages) or (Pages.Count = 0) then
    raise Exception.Create('Nothing to export: the page list is empty.');

  // Ensure title is safe for a filename
  SafeTitle := AReportTitle;
  if SafeTitle = '' then
    SafeTitle := 'Report';
  for var c in TPath.GetInvalidFileNameChars do
    SafeTitle := SafeTitle.Replace(c, '_');

  TempDir := TPath.GetTempPath;
  TempFile := TPath.Combine(TempDir, SafeTitle + '.pdf');

  // Generate the PDF to the temp file
  TReportPDFExporter.ExportToFile(Pages, TempFile);
  try
    // Prepare the MAPI message
    FillChar(MapiMsg, SizeOf(TMapiMessage), 0);
    MapiMsg.lpszSubject := PAnsiChar(AnsiString('Report: ' + AReportTitle));
    MapiMsg.lpszNoteText := PAnsiChar(AnsiString('Please find the attached report.'));

    // Attach the file
    FillChar(FileDesc, SizeOf(TMapiFileDesc), 0);
    FileDesc.nPosition := Cardinal($FFFFFFFF);
    FileDesc.lpszPathName := PAnsiChar(AnsiString(TempFile));
    FileDesc.lpszFileName := PAnsiChar(AnsiString(ExtractFileName(TempFile)));

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
      if TFile.Exists(TempFile) then
        TFile.Delete(TempFile);
    except
      // Ignore if locked by the mail client
    end;
  end;
end;

end.
