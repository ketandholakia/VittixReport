unit Vittix.Report.DesignerInteraction;

interface

uses
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

end.
