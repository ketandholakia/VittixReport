unit Vittix.Report.Export.PDF;

{
  Vittix.Report.Export.PDF
  ========================
  Exports a rendered report (list of TMetafile pages) to a PDF file by
  printing to the "Microsoft Print to PDF" virtual printer built into
  Windows 10 / 11.

  Architecture changes in this revision
  --------------------------------------
  • TReportPDFExporter now implements IReportExporter instead of coupling
    directly to TReportEngine.  Any TObjectList<TMetafile> can be passed in —
    pages may come from TReportEngine, a cache, or any other producer.
  • The legacy class method ExportToPDF(Engine, FileName) is retained as
    an overloaded convenience wrapper for backward compatibility.

  Limitations
  -----------
  • Relies on "Microsoft Print to PDF" being available (Win10+).
  • Does not select a custom output path natively; Windows may show a Save
    dialog if the printer's port is not pre-configured.  For silent PDF
    generation consider a third-party library (e.g. Skia, FreeSpire.PDF).
}

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vittix.Report.Interfaces;   // IReportExporter

type
  TReportPDFExporter = class(TInterfacedObject, IReportExporter)
  public
    { IReportExporter }
    procedure ExportPages(
      const Pages: TObjectList<TMetafile>;
      const FileName: string);
    function FormatName: string;
    function DefaultExtension: string;

    { Convenience class method — backward-compatible, wraps ExportPages }
    class procedure ExportToFile(
      const Pages: TObjectList<TMetafile>;
      const FileName: string);
  end;

implementation

uses
  System.SysUtils,
  Vcl.Printers,
  Winapi.Windows,
  Vcl.Dialogs;

type
  TPDFExportScaleMode = (pesFullStretch, pesFitPreserveAspectCentered);

function CalculatePDFDestRect(
  const MF: TMetafile;
  PrinterWidth: Integer;
  PrinterHeight: Integer;
  Mode: TPDFExportScaleMode): TRect;
var
  Scale: Double;
  W: Integer;
  H: Integer;
  X: Integer;
  Y: Integer;
begin
  case Mode of
    pesFitPreserveAspectCentered:
      begin
        if (not Assigned(MF)) or (MF.Width <= 0) or (MF.Height <= 0) or
           (PrinterWidth <= 0) or (PrinterHeight <= 0) then
        begin
          Result := Rect(0, 0, PrinterWidth, PrinterHeight);
          Exit;
        end;

        Scale := PrinterWidth / MF.Width;
        if (PrinterHeight / MF.Height) < Scale then
          Scale := PrinterHeight / MF.Height;

        W := Round(MF.Width * Scale);
        H := Round(MF.Height * Scale);
        X := (PrinterWidth - W) div 2;
        Y := (PrinterHeight - H) div 2;
        Result := Rect(X, Y, X + W, Y + H);
      end;
  else
    // Default mode preserves existing export behavior exactly.
    Result := Rect(0, 0, PrinterWidth, PrinterHeight);
  end;
end;

// ---------------------------------------------------------------------------
// IReportExporter
// ---------------------------------------------------------------------------

function TReportPDFExporter.FormatName: string;
begin
  Result := 'PDF Document';
end;

function TReportPDFExporter.DefaultExtension: string;
begin
  Result := 'pdf';
end;

procedure TReportPDFExporter.ExportPages(
  const Pages: TObjectList<TMetafile>;
  const FileName: string);
var
  i:    Integer;
  MF:   TMetafile;
  Dest: TRect;
  ScaleMode: TPDFExportScaleMode;
  ReportW: Integer;
  ReportH: Integer;
  PrinterW: Integer;
  PrinterH: Integer;
  SizeTolerance: Integer;
begin
  if not Assigned(Pages) or (Pages.Count = 0) then
    raise Exception.Create('Nothing to export: the page list is empty.');

  { Locate "Microsoft Print to PDF" virtual printer }
  Printer.PrinterIndex :=
    Printer.Printers.IndexOf('Microsoft Print to PDF');

  if Printer.PrinterIndex < 0 then
    raise Exception.Create(
      '"Microsoft Print to PDF" printer not found. ' +
      'This feature requires Windows 10 or later.');

  Printer.Title := ChangeFileExt(ExtractFileName(FileName), '');

  Printer.BeginDoc;
  try
    ScaleMode := pesFullStretch;

    // Diagnostic only: warn if report/metafile page size and printer canvas
    // size differ materially; export path remains unchanged.
    SizeTolerance := 2;
    ReportW := Pages[0].Width;
    ReportH := Pages[0].Height;
    PrinterW := Printer.PageWidth;
    PrinterH := Printer.PageHeight;
    if (Abs(ReportW - PrinterW) > SizeTolerance) or
       (Abs(ReportH - PrinterH) > SizeTolerance) then
    begin
      ShowMessage(Format(
        'PDF export page size differs from report page size. Output may be scaled.' + sLineBreak +
        'Report: %d x %d' + sLineBreak +
        'Printer: %d x %d',
        [ReportW, ReportH, PrinterW, PrinterH]));
    end;

    for i := 0 to Pages.Count - 1 do
    begin
      if i > 0 then
        Printer.NewPage;

      MF   := Pages[i];
      Dest := CalculatePDFDestRect(MF, Printer.PageWidth, Printer.PageHeight, ScaleMode);
      Printer.Canvas.StretchDraw(Dest, MF);
    end;
    Printer.EndDoc;
  except
    Printer.Abort;
    raise;
  end;
end;

// ---------------------------------------------------------------------------
// Class convenience wrapper
// ---------------------------------------------------------------------------

class procedure TReportPDFExporter.ExportToFile(
  const Pages: TObjectList<TMetafile>;
  const FileName: string);
var
  Exporter: TReportPDFExporter;
begin
  Exporter := TReportPDFExporter.Create;
  try
    Exporter.ExportPages(Pages, FileName);
  finally
    Exporter.Free;
  end;
end;

end.
