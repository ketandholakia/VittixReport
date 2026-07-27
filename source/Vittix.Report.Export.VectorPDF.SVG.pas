unit Vittix.Report.Export.VectorPDF.SVG;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Math, System.StrUtils,
  System.Variants,
  Xml.XMLDoc, Xml.XMLIntf,
  Vittix.Report.Export.Commands;

function TryDrawSVGToPDFCommands(ACommand: TReportExportImageCommand;
  APageHeight: Integer; out APdfCommands: AnsiString): Boolean;

implementation

uses
  Vcl.Graphics;

function PdfNumber(const V: Double): AnsiString;
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Create('en-US');
  Result := AnsiString(FloatToStr(RoundTo(V, -3), FS));
end;

function PdfY(const APageHeight: Integer; const AY: Double): Double;
begin
  Result := APageHeight - AY;
end;

function TryDrawSVGToPDFCommands(ACommand: TReportExportImageCommand;
  APageHeight: Integer; out APdfCommands: AnsiString): Boolean;
var
  XML: IXMLDocument;
  Root: IXMLNode;
  I: Integer;
  Node: IXMLNode;
  Cmd: AnsiString;
  ScaleX, ScaleY, Scale: Double;
  ViewBoxW, ViewBoxH: Double;
  R: TRect;
  Arr: TArray<string>;
begin
  Result := False;
  APdfCommands := '';
  if not FileExists(ACommand.Source) then
    Exit;

  try
    XML := LoadXMLDocument(ACommand.Source);
    Root := XML.DocumentElement;
    if not SameText(Root.NodeName, 'svg') then
      Exit;

    ViewBoxW := 100;
    ViewBoxH := 100;
    if Root.HasAttribute('viewBox') then
    begin
      Arr := string(Root.Attributes['viewBox']).Split([' ']);
      if Length(Arr) = 4 then
      begin
        ViewBoxW := StrToFloatDef(Arr[2], 100);
        ViewBoxH := StrToFloatDef(Arr[3], 100);
      end;
    end
    else
    begin
      if Root.HasAttribute('width') then ViewBoxW := StrToFloatDef(Root.Attributes['width'], 100);
      if Root.HasAttribute('height') then ViewBoxH := StrToFloatDef(Root.Attributes['height'], 100);
    end;

    R := ACommand.Bounds;
    ScaleX := R.Width / Max(1, ViewBoxW);
    ScaleY := R.Height / Max(1, ViewBoxH);
    Scale := Min(ScaleX, ScaleY);

    Cmd := 'q' + #10 +
           '0 0 0 RG' + #10 + // default black stroke
           '1 w' + #10;       // default line width 1

    for I := 0 to Root.ChildNodes.Count - 1 do
    begin
      Node := Root.ChildNodes[I];
      if SameText(Node.NodeName, 'rect') then
      begin
        var X := StrToFloatDef(VarToStr(Node.Attributes['x']), 0) * Scale;
        var Y := StrToFloatDef(VarToStr(Node.Attributes['y']), 0) * Scale;
        var W := StrToFloatDef(VarToStr(Node.Attributes['width']), 0) * Scale;
        var H := StrToFloatDef(VarToStr(Node.Attributes['height']), 0) * Scale;

        Cmd := Cmd +
          PdfNumber(R.Left + X) + ' ' + PdfNumber(PdfY(APageHeight, R.Top + Y + H)) + ' ' +
          PdfNumber(W) + ' ' + PdfNumber(H) + ' re' + #10 +
          'S' + #10;
      end
      else if SameText(Node.NodeName, 'circle') then
      begin
        var CX := StrToFloatDef(VarToStr(Node.Attributes['cx']), 0) * Scale;
        var CY := StrToFloatDef(VarToStr(Node.Attributes['cy']), 0) * Scale;
        var Rad := StrToFloatDef(VarToStr(Node.Attributes['r']), 0) * Scale;

        // Bezier approximation of a circle
        var Magic := Rad * 0.552284749831;
        var PdfCY := PdfY(APageHeight, R.Top + CY);
        var PdfCX := R.Left + CX;

        Cmd := Cmd +
          PdfNumber(PdfCX + Rad) + ' ' + PdfNumber(PdfCY) + ' m' + #10 +
          PdfNumber(PdfCX + Rad) + ' ' + PdfNumber(PdfCY + Magic) + ' ' +
          PdfNumber(PdfCX + Magic) + ' ' + PdfNumber(PdfCY + Rad) + ' ' +
          PdfNumber(PdfCX) + ' ' + PdfNumber(PdfCY + Rad) + ' c' + #10 +
          PdfNumber(PdfCX - Magic) + ' ' + PdfNumber(PdfCY + Rad) + ' ' +
          PdfNumber(PdfCX - Rad) + ' ' + PdfNumber(PdfCY + Magic) + ' ' +
          PdfNumber(PdfCX - Rad) + ' ' + PdfNumber(PdfCY) + ' c' + #10 +
          PdfNumber(PdfCX - Rad) + ' ' + PdfNumber(PdfCY - Magic) + ' ' +
          PdfNumber(PdfCX - Magic) + ' ' + PdfNumber(PdfCY - Rad) + ' ' +
          PdfNumber(PdfCX) + ' ' + PdfNumber(PdfCY - Rad) + ' c' + #10 +
          PdfNumber(PdfCX + Magic) + ' ' + PdfNumber(PdfCY - Rad) + ' ' +
          PdfNumber(PdfCX + Rad) + ' ' + PdfNumber(PdfCY - Magic) + ' ' +
          PdfNumber(PdfCX + Rad) + ' ' + PdfNumber(PdfCY) + ' c' + #10 +
          'S' + #10;
      end
      else if SameText(Node.NodeName, 'line') then
      begin
        var X1 := StrToFloatDef(VarToStr(Node.Attributes['x1']), 0) * Scale;
        var Y1 := StrToFloatDef(VarToStr(Node.Attributes['y1']), 0) * Scale;
        var X2 := StrToFloatDef(VarToStr(Node.Attributes['x2']), 0) * Scale;
        var Y2 := StrToFloatDef(VarToStr(Node.Attributes['y2']), 0) * Scale;

        Cmd := Cmd +
          PdfNumber(R.Left + X1) + ' ' + PdfNumber(PdfY(APageHeight, R.Top + Y1)) + ' m' + #10 +
          PdfNumber(R.Left + X2) + ' ' + PdfNumber(PdfY(APageHeight, R.Top + Y2)) + ' l' + #10 +
          'S' + #10;
      end;
    end;

    Cmd := Cmd + 'Q' + #10;
    APdfCommands := Cmd;
    Result := True;
  except
    Result := False;
  end;
end;

end.
