unit Vittix.Report.DesignerControl;

(*
  Vittix.Report.DesignerControl  --  Full-featured report designer VCL control
  =============================================================================

  Features
  --------
  Band-aware page layout    Bands shown as labelled, colour-coded horizontal
                            zones stacked from the page top margin.
  Band resize               Drag the bottom separator of any band to change
                            its Height (undoable).
  Rulers                    Optional horizontal + vertical rulers (20 px).
  Page margins              Optional blue dotted guide lines.
  Grid + snap               Configurable dot-grid with snap-to-grid.
  Zoom                      Ctrl+MouseWheel or ZoomIn/ZoomOut/ZoomReset.
  Insert objects            BeginInsertObject -> click to place into the
                            active (last-clicked) band.
  Select / move / resize    Single-click, Ctrl+click multi-select, rubber-band.
                            Full 8-handle resize (all corners + edge midpoints).
  Alignment tools           AlignLeft/Right/Top/Bottom, SameWidth/Height,
                            DistributeH/V, CenterH/V.
  Z-order                   BringToFront / SendToBack (undoable).
  Keyboard shortcuts        Del=delete, Ctrl+A=select-all, Ctrl+C/V=copy/paste,
                            Ctrl+Z/Y=undo/redo, arrows=nudge, Esc=cancel insert.
  Undo/Redo                 Full history via TCommandManager.
  Events                    OnSelectionChanged, OnModified.
*)

interface

uses
  System.Classes, System.Types, System.SysUtils, System.Math,
  System.Generics.Collections, System.Generics.Defaults,
  Vcl.Controls, Vcl.Graphics, Vcl.Forms,
  Winapi.Windows, Winapi.Messages,
  Data.DB,
  Vittix.Report.Model, Vittix.Report.Objects, Vittix.Report.Bands,
  Vittix.Report.PageSettings, Vittix.Report.Context,
  Vittix.Report.Undo, Vittix.Report.Serializer;

const
  RULER_W     = 20;   // ruler strip width/height (pixels)
  PAGE_PAD    = 20;   // gap between ruler edge and page edge (pixels)
  HANDLE_SZ   = 4;    // half-size of resize handle square
  MIN_OBJ_SZ  = 8;    // minimum object dimension (logical)
  MIN_BAND_H  = 10;   // minimum band height (logical)
  BAND_LBL_W  = 68;   // width of band label strip on page left (logical)
  BAND_SEP_HT = 4;    // screen pixels - click zone for band-bottom separator

type
  TDesignerMode = (dmSelect, dmMove, dmResize, dmBandResize,
                   dmRubberBand, dmInsert);

  TResizeHandle = (
    rhNone,
    rhTopLeft, rhTop, rhTopRight,
    rhLeft,          rhRight,
    rhBottomLeft, rhBottom, rhBottomRight
  );

  TBandLayout = record
    Band  : TReportBand;
    Y     : Integer;   // top of band in page-space (logical px)
    Height: Integer;   // = Band.Height
  end;

  TVittixReportDesigner = class(TCustomControl)
  private
    { Report }
    FReport    : TReportModel;
    FOwnsReport: Boolean;
    FDataSet   : TDataSet;
    FDataSource: TDataSource;
    FReportJSON: string;   // DFM-persisted report definition

    { Appearance }
    FShowGrid   : Boolean;
    FSnapToGrid : Boolean;
    FGridSize   : Integer;
    FShowRulers : Boolean;
    FShowMargins: Boolean;
    FZoom       : Integer;

    { Layout (recomputed when report changes) }
    FBandLayouts  : TArray<TBandLayout>;
    FObjectBandMap: TDictionary<TReportObject, TReportBand>;

    { Page position on screen (top-left of paper) }
    FPageLeft: Integer;
    FPageTop : Integer;

    { Selection }
    FSelected  : TList<TReportObject>;
    FActiveBand: TReportBand;   // band context for new inserts

    { Insertion }
    FInsertClass: TReportObjectClass;

    { Mode + drag state }
    FMode           : TDesignerMode;
    FResizeHandle   : TResizeHandle;
    FHoverHandle    : TResizeHandle;

    FMouseDown      : Boolean;
    FMouseStart     : TPoint;    // screen coords at mouse-down
    FDragStartBounds: TDictionary<TReportObject, TRect>;

    FBandResizeBand : TReportBand;
    FBandResizeOrigH: Integer;

    { Rubber-band }
    FRubberRect : TRect;   // screen coords
    FRubbering  : Boolean;

    { Undo/redo }
    FCommands: TCommandManager;

    { Clipboard }
    FClipboard: TReportObject;   // owned by designer; nil when empty

    { Batch paint suppression }
    FUpdateCount: Integer;

    { Events }
    FOnSelectionChanged: TNotifyEvent;
    FOnModified        : TNotifyEvent;
    FOnDataSetChanged  : TNotifyEvent;

    { Internal helpers - coordinate transforms }
    function  Scale(V: Integer): Integer;    // logical -> screen  (apply zoom)
    function  UnScale(V: Integer): Integer;  // screen  -> logical (remove zoom)
    function  PageLeft: Integer;
    function  PageTop: Integer;
    function  PageWidth: Integer;
    function  PageHeight: Integer;

    function  ScreenToPage(const P: TPoint): TPoint;

    { Layout }
    procedure ComputeBandLayouts;
    function  BandLayoutIndex(ABand: TReportBand): Integer;
    function  BandOwnerOf(Obj: TReportObject): TReportBand;
    function  OwnerListOf(Obj: TReportObject): TObjectList<TReportObject>;
    function  IndexInOwner(Obj: TReportObject): Integer;

    { Hit testing }
    function  BandSepHitTest(ScreenPt: TPoint; out HitBand: TReportBand): Boolean;
    function  ObjectHitTest(ScreenPt: TPoint; out HitObj: TReportObject): Boolean;
    function  HandleHitTest(ScreenPt: TPoint; out H: TResizeHandle): Boolean;

    { Object screen rect }
    function  ObjScreenRect(Obj: TReportObject): TRect;

    { Snap }
    function  SnapV(V: Integer): Integer;

    { Selection helpers }
    procedure AddToSelection(Obj: TReportObject);
    procedure RemoveFromSelection(Obj: TReportObject);
    procedure DoSelectionChanged;
    procedure DoModified;

    { Property setters }
    procedure SetDataSet(const V: TDataSet);
    procedure SetDataSource(const V: TDataSource);
    function  GetReportJSON: string;
    procedure SetReportJSON(const V: string);
    procedure SetZoom(const V: Integer);
    procedure SetShowGrid(const V: Boolean);
    procedure SetShowRulers(const V: Boolean);
    procedure SetShowMargins(const V: Boolean);

    function  GetPrimarySelected: TReportObject;
    function  GetSelectedCount: Integer;
    function  GetCanUndo: Boolean;
    function  GetCanRedo: Boolean;

    { Cursor }
    procedure UpdateCursor(X, Y: Integer);
    function  CursorForHandle(H: TResizeHandle): TCursor;

    { Paint sub-routines }
    procedure DrawPageBackground;
    procedure DrawMarginGuides;
    procedure DrawGrid;
    procedure DrawBandZones;
    procedure DrawBandChildren(const BL: TBandLayout);
    procedure DrawSelectionHandles;
    procedure DrawRubberBand;
    procedure DrawRulers;
    procedure DrawInsertHint;

    { Mouse wheel }
    procedure WMMouseWheel(var Msg: TWMMouseWheel); message WM_MOUSEWHEEL;

  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure WMGetDlgCode(var Msg: TWMGetDlgCode); message WM_GETDLGCODE;

  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    { Report management }
    procedure LoadReport(AReport: TReportModel; TakeOwnership: Boolean = False;
      ClearUndoHistory: Boolean = True);
    procedure NewReport;

    { Insert }
    procedure BeginInsertObject(AClass: TReportObjectClass);

    { Selection }
    procedure SelectObject(AObj: TReportObject);
    procedure SelectAllObjects;
    procedure ClearSelection;

    { Editing }
    procedure DeleteSelected;
    procedure CopySelection;
    procedure PasteSelection;

    { Alignment (all undoable) }
    procedure AlignLeft;
    procedure AlignRight;
    procedure AlignTop;
    procedure AlignBottom;
    procedure SameWidth;
    procedure SameHeight;
    procedure CenterH;
    procedure CenterV;
    procedure DistributeH;
    procedure DistributeV;

    { Z-order }
    procedure BringToFront;
    procedure SendToBack;

    { Zoom }
    procedure ZoomIn;
    procedure ZoomOut;
    procedure ZoomReset;

    { Undo / Redo }
    procedure ExecuteUndoCommand(ACommand: TUndoableAction);
    procedure Undo;
    procedure Redo;

    { Batch update (suppress repaints) }
    procedure BeginUpdate;
    procedure EndUpdate;

    { Dataset helpers }
    function  GetFieldNames: TArray<string>;
    function  InsertFieldObject(const AFieldName: string): Boolean;
    function  InsertFieldObjectAt(const AFieldName: string; X, Y: Integer): Boolean;

    { Rebuild internal band/object layout after external report mutations }
    procedure RebuildLayout;

    property Report          : TReportModel  read FReport;
    property PrimarySelected : TReportObject read GetPrimarySelected;
    property SelectedCount   : Integer       read GetSelectedCount;
    property CanUndo         : Boolean       read GetCanUndo;
    property CanRedo         : Boolean       read GetCanRedo;

  published
    property Align;
    property Color default $00E8E8E8;
    property TabOrder;

    property DataSet    : TDataSet   read FDataSet    write SetDataSet;
    property DataSource : TDataSource read FDataSource write SetDataSource;

    { Serialised report definition — persisted to the host form's DFM file.
      The component editor reads/writes this automatically when the IDE
      designer is opened and closed. }
    property ReportJSON : string     read GetReportJSON write SetReportJSON;
    property ShowGrid   : Boolean  read FShowGrid   write SetShowGrid   default True;
    property SnapToGrid : Boolean  read FSnapToGrid write FSnapToGrid   default True;
    property GridSize   : Integer  read FGridSize   write FGridSize     default 8;
    property ShowRulers : Boolean  read FShowRulers write SetShowRulers default True;
    property ShowMargins: Boolean  read FShowMargins write SetShowMargins default True;
    property Zoom       : Integer  read FZoom       write SetZoom       default 100;

    property OnSelectionChanged: TNotifyEvent
      read FOnSelectionChanged write FOnSelectionChanged;
    property OnModified: TNotifyEvent
      read FOnModified write FOnModified;
    property OnDataSetChanged: TNotifyEvent
      read FOnDataSetChanged write FOnDataSetChanged;
    property OnDragOver;
    property OnDragDrop;
  end;

procedure Register;


implementation

const
  BAND_COLORS: array[TReportBandType] of TColor = (
    $00FFF0F0,  // btReportTitle   pale rose
    $00F0F0FF,  // btPageHeader    pale blue
    $00FFFFFF,  // btMasterData    white
    $00F0F0FF,  // btPageFooter    pale blue
    $00FFFFF0,  // btReportSummary pale yellow
    $00FFF8F0,  // btGroupHeader   pale peach
    $00F0FFF0,  // btGroupFooter   pale green
    $00E0F4FF,  // btColumnHeader  pale cyan
    $00FFFFFF,  // btDetail        white (same as MasterData)
    $00ECE8FF   // btOverlay       pale lavender
  );

  BAND_LABEL_COLORS: array[TReportBandType] of TColor = (
    $00C08080,  // btReportTitle
    $00A0B0D0,  // btPageHeader
    $00909090,  // btMasterData
    $00A0B0D0,  // btPageFooter
    $00B0B068,  // btReportSummary
    $00D0A070,  // btGroupHeader
    $0080B080,  // btGroupFooter
    $00609898,  // btColumnHeader  teal
    $00909090,  // btDetail
    $007878A0   // btOverlay       slate
  );

  BAND_LABELS: array[TReportBandType] of string = (
    'Title',         'Page Header',
    'Master Data',   'Page Footer',
    'Summary',       'Group Header',
    'Group Footer',  'Column Header',
    'Detail',        'Overlay'
  );

  BAND_ORDER: array[TReportBandType] of Integer = (
    0,   // btReportTitle
    1,   // btPageHeader
    20,  // btMasterData
    50,  // btPageFooter
    60,  // btReportSummary
    10,  // btGroupHeader
    40,  // btGroupFooter
    2,   // btColumnHeader  — sorted just below PageHeader
    20,  // btDetail        — same sort order as MasterData
    70   // btOverlay       — after everything
  );

{ -- Register ---------------------------------------------------------------- }

procedure Register;
begin
  // RegisterComponents('VittixReport', [TVittixReportDesigner]);
end;

{ -- TVittixReportDesigner --------------------------------------------------- }

constructor TVittixReportDesigner.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  TabStop      := True;
  Width        := 640;
  Height       := 480;
  Color        := $00E8E8E8;

  FReport     := TReportModel.Create;
  FOwnsReport := True;

  FSelected         := TList<TReportObject>.Create;
  FDragStartBounds  := TDictionary<TReportObject, TRect>.Create;
  FObjectBandMap    := TDictionary<TReportObject, TReportBand>.Create;
  FCommands         := TCommandManager.Create;

  FZoom        := 100;
  FShowGrid    := True;
  FSnapToGrid  := True;
  FGridSize    := 8;
  FShowRulers  := True;
  FShowMargins := True;
  FMode        := dmSelect;

  ComputeBandLayouts;
end;

destructor TVittixReportDesigner.Destroy;
begin
  FCommands.Free;
  FObjectBandMap.Free;
  FDragStartBounds.Free;
  FSelected.Free;
  FClipboard.Free;   // nil-safe
  if FOwnsReport then
    FReport.Free;
  inherited;
end;

{ -- Coordinate transforms -------------------------------------------------- }

function TVittixReportDesigner.Scale(V: Integer): Integer;
begin
  Result := MulDiv(V, FZoom, 100);
end;

function TVittixReportDesigner.UnScale(V: Integer): Integer;
begin
  if FZoom = 0 then Exit(V);
  Result := MulDiv(V, 100, FZoom);
end;

function TVittixReportDesigner.PageLeft: Integer;
begin
  if FShowRulers then
    Result := RULER_W + PAGE_PAD
  else
    Result := PAGE_PAD;
end;

function TVittixReportDesigner.PageTop: Integer;
begin
  if FShowRulers then
    Result := RULER_W + PAGE_PAD
  else
    Result := PAGE_PAD;
end;

function TVittixReportDesigner.PageWidth: Integer;
begin
  Result := Scale(FReport.PageSettings.PageWidth);
end;

function TVittixReportDesigner.PageHeight: Integer;
begin
  Result := Scale(FReport.PageSettings.PageHeight);
end;

function TVittixReportDesigner.ScreenToPage(const P: TPoint): TPoint;
begin
  Result.X := UnScale(P.X - PageLeft);
  Result.Y := UnScale(P.Y - PageTop);
end;

{ -- Layout ------------------------------------------------------------------ }

procedure TVittixReportDesigner.ComputeBandLayouts;
var
  I    : Integer;
  BL   : TBandLayout;
  CurY : Integer;
  Obj  : TReportObject;
  Layouts: TList<TBandLayout>;
begin
  FBandLayouts := nil;   // always rebuild from scratch
  FObjectBandMap.Clear;
  Layouts := TList<TBandLayout>.Create;
  try
    for I := 0 to FReport.Objects.Count - 1 do
    begin
      if not (FReport.Objects[I] is TReportBand) then Continue;
      BL.Band   := FReport.Objects[I] as TReportBand;
      BL.Y      := 0;
      BL.Height := BL.Band.Height;
      Layouts.Add(BL);
    end;

    Layouts.Sort(TComparer<TBandLayout>.Construct(
      function(const L, R: TBandLayout): Integer
      begin
        Result := BAND_ORDER[L.Band.BandType] - BAND_ORDER[R.Band.BandType];
        if Result = 0 then
          Result := L.Band.GroupLevel - R.Band.GroupLevel;
      end));

    CurY := FReport.PageSettings.Margins.Top;
    for I := 0 to Layouts.Count - 1 do
    begin
      BL   := Layouts[I];
      BL.Y := CurY;
      Inc(CurY, BL.Height);
      FBandLayouts := FBandLayouts + [BL];

      for Obj in BL.Band.Children do
        FObjectBandMap.AddOrSetValue(Obj, BL.Band);
    end;
  finally
    Layouts.Free;
  end;
end;

function TVittixReportDesigner.BandLayoutIndex(ABand: TReportBand): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to High(FBandLayouts) do
    if FBandLayouts[I].Band = ABand then
      Exit(I);
end;

function TVittixReportDesigner.BandOwnerOf(Obj: TReportObject): TReportBand;
begin
  if not FObjectBandMap.TryGetValue(Obj, Result) then
    Result := nil;
end;

function TVittixReportDesigner.OwnerListOf(Obj: TReportObject): TObjectList<TReportObject>;
var Band: TReportBand;
begin
  Band := BandOwnerOf(Obj);
  if Assigned(Band) then
    Result := Band.Children
  else
    Result := nil;
end;

function TVittixReportDesigner.IndexInOwner(Obj: TReportObject): Integer;
var
  List: TObjectList<TReportObject>;
begin
  List := OwnerListOf(Obj);
  if Assigned(List) then
    Result := List.IndexOf(Obj)
  else
    Result := -1;
end;

{ -- Object screen rect ----------------------------------------------------- }

function TVittixReportDesigner.ObjScreenRect(Obj: TReportObject): TRect;
var
  Band: TReportBand;
  Idx : Integer;
  BandY: Integer;
begin
  Band  := BandOwnerOf(Obj);
  BandY := 0;
  if Assigned(Band) then
  begin
    Idx := BandLayoutIndex(Band);
    if Idx >= 0 then
      BandY := FBandLayouts[Idx].Y;
  end;
  Result.Left   := PageLeft + Scale(Obj.Bounds.Left);
  Result.Top    := PageTop  + Scale(BandY + Obj.Bounds.Top);
  Result.Right  := PageLeft + Scale(Obj.Bounds.Right);
  Result.Bottom := PageTop  + Scale(BandY + Obj.Bounds.Bottom);
end;

{ -- Hit testing ------------------------------------------------------------ }

function TVittixReportDesigner.BandSepHitTest(ScreenPt: TPoint;
  out HitBand: TReportBand): Boolean;
var
  I  : Integer;
  SepY: Integer;
begin
  Result  := False;
  HitBand := nil;
  for I := 0 to High(FBandLayouts) do
  begin
    SepY := PageTop + Scale(FBandLayouts[I].Y + FBandLayouts[I].Height);
    if Abs(ScreenPt.Y - SepY) <= BAND_SEP_HT then
    begin
      HitBand := FBandLayouts[I].Band;
      Exit(True);
    end;
  end;
end;

function TVittixReportDesigner.ObjectHitTest(ScreenPt: TPoint;
  out HitObj: TReportObject): Boolean;
var
  I  : Integer;
  BL : TBandLayout;
  Obj: TReportObject;
  SR : TRect;
begin
  Result := False;
  HitObj := nil;
  { Iterate bands from bottom so topmost visible is hit first }
  for I := High(FBandLayouts) downto 0 do
  begin
    BL := FBandLayouts[I];
    for Obj in BL.Band.Children do
    begin
      SR := ObjScreenRect(Obj);
      if PtInRect(SR, ScreenPt) then
      begin
        HitObj := Obj;
        Exit(True);
      end;
    end;
  end;
end;

function TVittixReportDesigner.HandleHitTest(ScreenPt: TPoint;
  out H: TResizeHandle): Boolean;
const
  R: array[TResizeHandle] of TPoint = (
    (X:0; Y:0),                // rhNone - unused
    (X:0; Y:0),  (X:0; Y:0),  // rhTopLeft, rhTop
    (X:0; Y:0),  (X:0; Y:0),  // rhTopRight, rhLeft
    (X:0; Y:0),  (X:0; Y:0),  // rhRight, rhBottomLeft
    (X:0; Y:0),  (X:0; Y:0)   // rhBottom, rhBottomRight
  );
var
  Obj: TReportObject;
  SR : TRect;
  CX, CY, HW, HH: Integer;
  HH2: Integer;

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
  if FSelected.Count = 0 then Exit;

  Obj := FSelected[FSelected.Count - 1];
  SR  := ObjScreenRect(Obj);
  CX  := (SR.Left + SR.Right)  div 2;
  CY  := (SR.Top  + SR.Bottom) div 2;

  if Check(SR.Left,  SR.Top,    rhTopLeft)     then Exit(True);
  if Check(CX,       SR.Top,    rhTop)          then Exit(True);
  if Check(SR.Right, SR.Top,    rhTopRight)     then Exit(True);
  if Check(SR.Left,  CY,        rhLeft)         then Exit(True);
  if Check(SR.Right, CY,        rhRight)        then Exit(True);
  if Check(SR.Left,  SR.Bottom, rhBottomLeft)   then Exit(True);
  if Check(CX,       SR.Bottom, rhBottom)       then Exit(True);
  if Check(SR.Right, SR.Bottom, rhBottomRight)  then Exit(True);
end;

{ -- Snap ------------------------------------------------------------------- }

function TVittixReportDesigner.SnapV(V: Integer): Integer;
begin
  if FSnapToGrid and (FGridSize > 0) then
    Result := Round(V / FGridSize) * FGridSize
  else
    Result := V;
end;

{ -- Selection -------------------------------------------------------------- }

procedure TVittixReportDesigner.AddToSelection(Obj: TReportObject);
begin
  if not FSelected.Contains(Obj) then
  begin
    FSelected.Add(Obj);
    DoSelectionChanged;
  end;
end;

procedure TVittixReportDesigner.RemoveFromSelection(Obj: TReportObject);
begin
  if FSelected.Remove(Obj) >= 0 then
    DoSelectionChanged;
end;

procedure TVittixReportDesigner.ClearSelection;
begin
  if FSelected.Count > 0 then
  begin
    FSelected.Clear;
    DoSelectionChanged;
  end;
end;

procedure TVittixReportDesigner.DoSelectionChanged;
begin
  Invalidate;
  if Assigned(FOnSelectionChanged) then
    FOnSelectionChanged(Self);
end;

procedure TVittixReportDesigner.DoModified;
begin
  if FUpdateCount = 0 then
    Invalidate;
  if Assigned(FOnModified) then
    FOnModified(Self);
end;

{ -- Public interface ------------------------------------------------------- }

procedure TVittixReportDesigner.LoadReport(AReport: TReportModel;
  TakeOwnership: Boolean; ClearUndoHistory: Boolean);
begin
  if FOwnsReport then FReport.Free;
  FReport      := AReport;
  FOwnsReport  := TakeOwnership;
  FSelected.Clear;
  FActiveBand  := nil;
  if ClearUndoHistory then
    FCommands.Clear;
  FBandLayouts := nil;
  FObjectBandMap.Clear;
  ComputeBandLayouts;
  Invalidate;
  // Notify the host (designer EXE field panel) that the dataset may have changed.
  // This causes the "Dataset Fields" panel to refresh from the newly loaded report.
  if Assigned(FOnDataSetChanged) then
    FOnDataSetChanged(Self);
end;

procedure TVittixReportDesigner.NewReport;
var R: TReportModel;
begin
  R := TReportModel.Create;
  LoadReport(R, True);
end;

procedure TVittixReportDesigner.BeginInsertObject(AClass: TReportObjectClass);
begin
  FInsertClass := AClass;
  FMode        := dmInsert;
  Cursor       := crCross;
  ClearSelection;
end;

procedure TVittixReportDesigner.SelectObject(AObj: TReportObject);
var
  OwnerBand: TReportBand;
begin
  if AObj = nil then
  begin
    if (FSelected.Count > 0) or Assigned(FActiveBand) then
    begin
      FSelected.Clear;
      FActiveBand := nil;
      DoSelectionChanged;
    end;
    Exit;
  end;

  FSelected.Clear;

  if AObj is TReportBand then
  begin
    FActiveBand := TReportBand(AObj);
    DoSelectionChanged;
    Exit;
  end;

  OwnerBand := BandOwnerOf(AObj);
  FActiveBand := OwnerBand;
  FSelected.Add(AObj);
  DoSelectionChanged;
end;

procedure TVittixReportDesigner.SelectAllObjects;
var
  I: Integer;
  BL: TBandLayout;
  Obj: TReportObject;
begin
  FSelected.Clear;
  for I := 0 to High(FBandLayouts) do
  begin
    BL := FBandLayouts[I];
    for Obj in BL.Band.Children do
      FSelected.Add(Obj);
  end;
  DoSelectionChanged;
end;

procedure TVittixReportDesigner.DeleteSelected;
var
  Objs   : TArray<TReportObject>;
  Owners : TArray<TObjectList<TReportObject>>;
  Indices: TArray<Integer>;
  I      : Integer;
  Obj    : TReportObject;
  Cmd    : TDeleteObjectsCommand;
  BandCmd: TDeleteBandCommand;
  ActiveBand: TReportBand;
  BandIdx: Integer;
begin
  if FSelected.Count = 0 then
  begin
    ActiveBand := FActiveBand;
    if not Assigned(ActiveBand) then
      Exit;

    BandIdx := FReport.Objects.IndexOf(ActiveBand);
    if BandIdx < 0 then
      Exit;

    FSelected.Clear;
    FActiveBand := nil;
    BandCmd := TDeleteBandCommand.Create(FReport.Objects, ActiveBand, BandIdx);
    FCommands.DoCommand(BandCmd);
    ComputeBandLayouts;
    DoModified;
    Exit;
  end;
  SetLength(Objs,    FSelected.Count);
  SetLength(Owners,  FSelected.Count);
  SetLength(Indices, FSelected.Count);
  for I := 0 to FSelected.Count - 1 do
  begin
    Obj        := FSelected[I];
    Objs[I]    := Obj;
    Owners[I]  := OwnerListOf(Obj);
    Indices[I] := IndexInOwner(Obj);
  end;
  ClearSelection;
  Cmd := TDeleteObjectsCommand.Create(Objs, Owners, Indices);
  FCommands.DoCommand(Cmd);
  ComputeBandLayouts;
  DoModified;
end;

procedure TVittixReportDesigner.CopySelection;
begin
  if FSelected.Count = 0 then Exit;
  FreeAndNil(FClipboard);
  FClipboard := TReportSerializer.CloneObject(FSelected[FSelected.Count - 1]);
end;

procedure TVittixReportDesigner.PasteSelection;
var
  Obj : TReportObject;
  Band: TReportBand;
  Cmd : TInsertObjectCommand;
begin
  if (FClipboard = nil) or not Assigned(FActiveBand) then Exit;
  Obj  := TReportSerializer.CloneObject(FClipboard);
  if Obj = nil then Exit;
  Obj.Bounds := Bounds(Obj.Bounds.Left + 8, Obj.Bounds.Top + 8,
                       Obj.Bounds.Width, Obj.Bounds.Height);
  Band := FActiveBand;
  Cmd  := TInsertObjectCommand.Create(Band.Children, Obj);
  FCommands.DoCommand(Cmd);
  FObjectBandMap.AddOrSetValue(Obj, Band);
  ClearSelection;
  AddToSelection(Obj);
  DoModified;
end;

{ -- Alignment -------------------------------------------------------------- }

procedure TVittixReportDesigner.AlignLeft;
var
  I, MinL: Integer;
  R: TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if FSelected.Count < 2 then Exit;
  MinL := MaxInt;
  for I := 0 to FSelected.Count - 1 do
    if FSelected[I].Bounds.Left < MinL then MinL := FSelected[I].Bounds.Left;
  SetLength(Objects,   FSelected.Count);
  SetLength(OldBounds, FSelected.Count);
  SetLength(NewBounds, FSelected.Count);
  for I := 0 to FSelected.Count - 1 do
  begin
    Objects[I]   := FSelected[I];
    OldBounds[I] := FSelected[I].Bounds;
    R := FSelected[I].Bounds;
    NewBounds[I] := Bounds(MinL, R.Top, R.Width, R.Height);
    FSelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

procedure TVittixReportDesigner.AlignRight;
var
  I, MaxR: Integer;
  R: TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if FSelected.Count < 2 then Exit;
  MaxR := -MaxInt;
  for I := 0 to FSelected.Count - 1 do
    if FSelected[I].Bounds.Right > MaxR then MaxR := FSelected[I].Bounds.Right;
  SetLength(Objects,   FSelected.Count);
  SetLength(OldBounds, FSelected.Count);
  SetLength(NewBounds, FSelected.Count);
  for I := 0 to FSelected.Count - 1 do
  begin
    Objects[I]   := FSelected[I];
    OldBounds[I] := FSelected[I].Bounds;
    R := FSelected[I].Bounds;
    NewBounds[I] := Bounds(MaxR - R.Width, R.Top, R.Width, R.Height);
    FSelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

procedure TVittixReportDesigner.AlignTop;
var
  I, MinT: Integer;
  R: TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if FSelected.Count < 2 then Exit;
  MinT := MaxInt;
  for I := 0 to FSelected.Count - 1 do
    if FSelected[I].Bounds.Top < MinT then MinT := FSelected[I].Bounds.Top;
  SetLength(Objects,   FSelected.Count);
  SetLength(OldBounds, FSelected.Count);
  SetLength(NewBounds, FSelected.Count);
  for I := 0 to FSelected.Count - 1 do
  begin
    Objects[I]   := FSelected[I];
    OldBounds[I] := FSelected[I].Bounds;
    R := FSelected[I].Bounds;
    NewBounds[I] := Bounds(R.Left, MinT, R.Width, R.Height);
    FSelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

procedure TVittixReportDesigner.AlignBottom;
var
  I, MaxB: Integer;
  R: TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if FSelected.Count < 2 then Exit;
  MaxB := -MaxInt;
  for I := 0 to FSelected.Count - 1 do
    if FSelected[I].Bounds.Bottom > MaxB then MaxB := FSelected[I].Bounds.Bottom;
  SetLength(Objects,   FSelected.Count);
  SetLength(OldBounds, FSelected.Count);
  SetLength(NewBounds, FSelected.Count);
  for I := 0 to FSelected.Count - 1 do
  begin
    Objects[I]   := FSelected[I];
    OldBounds[I] := FSelected[I].Bounds;
    R := FSelected[I].Bounds;
    NewBounds[I] := Bounds(R.Left, MaxB - R.Height, R.Width, R.Height);
    FSelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

procedure TVittixReportDesigner.SameWidth;
var
  I, W: Integer;
  R   : TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if FSelected.Count < 2 then Exit;
  W := FSelected[FSelected.Count - 1].Bounds.Width;
  SetLength(Objects,   FSelected.Count - 1);
  SetLength(OldBounds, FSelected.Count - 1);
  SetLength(NewBounds, FSelected.Count - 1);
  for I := 0 to FSelected.Count - 2 do
  begin
    Objects[I]   := FSelected[I];
    OldBounds[I] := FSelected[I].Bounds;
    R := FSelected[I].Bounds;
    NewBounds[I] := Bounds(R.Left, R.Top, W, R.Height);
    FSelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

procedure TVittixReportDesigner.SameHeight;
var
  I, H: Integer;
  R   : TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if FSelected.Count < 2 then Exit;
  H := FSelected[FSelected.Count - 1].Bounds.Height;
  SetLength(Objects,   FSelected.Count - 1);
  SetLength(OldBounds, FSelected.Count - 1);
  SetLength(NewBounds, FSelected.Count - 1);
  for I := 0 to FSelected.Count - 2 do
  begin
    Objects[I]   := FSelected[I];
    OldBounds[I] := FSelected[I].Bounds;
    R := FSelected[I].Bounds;
    NewBounds[I] := Bounds(R.Left, R.Top, R.Width, H);
    FSelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

procedure TVittixReportDesigner.CenterH;
var
  I, Mid: Integer;
  R : TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if FSelected.Count = 0 then Exit;
  Mid := FReport.PageSettings.ContentWidth div 2;
  SetLength(Objects,   FSelected.Count);
  SetLength(OldBounds, FSelected.Count);
  SetLength(NewBounds, FSelected.Count);
  for I := 0 to FSelected.Count - 1 do
  begin
    Objects[I]   := FSelected[I];
    OldBounds[I] := FSelected[I].Bounds;
    R := FSelected[I].Bounds;
    NewBounds[I] := Bounds(Mid - R.Width div 2, R.Top, R.Width, R.Height);
    FSelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

procedure TVittixReportDesigner.CenterV;
var
  I   : Integer;
  Band: TReportBand;
  R   : TRect;
  Mid : Integer;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if FSelected.Count = 0 then Exit;
  SetLength(Objects,   FSelected.Count);
  SetLength(OldBounds, FSelected.Count);
  SetLength(NewBounds, FSelected.Count);
  for I := 0 to FSelected.Count - 1 do
  begin
    Objects[I]   := FSelected[I];
    OldBounds[I] := FSelected[I].Bounds;
    Band := BandOwnerOf(FSelected[I]);
    R    := FSelected[I].Bounds;
    if Assigned(Band) then
    begin
      Mid := Band.Height div 2;
      NewBounds[I] := Bounds(R.Left, Mid - R.Height div 2, R.Width, R.Height);
    end
    else
      NewBounds[I] := R;  // no band owner — leave unchanged
    FSelected[I].Bounds := NewBounds[I];
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

procedure TVittixReportDesigner.DistributeH;
var
  I, TotalW, Gap, CurX, MinL, MaxR: Integer;
  R: TRect;
  Sorted   : TArray<TReportObject>;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if FSelected.Count < 3 then Exit;

  { Sort a copy of the selection by Left position so spacing is meaningful
    regardless of the order the user clicked objects }
  SetLength(Sorted, FSelected.Count);
  for I := 0 to FSelected.Count - 1 do
    Sorted[I] := FSelected[I];
  TArray.Sort<TReportObject>(Sorted,
    TComparer<TReportObject>.Construct(
      function(const L, R2: TReportObject): Integer
      begin
        Result := L.Bounds.Left - R2.Bounds.Left;
      end));

  MinL := MaxInt; MaxR := -MaxInt; TotalW := 0;
  for I := 0 to High(Sorted) do
  begin
    R := Sorted[I].Bounds;
    if R.Left < MinL then MinL := R.Left;
    if R.Right > MaxR then MaxR := R.Right;
    Inc(TotalW, R.Width);
  end;
  Gap  := (MaxR - MinL - TotalW) div (Length(Sorted) - 1);
  CurX := MinL;

  SetLength(Objects,   Length(Sorted));
  SetLength(OldBounds, Length(Sorted));
  SetLength(NewBounds, Length(Sorted));
  for I := 0 to High(Sorted) do
  begin
    Objects[I]   := Sorted[I];
    OldBounds[I] := Sorted[I].Bounds;
    R := Sorted[I].Bounds;
    NewBounds[I] := Bounds(CurX, R.Top, R.Width, R.Height);
    Sorted[I].Bounds := NewBounds[I];
    Inc(CurX, R.Width + Gap);
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

procedure TVittixReportDesigner.DistributeV;
var
  I, TotalH, Gap, CurY, MinT, MaxB: Integer;
  R: TRect;
  Sorted   : TArray<TReportObject>;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd: TMultiMoveCommand;
begin
  if FSelected.Count < 3 then Exit;

  { Sort a copy of the selection by Top position so spacing is meaningful
    regardless of the order the user clicked objects }
  SetLength(Sorted, FSelected.Count);
  for I := 0 to FSelected.Count - 1 do
    Sorted[I] := FSelected[I];
  TArray.Sort<TReportObject>(Sorted,
    TComparer<TReportObject>.Construct(
      function(const L, R2: TReportObject): Integer
      begin
        Result := L.Bounds.Top - R2.Bounds.Top;
      end));

  MinT := MaxInt; MaxB := -MaxInt; TotalH := 0;
  for I := 0 to High(Sorted) do
  begin
    R := Sorted[I].Bounds;
    if R.Top < MinT then MinT := R.Top;
    if R.Bottom > MaxB then MaxB := R.Bottom;
    Inc(TotalH, R.Height);
  end;
  Gap  := (MaxB - MinT - TotalH) div (Length(Sorted) - 1);
  CurY := MinT;

  SetLength(Objects,   Length(Sorted));
  SetLength(OldBounds, Length(Sorted));
  SetLength(NewBounds, Length(Sorted));
  for I := 0 to High(Sorted) do
  begin
    Objects[I]   := Sorted[I];
    OldBounds[I] := Sorted[I].Bounds;
    R := Sorted[I].Bounds;
    NewBounds[I] := Bounds(R.Left, CurY, R.Width, R.Height);
    Sorted[I].Bounds := NewBounds[I];
    Inc(CurY, R.Height + Gap);
  end;
  Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

{ -- Z-order ---------------------------------------------------------------- }

procedure TVittixReportDesigner.BringToFront;
var
  Obj : TReportObject;
  List: TObjectList<TReportObject>;
  From: Integer;
  Cmd : TZOrderCommand;
begin
  if FSelected.Count = 0 then Exit;
  Obj  := FSelected[FSelected.Count - 1];
  List := OwnerListOf(Obj);
  if List = nil then Exit;
  From := List.IndexOf(Obj);
  if From < 0 then Exit;
  Cmd := TZOrderCommand.Create(List, Obj, From, List.Count - 1);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

procedure TVittixReportDesigner.SendToBack;
var
  Obj : TReportObject;
  List: TObjectList<TReportObject>;
  From: Integer;
  Cmd : TZOrderCommand;
begin
  if FSelected.Count = 0 then Exit;
  Obj  := FSelected[FSelected.Count - 1];
  List := OwnerListOf(Obj);
  if List = nil then Exit;
  From := List.IndexOf(Obj);
  if From < 0 then Exit;
  Cmd := TZOrderCommand.Create(List, Obj, From, 0);
  FCommands.DoCommand(Cmd);
  DoModified;
end;

{ -- Zoom ------------------------------------------------------------------- }

procedure TVittixReportDesigner.ZoomIn;   begin SetZoom(FZoom + 10); end;
procedure TVittixReportDesigner.ZoomOut;  begin SetZoom(FZoom - 10); end;
procedure TVittixReportDesigner.ZoomReset;begin SetZoom(100);        end;

{ -- Undo/Redo -------------------------------------------------------------- }

procedure TVittixReportDesigner.ExecuteUndoCommand(ACommand: TUndoableAction);
begin
  if not Assigned(ACommand) then
    Exit;
  FCommands.DoCommand(ACommand);
  ComputeBandLayouts;
  DoModified;
end;

procedure TVittixReportDesigner.Undo;
begin
  FCommands.UndoLast;
  ComputeBandLayouts;
  DoModified;
end;

procedure TVittixReportDesigner.Redo;
begin
  FCommands.RedoLast;
  ComputeBandLayouts;
  DoModified;
end;

{ -- Batch update ----------------------------------------------------------- }

procedure TVittixReportDesigner.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TVittixReportDesigner.EndUpdate;
begin
  if FUpdateCount > 0 then
    Dec(FUpdateCount);
  if FUpdateCount = 0 then
    Invalidate;
end;

procedure TVittixReportDesigner.RebuildLayout;
begin
  ComputeBandLayouts;
  Invalidate;
end;

{ -- Property accessors ----------------------------------------------------- }

function TVittixReportDesigner.GetPrimarySelected: TReportObject;
begin
  if FSelected.Count > 0 then
    Result := FSelected[FSelected.Count - 1]
  else if Assigned(FActiveBand) then
    Result := FActiveBand
  else
    Result := nil;
end;

function TVittixReportDesigner.GetSelectedCount: Integer;
begin
  Result := FSelected.Count;
end;

function TVittixReportDesigner.GetCanUndo: Boolean;
begin
  Result := FCommands.CanUndo;
end;

function TVittixReportDesigner.GetCanRedo: Boolean;
begin
  Result := FCommands.CanRedo;
end;

procedure TVittixReportDesigner.SetDataSet(const V: TDataSet);
begin
  FDataSet := V;
  if Assigned(FOnDataSetChanged) then
    FOnDataSetChanged(Self);
end;

procedure TVittixReportDesigner.SetDataSource(const V: TDataSource);
begin
  if FDataSource = V then Exit;

  // Stop watching the old DataSource
  if Assigned(FDataSource) then
    FDataSource.RemoveFreeNotification(Self);

  FDataSource := V;

  // Watch the new DataSource so we're notified if it's freed
  if Assigned(FDataSource) then
    FDataSource.FreeNotification(Self);

  // Sync FDataSet from the new source (nil is fine)
  if Assigned(FDataSource) then
    SetDataSet(FDataSource.DataSet)
  else
    SetDataSet(nil);
end;

procedure TVittixReportDesigner.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) then
  begin
    if AComponent = FDataSource then
    begin
      FDataSource := nil;
      SetDataSet(nil);
    end
    else if AComponent = FDataSet then
      SetDataSet(nil);
  end;
end;

function TVittixReportDesigner.GetReportJSON: string;
begin
  // Always serialise the live model so the value is current
  if Assigned(FReport) then
    Result := TReportSerializer.SaveToJSON(FReport)
  else
    Result := FReportJSON;
end;

procedure TVittixReportDesigner.SetReportJSON(const V: string);
var
  Model: TReportModel;
begin
  FReportJSON := V;
  if V = '' then
  begin
    NewReport;  // reset to blank
    Exit;
  end;
  try
    Model := TReportSerializer.LoadFromJSON(V);
    LoadReport(Model, True {take ownership});
  except
    // Silently ignore corrupt JSON at DFM load time;
    // the designer will just show a blank report.
  end;
end;

function TVittixReportDesigner.GetFieldNames: TArray<string>;
var
  I: Integer;
begin
  Result := [];
  if Assigned(FDataSet) and FDataSet.Active and (FDataSet.FieldCount > 0) then
  begin
    // Live dataset connected (design-time / host app) — read field names directly
    SetLength(Result, FDataSet.FieldCount);
    for I := 0 to FDataSet.FieldCount - 1 do
      Result[I] := FDataSet.Fields[I].FieldName;
  end
  else if Assigned(FReport) and (FReport.FieldNames.Count > 0) then
  begin
    // Standalone designer: no live DB — use field names embedded in the .vrt file
    SetLength(Result, FReport.FieldNames.Count);
    for I := 0 to FReport.FieldNames.Count - 1 do
      Result[I] := FReport.FieldNames[I];
  end;
end;

function TVittixReportDesigner.InsertFieldObject(const AFieldName: string): Boolean;
begin
  Result := InsertFieldObjectAt(AFieldName, -1, -1);
end;

function TVittixReportDesigner.InsertFieldObjectAt(const AFieldName: string; X, Y: Integer): Boolean;
var
  TargetBand: TReportBand;
  NewObj    : TReportTextObject;
  Cmd       : TInsertObjectCommand;
  NextX, NextY: Integer;
  Obj       : TReportObject;
  PP        : TPoint;
  I         : Integer;
  BL        : TBandLayout;
  BandTop   : Integer;
begin
  Result := False;
  BandTop := 0;

  { If a drop point is provided, resolve target band from point first. }
  TargetBand := nil;
  if (X >= 0) and (Y >= 0) then
  begin
    PP := ScreenToPage(Point(X, Y));
    for I := 0 to High(FBandLayouts) do
    begin
      BL := FBandLayouts[I];
      if (PP.Y >= BL.Y) and (PP.Y < BL.Y + BL.Height) then
      begin
        TargetBand := BL.Band;
        BandTop := BL.Y;
        Break;
      end;
    end;
  end;

  { Fallback to active band (double-click behavior). }
  if not Assigned(TargetBand) then
    TargetBand := FActiveBand;
  if not Assigned(TargetBand) and (Length(FBandLayouts) > 0) then
    TargetBand := FBandLayouts[0].Band;   // final fallback: first band
  if not Assigned(TargetBand) then Exit;

  if BandTop = 0 then
    for I := 0 to High(FBandLayouts) do
      if FBandLayouts[I].Band = TargetBand then
      begin
        BandTop := FBandLayouts[I].Y;
        Break;
      end;

  if (X >= 0) and (Y >= 0) then
  begin
    { Drop at mouse location inside target band. }
    NextX := SnapV(PP.X);
    NextY := SnapV(PP.Y - BandTop);
    if NextY < 0 then NextY := 0;
  end
  else
  begin
    { Legacy behavior: stack below existing children. }
    NextY := 4;
    NextX := 4;
    for Obj in TargetBand.Children do
      if Obj.Bounds.Bottom + 2 > NextY then
        NextY := Obj.Bounds.Bottom + 2;
  end;

  NewObj           := TReportFieldObject.Create;
  NewObj.Bounds    := Bounds(SnapV(NextX), SnapV(NextY), 120, 20);
  NewObj.DataField := AFieldName;
  NewObj.Text      := '[' + AFieldName + ']';

  Cmd := TInsertObjectCommand.Create(TargetBand.Children, NewObj);
  FCommands.DoCommand(Cmd);
  FObjectBandMap.AddOrSetValue(NewObj, TargetBand);

  ClearSelection;
  AddToSelection(NewObj);
  FActiveBand := TargetBand;
  DoModified;
  Result := True;
end;

procedure TVittixReportDesigner.SetZoom(const V: Integer);
begin
  FZoom := Max(25, Min(400, V));
  Invalidate;
end;

procedure TVittixReportDesigner.SetShowGrid(const V: Boolean);
begin
  FShowGrid := V;
  Invalidate;
end;

procedure TVittixReportDesigner.SetShowRulers(const V: Boolean);
begin
  FShowRulers := V;
  Invalidate;
end;

procedure TVittixReportDesigner.SetShowMargins(const V: Boolean);
begin
  FShowMargins := V;
  Invalidate;
end;


{ -- Cursor helpers --------------------------------------------------------- }

function TVittixReportDesigner.CursorForHandle(H: TResizeHandle): TCursor;
begin
  case H of
    rhTopLeft, rhBottomRight: Result := crSizeNWSE;
    rhTopRight, rhBottomLeft: Result := crSizeNESW;
    rhTop,      rhBottom:     Result := crSizeNS;
    rhLeft,     rhRight:      Result := crSizeWE;
  else
    Result := crDefault;
  end;
end;

procedure TVittixReportDesigner.UpdateCursor(X, Y: Integer);
var
  H   : TResizeHandle;
  Dummy: TReportBand;
begin
  if FMode = dmInsert then
  begin
    Cursor := crCross;
    Exit;
  end;
  if HandleHitTest(Point(X, Y), H) then
    Cursor := CursorForHandle(H)
  else if BandSepHitTest(Point(X, Y), Dummy) then
    Cursor := crSizeNS
  else
    Cursor := crDefault;
end;

{ -- Paint helpers ---------------------------------------------------------- }

procedure TVittixReportDesigner.DrawPageBackground;
var
  R: TRect;
begin
  { Shadow }
  R := Bounds(PageLeft + 4, PageTop + 4, PageWidth, PageHeight);
  Canvas.Brush.Color := $00A0A0A0;
  Canvas.Brush.Style := bsSolid;
  Canvas.FillRect(R);

  { Page }
  R := Bounds(PageLeft, PageTop, PageWidth, PageHeight);
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(R);

  { Page border }
  Canvas.Pen.Color := $00808080;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(R);
end;

procedure TVittixReportDesigner.DrawMarginGuides;
var
  PM: TReportMargins;
  PL, PT, PW, PH: Integer;
begin
  if not FShowMargins then Exit;
  PM := FReport.PageSettings.Margins;
  PL := PageLeft; PT := PageTop;
  PW := PageWidth; PH := PageHeight;

  Canvas.Pen.Style  := psDot;
  Canvas.Pen.Color  := $00FF8000;
  Canvas.Pen.Width  := 1;

  { Left margin }
  Canvas.MoveTo(PL + Scale(PM.Left), PT);
  Canvas.LineTo(PL + Scale(PM.Left), PT + PH);

  { Right margin }
  Canvas.MoveTo(PL + PW - Scale(PM.Right), PT);
  Canvas.LineTo(PL + PW - Scale(PM.Right), PT + PH);

  { Top margin }
  Canvas.MoveTo(PL, PT + Scale(PM.Top));
  Canvas.LineTo(PL + PW, PT + Scale(PM.Top));

  { Bottom margin }
  Canvas.MoveTo(PL, PT + PH - Scale(PM.Bottom));
  Canvas.LineTo(PL + PW, PT + PH - Scale(PM.Bottom));

  Canvas.Pen.Style := psSolid;
end;

procedure TVittixReportDesigner.DrawGrid;
var
  X, Y: Integer;
  PL, PT, PW, PH: Integer;
  Step: Integer;
begin
  if not FShowGrid then Exit;
  Step := Scale(FGridSize);
  if Step < 4 then Exit;   // too zoomed out to show dots

  PL := PageLeft; PT := PageTop;
  PW := PageWidth; PH := PageHeight;

  Canvas.Pen.Color := $00C8C8C8;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 1;

  Y := PT;
  while Y <= PT + PH do
  begin
    X := PL;
    while X <= PL + PW do
    begin
      Canvas.Pixels[X, Y] := $00C0C0C0;
      Inc(X, Step);
    end;
    Inc(Y, Step);
  end;
end;

procedure TVittixReportDesigner.DrawBandZones;
var
  I   : Integer;
  BL  : TBandLayout;
  BR  : TRect;
  LR  : TRect;
  LblW: Integer;
  SepY: Integer;
  LblText: string;
begin
  LblW := Scale(BAND_LBL_W);

  for I := 0 to High(FBandLayouts) do
  begin
    BL := FBandLayouts[I];

    { Band background }
    BR := Rect(
      PageLeft,
      PageTop + Scale(BL.Y),
      PageLeft + PageWidth,
      PageTop + Scale(BL.Y + BL.Height)
    );
    Canvas.Brush.Color := BAND_COLORS[BL.Band.BandType];
    Canvas.Brush.Style := bsSolid;
    Canvas.FillRect(BR);

    { Label strip }
    LR := Rect(BR.Left, BR.Top, BR.Left + LblW, BR.Bottom);
    Canvas.Brush.Color := BAND_LABEL_COLORS[BL.Band.BandType];
    Canvas.FillRect(LR);

    { Label text (rotated 90 degrees) }
    Canvas.Font.Color   := clWhite;
    Canvas.Font.Size    := 7;
    Canvas.Font.Style   := [fsBold];
    Canvas.Brush.Style  := bsClear;
    LblText := BAND_LABELS[BL.Band.BandType];
    Canvas.TextRect(LR, LblText, [tfSingleLine, tfCenter, tfVerticalCenter]);

    { Separator line at bottom }
    SepY := PageTop + Scale(BL.Y + BL.Height);
    Canvas.Pen.Color := $00909090;
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Width := 1;
    Canvas.MoveTo(BR.Left, SepY);
    Canvas.LineTo(BR.Right, SepY);

    { Active band highlight }
    if BL.Band = FActiveBand then
    begin
      Canvas.Brush.Style := bsClear;
      Canvas.Pen.Color   := $00FF8000;
      Canvas.Pen.Width   := 2;
      Canvas.Rectangle(BR);
      Canvas.Pen.Width := 1;
    end;
  end;

  Canvas.Font.Style := [];
end;

procedure TVittixReportDesigner.DrawBandChildren(const BL: TBandLayout);
var
  Obj : TReportObject;
  OR_ : TRect;
  Ctx : TExpressionContext;
  SaveDC: Integer;
begin
  if BL.Band.Children.Count = 0 then Exit;

  { Set up DC for zoomed drawing of band children }
  SaveDC := Winapi.Windows.SaveDC(Canvas.Handle);
  try
    { Scale so 1 logical unit = Zoom/100 screen pixels }
    SetMapMode(Canvas.Handle, MM_ANISOTROPIC);
    SetWindowExtEx(Canvas.Handle, 100, 100, nil);
    SetViewportExtEx(Canvas.Handle, FZoom, FZoom, nil);
    { Viewport origin = screen top-left of the band's left edge (logical 0=page left) }
    SetViewportOrgEx(Canvas.Handle,
      PageLeft,
      PageTop + Scale(BL.Y),
      nil);
    for Obj in BL.Band.Children do
    begin
      Ctx := Default(TExpressionContext);
      Ctx.DataSet := FDataSet;
      Obj.Draw(Canvas, Ctx);
    end;
  finally
    Winapi.Windows.RestoreDC(Canvas.Handle, SaveDC);
  end;

  { Draw object borders and selection rectangles in screen-space }
  for Obj in BL.Band.Children do
  begin
    OR_ := ObjScreenRect(Obj);

    { Object border }
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Style   := psSolid;
    Canvas.Pen.Width   := 1;
    if FSelected.Contains(Obj) then
    begin
      Canvas.Pen.Color := $000080FF;   // bright selection color
      Canvas.Rectangle(OR_);
    end
    else
    begin
      Canvas.Pen.Color := $00C0C0C0;
      Canvas.Rectangle(OR_);
    end;
  end;
end;

procedure TVittixReportDesigner.DrawSelectionHandles;
var
  Obj : TReportObject;
  SR  : TRect;
  CX, CY: Integer;

  procedure DrawHandle(X, Y: Integer; H: TResizeHandle);
  var HR: TRect;
  begin
    HR := Bounds(X - HANDLE_SZ, Y - HANDLE_SZ, HANDLE_SZ*2+1, HANDLE_SZ*2+1);
    Canvas.Brush.Color := clWhite;
    Canvas.Pen.Color   := $000060C0;
    Canvas.Rectangle(HR);
  end;

begin
  if FSelected.Count = 0 then Exit;
  Obj := FSelected[FSelected.Count - 1];
  SR  := ObjScreenRect(Obj);
  CX  := (SR.Left + SR.Right)  div 2;
  CY  := (SR.Top  + SR.Bottom) div 2;

  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Width   := 1;

  DrawHandle(SR.Left,   SR.Top,    rhTopLeft);
  DrawHandle(CX,        SR.Top,    rhTop);
  DrawHandle(SR.Right,  SR.Top,    rhTopRight);
  DrawHandle(SR.Left,   CY,        rhLeft);
  DrawHandle(SR.Right,  CY,        rhRight);
  DrawHandle(SR.Left,   SR.Bottom, rhBottomLeft);
  DrawHandle(CX,        SR.Bottom, rhBottom);
  DrawHandle(SR.Right,  SR.Bottom, rhBottomRight);
end;

procedure TVittixReportDesigner.DrawRubberBand;
var R: TRect;
begin
  if not FRubbering then Exit;
  R := FRubberRect;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Style   := psDot;
  Canvas.Pen.Color   := clBlack;
  Canvas.Pen.Width   := 1;
  Canvas.Rectangle(R);
  Canvas.Pen.Style   := psSolid;
end;

procedure TVittixReportDesigner.DrawRulers;
var
  I, TickY, TickX, LogPx: Integer;
  PL, PT: Integer;
begin
  if not FShowRulers then Exit;
  PL := PageLeft; PT := PageTop;

  { Ruler background }
  Canvas.Brush.Color := $00D0D0D0;
  Canvas.Brush.Style := bsSolid;
  Canvas.FillRect(Rect(0, 0, Width, RULER_W));
  Canvas.FillRect(Rect(0, 0, RULER_W, Height));

  { Corner square }
  Canvas.Brush.Color := $00B8B8B8;
  Canvas.FillRect(Rect(0, 0, RULER_W, RULER_W));

  Canvas.Pen.Color := $00909090;
  Canvas.Pen.Width := 1;

  { Horizontal ticks (every 10 logical px) }
  Canvas.Font.Size  := 6;
  Canvas.Font.Color := $00505050;
  Canvas.Font.Style := [];
  I := 0;
  while I <= FReport.PageSettings.PageWidth do
  begin
    TickX := PL + Scale(I);
    if (I mod 100) = 0 then
    begin
      Canvas.MoveTo(TickX, RULER_W - 10);
      Canvas.LineTo(TickX, RULER_W - 1);
      if I > 0 then
        Canvas.TextOut(TickX + 1, 1, IntToStr(I));
    end
    else if (I mod 50) = 0 then
    begin
      Canvas.MoveTo(TickX, RULER_W - 7);
      Canvas.LineTo(TickX, RULER_W - 1);
    end
    else if (I mod 10) = 0 then
    begin
      Canvas.MoveTo(TickX, RULER_W - 4);
      Canvas.LineTo(TickX, RULER_W - 1);
    end;
    Inc(I, 10);
  end;

  { Vertical ticks (every 10 logical px) }
  I := 0;
  while I <= FReport.PageSettings.PageHeight do
  begin
    TickY := PT + Scale(I);
    if (I mod 100) = 0 then
    begin
      Canvas.MoveTo(RULER_W - 10, TickY);
      Canvas.LineTo(RULER_W - 1,  TickY);
      if I > 0 then
        Canvas.TextOut(1, TickY + 1, IntToStr(I));
    end
    else if (I mod 50) = 0 then
    begin
      Canvas.MoveTo(RULER_W - 7, TickY);
      Canvas.LineTo(RULER_W - 1, TickY);
    end
    else if (I mod 10) = 0 then
    begin
      Canvas.MoveTo(RULER_W - 4, TickY);
      Canvas.LineTo(RULER_W - 1, TickY);
    end;
    Inc(I, 10);
  end;

  { Ruler border lines }
  Canvas.Pen.Color := $00808080;
  Canvas.MoveTo(0,       RULER_W - 1);
  Canvas.LineTo(Width,   RULER_W - 1);
  Canvas.MoveTo(RULER_W - 1, 0);
  Canvas.LineTo(RULER_W - 1, Height);
end;

procedure TVittixReportDesigner.DrawInsertHint;
var
  HintRect: TRect;
  HintText: string;
begin
  if (FMode <> dmInsert) or not Assigned(FInsertClass) then
    Exit;

  if Length(FBandLayouts) = 0 then
    HintText := 'Insert mode: add a band first, then click inside the band to place ' + FInsertClass.DisplayName
  else
    HintText := 'Insert mode: click inside a band to place ' + FInsertClass.DisplayName + '  (Esc to cancel)';

  HintRect := Rect(PageLeft + 8, PageTop + 8, PageLeft + PageWidth - 8, PageTop + 30);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clInfoBk;
  Canvas.Pen.Color   := clGray;
  Canvas.Rectangle(HintRect);

  InflateRect(HintRect, -6, -3);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color  := clInfoText;
  Canvas.Font.Style  := [fsBold];
  DrawText(Canvas.Handle, PChar(HintText), -1, HintRect,
    DT_SINGLELINE or DT_LEFT or DT_VCENTER or DT_END_ELLIPSIS);
  Canvas.Font.Style := [];
end;

{ -- Paint ------------------------------------------------------------------ }

procedure TVittixReportDesigner.Paint;
var I: Integer;
begin
  { Background }
  Canvas.Brush.Color := Color;
  Canvas.Brush.Style := bsSolid;
  Canvas.FillRect(ClientRect);

  DrawPageBackground;
  DrawGrid;
  DrawMarginGuides;
  DrawBandZones;

  { Children of each band }
  for I := 0 to High(FBandLayouts) do
    DrawBandChildren(FBandLayouts[I]);

  DrawSelectionHandles;
  DrawRubberBand;
  DrawInsertHint;
  DrawRulers;
end;

procedure TVittixReportDesigner.Resize;
begin
  inherited;
  Invalidate;
end;

{ -- Mouse ------------------------------------------------------------------ }

procedure TVittixReportDesigner.MouseDown(Button: TMouseButton;
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
  BL      : TBandLayout;
begin
  SetFocus;
  FMouseDown  := True;
  FMouseStart := Point(X, Y);

  if Button = mbLeft then
  begin
    { ---- INSERT MODE ---- }
    if FMode = dmInsert then
    begin
      if Assigned(FInsertClass) then
      begin
        PP := ScreenToPage(Point(X, Y));

        { Find which band was clicked }
        TargetBand := nil;
        for I := 0 to High(FBandLayouts) do
        begin
          BL := FBandLayouts[I];
          if (PP.Y >= BL.Y) and (PP.Y < BL.Y + BL.Height) then
          begin
            TargetBand := BL.Band;
            Break;
          end;
        end;

        if Assigned(TargetBand) then
        begin
          NewObj := FInsertClass.Create;
          NewObj.Bounds := Bounds(
            SnapV(PP.X),
            SnapV(PP.Y - BL.Y),
            80, 20);
          Cmd := TInsertObjectCommand.Create(TargetBand.Children, NewObj);
          FCommands.DoCommand(Cmd);
          FObjectBandMap.AddOrSetValue(NewObj, TargetBand);

          ClearSelection;
          AddToSelection(NewObj);
          FActiveBand := TargetBand;
          FMode       := dmSelect;
          Cursor      := crDefault;
          DoModified;
        end;
      end;
      Exit;
    end;

    { ---- BAND SEPARATOR ---- }
    if BandSepHitTest(Point(X, Y), HitBand) then
    begin
      FMode            := dmBandResize;
      FBandResizeBand  := HitBand;
      FBandResizeOrigH := HitBand.Height;
      Exit;
    end;

    { ---- RESIZE HANDLE ---- }
    if HandleHitTest(Point(X, Y), H) then
    begin
      FMode         := dmResize;
      FResizeHandle := H;
      { Snapshot bounds of all selected for undo }
      FDragStartBounds.Clear;
      for HitObj in FSelected do
        FDragStartBounds.Add(HitObj, HitObj.Bounds);
      Exit;
    end;

    { ---- OBJECT HIT TEST ---- }
    if ObjectHitTest(Point(X, Y), HitObj) then
    begin
      if ssCtrl in Shift then
      begin
        if FSelected.Contains(HitObj) then
          RemoveFromSelection(HitObj)
        else
          AddToSelection(HitObj);
      end
      else
      begin
        if not FSelected.Contains(HitObj) then
        begin
          ClearSelection;
          AddToSelection(HitObj);
        end;
      end;

      { Update active band }
      FActiveBand := BandOwnerOf(HitObj);

      { Move mode }
      FMode := dmMove;
      FDragStartBounds.Clear;
      for HitObj in FSelected do
        FDragStartBounds.Add(HitObj, HitObj.Bounds);
      Exit;
    end;

    { ---- EMPTY SPACE = rubber band or band activate ---- }
    if not (ssCtrl in Shift) then
    begin
      var HadSelection := FSelected.Count > 0;
      { Update active band }
      PP := ScreenToPage(Point(X, Y));
      for I := 0 to High(FBandLayouts) do
      begin
        BL := FBandLayouts[I];
        if (PP.Y >= BL.Y) and (PP.Y < BL.Y + BL.Height) then
        begin
          FActiveBand := BL.Band;
          Break;
        end;
      end;

      ClearSelection;
      if not HadSelection then
        DoSelectionChanged;
    end;

    FRubbering  := True;
    FRubberRect := Rect(X, Y, X, Y);
    FMode       := dmRubberBand;
  end;
end;

procedure TVittixReportDesigner.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  DX, DY   : Integer;
  LogDX, LogDY: Integer;
  Obj      : TReportObject;
  R, StartR: TRect;
  NewH     : Integer;
  H        : TResizeHandle;
begin
  if not FMouseDown then
  begin
    UpdateCursor(X, Y);
    Exit;
  end;

  DX := X - FMouseStart.X;
  DY := Y - FMouseStart.Y;
  LogDX := UnScale(DX);
  LogDY := UnScale(DY);

  case FMode of
    dmMove:
    begin
      for Obj in FSelected do
      begin
        if FDragStartBounds.TryGetValue(Obj, StartR) then
        begin
          R := Bounds(
            SnapV(StartR.Left + LogDX),
            SnapV(StartR.Top  + LogDY),
            StartR.Width, StartR.Height);
          { Clamp to content area }
          if R.Left < 0 then R := Bounds(0, R.Top, R.Width, R.Height);
          if R.Top  < 0 then R := Bounds(R.Left, 0, R.Width, R.Height);
          Obj.Bounds := R;
        end;
      end;
      Invalidate;
    end;

    dmResize:
    begin
      Obj := GetPrimarySelected;
      if Assigned(Obj) and FDragStartBounds.TryGetValue(Obj, StartR) then
      begin
        R := StartR;
        case FResizeHandle of
          rhLeft, rhTopLeft, rhBottomLeft:
            R.Left := SnapV(Min(StartR.Left + LogDX, StartR.Right - MIN_OBJ_SZ));
          rhRight, rhTopRight, rhBottomRight:
            R.Right := SnapV(Max(StartR.Right + LogDX, StartR.Left + MIN_OBJ_SZ));
        end;
        case FResizeHandle of
          rhTop, rhTopLeft, rhTopRight:
            R.Top    := SnapV(Min(StartR.Top + LogDY, StartR.Bottom - MIN_OBJ_SZ));
          rhBottom, rhBottomLeft, rhBottomRight:
            R.Bottom := SnapV(Max(StartR.Bottom + LogDY, StartR.Top + MIN_OBJ_SZ));
        end;
        Obj.Bounds := R;
        Invalidate;
      end;
    end;

    dmBandResize:
    begin
      if Assigned(FBandResizeBand) then
      begin
        NewH := Max(MIN_BAND_H, FBandResizeOrigH + LogDY);
        FBandResizeBand.Height := NewH;
        ComputeBandLayouts;
        Invalidate;
      end;
    end;

    dmRubberBand:
    begin
      FRubberRect.Right  := X;
      FRubberRect.Bottom := Y;
      Invalidate;
    end;
  end;
end;

procedure TVittixReportDesigner.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  NormRect : TRect;
  I        : Integer;
  BL       : TBandLayout;
  Obj      : TReportObject;
  OR_      : TRect;
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
      if FSelected.Count > 0 then
      begin
        SetLength(Objects,   FSelected.Count);
        SetLength(OldBounds, FSelected.Count);
        SetLength(NewBounds, FSelected.Count);
        for J := 0 to FSelected.Count - 1 do
        begin
          Obj         := FSelected[J];
          Objects[J]  := Obj;
          NewBounds[J]:= Obj.Bounds;
          if FDragStartBounds.TryGetValue(Obj, OldBounds[J]) then ;
        end;
        Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
        FCommands.DoCommand(Cmd);
        DoModified;
      end;
    end;

    dmResize:
    begin
      Obj := GetPrimarySelected;
      if Assigned(Obj) then
      begin
        var OldR: TRect;
        if FDragStartBounds.TryGetValue(Obj, OldR) then
        begin
          var ResizeCmd := TMoveObjectCommand.Create(Obj, OldR, Obj.Bounds);
          FCommands.DoCommand(ResizeCmd);
          DoModified;
        end;
      end;
    end;

    dmBandResize:
    begin
      if Assigned(FBandResizeBand) then
      begin
        BandCmd := TBandResizeCommand.Create(
          FBandResizeBand, FBandResizeOrigH, FBandResizeBand.Height);
        FCommands.DoCommand(BandCmd);
        DoModified;
      end;
      FBandResizeBand := nil;
    end;

    dmRubberBand:
    begin
      FRubbering := False;
      NormRect   := FRubberRect;
      if NormRect.Right < NormRect.Left then
      begin
        var Tmp := NormRect.Left;
        NormRect.Left  := NormRect.Right;
        NormRect.Right := Tmp;
      end;
      if NormRect.Bottom < NormRect.Top then
      begin
        var Tmp := NormRect.Top;
        NormRect.Top    := NormRect.Bottom;
        NormRect.Bottom := Tmp;
      end;

      for I := 0 to High(FBandLayouts) do
      begin
        BL := FBandLayouts[I];
        for Obj in BL.Band.Children do
        begin
          OR_ := ObjScreenRect(Obj);
          var TmpR: TRect;
          if IntersectRect(TmpR, NormRect, OR_) then
            AddToSelection(Obj);
        end;
      end;
    end;
  end;

  FMode := dmSelect;
  FDragStartBounds.Clear;
  UpdateCursor(X, Y);
end;

{ -- Keyboard --------------------------------------------------------------- }

procedure TVittixReportDesigner.WMGetDlgCode(var Msg: TWMGetDlgCode);
begin
  inherited;
  Msg.Result := Msg.Result or DLGC_WANTARROWS or DLGC_WANTCHARS;
end;

procedure TVittixReportDesigner.KeyDown(var Key: Word; Shift: TShiftState);
const
  NUDGE_NORMAL = 1;
  RESIZE_STEP  = 1;
  MIN_KEYBOARD_OBJ_SZ = 4;
var
  Step : Integer;
  I    : Integer;
  Obj  : TReportObject;
  R    : TRect;
  Objects  : TArray<TReportObject>;
  OldBounds: TArray<TRect>;
  NewBounds: TArray<TRect>;
  Cmd  : TMultiMoveCommand;

  { Snapshot current selection, apply delta, record command }
  procedure NudgeSelected(DX, DY: Integer);
  var
    I: Integer;
  begin
    if FSelected.Count = 0 then Exit;
    SetLength(Objects,   FSelected.Count);
    SetLength(OldBounds, FSelected.Count);
    SetLength(NewBounds, FSelected.Count);
    for I := 0 to FSelected.Count - 1 do
    begin
      Obj          := FSelected[I];
      Objects[I]   := Obj;
      OldBounds[I] := Obj.Bounds;
      R := Obj.Bounds;
      NewBounds[I] := Bounds(R.Left + DX, R.Top + DY, R.Width, R.Height);
      Obj.Bounds   := NewBounds[I];
    end;
    Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
    FCommands.DoCommand(Cmd);
    DoModified;
  end;

  procedure ResizeSelected(DW, DH: Integer);
  var
    I: Integer;
    NewW, NewH: Integer;
    ChangedCount: Integer;
  begin
    if FSelected.Count = 0 then Exit;

    SetLength(Objects,   FSelected.Count);
    SetLength(OldBounds, FSelected.Count);
    SetLength(NewBounds, FSelected.Count);
    ChangedCount := 0;

    for I := 0 to FSelected.Count - 1 do
    begin
      Obj := FSelected[I];
      // Keyboard resize is only for regular objects in this phase.
      if Obj is TReportBand then
        Continue;

      R := Obj.Bounds;
      NewW := Max(MIN_KEYBOARD_OBJ_SZ, R.Width + DW);
      NewH := Max(MIN_KEYBOARD_OBJ_SZ, R.Height + DH);

      if (NewW = R.Width) and (NewH = R.Height) then
        Continue;

      Objects[ChangedCount]   := Obj;
      OldBounds[ChangedCount] := R;
      NewBounds[ChangedCount] := Bounds(R.Left, R.Top, NewW, NewH);
      Obj.Bounds := NewBounds[ChangedCount];
      Inc(ChangedCount);
    end;

    if ChangedCount = 0 then
      Exit;

    SetLength(Objects, ChangedCount);
    SetLength(OldBounds, ChangedCount);
    SetLength(NewBounds, ChangedCount);
    Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
    FCommands.DoCommand(Cmd);
    DoModified;
  end;

begin
  // Arrow-key behavior:
  // Ctrl+Arrow       = fine move (1 unit)
  // Ctrl+Shift+Arrow = coarse move (GridSize)
  // Shift+Arrow      = resize (1 unit)
  Step := NUDGE_NORMAL;
  if (ssCtrl in Shift) and (ssShift in Shift) then
    Step := FGridSize;
  if (ssCtrl in Shift) and not (ssShift in Shift) then
    Step := NUDGE_NORMAL;

  case Key of
    VK_DELETE:
      if (FMode = dmSelect) and (FSelected.Count > 0) then
      begin
        DeleteSelected;
        Key := 0;
      end;

    VK_LEFT:
    begin
      if (ssShift in Shift) and not (ssCtrl in Shift) then
        ResizeSelected(-RESIZE_STEP, 0)
      else
        NudgeSelected(-Step, 0);
      Key := 0;
    end;
    VK_RIGHT:
    begin
      if (ssShift in Shift) and not (ssCtrl in Shift) then
        ResizeSelected(RESIZE_STEP, 0)
      else
        NudgeSelected(Step, 0);
      Key := 0;
    end;
    VK_UP:
    begin
      if (ssShift in Shift) and not (ssCtrl in Shift) then
        ResizeSelected(0, -RESIZE_STEP)
      else
        NudgeSelected(0, -Step);
      Key := 0;
    end;
    VK_DOWN:
    begin
      if (ssShift in Shift) and not (ssCtrl in Shift) then
        ResizeSelected(0, RESIZE_STEP)
      else
        NudgeSelected(0, Step);
      Key := 0;
    end;
    VK_ESCAPE:
    begin
      if FMode = dmInsert then
      begin
        FMode   := dmSelect;
        Cursor  := crDefault;
        FInsertClass := nil;
      end;
      Key := 0;
    end;

    Ord('A'):
      if ssCtrl in Shift then
      begin
        SelectAllObjects;
        Key := 0;
      end;

    Ord('Z'):
      if ssCtrl in Shift then
      begin
        Undo; Key := 0;
      end;

    Ord('Y'):
      if ssCtrl in Shift then
      begin
        Redo; Key := 0;
      end;

    Ord('C'):
      if ssCtrl in Shift then
      begin
        CopySelection; Key := 0;
      end;

    Ord('V'):
      if ssCtrl in Shift then
      begin
        PasteSelection; Key := 0;
      end;
  end;

  inherited;
end;

{ -- Mouse wheel (zoom) ----------------------------------------------------- }

procedure TVittixReportDesigner.WMMouseWheel(var Msg: TWMMouseWheel);
begin
  if ssCtrl in KeysToShiftState(Msg.Keys) then
  begin
    if Msg.WheelDelta > 0 then ZoomIn
    else                        ZoomOut;
    Msg.Result := 1;
  end
  else
    inherited;
end;

end.
