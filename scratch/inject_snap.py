import re

content = open('source/Vittix.Report.DesignerInteraction.pas', 'r', encoding='utf-8').read()

decl = '''
function DesignerSnapV(V, AGridStepPx: Integer; ASnapToGrid: Boolean): Integer;

procedure DesignerSnapToObjects(
  var TargetRect: TRect;
  const TargetBandY: Integer;
  const ABandLayouts: TDesignerBandLayouts;
  const ASelected: TList<TReportObject>;
  AThreshold: Integer;
  out Guides: TArray<TSmartGuideLine>);
'''
content = content.replace('function DesignerSnapV(V, AGridStepPx: Integer; ASnapToGrid: Boolean): Integer;', decl.strip())

impl = '''
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
  BL: TDesignerBandLayout;
  Peer: TReportObject;
  PeerY: Integer;
  PeerR: TRect;
  SnapX, SnapY: Integer;
  MinDX, MinDY: Integer;
  IsSelected: Boolean;
  Guide: TSmartGuideLine;
  SelObj: TReportObject;
  GuidesList: TList<TSmartGuideLine>;
  GlobalTargetY: Integer;

  procedure CheckX(Val, PeerVal: Integer; var MinD: Integer; var SnapVal: Integer; P1Y, P2Y: Integer);
  var D: Integer;
  begin
    D := Abs(Val - PeerVal);
    if D < MinD then
    begin
      MinD := D;
      SnapVal := PeerVal - (Val - TargetRect.Left);
      // Clear X guides since we found a better match
      if GuidesList.Count > 0 then
      begin
        // Retain only Y guides
        for var i := GuidesList.Count - 1 downto 0 do
          if GuidesList[i].P1.X = GuidesList[i].P2.X then
            GuidesList.Delete(i);
      end;
      Guide.P1 := Point(PeerVal, P1Y);
      Guide.P2 := Point(PeerVal, P2Y);
      GuidesList.Add(Guide);
    end else if (D = MinD) and (D < AThreshold) then
    begin
      Guide.P1 := Point(PeerVal, P1Y);
      Guide.P2 := Point(PeerVal, P2Y);
      GuidesList.Add(Guide);
    end;
  end;

  procedure CheckY(Val, PeerVal: Integer; var MinD: Integer; var SnapVal: Integer; P1X, P2X: Integer);
  var D: Integer;
  begin
    D := Abs(Val - PeerVal);
    if D < MinD then
    begin
      MinD := D;
      SnapVal := PeerVal - (Val - GlobalTargetY);
      // Clear Y guides since we found a better match
      if GuidesList.Count > 0 then
      begin
        for var i := GuidesList.Count - 1 downto 0 do
          if GuidesList[i].P1.Y = GuidesList[i].P2.Y then
            GuidesList.Delete(i);
      end;
      Guide.P1 := Point(P1X, PeerVal);
      Guide.P2 := Point(P2X, PeerVal);
      GuidesList.Add(Guide);
    end else if (D = MinD) and (D < AThreshold) then
    begin
      Guide.P1 := Point(P1X, PeerVal);
      Guide.P2 := Point(P2X, PeerVal);
      GuidesList.Add(Guide);
    end;
  end;

begin
  Guides := nil;
  SnapX := TargetRect.Left;
  SnapY := TargetRect.Top;
  GlobalTargetY := TargetBandY + TargetRect.Top;
  
  MinDX := AThreshold;
  MinDY := AThreshold;
  GuidesList := TList<TSmartGuideLine>.Create;
  try
    for BL in ABandLayouts do
    begin
      for Peer in BL.Band.Children do
      begin
        IsSelected := False;
        if Assigned(ASelected) then
          for SelObj in ASelected do
            if SelObj = Peer then
            begin
              IsSelected := True;
              Break;
            end;
            
        if IsSelected then Continue;

        PeerY := BL.Y + Peer.Bounds.Top;
        PeerR := Bounds(Peer.Bounds.Left, PeerY, Peer.Width, Peer.Height);
        
        // X Checks
        CheckX(TargetRect.Left, PeerR.Left, MinDX, SnapX, Min(GlobalTargetY, PeerR.Top), Max(GlobalTargetY + TargetRect.Height, PeerR.Bottom));
        CheckX(TargetRect.Right, PeerR.Right, MinDX, SnapX, Min(GlobalTargetY, PeerR.Top), Max(GlobalTargetY + TargetRect.Height, PeerR.Bottom));
        CheckX(TargetRect.Left, PeerR.Right, MinDX, SnapX, Min(GlobalTargetY, PeerR.Top), Max(GlobalTargetY + TargetRect.Height, PeerR.Bottom));
        CheckX(TargetRect.Right, PeerR.Left, MinDX, SnapX, Min(GlobalTargetY, PeerR.Top), Max(GlobalTargetY + TargetRect.Height, PeerR.Bottom));
        
        // Y Checks
        CheckY(GlobalTargetY, PeerR.Top, MinDY, SnapY, Min(TargetRect.Left, PeerR.Left), Max(TargetRect.Right, PeerR.Right));
        CheckY(GlobalTargetY + TargetRect.Height, PeerR.Bottom, MinDY, SnapY, Min(TargetRect.Left, PeerR.Left), Max(TargetRect.Right, PeerR.Right));
        CheckY(GlobalTargetY, PeerR.Bottom, MinDY, SnapY, Min(TargetRect.Left, PeerR.Left), Max(TargetRect.Right, PeerR.Right));
        CheckY(GlobalTargetY + TargetRect.Height, PeerR.Top, MinDY, SnapY, Min(TargetRect.Left, PeerR.Left), Max(TargetRect.Right, PeerR.Right));
      end;
    end;
    
    if MinDX < AThreshold then
      TargetRect.SetLocation(SnapX, TargetRect.Top);
    if MinDY < AThreshold then
      TargetRect.SetLocation(TargetRect.Left, SnapY - TargetBandY); // Convert back to local Y
      
    Guides := GuidesList.ToArray;
  finally
    GuidesList.Free;
  end;
end;
'''

import sys
if 'System.Math' not in content:
    content = content.replace('uses\n', 'uses\n  System.Math,\n')

old_impl = '''
function DesignerSnapV(V, AGridStepPx: Integer; ASnapToGrid: Boolean): Integer;
begin
  if ASnapToGrid and (AGridStepPx > 0) then
    Result := Round(V / AGridStepPx) * AGridStepPx
  else
    Result := V;
end;
'''
content = content.replace(old_impl.strip(), impl.strip())
open('source/Vittix.Report.DesignerInteraction.pas', 'w', encoding='utf-8').write(content)
