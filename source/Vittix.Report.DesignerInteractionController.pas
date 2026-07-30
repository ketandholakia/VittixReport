unit Vittix.Report.DesignerInteractionController;

interface

uses
  System.Classes,
  System.Types,
  System.Math,
  System.Generics.Collections,
  Vcl.Controls,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Undo,
  Vittix.Report.CommandDispatcher,
  Vittix.Report.DesignerInteraction,
  Vittix.Report.PageSettings;

type
  TDesignerMode = (dmSelect, dmMove, dmResize, dmBandResize, dmRubberBand, dmInsert);

  IDesignerSurface = interface
    ['{69A4C075-8134-4C51-B2C1-30D8E8B626C4}']
    procedure SetFocus;
    procedure Invalidate;
    procedure DoModified;
    procedure DoSelectionChanged;
    function GetCursor: TCursor;
    procedure SetCursor(Value: TCursor);
    function GetCommands: TCommandDispatcher;
    function GetSelected: TList<TReportObject>;
    function GetBandLayouts: TDesignerBandLayouts;
    procedure SetActiveBand(ABand: TReportBand);
    function GetActiveBand: TReportBand;
    function GetInsertClass: TReportObjectClass;
    procedure SetInsertClass(AClass: TReportObjectClass);
    function UnScale(V: Integer): Integer;
    function SnapV(V: Integer): Integer;
    function ScreenToPage(const P: TPoint): TPoint;
    procedure ClearSelection;
    procedure AddToSelection(AObj: TReportObject);
    procedure RemoveFromSelection(AObj: TReportObject);
    procedure SelectObject(AObj: TReportObject);
    function GetPrimarySelected: TReportObject;
    function GetObjectBandMap: TDictionary<TReportObject, TReportBand>;
    function GetSmartGuides: Boolean;
    procedure ComputeBandLayouts;
    function BandOwnerOf(AObj: TReportObject): TReportBand;
    procedure UpdateCursor(X, Y: Integer);
    function GetPageLeft: Integer;
    function GetPageTop: Integer;
    function GetPageWidth: Integer;
    function GetPageHeight: Integer;
    function BandSepHitTest(ScreenPt: TPoint; out HitBand: TReportBand): Boolean;
    function BandHeaderHitTest(ScreenPt: TPoint; out HitBand: TReportBand): Boolean;
    function BandHitTest(ScreenPt: TPoint; out HitBand: TReportBand): Boolean;
    function ObjectHitTest(ScreenPt: TPoint; out HitObj: TReportObject): Boolean;
    function HandleHitTest(ScreenPt: TPoint; out H: TResizeHandle): Boolean;
    function ObjScreenRect(Obj: TReportObject): TRect;
  end;

  TDesignerInteractionController = class
  private
    FSurface: IDesignerSurface;
    FMouseDown: Boolean;
    FMouseStart: TPoint;
    FMode: TDesignerMode;
    FResizeHandle: TResizeHandle;
    FDragStartBounds: TDictionary<TReportObject, TRect>;
    FBandResizeBand: TReportBand;
    FBandResizeOrigH: Integer;
    FRubberRect: TRect;
    FRubbering: Boolean;
    FActiveGuides: TArray<TSmartGuideLine>;
    function ObjScreenRectWrapper(Obj: TReportObject): TRect;
  public
    constructor Create(ASurface: IDesignerSurface);
    destructor Destroy; override;

    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MouseMove(Shift: TShiftState; X, Y: Integer);
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    property Mode: TDesignerMode read FMode write FMode;
    property ActiveGuides: TArray<TSmartGuideLine> read FActiveGuides write FActiveGuides;
    property RubberRect: TRect read FRubberRect;
    property Rubbering: Boolean read FRubbering;
  end;

implementation

uses
  Vittix.Report.SelectionHelpers;

const
  MIN_OBJ_SZ  = 8;
  MIN_BAND_H  = 10;
  MOVE_DRAG_THRESHOLD = 3;

{ TDesignerInteractionController }

function TDesignerInteractionController.ObjScreenRectWrapper(Obj: TReportObject): TRect;
begin
  Result := FSurface.ObjScreenRect(Obj);
end;

constructor TDesignerInteractionController.Create(ASurface: IDesignerSurface);
begin
  inherited Create;
  FSurface := ASurface;
  FDragStartBounds := TDictionary<TReportObject, TRect>.Create;
  FMode := dmSelect;
end;

destructor TDesignerInteractionController.Destroy;
begin
  FDragStartBounds.Free;
  inherited;
end;

procedure TDesignerInteractionController.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  HitObj  : TReportObject;
  HitBand : TReportBand;
  H       : TResizeHandle;
  NewObj  : TReportObject;
  Cmd     : TInsertObjectCommand;
  TargetBand: TReportBand;
  PP      : TPoint;
  I       : Integer;
  BL      : TDesignerBandLayout;
begin
  FSurface.SetFocus;
  FMouseDown  := True;
  FMouseStart := Point(X, Y);
  if Button = mbLeft then
  begin
    { ---- INSERT MODE ---- }
    if FMode = dmInsert then
    begin
      if Assigned(FSurface.GetInsertClass()) then
      begin
        PP := FSurface.ScreenToPage(Point(X, Y));

        { Find which band was clicked }
        TargetBand := nil;
        for I := 0 to High(FSurface.GetBandLayouts()) do
        begin
          BL := FSurface.GetBandLayouts()[I];
          if (PP.Y >= BL.Y) and (PP.Y < BL.Y + BL.Height) then
          begin
            TargetBand := BL.Band;
            Break;
          end;
        end;

        if Assigned(TargetBand) then
        begin
          NewObj := FSurface.GetInsertClass().Create;
          NewObj.Bounds := Bounds(
            FSurface.SnapV(PP.X),
            FSurface.SnapV(PP.Y - BL.Y - 14),
            80, 20);
          Cmd := TInsertObjectCommand.Create(TargetBand.Children, NewObj);
          Cmd.ActionName := 'Insert Object';
          FSurface.GetCommands().DoCommand(Cmd);
          FSurface.GetObjectBandMap().AddOrSetValue(NewObj, TargetBand);

          FSurface.ClearSelection;
          FSurface.AddToSelection(NewObj);
          FSurface.SetActiveBand(TargetBand);
          FActiveGuides := nil;
      FMode := dmSelect;
          FSurface.SetCursor( crDefault );
          FSurface.DoModified;
        end;
      end;
      Exit;
    end;

    { ---- BAND SEPARATOR ---- }
    if FSurface.BandSepHitTest(Point(X, Y), HitBand) then
    begin
      FMode := dmBandResize;
      FBandResizeBand  := HitBand;
      FBandResizeOrigH := HitBand.Height;
      Exit;
    end;

    { ---- RESIZE HANDLE ---- }
    if FSurface.HandleHitTest(Point(X, Y), H) then
    begin
      FMode := dmResize;
      FResizeHandle := H;
      { Snapshot bounds of all selected for undo }
      FDragStartBounds.Clear;
      for HitObj in FSurface.GetSelected() do
      begin
        if not HitObj.Locked then
          FDragStartBounds.Add(HitObj, HitObj.Bounds);
      end;
      Exit;
    end;

    { ---- BAND HEADER ---- }
    if FSurface.BandHeaderHitTest(Point(X, Y), HitBand) then
    begin
      FSurface.SelectObject(HitBand);
      Exit;
    end;

    { ---- OBJECT HIT TEST ---- }
    if FSurface.ObjectHitTest(Point(X, Y), HitObj) then
    begin
      if (ssCtrl in Shift) or (ssShift in Shift) then
      begin
        if FSurface.GetSelected().Contains(HitObj) then
          FSurface.RemoveFromSelection(HitObj)
        else
          FSurface.AddToSelection(HitObj);

        { Modifier-click is selection-only; do not start a move operation. }
        FSurface.SetActiveBand( FSurface.BandOwnerOf(HitObj) );
        Exit;
      end
      else
      begin
        // Single-click selection should emit one selection-changed notification.
        // Avoid FSurface.ClearSelection/FSurface.AddToSelection because each helper notifies.
        if (FSurface.GetSelected().Count <> 1) or (not FSurface.GetSelected().Contains(HitObj)) then
        begin
          FSurface.GetSelected().Clear;
          FSurface.GetSelected().Add(HitObj);
          FSurface.DoSelectionChanged;
        end;
      end;

      { Update active band }
      FSurface.SetActiveBand( FSurface.BandOwnerOf(HitObj) );

      if ssDouble in Shift then
      begin
        FMouseDown := False;
        Exit;
      end;

      { Move mode }
      FMode := dmMove;
      FDragStartBounds.Clear;
      for HitObj in FSurface.GetSelected() do
      begin
        if not HitObj.Locked then
          FDragStartBounds.Add(HitObj, HitObj.Bounds);
      end;
      Exit;
    end;

    { ---- BAND HIT TEST ---- }
    if FSurface.BandHitTest(Point(X, Y), HitBand) then
    begin
      FSurface.SelectObject(HitBand);
      Exit;
    end;

    { ---- EMPTY SPACE = deselect and optionally rubber band ---- }
    var TempBand: TReportBand := FSurface.GetActiveBand();
      if not DesignerBeginRubberBandSelection(
        FSurface.GetSelected(),
        TempBand,
        Shift,
        Point(X, Y),
        Rect(FSurface.GetPageLeft(), FSurface.GetPageTop(), FSurface.GetPageLeft() + FSurface.GetPageWidth(), FSurface.GetPageTop() + FSurface.GetPageHeight()),
        nil,
        Self) then
        Exit;
      FSurface.SetActiveBand(TempBand);

    FRubbering  := True;
    FRubberRect := Rect(X, Y, X, Y);
    FMode := dmRubberBand;
  end;
end;

procedure TDesignerInteractionController.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  DX, DY   : Integer;
  LogDX, LogDY: Integer;
  Obj      : TReportObject;
  R, StartR: TRect;
  UnionStart, UnionNew: TRect;
  NewH     : Integer;
  H        : TResizeHandle;
  I        : Integer;
  SrcR     : TRect;
  SX, SY   : Double;
begin
  if not FMouseDown then
  begin
    FSurface.UpdateCursor(X, Y);
    Exit;
  end;

  DX := X - FMouseStart.X;
  DY := Y - FMouseStart.Y;
  LogDX := FSurface.UnScale(DX);
  LogDY := FSurface.UnScale(DY);

  case FMode of
    dmMove:
    begin
      if (Abs(DX) < MOVE_DRAG_THRESHOLD) and (Abs(DY) < MOVE_DRAG_THRESHOLD) then
        Exit;

      FActiveGuides := nil;

      if FSurface.GetSelected().Count > 0 then
      begin
        Obj := FSurface.GetPrimarySelected();
        if not Assigned(Obj) then Obj := FSurface.GetSelected().Last;

        if FDragStartBounds.TryGetValue(Obj, StartR) then
        begin
          R := Bounds(
            FSurface.SnapV(StartR.Left + LogDX),
            FSurface.SnapV(StartR.Top  + LogDY),
            StartR.Width, StartR.Height);

          if FSurface.GetSmartGuides() then
          begin
            var TargetBand: TReportBand;
            var TargetBandY: Integer;
            if FSurface.GetObjectBandMap().TryGetValue(Obj, TargetBand) then
            begin
              TargetBandY := -1;
              for I := 0 to High(FSurface.GetBandLayouts()) do
                if FSurface.GetBandLayouts()[I].Band = TargetBand then
                begin
                  TargetBandY := FSurface.GetBandLayouts()[I].Y;
                  Break;
                end;

              if TargetBandY >= 0 then
                DesignerSnapToObjects(R, TargetBandY, FSurface.GetBandLayouts(), FSurface.GetSelected(), 5, FActiveGuides);
            end;
          end;

          var SnappedLogDX: Integer := R.Left - StartR.Left;
          var SnappedLogDY: Integer := R.Top - StartR.Top;

          for Obj in FSurface.GetSelected() do
          begin
            if FDragStartBounds.TryGetValue(Obj, StartR) then
            begin
              var RR: TRect := Bounds(StartR.Left + SnappedLogDX, StartR.Top + SnappedLogDY, StartR.Width, StartR.Height);
              if RR.Left < 0 then RR := Bounds(0, RR.Top, RR.Width, RR.Height);
              if RR.Top  < 0 then RR := Bounds(RR.Left, 0, RR.Width, RR.Height);
              Obj.Bounds := RR;
            end;
          end;
        end;
      end;
      FSurface.Invalidate;
    end;

    dmResize:
    begin
      if FSurface.GetSelected().Count > 1 then
      begin
        UnionStart := Rect(MaxInt, MaxInt, -MaxInt, -MaxInt);
        for Obj in FSurface.GetSelected() do
          if FDragStartBounds.TryGetValue(Obj, SrcR) then
          begin
            UnionStart.Left   := Min(UnionStart.Left, SrcR.Left);
            UnionStart.Top    := Min(UnionStart.Top, SrcR.Top);
            UnionStart.Right  := Max(UnionStart.Right, SrcR.Right);
            UnionStart.Bottom := Max(UnionStart.Bottom, SrcR.Bottom);
          end;

        UnionNew := UnionStart;
        case TResizeHandle(FResizeHandle) of
          rhLeft, rhTopLeft, rhBottomLeft:
            UnionNew.Left := FSurface.SnapV(Min(UnionStart.Left + LogDX, UnionStart.Right - MIN_OBJ_SZ));
          rhRight, rhTopRight, rhBottomRight:
            UnionNew.Right := FSurface.SnapV(Max(UnionStart.Right + LogDX, UnionStart.Left + MIN_OBJ_SZ));
        end;
        case TResizeHandle(FResizeHandle) of
          rhTop, rhTopLeft, rhTopRight:
            UnionNew.Top := FSurface.SnapV(Min(UnionStart.Top + LogDY, UnionStart.Bottom - MIN_OBJ_SZ));
          rhBottom, rhBottomLeft, rhBottomRight:
            UnionNew.Bottom := FSurface.SnapV(Max(UnionStart.Bottom + LogDY, UnionStart.Top + MIN_OBJ_SZ));
        end;

        if ssShift in Shift then
        begin
          if (FResizeHandle in [rhLeft, rhRight]) and
             ((UnionNew.Bottom - UnionNew.Top) <> (UnionStart.Bottom - UnionStart.Top)) then
          begin
            if FResizeHandle = rhLeft then
              UnionNew.Left := FSurface.SnapV(UnionNew.Right - Round((UnionStart.Right - UnionStart.Left) *
                ((UnionNew.Bottom - UnionNew.Top) / Max(1, UnionStart.Bottom - UnionStart.Top))))
            else
              UnionNew.Right := FSurface.SnapV(UnionNew.Left + Round((UnionStart.Right - UnionStart.Left) *
                ((UnionNew.Bottom - UnionNew.Top) / Max(1, UnionStart.Bottom - UnionStart.Top))));
          end
          else if (FResizeHandle in [rhTop, rhBottom]) and
                  ((UnionNew.Right - UnionNew.Left) <> (UnionStart.Right - UnionStart.Left)) then
          begin
            if FResizeHandle = rhTop then
              UnionNew.Top := FSurface.SnapV(UnionNew.Bottom - Round((UnionStart.Bottom - UnionStart.Top) *
                ((UnionNew.Right - UnionNew.Left) / Max(1, UnionStart.Right - UnionStart.Left))))
            else
              UnionNew.Bottom := FSurface.SnapV(UnionNew.Top + Round((UnionStart.Bottom - UnionStart.Top) *
                ((UnionNew.Right - UnionNew.Left) / Max(1, UnionStart.Right - UnionStart.Left))));
          end
          else
          begin
            if Abs(UnionNew.Right - UnionNew.Left) > Abs(UnionNew.Bottom - UnionNew.Top) then
            begin
              if FResizeHandle in [rhLeft, rhTopLeft, rhBottomLeft] then
                UnionNew.Left := FSurface.SnapV(UnionNew.Right - Round((UnionStart.Right - UnionStart.Left) *
                  ((UnionNew.Bottom - UnionNew.Top) / Max(1, UnionStart.Bottom - UnionStart.Top))))
              else
                UnionNew.Right := FSurface.SnapV(UnionNew.Left + Round((UnionStart.Right - UnionStart.Left) *
                  ((UnionNew.Bottom - UnionNew.Top) / Max(1, UnionStart.Bottom - UnionStart.Top))));
            end
            else
            begin
              if FResizeHandle in [rhTop, rhTopLeft, rhTopRight] then
                UnionNew.Top := FSurface.SnapV(UnionNew.Bottom - Round((UnionStart.Bottom - UnionStart.Top) *
                  ((UnionNew.Right - UnionNew.Left) / Max(1, UnionStart.Right - UnionStart.Left))))
              else
                UnionNew.Bottom := FSurface.SnapV(UnionNew.Top + Round((UnionStart.Bottom - UnionStart.Top) *
                  ((UnionNew.Right - UnionNew.Left) / Max(1, UnionStart.Right - UnionStart.Left))));
            end;
          end;
        end;

        if (UnionStart.Right <= UnionStart.Left) or (UnionStart.Bottom <= UnionStart.Top) then
          Exit;

        SX := (UnionNew.Right - UnionNew.Left) / (UnionStart.Right - UnionStart.Left);
        SY := (UnionNew.Bottom - UnionNew.Top) / (UnionStart.Bottom - UnionStart.Top);
        for Obj in FSurface.GetSelected() do
          if FDragStartBounds.TryGetValue(Obj, SrcR) then
          begin
            R.Left   := Round(UnionNew.Left + (SrcR.Left   - UnionStart.Left) * SX);
            R.Top    := Round(UnionNew.Top  + (SrcR.Top    - UnionStart.Top)  * SY);
            R.Right  := Round(UnionNew.Left + (SrcR.Right  - UnionStart.Left) * SX);
            R.Bottom := Round(UnionNew.Top  + (SrcR.Bottom - UnionStart.Top)  * SY);
            if R.Right - R.Left < MIN_OBJ_SZ then
              R.Right := R.Left + MIN_OBJ_SZ;
            if R.Bottom - R.Top < MIN_OBJ_SZ then
              R.Bottom := R.Top + MIN_OBJ_SZ;
            Obj.Bounds := R;
          end;
        FSurface.Invalidate;
      end
      else
      begin
        Obj := FSurface.GetPrimarySelected;
        if Assigned(Obj) and FDragStartBounds.TryGetValue(Obj, StartR) then
        begin
          R := StartR;
          case TResizeHandle(FResizeHandle) of
            rhLeft, rhTopLeft, rhBottomLeft:
              R.Left := FSurface.SnapV(Min(StartR.Left + LogDX, StartR.Right - MIN_OBJ_SZ));
            rhRight, rhTopRight, rhBottomRight:
              R.Right := FSurface.SnapV(Max(StartR.Right + LogDX, StartR.Left + MIN_OBJ_SZ));
          end;
          case TResizeHandle(FResizeHandle) of
            rhTop, rhTopLeft, rhTopRight:
              R.Top    := FSurface.SnapV(Min(StartR.Top + LogDY, StartR.Bottom - MIN_OBJ_SZ));
            rhBottom, rhBottomLeft, rhBottomRight:
              R.Bottom := FSurface.SnapV(Max(StartR.Bottom + LogDY, StartR.Top + MIN_OBJ_SZ));
          end;
          if ssShift in Shift then
          begin
            if Abs(R.Right - R.Left) > Abs(R.Bottom - R.Top) then
            begin
              if FResizeHandle in [rhLeft, rhTopLeft, rhBottomLeft] then
                R.Left := R.Right - Round((StartR.Right - StartR.Left) * ((R.Bottom - R.Top) / Max(1, StartR.Bottom - StartR.Top)))
              else
                R.Right := R.Left + Round((StartR.Right - StartR.Left) * ((R.Bottom - R.Top) / Max(1, StartR.Bottom - StartR.Top)));
            end
            else
            begin
              if FResizeHandle in [rhTop, rhTopLeft, rhTopRight] then
                R.Top := R.Bottom - Round((StartR.Bottom - StartR.Top) * ((R.Right - R.Left) / Max(1, StartR.Right - StartR.Left)))
              else
                R.Bottom := R.Top + Round((StartR.Bottom - StartR.Top) * ((R.Right - R.Left) / Max(1, StartR.Right - StartR.Left)));
            end;
          end;
          Obj.Bounds := R;
          FSurface.Invalidate;
        end;
      end;
    end;

    dmBandResize:
    begin
      if Assigned(FBandResizeBand) then
      begin
        NewH := Max(MIN_BAND_H, FBandResizeOrigH + LogDY);
        FBandResizeBand.Height := NewH;
        FSurface.ComputeBandLayouts;
        FSurface.Invalidate;
      end;
    end;

    dmRubberBand:
    begin
      if (Abs(DX) < MOVE_DRAG_THRESHOLD) and (Abs(DY) < MOVE_DRAG_THRESHOLD) then
        Exit;
      FRubberRect := Rect(FMouseStart.X, FMouseStart.Y, X, Y);
      FSurface.Invalidate;
    end;
  end;
end;

procedure TDesignerInteractionController.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Obj      : TReportObject;
  Cmd      : TMultiMoveCommand;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  J        : Integer;
  BandCmd  : TBandResizeCommand;
begin
  if not FMouseDown then Exit;
  FMouseDown := False;
  case FMode of
    dmMove:
    begin
      if FSurface.GetSelected().Count > 0 then
      begin
        SetLength(Objects,   FSurface.GetSelected().Count);
        SetLength(OldBounds, FSurface.GetSelected().Count);
        SetLength(NewBounds, FSurface.GetSelected().Count);
        for J := 0 to FSurface.GetSelected().Count - 1 do
        begin
          Obj         := FSurface.GetSelected()[J];
          Objects[J]  := Obj;
          NewBounds[J]:= Obj.Bounds;
          if FDragStartBounds.TryGetValue(Obj, OldBounds[J]) then ;
        end;
        Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
        if Length(Objects) <= 1 then
          Cmd.ActionName := 'Move Object'
        else
          Cmd.ActionName := 'Move Objects';
        FSurface.GetCommands().DoCommand(Cmd);
        FSurface.DoModified;
      end;
    end;

    dmResize:
    begin
      if FSurface.GetSelected().Count > 1 then
      begin
        SetLength(Objects,   FSurface.GetSelected().Count);
        SetLength(OldBounds, FSurface.GetSelected().Count);
        SetLength(NewBounds, FSurface.GetSelected().Count);
        for J := 0 to FSurface.GetSelected().Count - 1 do
        begin
          Obj         := FSurface.GetSelected()[J];
          Objects[J]  := Obj;
          if FDragStartBounds.TryGetValue(Obj, OldBounds[J]) then
            NewBounds[J] := Obj.Bounds
          else
            NewBounds[J] := Obj.Bounds;
        end;

        Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
        Cmd.ActionName := 'Resize Objects';
        FSurface.GetCommands().DoCommand(Cmd);
        FSurface.DoModified;
      end
      else
      begin
        Obj := FSurface.GetPrimarySelected;
        if Assigned(Obj) then
        begin
          var OldR: TRect;
          if FDragStartBounds.TryGetValue(Obj, OldR) then
          begin
            var ResizeCmd := TMoveObjectCommand.Create(Obj, OldR, Obj.Bounds);
            ResizeCmd.ActionName := 'Resize Object';
            FSurface.GetCommands().DoCommand(ResizeCmd);
            FSurface.DoModified;
          end;
        end;
      end;
    end;

    dmBandResize:
    begin
      if Assigned(FBandResizeBand) then
      begin
        BandCmd := TBandResizeCommand.Create(
          FBandResizeBand, FBandResizeOrigH, FBandResizeBand.Height);
        FSurface.GetCommands().DoCommand(BandCmd);
        FSurface.DoModified;
      end;
      FBandResizeBand := nil;
    end;

    dmRubberBand:
    begin
      FRubbering := False;
      if DesignerApplyRubberBandSelection(
        FSurface.GetSelected(),
        FSurface.GetBandLayouts(),
        FRubberRect,
        ObjScreenRectWrapper,
        nil,
        Self) then
        FSurface.DoSelectionChanged
      else
        FSurface.Invalidate;
    end;
  end;

  FActiveGuides := nil;
      FMode := dmSelect;
  FDragStartBounds.Clear;
  FSurface.UpdateCursor(X, Y);
end;

end.
