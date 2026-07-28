unit Vittix.Report.Export.VectorPDF.EMF;

interface

uses
  System.SysUtils, System.Classes, System.Math, Winapi.Windows,
  Vittix.Report.Core, Vittix.Report.Context, Vittix.Report.Export.Commands;

/// <summary>
/// Attempts to parse an EMF/WMF metafile and translate its fundamental vector
/// drawing records (lines, rectangles, colors) into raw PDF vector graphics operators.
/// Returns True if the metafile was successfully read and contains valid records.
/// </summary>
function TryDrawEMFToPDFCommands(
  ACommand: TReportExportImageCommand;
  APageHeight: Integer;
  out APdfCommands: AnsiString): Boolean;

implementation

uses
  System.Generics.Collections, Vcl.Graphics, Vittix.Report.Export.VectorPDF;

type
  TEMFState = record
    Commands: TStringBuilder;
    PageHeight: Integer;
    Bounds: TRect;
    MetaBounds: TRect;
    ScaleX: Double;
    ScaleY: Double;
    PenColor: TColor;
    BrushColor: TColor;
    PenWidth: Double;
    StrokeColorStr: string;
    FillColorStr: string;
    LineWStr: string;
    IsStroke: Boolean;
    IsFill: Boolean;
    CurrentX: Integer;
    CurrentY: Integer;
    GdiObjects: TDictionary<Integer, TObject>; // Handle -> Delphi wrapper
    StockPen: TPen;
    StockBrush: TBrush;
    PathActive: Boolean;
  end;
  PEMFState = ^TEMFState;

function PdfY(APageHeight: Integer; AY: Double): Double;
begin
  Result := APageHeight - AY;
end;

function PdfNumber(AValue: Double): string;
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Invariant;
  Result := FloatToStr(AValue, FS);
  if Result.EndsWith('.0') then
    Result := Result.Substring(0, Length(Result) - 2);
end;

function PdfColor(AColor: TColor): string;
var
  R, G, B: Double;
  ColorVal: Integer;
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Invariant;
  ColorVal := ColorToRGB(AColor);
  R := (ColorVal and $FF) / 255.0;
  G := ((ColorVal shr 8) and $FF) / 255.0;
  B := ((ColorVal shr 16) and $FF) / 255.0;
  Result := Format('%.3f %.3f %.3f', [R, G, B], FS);
end;

function EMFEnhEnumProc(DC: HDC; var Table: THandletable;
  var Record_: TEnhMetaRecord; Count: Integer; Data: Pointer): Integer; stdcall;
var
  State: PEMFState;
  
  function MapX(AX: Integer): Double;
  begin
    Result := State.Bounds.Left + (AX - State.MetaBounds.Left) * State.ScaleX;
  end;

  function MapY(AY: Integer): Double;
  begin
    Result := State.Bounds.Top + (AY - State.MetaBounds.Top) * State.ScaleY;
  end;

  procedure AppendCmd(const S: string);
  begin
    State.Commands.Append(S).Append(#10);
  end;
  
  procedure SyncStyles(AStroke, AFill: Boolean);
  begin
    if AStroke and (State.StrokeColorStr <> '') then
    begin
      AppendCmd(State.StrokeColorStr);
      State.StrokeColorStr := '';
    end;
    if AStroke and (State.LineWStr <> '') then
    begin
      AppendCmd(State.LineWStr);
      State.LineWStr := '';
    end;
    if AFill and (State.FillColorStr <> '') then
    begin
      AppendCmd(State.FillColorStr);
      State.FillColorStr := '';
    end;
  end;
  
var
  PRect: PEMRRectangle;
  PMoveTo: PEMRMoveToEx;
  PLineTo: PEMRLineTo;
  PPolyline: PEMRPolyline;
  PCreatePen: PEMRCreatePen;
  PCreateBrush: PEMRCreateBrushIndirect;
  PSelectObj: PEMRSelectObject;
  X, Y, W, H: Double;
  I: Integer;
  Pen: TPen;
  Brush: TBrush;
  ObjHandle: Integer;
  Pt: TPoint;
begin
  Result := 1; // 1 = continue enumerating
  State := PEMFState(Data);
  if State = nil then Exit;

  case Record_.iType of
    EMR_CREATEPEN:
    begin
      PCreatePen := @Record_;
      Pen := TPen.Create;
      Pen.Color := PCreatePen.lopn.lopnColor;
      Pen.Width := Max(1, PCreatePen.lopn.lopnWidth.X);
      Pen.Style := TPenStyle(PCreatePen.lopn.lopnStyle);
      State.GdiObjects.AddOrSetValue(PCreatePen.ihPen, Pen);
    end;
    
    EMR_CREATEBRUSHINDIRECT:
    begin
      PCreateBrush := @Record_;
      Brush := TBrush.Create;
      Brush.Color := PCreateBrush.lb.lbColor;
      if PCreateBrush.lb.lbStyle = BS_NULL then
        Brush.Style := bsClear
      else
        Brush.Style := bsSolid;
      State.GdiObjects.AddOrSetValue(PCreateBrush.ihBrush, Brush);
    end;

    EMR_SELECTOBJECT:
    begin
      PSelectObj := @Record_;
      ObjHandle := Integer(PSelectObj.ihObject);
      
      // Stock objects have top bit set
      if (ObjHandle and $80000000) <> 0 then
      begin
        ObjHandle := ObjHandle and $7FFFFFFF;
        case ObjHandle of
          WHITE_BRUSH: State.BrushColor := clWhite;
          LTGRAY_BRUSH: State.BrushColor := clLtGray;
          GRAY_BRUSH: State.BrushColor := clGray;
          DKGRAY_BRUSH: State.BrushColor := clDkGray;
          BLACK_BRUSH: State.BrushColor := clBlack;
          NULL_BRUSH: State.IsFill := False;
          
          WHITE_PEN: State.PenColor := clWhite;
          BLACK_PEN: State.PenColor := clBlack;
          NULL_PEN: State.IsStroke := False;
        end;
        
        if (ObjHandle <= HOLLOW_BRUSH) then
        begin
          State.IsFill := (ObjHandle <> NULL_BRUSH);
          if State.IsFill then
            State.FillColorStr := PdfColor(State.BrushColor) + ' rg';
        end
        else
        begin
          State.IsStroke := (ObjHandle <> NULL_PEN);
          if State.IsStroke then
            State.StrokeColorStr := PdfColor(State.PenColor) + ' RG';
        end;
      end
      else if State.GdiObjects.ContainsKey(ObjHandle) then
      begin
        if State.GdiObjects[ObjHandle] is TPen then
        begin
          Pen := TPen(State.GdiObjects[ObjHandle]);
          State.PenColor := Pen.Color;
          State.PenWidth := Pen.Width * State.ScaleX; // Rough scaling
          State.IsStroke := Pen.Style <> psClear;
          
          if State.IsStroke then
          begin
            State.StrokeColorStr := PdfColor(State.PenColor) + ' RG';
            State.LineWStr := PdfNumber(Max(0.1, State.PenWidth)) + ' w';
          end;
        end
        else if State.GdiObjects[ObjHandle] is TBrush then
        begin
          Brush := TBrush(State.GdiObjects[ObjHandle]);
          State.BrushColor := Brush.Color;
          State.IsFill := Brush.Style <> bsClear;
          
          if State.IsFill then
            State.FillColorStr := PdfColor(State.BrushColor) + ' rg';
        end;
      end;
    end;
    
    EMR_DELETEOBJECT:
    begin
      PSelectObj := @Record_; // Structure is the same (ihObject)
      ObjHandle := Integer(PSelectObj.ihObject);
      if State.GdiObjects.ContainsKey(ObjHandle) then
      begin
        State.GdiObjects[ObjHandle].Free;
        State.GdiObjects.Remove(ObjHandle);
      end;
    end;
    
    EMR_MOVETOEX:
    begin
      PMoveTo := @Record_;
      State.CurrentX := PMoveTo.ptl.X;
      State.CurrentY := PMoveTo.ptl.Y;
      State.PathActive := False;
    end;
    
    EMR_LINETO:
    begin
      if not State.IsStroke then Exit;
      PLineTo := @Record_;
      
      SyncStyles(True, False);
      if not State.PathActive then
      begin
        AppendCmd(Format('%s %s m', [
          PdfNumber(MapX(State.CurrentX)), 
          PdfNumber(PdfY(State.PageHeight, MapY(State.CurrentY)))]));
        State.PathActive := True;
      end;
      
      AppendCmd(Format('%s %s l', [
        PdfNumber(MapX(PLineTo.ptl.X)), 
        PdfNumber(PdfY(State.PageHeight, MapY(PLineTo.ptl.Y)))]));
        
      AppendCmd('S'); // Stroke
      State.PathActive := False;
      State.CurrentX := PLineTo.ptl.X;
      State.CurrentY := PLineTo.ptl.Y;
    end;
    
    EMR_POLYLINE, EMR_POLYGON:
    begin
      if (not State.IsStroke) and (not State.IsFill) then Exit;
      PPolyline := @Record_;
      if PPolyline.cptl <= 1 then Exit;
      
      SyncStyles(State.IsStroke, State.IsFill);
      
      Pt := PPolyline.aptl[0];
      AppendCmd(Format('%s %s m', [
        PdfNumber(MapX(Pt.X)), 
        PdfNumber(PdfY(State.PageHeight, MapY(Pt.Y)))]));
        
      for I := 1 to PPolyline.cptl - 1 do
      begin
        Pt := PPolyline.aptl[I];
        AppendCmd(Format('%s %s l', [
          PdfNumber(MapX(Pt.X)), 
          PdfNumber(PdfY(State.PageHeight, MapY(Pt.Y)))]));
      end;
      
      if Record_.iType = EMR_POLYGON then
        AppendCmd('h'); // Close path
        
      if State.IsStroke and State.IsFill then
        AppendCmd('B')
      else if State.IsFill then
        AppendCmd('f')
      else
        AppendCmd('S');
    end;

    EMR_RECTANGLE:
    begin
      if (not State.IsStroke) and (not State.IsFill) then Exit;
      PRect := @Record_;
      
      SyncStyles(State.IsStroke, State.IsFill);
      
      X := MapX(PRect.rclBox.Left);
      Y := PdfY(State.PageHeight, MapY(PRect.rclBox.Top));
      W := MapX(PRect.rclBox.Right) - X;
      H := PdfY(State.PageHeight, MapY(PRect.rclBox.Bottom)) - Y; // Negative height is correct in PDF context
      
      AppendCmd(Format('%s %s %s %s re', [
        PdfNumber(X), PdfNumber(Y), PdfNumber(W), PdfNumber(H)]));
        
      if State.IsStroke and State.IsFill then
        AppendCmd('B')
      else if State.IsFill then
        AppendCmd('f')
      else
        AppendCmd('S');
    end;
  end;
end;

function TryDrawEMFToPDFCommands(
  ACommand: TReportExportImageCommand;
  APageHeight: Integer;
  out APdfCommands: AnsiString): Boolean;
var
  Metafile: TMetafile;
  State: TEMFState;
  Pair: TPair<Integer, TObject>;
begin
  Result := False;
  APdfCommands := '';

  if not FileExists(ACommand.Source) then Exit;

  Metafile := TMetafile.Create;
  try
    try
      Metafile.LoadFromFile(ACommand.Source);
    except
      Exit; // Invalid metafile or raster disguised as EMF
    end;
    
    if (Metafile.Width = 0) or (Metafile.Height = 0) then Exit;

    State.Commands := TStringBuilder.Create;
    State.GdiObjects := TDictionary<Integer, TObject>.Create;
    try
      State.Commands.Append('q' + #10);
      
      State.PageHeight := APageHeight;
      State.Bounds := ACommand.Bounds;
      
      // Get logical bounds of metafile. MM_ANISOTROPIC mappings might make this
      // complex, but assuming standard metafile creation.
      State.MetaBounds := Rect(0, 0, Metafile.MMWidth, Metafile.MMHeight);
      
      if (State.MetaBounds.Width > 0) and (State.MetaBounds.Height > 0) then
      begin
        State.ScaleX := State.Bounds.Width / State.MetaBounds.Width;
        State.ScaleY := State.Bounds.Height / State.MetaBounds.Height;
      end
      else
      begin
        State.ScaleX := 1.0;
        State.ScaleY := 1.0;
      end;
      
      State.IsStroke := True;
      State.IsFill := False;
      State.PenColor := clBlack;
      State.BrushColor := clWhite;
      State.PenWidth := 1.0;
      State.StrokeColorStr := '';
      State.FillColorStr := '';
      State.LineWStr := '';
      State.PathActive := False;

      EnumEnhMetaFile(0, Metafile.Handle, @EMFEnhEnumProc, @State, State.Bounds);

      State.Commands.Append('Q' + #10);
      APdfCommands := AnsiString(State.Commands.ToString);
      Result := True;
      
    finally
      for Pair in State.GdiObjects do
        Pair.Value.Free;
      State.GdiObjects.Free;
      State.Commands.Free;
    end;
  finally
    Metafile.Free;
  end;
end;

end.
