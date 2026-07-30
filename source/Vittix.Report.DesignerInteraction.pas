unit Vittix.Report.DesignerInteraction;

interface

uses
  System.Math,
  System.Types,
  System.Generics.Collections,
  Vcl.Graphics,
  Winapi.Windows,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.PageSettings;

type
  TResizeHandle = (
    rhNone,
    rhTopLeft, rhTop, rhTopRight,
    rhLeft, rhRight,
    rhBottomLeft, rhBottom, rhBottomRight
  );

TSmartGuideLine = record
    P1, P2: TPoint;
  end;

  TBandOwnerFunc = function(AObj: TReportObject): TReportBand of object;
  TBandLayoutIndexFunc = function(ABand: TReportBand): Integer of object;

  TDesignerBandLayout = record
    Band: TReportBand;
    Y: Integer;
    Height: Integer;
  end;

  TDesignerBandLayouts = TArray<TDesignerBandLayout>;

function DesignerScreenToPage(
  const P: TPoint;
  APageLeft, APageTop, AMarginLeft, AZoom: Integer): TPoint;

function DesignerObjScreenRect(
  AObj: TReportObject;
  ABandLayouts: TDesignerBandLayouts;
  APageLeft, APageTop, AMarginLeft, AZoom: Integer;
  const APageSettings: TReportPageSettings;
  ABandOwner: TBandOwnerFunc;
  ABandLayoutIndex: TBandLayoutIndexFunc): TRect;

function DesignerBandSepHitTest(
  const ScreenPt: TPoint;
  const ABandLayouts: TDesignerBandLayouts;
  APageTop, AZoom: Integer;
  out HitBand: TReportBand): Boolean;

function DesignerObjectHitTest(
  const ScreenPt: TPoint;
  const ABandLayouts: TDesignerBandLayouts;
  APageLeft, APageTop, AMarginLeft, AZoom: Integer;
  const APageSettings: TReportPageSettings;
  ABandOwner: TBandOwnerFunc;
  ABandLayoutIndex: TBandLayoutIndexFunc;
  out HitObj: TReportObject): Boolean;

function DesignerHandleHitTest(
  const ScreenPt: TPoint;
  const ABandLayouts: TDesignerBandLayouts;
  APageLeft, APageTop, AMarginLeft, AZoom: Integer;
  const APageSettings: TReportPageSettings;
  ABandOwner: TBandOwnerFunc;
  ABandLayoutIndex: TBandLayoutIndexFunc;
  const ASelected: TList<TReportObject>;
  out H: TResizeHandle): Boolean;

function DesignerSnapV(V, AGridStepPx: Integer; ASnapToGrid: Boolean): Integer;

procedure DesignerSnapToObjects(
  var TargetRect: TRect;
  const TargetBandY: Integer;
  const ABandLayouts: TDesignerBandLayouts;
  const ASelected: TList<TReportObject>;
  AThreshold: Integer;
  out Guides: TArray<TSmartGuideLine>);

implementation

const
  HANDLE_SZ = 3;
  BAND_SEP_HT = 4;
  BAND_HDR_H  = 14;

function DesignerScreenToPage(
  const P: TPoint;
  APageLeft, APageTop, AMarginLeft, AZoom: Integer): TPoint;
begin
  Result.X := MulDiv(P.X - APageLeft - MulDiv(AMarginLeft, AZoom, 100), 100, AZoom);
  Result.Y := MulDiv(P.Y - APageTop, 100, AZoom);
end;

function ObjScreenRectInternal(
  AObj: TReportObject;
  ABandLayouts: TDesignerBandLayouts;
  APageLeft, APageTop, AMarginLeft, AZoom: Integer;
  ABandOwner: TBandOwnerFunc;
  ABandLayoutIndex: TBandLayoutIndexFunc): TRect;
var
  Band: TReportBand;
  Idx : Integer;
  BandY: Integer;
  ContentLeft: Integer;
  PrintableW: Integer;
begin
  Band := ABandOwner(AObj);
  BandY := 0;
  if Assigned(Band) then
  begin
    Idx := ABandLayoutIndex(Band);
    if Idx >= 0 then
      BandY := ABandLayouts[Idx].Y;
  end;
  ContentLeft   := APageLeft + MulDiv(AMarginLeft, AZoom, 100);
  PrintableW    := MulDiv(AObj.Bounds.Right - AObj.Bounds.Left, AZoom, 100);
  Result.Left   := ContentLeft + MulDiv(AObj.Bounds.Left, AZoom, 100);
  Result.Top    := APageTop  + MulDiv(BandY + BAND_HDR_H + AObj.Bounds.Top, AZoom, 100);
  Result.Right  := ContentLeft + MulDiv(AObj.Bounds.Right, AZoom, 100);
  Result.Bottom := APageTop  + MulDiv(BandY + BAND_HDR_H + AObj.Bounds.Bottom, AZoom, 100);
  if Result.Right < Result.Left then
    Result.Right := Result.Left + PrintableW;
end;

function DesignerObjScreenRect(
  AObj: TReportObject;
  ABandLayouts: TDesignerBandLayouts;
  APageLeft, APageTop, AMarginLeft, AZoom: Integer;
  const APageSettings: TReportPageSettings;
  ABandOwner: TBandOwnerFunc;
  ABandLayoutIndex: TBandLayoutIndexFunc): TRect;
begin
  Result := ObjScreenRectInternal(AObj, ABandLayouts, APageLeft, APageTop, AMarginLeft, AZoom,
    ABandOwner, ABandLayoutIndex);
end;

function DesignerBandSepHitTest(
  const ScreenPt: TPoint;
  const ABandLayouts: TDesignerBandLayouts;
  APageTop, AZoom: Integer;
  out HitBand: TReportBand): Boolean;
var
  I  : Integer;
  SepY: Integer;
begin
  Result  := False;
  HitBand := nil;
  for I := 0 to High(ABandLayouts) do
  begin
    SepY := APageTop + MulDiv(ABandLayouts[I].Y + ABandLayouts[I].Height + BAND_HDR_H, AZoom, 100);
    if Abs(ScreenPt.Y - SepY) <= BAND_SEP_HT then
    begin
      HitBand := ABandLayouts[I].Band;
      Exit(True);
    end;
  end;
end;

function DesignerObjectHitTest(
  const ScreenPt: TPoint;
  const ABandLayouts: TDesignerBandLayouts;
  APageLeft, APageTop, AMarginLeft, AZoom: Integer;
  const APageSettings: TReportPageSettings;
  ABandOwner: TBandOwnerFunc;
  ABandLayoutIndex: TBandLayoutIndexFunc;
  out HitObj: TReportObject): Boolean;
var
  I  : Integer;
  BL : TDesignerBandLayout;
  Obj: TReportObject;
  SR : TRect;
begin
  Result := False;
  HitObj := nil;
  for I := High(ABandLayouts) downto 0 do
  begin
    BL := ABandLayouts[I];
    for Obj in BL.Band.Children do
    begin
      SR := ObjScreenRectInternal(Obj, ABandLayouts, APageLeft, APageTop, AMarginLeft, AZoom,
        ABandOwner, ABandLayoutIndex);
      if PtInRect(SR, ScreenPt) then
      begin
        HitObj := Obj;
        Exit(True);
      end;
    end;
  end;
end;

function DesignerHandleHitTest(
  const ScreenPt: TPoint;
  const ABandLayouts: TDesignerBandLayouts;
  APageLeft, APageTop, AMarginLeft, AZoom: Integer;
  const APageSettings: TReportPageSettings;
  ABandOwner: TBandOwnerFunc;
  ABandLayoutIndex: TBandLayoutIndexFunc;
  const ASelected: TList<TReportObject>;
  out H: TResizeHandle): Boolean;
var
  Obj: TReportObject;
  SR : TRect;
  CX, CY: Integer;

  function HandleRect(px, py: Integer): TRect;
  begin
    Result := Bounds(px - HANDLE_SZ, py - HANDLE_SZ, HANDLE_SZ*2+1, HANDLE_SZ*2+1);
  end;

  function Check(px, py: Integer; RH: TResizeHandle): Boolean;
  begin
    Result := PtInRect(HandleRect(px, py), ScreenPt);
    if Result then H := RH;
  end;

begin
  H      := rhNone;
  Result := False;
  if not Assigned(ASelected) or (ASelected.Count = 0) then Exit;

  Obj := ASelected[ASelected.Count - 1];
  if Obj.Locked then Exit;

  SR  := ObjScreenRectInternal(Obj, ABandLayouts, APageLeft, APageTop, AMarginLeft, AZoom,
    ABandOwner, ABandLayoutIndex);
  CX  := (SR.Left + SR.Right)  div 2;
  CY  := (SR.Top  + SR.Bottom) div 2;

  if Check(SR.Left,  SR.Top,    rhTopLeft)     then Exit(True);
  if Check(CX,       SR.Top,    rhTop)         then Exit(True);
  if Check(SR.Right, SR.Top,    rhTopRight)    then Exit(True);
  if Check(SR.Left,  CY,        rhLeft)        then Exit(True);
  if Check(SR.Right, CY,        rhRight)       then Exit(True);
  if Check(SR.Left,  SR.Bottom, rhBottomLeft)  then Exit(True);
  if Check(CX,       SR.Bottom, rhBottom)      then Exit(True);
  if Check(SR.Right, SR.Bottom, rhBottomRight) then Exit(True);
end;

function DesignerSnapV(V, AGridStepPx: Integer; ASnapToGrid: Boolean): Integer;
begin
  if ASnapToGrid and (AGridStepPx > 0) then
    Result := Round(V / AGridStepPx) * AGridStepPx
  else
    Result := V;
end;

procedure DesignerSnapToObjects(
  var TargetRect: TRect;
  const TargetBandY: Integer;
  const ABandLayouts: TDesignerBandLayouts;
  const ASelected: TList<TReportObject>;
  AThreshold: Integer;
  out Guides: TArray<TSmartGuideLine>);
var
  BandIdx, I, J: Integer;
  BL: TDesignerBandLayout;
  Obj: TReportObject;
  R: TRect;
  TCX, TCY, OCX, OCY: Integer;
  GList: TList<TSmartGuideLine>;
  G: TSmartGuideLine;
  MinDx, MinDy: Integer;
  SnapX, SnapY: Integer;
  MatchedX, MatchedY: Boolean;
begin
  Guides := nil;
  if Length(ABandLayouts) = 0 then Exit;

  // Find the band
  BandIdx := -1;
  for I := 0 to High(ABandLayouts) do
  begin
    if ABandLayouts[I].Y = TargetBandY then
    begin
      BandIdx := I;
      Break;
    end;
  end;
  if BandIdx < 0 then Exit;

  BL := ABandLayouts[BandIdx];
  if not Assigned(BL.Band) then Exit;

  TCX := (TargetRect.Left + TargetRect.Right) div 2;
  TCY := (TargetRect.Top + TargetRect.Bottom) div 2;

  GList := TList<TSmartGuideLine>.Create;
  try
    MinDx := AThreshold + 1;
    MinDy := AThreshold + 1;
    SnapX := 0;
    SnapY := 0;
    MatchedX := False;
    MatchedY := False;

    for I := 0 to BL.Band.Children.Count - 1 do
    begin
      Obj := BL.Band.Children[I];
      if ASelected.Contains(Obj) then Continue;

      R := Obj.Bounds;
      OCX := (R.Left + R.Right) div 2;
      OCY := (R.Top + R.Bottom) div 2;

      // Vertical guides (snap X)
      if Abs(TargetRect.Left - R.Left) < MinDx then begin MinDx := Abs(TargetRect.Left - R.Left); SnapX := R.Left - TargetRect.Left; MatchedX := True; end;
      if Abs(TargetRect.Left - R.Right) < MinDx then begin MinDx := Abs(TargetRect.Left - R.Right); SnapX := R.Right - TargetRect.Left; MatchedX := True; end;
      if Abs(TargetRect.Right - R.Left) < MinDx then begin MinDx := Abs(TargetRect.Right - R.Left); SnapX := R.Left - TargetRect.Right; MatchedX := True; end;
      if Abs(TargetRect.Right - R.Right) < MinDx then begin MinDx := Abs(TargetRect.Right - R.Right); SnapX := R.Right - TargetRect.Right; MatchedX := True; end;
      if Abs(TCX - OCX) < MinDx then begin MinDx := Abs(TCX - OCX); SnapX := OCX - TCX; MatchedX := True; end;

      // Horizontal guides (snap Y)
      if Abs(TargetRect.Top - R.Top) < MinDy then begin MinDy := Abs(TargetRect.Top - R.Top); SnapY := R.Top - TargetRect.Top; MatchedY := True; end;
      if Abs(TargetRect.Top - R.Bottom) < MinDy then begin MinDy := Abs(TargetRect.Top - R.Bottom); SnapY := R.Bottom - TargetRect.Top; MatchedY := True; end;
      if Abs(TargetRect.Bottom - R.Top) < MinDy then begin MinDy := Abs(TargetRect.Bottom - R.Top); SnapY := R.Top - TargetRect.Bottom; MatchedY := True; end;
      if Abs(TargetRect.Bottom - R.Bottom) < MinDy then begin MinDy := Abs(TargetRect.Bottom - R.Bottom); SnapY := R.Bottom - TargetRect.Bottom; MatchedY := True; end;
      if Abs(TCY - OCY) < MinDy then begin MinDy := Abs(TCY - OCY); SnapY := OCY - TCY; MatchedY := True; end;
    end;

    if MatchedX then OffsetRect(TargetRect, SnapX, 0);
    if MatchedY then OffsetRect(TargetRect, 0, SnapY);
    TCX := (TargetRect.Left + TargetRect.Right) div 2;
    TCY := (TargetRect.Top + TargetRect.Bottom) div 2;

    // Second pass to generate guides for snapped coordinates
    if MatchedX or MatchedY then
    begin
      for I := 0 to BL.Band.Children.Count - 1 do
      begin
        Obj := BL.Band.Children[I];
        if ASelected.Contains(Obj) then Continue;
        R := Obj.Bounds;
        OCX := (R.Left + R.Right) div 2;
        OCY := (R.Top + R.Bottom) div 2;

        if MatchedX then
        begin
          if (TargetRect.Left = R.Left) or (TargetRect.Left = R.Right) then begin G.P1 := Point(TargetRect.Left, Min(TargetRect.Top, R.Top)); G.P2 := Point(TargetRect.Left, Max(TargetRect.Bottom, R.Bottom)); GList.Add(G); end;
          if (TargetRect.Right = R.Left) or (TargetRect.Right = R.Right) then begin G.P1 := Point(TargetRect.Right, Min(TargetRect.Top, R.Top)); G.P2 := Point(TargetRect.Right, Max(TargetRect.Bottom, R.Bottom)); GList.Add(G); end;
          if (TCX = OCX) then begin G.P1 := Point(TCX, Min(TargetRect.Top, R.Top)); G.P2 := Point(TCX, Max(TargetRect.Bottom, R.Bottom)); GList.Add(G); end;
        end;

        if MatchedY then
        begin
          if (TargetRect.Top = R.Top) or (TargetRect.Top = R.Bottom) then begin G.P1 := Point(Min(TargetRect.Left, R.Left), TargetRect.Top); G.P2 := Point(Max(TargetRect.Right, R.Right), TargetRect.Top); GList.Add(G); end;
          if (TargetRect.Bottom = R.Top) or (TargetRect.Bottom = R.Bottom) then begin G.P1 := Point(Min(TargetRect.Left, R.Left), TargetRect.Bottom); G.P2 := Point(Max(TargetRect.Right, R.Right), TargetRect.Bottom); GList.Add(G); end;
          if (TCY = OCY) then begin G.P1 := Point(Min(TargetRect.Left, R.Left), TCY); G.P2 := Point(Max(TargetRect.Right, R.Right), TCY); GList.Add(G); end;
        end;
      end;
    end;

    Guides := GList.ToArray;
  finally
    GList.Free;
  end;
end;

end.
