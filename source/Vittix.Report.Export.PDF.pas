unit Vittix.Report.Export.PDF;

interface

uses
  System.Classes,
  Vcl.Graphics,
  Vittix.Report.Engine;

type
  TReportPDFExporter = class
  public
    class procedure ExportToPDF(
      Engine: TReportEngine;
      const FileName: string);
  end;

implementation

uses
  System.SysUtils,
  Vcl.Printers,
  Winapi.Windows;

class procedure TReportPDFExporter.ExportToPDF(
  Engine: TReportEngine;
  const FileName: string);
var
  i: Integer;
  MF: TMetafile;
  PDFCanvas: TCanvas;
begin
  if Engine.Pages.Count = 0 then
    raise Exception.Create('Engine has no pages');

  { use Windows PDF printer (built-in Win10+) }
  Printer.PrinterIndex :=
    Printer.Printers.IndexOf('Microsoft Print to PDF');

  if Printer.PrinterIndex < 0 then
    raise Exception.Create('Microsoft Print to PDF not found');

  Printer.Title := ChangeFileExt(
    ExtractFileName(FileName), '');

  Printer.BeginDoc;
  try
    for i := 0 to Engine.Pages.Count-1 do
    begin
      if i > 0 then
        Printer.NewPage;

      MF := Engine.Pages[i];
      PDFCanvas := Printer.Canvas;

      PDFCanvas.StretchDraw(
        Rect(0,0,
          Printer.PageWidth,
          Printer.PageHeight),
        MF);
    end;
  finally
    Printer.EndDoc;
  end;
end;

end.
