unit Vittix.Report.Export.HTML;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.Graphics,
  Vittix.Report.Export.Commands;

type
  TReportHTMLExporter = class
  public
    class procedure ExportDocument(ADocument: TReportExportDocument; const AFileName: string); overload;
    class procedure ExportDocument(ADocument: TReportExportDocument; AStream: TStream); overload;
  end;

implementation

uses
  Winapi.Windows,
  System.NetEncoding,
  System.IOUtils,
  System.StrUtils,
  System.Math,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage;

function ColorToHTML(AColor: TColor): string;
var
  RGBColor: Longint;
begin
  RGBColor := ColorToRGB(AColor);
  Result := Format('#%.2x%.2x%.2x', [GetRValue(RGBColor), GetGValue(RGBColor), GetBValue(RGBColor)]);
end;

function TryGetBase64Image(const ASource: string; out ABase64Data: string): Boolean;
var
  Ext: string;
  Fs: TFileStream;
  Ss: TStringStream;
  MimeType: string;
begin
  Result := False;
  if not TFile.Exists(ASource) then Exit;
  Ext := LowerCase(ExtractFileExt(ASource));
  if (Ext = '.jpg') or (Ext = '.jpeg') then MimeType := 'image/jpeg'
  else if Ext = '.png' then MimeType := 'image/png'
  else if Ext = '.gif' then MimeType := 'image/gif'
  else if Ext = '.bmp' then MimeType := 'image/bmp'
  else Exit; // Not supported directly or needs conversion

  try
    Fs := TFileStream.Create(ASource, fmOpenRead or fmShareDenyNone);
    try
      Ss := TStringStream.Create('');
      try
        TNetEncoding.Base64.Encode(Fs, Ss);
        ABase64Data := 'data:' + MimeType + ';base64,' + Ss.DataString;
        Result := True;
      finally
        Ss.Free;
      end;
    finally
      Fs.Free;
    end;
  except
    // ignore
  end;
end;

function PathToFileURI(const APath: string): string;
{
  Converts a filesystem path to a properly percent-encoded file:/// URI.
  RFC 3986 unreserved characters (A-Z a-z 0-9 - . _ ~) plus the path
  separators '/' and the drive-letter ':' are kept literal; every other
  byte of the UTF-8 representation is percent-encoded, so spaces, '#',
  '%', '?' and non-ASCII filenames produce correct URIs.  The result is
  NOT yet HTML-escaped — callers must escape it again when placing it
  inside a quoted HTML attribute.
}
const
  SafeBytes = [Ord('A')..Ord('Z'), Ord('a')..Ord('z'), Ord('0')..Ord('9'),
    Ord('-'), Ord('.'), Ord('_'), Ord('~'), Ord('/'), Ord(':')];
var
  PathBytes: TBytes;
  B: Byte;
begin
  Result := 'file:///';
  PathBytes := TEncoding.UTF8.GetBytes(StringReplace(APath, '\', '/', [rfReplaceAll]));
  for B in PathBytes do
  begin
    if Byte(B) in SafeBytes then
      Result := Result + Chr(B)
    else
      Result := Result + '%' + IntToHex(B, 2);
  end;
end;

function EscapeHTMLAttr(const S: string): string;
{
  Escapes S for safe inclusion inside a double-quoted HTML attribute.
  TNetEncoding.HTML.Encode covers & < > but leaves quote characters
  untouched, which is insufficient for attribute context — quotes would
  terminate the attribute (and, inside style values, the CSS string).
}
begin
  Result := TNetEncoding.HTML.Encode(S);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
end;

class procedure TReportHTMLExporter.ExportDocument(ADocument: TReportExportDocument; const AFileName: string);
var
  Fs: TFileStream;
begin
  Fs := TFileStream.Create(AFileName, fmCreate);
  try
    ExportDocument(ADocument, Fs);
  finally
    Fs.Free;
  end;
end;

class procedure TReportHTMLExporter.ExportDocument(ADocument: TReportExportDocument; AStream: TStream);
var
  Writer: TStreamWriter;
  PageIdx: Integer;
  Page: TReportExportPage;
  CmdIdx: Integer;
  Command: TReportExportCommand;
  TextCmd: TReportExportTextCommand;
  LineCmd: TReportExportLineCommand;
  RectCmd: TReportExportRectangleCommand;
  FillCmd: TReportExportFillRectangleCommand;
  ImageCmd: TReportExportImageCommand;

  AlignStr: string;
  FontStyleStr: string;
  FontWeightStr: string;
  FontDecorationStr: string;
  Base64Img: string;
  PageCountStr: string;
begin
  PageCountStr := '';
  if Assigned(ADocument) then
    PageCountStr := Format(' (%d page%s)', [ADocument.Pages.Count,
      IfThen(ADocument.Pages.Count = 1, '', 's')]);

  Writer := TStreamWriter.Create(AStream, TEncoding.UTF8);
  try
    Writer.WriteLine('<!DOCTYPE html>');
    Writer.WriteLine('<html>');
    Writer.WriteLine('<head>');
    Writer.WriteLine('<meta charset="utf-8">');
    Writer.WriteLine('<title>VittixReport Export' + PageCountStr + '</title>');
    Writer.WriteLine('<style>');
    Writer.WriteLine('  body { background: #e0e0e0; margin: 0; padding: 20px 0; display: flex; flex-direction: column; align-items: center; }');
    Writer.WriteLine('  .vrt-page { position: relative; background: white; margin-bottom: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.2); overflow: hidden; page-break-after: always; }');
    Writer.WriteLine('  .vrt-text { position: absolute; box-sizing: border-box; overflow: hidden; white-space: nowrap; }');
    Writer.WriteLine('  .vrt-text.wrap { white-space: normal; word-wrap: break-word; }');
    Writer.WriteLine('  .vrt-rect { position: absolute; box-sizing: border-box; }');
    Writer.WriteLine('  .vrt-fill { position: absolute; box-sizing: border-box; }');
    Writer.WriteLine('  .vrt-line { position: absolute; pointer-events: none; }');
    Writer.WriteLine('  .vrt-img { position: absolute; }');
    Writer.WriteLine('  @media print {');
    Writer.WriteLine('    body { background: white; margin: 0; padding: 0; display: block; }');
    Writer.WriteLine('    .vrt-page { box-shadow: none; margin: 0; }');
    Writer.WriteLine('  }');
    Writer.WriteLine('</style>');
    Writer.WriteLine('</head>');
    Writer.WriteLine('<body>');

    if Assigned(ADocument) then
    begin
      for PageIdx := 0 to ADocument.Pages.Count - 1 do
      begin
        Page := ADocument.Pages[PageIdx];
        Writer.WriteLine(Format('<div class="vrt-page" style="width: %dpx; height: %dpx;">', [Page.Width, Page.Height]));
        
        for CmdIdx := 0 to Page.Commands.Count - 1 do
        begin
          Command := Page.Commands[CmdIdx];
          case Command.Kind of
            eckText:
              begin
                TextCmd := TReportExportTextCommand(Command);
                AlignStr := 'left';
                if TextCmd.HAlign = taRightJustify then AlignStr := 'right'
                else if TextCmd.HAlign = taCenter then AlignStr := 'center';

                FontStyleStr := 'normal';
                if fsItalic in TextCmd.FontStyle then FontStyleStr := 'italic';

                FontWeightStr := 'normal';
                if fsBold in TextCmd.FontStyle then FontWeightStr := 'bold';

                FontDecorationStr := 'none';
                if fsUnderline in TextCmd.FontStyle then FontDecorationStr := 'underline';

                Writer.Write(Format('<div class="vrt-text%s" style="left:%dpx; top:%dpx; width:%dpx; height:%dpx; ',
                  [IfThen(TextCmd.WordWrap, ' wrap', ''), TextCmd.Bounds.Left, TextCmd.Bounds.Top, TextCmd.Bounds.Width, TextCmd.Bounds.Height]));
                Writer.Write(Format('font-family:''%s'',sans-serif; font-size:%dpt; color:%s; text-align:%s; font-style:%s; font-weight:%s; text-decoration:%s;">',
                  [EscapeHTMLAttr(TextCmd.FontName), TextCmd.FontSize, ColorToHTML(TextCmd.FontColor), AlignStr, FontStyleStr, FontWeightStr, FontDecorationStr]));
                
                // Escape HTML chars
                var EncodedText := StringReplace(TextCmd.Text, '&', '&amp;', [rfReplaceAll]);
                EncodedText := StringReplace(EncodedText, '<', '&lt;', [rfReplaceAll]);
                EncodedText := StringReplace(EncodedText, '>', '&gt;', [rfReplaceAll]);
                
                // Convert newlines to <br> if word-wrapped or multi-line
                if TextCmd.WordWrap or (Pos(#13, EncodedText) > 0) or (Pos(#10, EncodedText) > 0) then
                begin
                  EncodedText := StringReplace(EncodedText, #13#10, '<br>', [rfReplaceAll]);
                  EncodedText := StringReplace(EncodedText, #13, '<br>', [rfReplaceAll]);
                  EncodedText := StringReplace(EncodedText, #10, '<br>', [rfReplaceAll]);
                end;

                Writer.Write(EncodedText);
                Writer.WriteLine('</div>');
              end;
              
            eckRectangle:
              begin
                RectCmd := TReportExportRectangleCommand(Command);
                Writer.WriteLine(Format('<div class="vrt-rect" style="left:%dpx; top:%dpx; width:%dpx; height:%dpx; border:%dpx solid %s;"></div>',
                  [RectCmd.Bounds.Left, RectCmd.Bounds.Top, RectCmd.Bounds.Width, RectCmd.Bounds.Height,
                   RectCmd.BorderWidth, ColorToHTML(RectCmd.BorderColor)]));
              end;
              
            eckFillRectangle:
              begin
                FillCmd := TReportExportFillRectangleCommand(Command);
                Writer.WriteLine(Format('<div class="vrt-fill" style="left:%dpx; top:%dpx; width:%dpx; height:%dpx; background-color:%s;"></div>',
                  [FillCmd.Bounds.Left, FillCmd.Bounds.Top, FillCmd.Bounds.Width, FillCmd.Bounds.Height,
                   ColorToHTML(FillCmd.FillColor)]));
              end;
              
            eckLine:
              begin
                LineCmd := TReportExportLineCommand(Command);
                var MinX := Min(LineCmd.X1, LineCmd.X2);
                var MinY := Min(LineCmd.Y1, LineCmd.Y2);
                var W := Abs(LineCmd.X2 - LineCmd.X1);
                var H := Abs(LineCmd.Y2 - LineCmd.Y1);
                // padding for stroke width
                var Pad := LineCmd.Width;
                Writer.WriteLine(Format('<svg class="vrt-line" style="left:%dpx; top:%dpx;" width="%d" height="%d">',
                  [MinX - Pad, MinY - Pad, W + Pad*2, H + Pad*2]));
                Writer.WriteLine(Format('  <line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-width="%d" />',
                  [LineCmd.X1 - MinX + Pad, LineCmd.Y1 - MinY + Pad, 
                   LineCmd.X2 - MinX + Pad, LineCmd.Y2 - MinY + Pad, 
                   ColorToHTML(LineCmd.Color), LineCmd.Width]));
                Writer.WriteLine('</svg>');
              end;
              
            eckImage:
              begin
                ImageCmd := TReportExportImageCommand(Command);
                // Try Base64 embedding first
                if TryGetBase64Image(ImageCmd.Source, Base64Img) then
                begin
                  Writer.WriteLine(Format('<img class="vrt-img" style="left:%dpx; top:%dpx; width:%dpx; height:%dpx; object-fit:%s;" src="%s" />',
                    [ImageCmd.Bounds.Left, ImageCmd.Bounds.Top, ImageCmd.Bounds.Width, ImageCmd.Bounds.Height,
                     IfThen(ImageCmd.Stretch, 'fill', IfThen(ImageCmd.Proportional, 'contain', 'none')),
                     Base64Img]));
                end
                else
                begin
                  // Fallback to absolute local file path if base64 fails
                  var ImgSrc := EscapeHTMLAttr(PathToFileURI(ImageCmd.Source));
                  Writer.WriteLine(Format('<img class="vrt-img" style="left:%dpx; top:%dpx; width:%dpx; height:%dpx; object-fit:%s;" src="%s" />',
                    [ImageCmd.Bounds.Left, ImageCmd.Bounds.Top, ImageCmd.Bounds.Width, ImageCmd.Bounds.Height,
                     IfThen(ImageCmd.Stretch, 'fill', IfThen(ImageCmd.Proportional, 'contain', 'none')),
                     ImgSrc]));
                end;
              end;
          end;
        end;
        Writer.WriteLine('</div>');
      end;
    end;
    
    Writer.WriteLine('</body>');
    Writer.WriteLine('</html>');
  finally
    Writer.Free; // Flushes and frees
  end;
end;

end.
