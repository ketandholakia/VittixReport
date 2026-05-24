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
  Vittix.Report.Undo, Vittix.Report.Serializer,
  Vittix.Report.CommandDispatcher,
  Vittix.Report.DesignerInteraction,
  Vittix.Report.LayoutHelpers,
  Vittix.Report.SelectionHelpers,
  Vittix.Report.DesignerInteractionController;

const
  RULER_W     = 20;   // ruler strip width/height (pixels)
  HANDLE_SZ   = 4;    // half-size of resize handle square
  MIN_OBJ_SZ  = 8;    // minimum object dimension (logical)
  MIN_BAND_H  = 10;   // minimum band height (logical)
  BAND_LBL_W  = 68;   // width of band label strip on page left (logical)
  BAND_HDR_H  = 14;   // band header height (logical)
  BAND_SEP_HT = 4;    // screen pixels - click zone for band-bottom separator
  MOVE_DRAG_THRESHOLD = 3; // screen pixels before a click becomes a drag

type
  TDesignerMode = (dmSelect, dmMove, dmResize, dmBandResize,
                   dmRubberBand, dmInsert);

  TDesignerGridUnit = (guCentimeters, guInches, guPixels, guPoints);

  TResizeHandle = Vittix.Report.DesignerInteraction.TResizeHandle;

  TBandLayout = TDesignerBandLayout;

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
    FGridUnit   : TDesignerGridUnit;
    FShowRulers : Boolean;
    FShowMargins: Boolean;
    FPageColor   : TColor;
    FCanvasColor : TColor;
    FBandGap     : Integer;
    FZoom       : Integer;

    { Layout (recomputed when report changes) }
    FBandLayouts  : TDesignerBandLayouts;
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
    FInteractionState: TDesignerInteractionState;

    { Undo/redo }
    FCommands: TCommandDispatcher;

    { Clipboard }
    FClipboard: TReportObject;   // owned by designer; nil when empty

    { Batch paint suppression }
    FUpdateCount: Integer;

    { Events }
    FOnSelectionChanged: TNotifyEvent;
    FOnModified        : TNotifyEvent;
    FOnDataSetChanged  : TNotifyEvent;
    FOnViewChanged     : TNotifyEvent;

    { Internal helpers - coordinate transforms }
    function  Scale(V: Integer): Integer;    // logical -> screen  (apply zoom)
    function  UnScale(V: Integer): Integer;  // screen  -> logical (remove zoom)
    function  PageLeft: Integer;
    function  PageTop: Integer;
    function  PageWidth: Integer;
    function  PageHeight: Integer;
    procedure UpdateSurfaceExtent;

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
    procedure DoViewChanged;

    { Property setters }
    procedure PrepareDisplayDataSet;
    procedure SetDataSet(const V: TDataSet);
    procedure SetDataSource(const V: TDataSource);
    function  GetReportJSON: string;
    procedure SetReportJSON(const V: string);
    procedure SetZoom(const V: Integer);
    procedure SetShowGrid(const V: Boolean);
    procedure SetShowRulers(const V: Boolean);
    procedure SetShowMargins(const V: Boolean);
    procedure SetPageColor(const V: TColor);
    procedure SetCanvasColor(const V: TColor);
    procedure SetBandGap(const V: Integer);
    function  GridStepPx: Integer;

    function  GetPrimarySelected: TReportObject;
    function  GetSelectedCount: Integer;
    function  GetCanUndo: Boolean;
    function  GetCanRedo: Boolean;
    function  GetNextUndoName: string;
    function  GetNextRedoName: string;

    { Cursor }
    procedure UpdateCursor(X, Y: Integer);
    function  CursorForHandle(H: TResizeHandle): TCursor;

    { Paint sub-routines }
    procedure DrawPageBackground;
    procedure DrawMarginGuides;
    procedure DrawGrid;
    procedure DrawBandZones;
    procedure DrawBandChildren(const BL: TBandLayout);
    procedure DrawBandHeaders;
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
    function AddBand(ABandType: TReportBandType): TReportBand;

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
    function  GetCommands: TCommandDispatcher;
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
    property NextUndoName    : string        read GetNextUndoName;
    property NextRedoName    : string        read GetNextRedoName;
    property Commands        : TCommandDispatcher read GetCommands;

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
    property GridUnit   : TDesignerGridUnit read FGridUnit write FGridUnit default guPixels;
    property ShowRulers : Boolean  read FShowRulers write SetShowRulers default True;
    property ShowMargins: Boolean  read FShowMargins write SetShowMargins default True;
    property PageColor  : TColor   read FPageColor   write SetPageColor   default clWhite;
    property CanvasColor: TColor   read FCanvasColor write SetCanvasColor default $00808080;
    property BandGap    : Integer  read FBandGap     write SetBandGap     default 4;
    property Zoom       : Integer  read FZoom       write SetZoom       default 100;

    property OnSelectionChanged: TNotifyEvent
      read FOnSelectionChanged write FOnSelectionChanged;
    property OnModified: TNotifyEvent
      read FOnModified write FOnModified;
    property OnDataSetChanged: TNotifyEvent
      read FOnDataSetChanged write FOnDataSetChanged;
    property OnViewChanged: TNotifyEvent
      read FOnViewChanged write FOnViewChanged;
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
  DoubleBuffered := True;
  TabStop      := True;
  Width        := 640;
  Height       := 480;
  Color        := $00E8E8E8;

  FReport     := TReportModel.Create;
  FOwnsReport := True;

  FSelected         := TList<TReportObject>.Create;
  FObjectBandMap    := TDictionary<TReportObject, TReportBand>.Create;
  FCommands         := TCommandDispatcher.Create;
  FInteractionState.DragStartBounds := TDictionary<TReportObject, TRect>.Create;

  FZoom        := 100;
  FShowGrid    := True;
  FSnapToGrid  := True;
  FGridSize    := 8;
  FGridUnit    := guPixels;
  FShowRulers  := True;
  FShowMargins := True;
  FPageColor   := clWhite;
  FCanvasColor := $00808080;
  FBandGap     := 4;
  ComputeBandLayouts;
end;

destructor TVittixReportDesigner.Destroy;
begin
  FCommands.Free;
  FObjectBandMap.Free;
  FInteractionState.DragStartBounds.Free;
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
    Result := RULER_W
  else
    Result := 0;
end;

function TVittixReportDesigner.PageTop: Integer;
begin
  if FShowRulers then
    Result := RULER_W
  else
    Result := 0;
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
  Result := DesignerScreenToPage(P, PageLeft, PageTop, FReport.PageSettings.Margins.Left, FZoom);
end;

function TVittixReportDesigner.GridStepPx: Integer;
begin
  case FGridUnit of
    guCentimeters: Result := Round(FGridSize * 96 / 2.54);
    guInches:      Result := Round(FGridSize * 96);
    guPixels:      Result := FGridSize;
    guPoints:      Result := Round(FGridSize * 96 / 72);
  else
    Result := FGridSize;
  end;
  if Result < 1 then
    Result := 1;
end;

{ -- Layout ------------------------------------------------------------------ }

procedure TVittixReportDesigner.ComputeBandLayouts;
begin
  FBandLayouts := BuildBandLayouts(
    FReport,
    nil,
    function(const L, R: TDesignerBandLayout): Integer
    begin
      Result := BAND_ORDER[L.Band.BandType] - BAND_ORDER[R.Band.BandType];
      if Result = 0 then
        Result := L.Band.GroupLevel - R.Band.GroupLevel;
    end,
    FReport.PageSettings.Margins.Top,
    FBandGap,
    FObjectBandMap);
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
begin
  Result := DesignerObjScreenRect(
    Obj, FBandLayouts, PageLeft, PageTop, FReport.PageSettings.Margins.Left, FZoom,
    FReport.PageSettings, BandOwnerOf, BandLayoutIndex);
end;

{ -- Hit testing ------------------------------------------------------------ }

function TVittixReportDesigner.BandSepHitTest(ScreenPt: TPoint;
  out HitBand: TReportBand): Boolean;
begin
  Result := DesignerBandSepHitTest(ScreenPt, FBandLayouts, PageTop, FZoom, HitBand);
end;

function TVittixReportDesigner.ObjectHitTest(ScreenPt: TPoint;
  out HitObj: TReportObject): Boolean;
begin
  Result := DesignerObjectHitTest(
    ScreenPt, FBandLayouts, PageLeft, PageTop, FReport.PageSettings.Margins.Left, FZoom,
    FReport.PageSettings, BandOwnerOf, BandLayoutIndex, HitObj);
end;

function TVittixReportDesigner.HandleHitTest(ScreenPt: TPoint;
  out H: TResizeHandle): Boolean;
begin
  Result := DesignerHandleHitTest(
    ScreenPt, FBandLayouts, PageLeft, PageTop, FReport.PageSettings.Margins.Left, FZoom,
    FReport.PageSettings, BandOwnerOf, BandLayoutIndex, FSelected, H);
end;

{ -- Snap ------------------------------------------------------------------- }

function TVittixReportDesigner.SnapV(V: Integer): Integer;
begin
  Result := DesignerSnapV(V, GridStepPx, FSnapToGrid);
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

procedure TVittixReportDesigner.DoViewChanged;
begin
  if Assigned(FOnViewChanged) then
    FOnViewChanged(Self);
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
  PrepareDisplayDataSet;
  ComputeBandLayouts;
  UpdateSurfaceExtent;
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
  FInteractionState.Mode := Ord(dmInsert);
  Cursor       := crCross;
  ClearSelection;
end;

function TVittixReportDesigner.AddBand(ABandType: TReportBandType): TReportBand;
var
  Cmd: TInsertObjectCommand;
begin
  Result := TReportBand.Create;
  Result.BandType := ABandType;
  Result.Height := 40;
  Cmd := TInsertObjectCommand.Create(FReport.Objects, Result);
  Cmd.ActionName := 'Add Band';
  FCommands.DoCommand(Cmd);
  ComputeBandLayouts;
  ClearSelection;
  AddToSelection(Result);
  FActiveBand := Result;
  DoModified;
end;

procedure TVittixReportDesigner.SelectObject(AObj: TReportObject);
begin
  DesignerSelectObject(FSelected, FActiveBand, AObj, BandOwnerOf, FOnSelectionChanged, Self);
end;

procedure TVittixReportDesigner.SelectAllObjects;
begin
  DesignerSelectAllObjects(FSelected, FBandLayouts, FOnSelectionChanged, Self);
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
  if FSelected.Count <= 1 then
    Cmd.ActionName := 'Paste Object'
  else
    Cmd.ActionName := 'Paste Objects';
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
  Cmd.ActionName := 'Align Left';
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
  Cmd.ActionName := 'Align Right';
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
  Cmd.ActionName := 'Align Top';
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
  Cmd.ActionName := 'Align Bottom';
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
  Cmd.ActionName := 'Same Width';
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
  Cmd.ActionName := 'Same Height';
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
  Cmd.ActionName := 'Center Horizontally';
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
  Cmd.ActionName := 'Center Vertically';
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
  Cmd.ActionName := 'Distribute Horizontally';
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
  Cmd.ActionName := 'Distribute Vertically';
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
  Cmd.ActionName := 'Bring To Front';
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
  Cmd.ActionName := 'Send To Back';
  FCommands.DoCommand(Cmd);
  DoModified;
end;

{ -- Zoom ------------------------------------------------------------------- }

procedure TVittixReportDesigner.ZoomIn;   begin SetZoom(FZoom + 10); end;
procedure TVittixReportDesigner.ZoomOut;  begin SetZoom(FZoom - 10); end;
procedure TVittixReportDesigner.ZoomReset;begin SetZoom(100);        end;

{ -- Undo/Redo -------------------------------------------------------------- }

procedure TVittixReportDesigner.Undo;
begin
  FCommands.Undo;
  ComputeBandLayouts;
  DoModified;
end;

procedure TVittixReportDesigner.Redo;
begin
  FCommands.Redo;
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
  UpdateSurfaceExtent;
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

function TVittixReportDesigner.GetNextUndoName: string;
begin
  Result := FCommands.NextUndoName;
end;

function TVittixReportDesigner.GetNextRedoName: string;
begin
  Result := FCommands.NextRedoName;
end;

function TVittixReportDesigner.GetCommands: TCommandDispatcher;
begin
  Result := FCommands;
end;

procedure TVittixReportDesigner.PrepareDisplayDataSet;
begin
  if not Assigned(FDataSet) or not FDataSet.Active then
    Exit;

  try
    if not FDataSet.IsEmpty and FDataSet.Eof then
      FDataSet.First;
  except
    // Keep designer painting non-fatal for datasets that do not support First
    // or raise while repositioning.
  end;
end;

procedure TVittixReportDesigner.SetDataSet(const V: TDataSet);
begin
  FDataSet := V;
  PrepareDisplayDataSet;
  if Assigned(FOnDataSetChanged) then
    FOnDataSetChanged(Self);
  Invalidate;
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
  Cmd.ActionName := 'Insert Field';
  FCommands.DoCommand(Cmd);
  FObjectBandMap.AddOrSetValue(NewObj, TargetBand);

  ClearSelection;
  AddToSelection(NewObj);
  FActiveBand := TargetBand;
  DoModified;
  Result := True;
end;

procedure TVittixReportDesigner.SetZoom(const V: Integer);
var
  NewZoom: Integer;
begin
  NewZoom := Max(25, Min(400, V));
  if FZoom = NewZoom then
    Exit;
  FZoom := NewZoom;
  UpdateSurfaceExtent;
  Invalidate;
  DoViewChanged;
end;

procedure TVittixReportDesigner.SetShowGrid(const V: Boolean);
begin
  if FShowGrid = V then
    Exit;
  FShowGrid := V;
  Invalidate;
  DoViewChanged;
end;

procedure TVittixReportDesigner.SetShowRulers(const V: Boolean);
begin
  if FShowRulers = V then
    Exit;
  FShowRulers := V;
  UpdateSurfaceExtent;
  Invalidate;
  DoViewChanged;
end;

procedure TVittixReportDesigner.SetShowMargins(const V: Boolean);
begin
  if FShowMargins = V then
    Exit;
  FShowMargins := V;
  Invalidate;
  DoViewChanged;
end;

procedure TVittixReportDesigner.SetPageColor(const V: TColor);
begin
  if FPageColor = V then
    Exit;
  FPageColor := V;
  Invalidate;
  DoViewChanged;
end;

procedure TVittixReportDesigner.SetCanvasColor(const V: TColor);
begin
  if FCanvasColor = V then
    Exit;
  FCanvasColor := V;
  Invalidate;
  DoViewChanged;
end;

procedure TVittixReportDesigner.SetBandGap(const V: Integer);
var
  NewGap: Integer;
begin
  NewGap := Max(0, V);
  if FBandGap = NewGap then
    Exit;
  FBandGap := NewGap;
  ComputeBandLayouts;
  UpdateSurfaceExtent;
  Invalidate;
  DoViewChanged;
end;

procedure TVittixReportDesigner.UpdateSurfaceExtent;
var
  ReqW, ReqH: Integer;
begin
  ReqW := PageLeft + PageWidth;
  ReqH := PageTop + PageHeight;

  if Assigned(Parent) then
  begin
    ReqW := Max(ReqW, Parent.ClientWidth);
    ReqH := Max(ReqH, Parent.ClientHeight);
  end;

  if (Width <> ReqW) or (Height <> ReqH) then
    SetBounds(Left, Top, ReqW, ReqH);
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
  if FInteractionState.Mode = Ord(dmInsert) then
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
  ContentR: TRect;
  PM: TReportMargins;
  MarginTopR, MarginBottomR, MarginLeftR, MarginRightR: TRect;
begin
  PM := FReport.PageSettings.Margins;

  { Shadow }
  R := Bounds(PageLeft + 4, PageTop + 4, PageWidth, PageHeight);
  Canvas.Brush.Color := $00A0A0A0;
  Canvas.Brush.Style := bsSolid;
  Canvas.FillRect(R);

  { Page }
  R := Bounds(PageLeft, PageTop, PageWidth, PageHeight);
  Canvas.Brush.Color := FPageColor;
  Canvas.FillRect(R);

  { Margin area outside printable content }
  Canvas.Brush.Color := FCanvasColor;

  MarginTopR := Rect(R.Left, R.Top, R.Right, R.Top + Scale(PM.Top));
  MarginBottomR := Rect(R.Left, R.Bottom - Scale(PM.Bottom), R.Right, R.Bottom);
  MarginLeftR := Rect(R.Left, R.Top + Scale(PM.Top), R.Left + Scale(PM.Left), R.Bottom - Scale(PM.Bottom));
  MarginRightR := Rect(R.Right - Scale(PM.Right), R.Top + Scale(PM.Top), R.Right, R.Bottom - Scale(PM.Bottom));

  if MarginTopR.Bottom > MarginTopR.Top then Canvas.FillRect(MarginTopR);
  if MarginBottomR.Bottom > MarginBottomR.Top then Canvas.FillRect(MarginBottomR);
  if MarginLeftR.Right > MarginLeftR.Left then Canvas.FillRect(MarginLeftR);
  if MarginRightR.Right > MarginRightR.Left then Canvas.FillRect(MarginRightR);

  { Printable content area }
  ContentR := Rect(
    PageLeft + Scale(PM.Left),
    PageTop + Scale(PM.Top),
    PageLeft + PageWidth - Scale(PM.Right),
    PageTop + PageHeight - Scale(PM.Bottom));
  if (ContentR.Right > ContentR.Left) and (ContentR.Bottom > ContentR.Top) then
  begin
    Canvas.Brush.Color := FPageColor;
    Canvas.FillRect(ContentR);

    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := $00D0A060;
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Width := 1;
    Canvas.Rectangle(ContentR);
  end;

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
  Step := Scale(GridStepPx);
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
  SepY: Integer;
  PM: TReportMargins;
  PrintableW: Integer;
begin
  PM := FReport.PageSettings.Margins;
  PrintableW := PageWidth - Scale(PM.Left) - Scale(PM.Right);
  if PrintableW < 0 then
    PrintableW := 0;

  for I := 0 to High(FBandLayouts) do
  begin
    BL := FBandLayouts[I];

    { Band background }
    BR := Rect(
      PageLeft + Scale(PM.Left),
      PageTop + Scale(BL.Y),
      PageLeft + Scale(PM.Left) + PrintableW,
      PageTop + Scale(BL.Y + BL.Height + BAND_HDR_H)
    );
    Canvas.Brush.Color := BAND_COLORS[BL.Band.BandType];
    Canvas.Brush.Style := bsSolid;
    Canvas.FillRect(BR);

    { Separator line at bottom }
    SepY := PageTop + Scale(BL.Y + BL.Height + BAND_HDR_H);
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
  OldBounds: TRect;
begin
  if BL.Band.Children.Count = 0 then Exit;

  { Draw object borders and selection rectangles in screen-space }
  SaveDC := Winapi.Windows.SaveDC(Canvas.Handle);
  try
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Style   := psSolid;
    Canvas.Pen.Width   := 1;
    IntersectClipRect(
      Canvas.Handle,
      PageLeft + Scale(FReport.PageSettings.Margins.Left),
      PageTop + Scale(BL.Y + BAND_HDR_H),
      PageLeft + Scale(FReport.PageSettings.PageWidth - FReport.PageSettings.Margins.Right),
      PageTop + Scale(BL.Y + BL.Height + BAND_HDR_H));

    Ctx := Default(TExpressionContext);
    Ctx.DataSet := FDataSet;
    Ctx.PageNumber := 1;
    Ctx.TotalPages := 1;
    Ctx.ReportTitle := FReport.Title;
    Ctx.ReportDate := Now;
    Ctx.PageBottom := PageTop + Scale(BL.Y + BL.Height + BAND_HDR_H);

    for Obj in BL.Band.Children do
    begin
      OR_ := ObjScreenRect(Obj);

      if not FSelected.Contains(Obj) then
      begin
        Canvas.Brush.Style := bsClear;
        Canvas.Pen.Color := $00C0C0C0;
        Canvas.Rectangle(OR_);
      end;

      OldBounds := Obj.Bounds;
      try
        Obj.Bounds := OR_;
        Obj.Draw(Canvas, Ctx);
      finally
        Obj.Bounds := OldBounds;
      end;

      { Object border }
      Canvas.Brush.Style := bsClear;
      if FSelected.Contains(Obj) then
      begin
        Canvas.Pen.Color := $000080FF;   // bright selection color
        Canvas.Rectangle(OR_);
      end
    end;
  finally
    Winapi.Windows.RestoreDC(Canvas.Handle, SaveDC);
  end;
end;

procedure TVittixReportDesigner.DrawBandHeaders;
var
  I   : Integer;
  BL  : TBandLayout;
  BR  : TRect;
  PM  : TReportMargins;
  PrintableW: Integer;
  Txt: string;
begin
  PM := FReport.PageSettings.Margins;
  PrintableW := PageWidth - Scale(PM.Left) - Scale(PM.Right);
  if PrintableW < 0 then
    PrintableW := 0;

  Canvas.Brush.Style := bsSolid;
  Canvas.Font.Color  := clBlack;
  Canvas.Font.Size   := 8;
  Canvas.Font.Style  := [fsBold];

  for I := 0 to High(FBandLayouts) do
  begin
    BL := FBandLayouts[I];
    BR := Rect(
      PageLeft + Scale(PM.Left),
      PageTop + Scale(BL.Y),
      PageLeft + Scale(PM.Left) + PrintableW,
      PageTop + Scale(BL.Y) + BAND_HDR_H);

    Canvas.Brush.Color := $00E0E0E0;
    Canvas.FillRect(BR);
    Canvas.Brush.Style := bsClear;
    Txt := BAND_LABELS[BL.Band.BandType] + ': ' + BL.Band.Name;
    Canvas.TextOut(BR.Left + 4, BR.Top + 1, Txt);
    Canvas.Pen.Color := $00808080;
    Canvas.MoveTo(BR.Left, BR.Bottom);
    Canvas.LineTo(BR.Right, BR.Bottom);
    Canvas.MoveTo(BR.Right - 12, BR.Top + 4);
    Canvas.LineTo(BR.Right - 4, BR.Top + 4);
    Canvas.MoveTo(BR.Right - 12, BR.Top + 7);
    Canvas.LineTo(BR.Right - 4, BR.Top + 7);
  end;

  Canvas.Font.Style := [];
end;

procedure TVittixReportDesigner.DrawSelectionHandles;
var
  Obj : TReportObject;
  SR  : TRect;
  UnionR: TRect;
  I   : Integer;
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

  if FSelected.Count = 1 then
    SR := ObjScreenRect(FSelected[0])
  else
  begin
    UnionR := ObjScreenRect(FSelected[0]);
    for I := 1 to FSelected.Count - 1 do
    begin
      Obj := FSelected[I];
      if Obj <> nil then
        UnionRect(UnionR, UnionR, ObjScreenRect(Obj));
    end;
    SR := UnionR;
  end;

  CX  := (SR.Left + SR.Right)  div 2;
  CY  := (SR.Top  + SR.Bottom) div 2;

  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Width   := 1;
  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Style   := psSolid;

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
  if not FInteractionState.Rubbering then Exit;
  R := FInteractionState.RubberRect;
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
  if (FInteractionState.Mode <> Ord(dmInsert)) or not Assigned(FInsertClass) then
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
  PrepareDisplayDataSet;

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

  DrawBandHeaders;
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
  FInteractionState.MouseDown  := True;
  FInteractionState.MouseStart := Point(X, Y);
  if Button = mbLeft then
  begin
    { ---- INSERT MODE ---- }
    if FInteractionState.Mode = Ord(dmInsert) then
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
            SnapV(PP.Y - BL.Y - 14),
            80, 20);
          Cmd := TInsertObjectCommand.Create(TargetBand.Children, NewObj);
          Cmd.ActionName := 'Insert Object';
          FCommands.DoCommand(Cmd);
          FObjectBandMap.AddOrSetValue(NewObj, TargetBand);

          ClearSelection;
          AddToSelection(NewObj);
          FActiveBand := TargetBand;
          FInteractionState.Mode := Ord(dmSelect);
          Cursor      := crDefault;
          DoModified;
        end;
      end;
      Exit;
    end;

    { ---- BAND SEPARATOR ---- }
    if BandSepHitTest(Point(X, Y), HitBand) then
    begin
      FInteractionState.Mode := Ord(dmBandResize);
      FInteractionState.BandResizeBand  := HitBand;
      FInteractionState.BandResizeOrigH := HitBand.Height;
      Exit;
    end;

    { ---- RESIZE HANDLE ---- }
    if HandleHitTest(Point(X, Y), H) then
    begin
      FInteractionState.Mode := Ord(dmResize);
      FInteractionState.ResizeHandle := H;
      { Snapshot bounds of all selected for undo }
      FInteractionState.DragStartBounds.Clear;
      for HitObj in FSelected do
      begin
        FInteractionState.DragStartBounds.Add(HitObj, HitObj.Bounds);
      end;
      Exit;
    end;

    { ---- OBJECT HIT TEST ---- }
    if ObjectHitTest(Point(X, Y), HitObj) then
    begin
      if (ssCtrl in Shift) or (ssShift in Shift) then
      begin
        if FSelected.Contains(HitObj) then
          RemoveFromSelection(HitObj)
        else
          AddToSelection(HitObj);

        { Modifier-click is selection-only; do not start a move operation. }
        FActiveBand := BandOwnerOf(HitObj);
        Exit;
      end
      else
      begin
        // Single-click selection should emit one selection-changed notification.
        // Avoid ClearSelection/AddToSelection because each helper notifies.
        if (FSelected.Count <> 1) or (not FSelected.Contains(HitObj)) then
        begin
          FSelected.Clear;
          FSelected.Add(HitObj);
          DoSelectionChanged;
        end;
      end;

      { Update active band }
      FActiveBand := BandOwnerOf(HitObj);

      { Move mode }
      FInteractionState.Mode := Ord(dmMove);
      FInteractionState.DragStartBounds.Clear;
      for HitObj in FSelected do
      begin
        FInteractionState.DragStartBounds.Add(HitObj, HitObj.Bounds);
      end;
      Exit;
    end;

    { ---- EMPTY SPACE = deselect and optionally rubber band ---- }
    if not DesignerBeginRubberBandSelection(
      FSelected,
      FActiveBand,
      Shift,
      Point(X, Y),
      Rect(PageLeft, PageTop, PageLeft + PageWidth, PageTop + PageHeight),
      FOnSelectionChanged,
      Self) then
      Exit;

    FInteractionState.Rubbering  := True;
    FInteractionState.RubberRect := Rect(X, Y, X, Y);
    FInteractionState.Mode := Ord(dmRubberBand);
  end;
end;

procedure TVittixReportDesigner.MouseMove(Shift: TShiftState; X, Y: Integer);
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
  if not FInteractionState.MouseDown then
  begin
    UpdateCursor(X, Y);
    Exit;
  end;

  DX := X - FInteractionState.MouseStart.X;
  DY := Y - FInteractionState.MouseStart.Y;
  LogDX := UnScale(DX);
  LogDY := UnScale(DY);

  case TDesignerMode(FInteractionState.Mode) of
    dmMove:
    begin
      if (Abs(DX) < MOVE_DRAG_THRESHOLD) and (Abs(DY) < MOVE_DRAG_THRESHOLD) then
        Exit;
      for Obj in FSelected do
      begin
        if FInteractionState.DragStartBounds.TryGetValue(Obj, StartR) then
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
      if FSelected.Count > 1 then
      begin
        UnionStart := Rect(MaxInt, MaxInt, -MaxInt, -MaxInt);
        for Obj in FSelected do
          if FInteractionState.DragStartBounds.TryGetValue(Obj, SrcR) then
          begin
            UnionStart.Left   := Min(UnionStart.Left, SrcR.Left);
            UnionStart.Top    := Min(UnionStart.Top, SrcR.Top);
            UnionStart.Right  := Max(UnionStart.Right, SrcR.Right);
            UnionStart.Bottom := Max(UnionStart.Bottom, SrcR.Bottom);
          end;

        UnionNew := UnionStart;
        case TResizeHandle(FInteractionState.ResizeHandle) of
          rhLeft, rhTopLeft, rhBottomLeft:
            UnionNew.Left := SnapV(Min(UnionStart.Left + LogDX, UnionStart.Right - MIN_OBJ_SZ));
          rhRight, rhTopRight, rhBottomRight:
            UnionNew.Right := SnapV(Max(UnionStart.Right + LogDX, UnionStart.Left + MIN_OBJ_SZ));
        end;
        case TResizeHandle(FInteractionState.ResizeHandle) of
          rhTop, rhTopLeft, rhTopRight:
            UnionNew.Top := SnapV(Min(UnionStart.Top + LogDY, UnionStart.Bottom - MIN_OBJ_SZ));
          rhBottom, rhBottomLeft, rhBottomRight:
            UnionNew.Bottom := SnapV(Max(UnionStart.Bottom + LogDY, UnionStart.Top + MIN_OBJ_SZ));
        end;

        if ssShift in Shift then
        begin
          if (FInteractionState.ResizeHandle in [rhLeft, rhRight]) and
             ((UnionNew.Bottom - UnionNew.Top) <> (UnionStart.Bottom - UnionStart.Top)) then
          begin
            if FInteractionState.ResizeHandle = rhLeft then
              UnionNew.Left := SnapV(UnionNew.Right - Round((UnionStart.Right - UnionStart.Left) *
                ((UnionNew.Bottom - UnionNew.Top) / Max(1, UnionStart.Bottom - UnionStart.Top))))
            else
              UnionNew.Right := SnapV(UnionNew.Left + Round((UnionStart.Right - UnionStart.Left) *
                ((UnionNew.Bottom - UnionNew.Top) / Max(1, UnionStart.Bottom - UnionStart.Top))));
          end
          else if (FInteractionState.ResizeHandle in [rhTop, rhBottom]) and
                  ((UnionNew.Right - UnionNew.Left) <> (UnionStart.Right - UnionStart.Left)) then
          begin
            if FInteractionState.ResizeHandle = rhTop then
              UnionNew.Top := SnapV(UnionNew.Bottom - Round((UnionStart.Bottom - UnionStart.Top) *
                ((UnionNew.Right - UnionNew.Left) / Max(1, UnionStart.Right - UnionStart.Left))))
            else
              UnionNew.Bottom := SnapV(UnionNew.Top + Round((UnionStart.Bottom - UnionStart.Top) *
                ((UnionNew.Right - UnionNew.Left) / Max(1, UnionStart.Right - UnionStart.Left))));
          end
          else
          begin
            if Abs(UnionNew.Right - UnionNew.Left) > Abs(UnionNew.Bottom - UnionNew.Top) then
            begin
              if FInteractionState.ResizeHandle in [rhLeft, rhTopLeft, rhBottomLeft] then
                UnionNew.Left := SnapV(UnionNew.Right - Round((UnionStart.Right - UnionStart.Left) *
                  ((UnionNew.Bottom - UnionNew.Top) / Max(1, UnionStart.Bottom - UnionStart.Top))))
              else
                UnionNew.Right := SnapV(UnionNew.Left + Round((UnionStart.Right - UnionStart.Left) *
                  ((UnionNew.Bottom - UnionNew.Top) / Max(1, UnionStart.Bottom - UnionStart.Top))));
            end
            else
            begin
              if FInteractionState.ResizeHandle in [rhTop, rhTopLeft, rhTopRight] then
                UnionNew.Top := SnapV(UnionNew.Bottom - Round((UnionStart.Bottom - UnionStart.Top) *
                  ((UnionNew.Right - UnionNew.Left) / Max(1, UnionStart.Right - UnionStart.Left))))
              else
                UnionNew.Bottom := SnapV(UnionNew.Top + Round((UnionStart.Bottom - UnionStart.Top) *
                  ((UnionNew.Right - UnionNew.Left) / Max(1, UnionStart.Right - UnionStart.Left))));
            end;
          end;
        end;

        if (UnionStart.Right <= UnionStart.Left) or (UnionStart.Bottom <= UnionStart.Top) then
          Exit;

        SX := (UnionNew.Right - UnionNew.Left) / (UnionStart.Right - UnionStart.Left);
        SY := (UnionNew.Bottom - UnionNew.Top) / (UnionStart.Bottom - UnionStart.Top);
        for Obj in FSelected do
          if FInteractionState.DragStartBounds.TryGetValue(Obj, SrcR) then
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
        Invalidate;
      end
      else
      begin
        Obj := GetPrimarySelected;
        if Assigned(Obj) and FInteractionState.DragStartBounds.TryGetValue(Obj, StartR) then
        begin
          R := StartR;
          case TResizeHandle(FInteractionState.ResizeHandle) of
            rhLeft, rhTopLeft, rhBottomLeft:
              R.Left := SnapV(Min(StartR.Left + LogDX, StartR.Right - MIN_OBJ_SZ));
            rhRight, rhTopRight, rhBottomRight:
              R.Right := SnapV(Max(StartR.Right + LogDX, StartR.Left + MIN_OBJ_SZ));
          end;
          case TResizeHandle(FInteractionState.ResizeHandle) of
            rhTop, rhTopLeft, rhTopRight:
              R.Top    := SnapV(Min(StartR.Top + LogDY, StartR.Bottom - MIN_OBJ_SZ));
            rhBottom, rhBottomLeft, rhBottomRight:
              R.Bottom := SnapV(Max(StartR.Bottom + LogDY, StartR.Top + MIN_OBJ_SZ));
          end;
          if ssShift in Shift then
          begin
            if Abs(R.Right - R.Left) > Abs(R.Bottom - R.Top) then
            begin
              if FInteractionState.ResizeHandle in [rhLeft, rhTopLeft, rhBottomLeft] then
                R.Left := R.Right - Round((StartR.Right - StartR.Left) * ((R.Bottom - R.Top) / Max(1, StartR.Bottom - StartR.Top)))
              else
                R.Right := R.Left + Round((StartR.Right - StartR.Left) * ((R.Bottom - R.Top) / Max(1, StartR.Bottom - StartR.Top)));
            end
            else
            begin
              if FInteractionState.ResizeHandle in [rhTop, rhTopLeft, rhTopRight] then
                R.Top := R.Bottom - Round((StartR.Bottom - StartR.Top) * ((R.Right - R.Left) / Max(1, StartR.Right - StartR.Left)))
              else
                R.Bottom := R.Top + Round((StartR.Bottom - StartR.Top) * ((R.Right - R.Left) / Max(1, StartR.Right - StartR.Left)));
            end;
          end;
          Obj.Bounds := R;
          Invalidate;
        end;
      end;
    end;

    dmBandResize:
    begin
      if Assigned(FInteractionState.BandResizeBand) then
      begin
        NewH := Max(MIN_BAND_H, FInteractionState.BandResizeOrigH + LogDY);
        FInteractionState.BandResizeBand.Height := NewH;
        ComputeBandLayouts;
        Invalidate;
      end;
    end;

    dmRubberBand:
    begin
      if (Abs(DX) < MOVE_DRAG_THRESHOLD) and (Abs(DY) < MOVE_DRAG_THRESHOLD) then
        Exit;
      FInteractionState.RubberRect := Rect(FInteractionState.MouseStart.X, FInteractionState.MouseStart.Y, X, Y);
      Invalidate;
    end;
  end;
end;

procedure TVittixReportDesigner.MouseUp(Button: TMouseButton;
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
  if not FInteractionState.MouseDown then Exit;
  FInteractionState.MouseDown := False;
  case TDesignerMode(FInteractionState.Mode) of
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
          if FInteractionState.DragStartBounds.TryGetValue(Obj, OldBounds[J]) then ;
        end;
        Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
        if Length(Objects) <= 1 then
          Cmd.ActionName := 'Move Object'
        else
          Cmd.ActionName := 'Move Objects';
        FCommands.DoCommand(Cmd);
        DoModified;
      end;
    end;

    dmResize:
    begin
      if FSelected.Count > 1 then
      begin
        SetLength(Objects,   FSelected.Count);
        SetLength(OldBounds, FSelected.Count);
        SetLength(NewBounds, FSelected.Count);
        for J := 0 to FSelected.Count - 1 do
        begin
          Obj         := FSelected[J];
          Objects[J]  := Obj;
          if FInteractionState.DragStartBounds.TryGetValue(Obj, OldBounds[J]) then
            NewBounds[J] := Obj.Bounds
          else
            NewBounds[J] := Obj.Bounds;
        end;

        Cmd := TMultiMoveCommand.Create(Objects, OldBounds, NewBounds);
        Cmd.ActionName := 'Resize Objects';
        FCommands.DoCommand(Cmd);
        DoModified;
      end
      else
      begin
        Obj := GetPrimarySelected;
        if Assigned(Obj) then
        begin
          var OldR: TRect;
          if FInteractionState.DragStartBounds.TryGetValue(Obj, OldR) then
          begin
            var ResizeCmd := TMoveObjectCommand.Create(Obj, OldR, Obj.Bounds);
            ResizeCmd.ActionName := 'Resize Object';
            FCommands.DoCommand(ResizeCmd);
            DoModified;
          end;
        end;
      end;
    end;

    dmBandResize:
    begin
      if Assigned(FInteractionState.BandResizeBand) then
      begin
        BandCmd := TBandResizeCommand.Create(
          FInteractionState.BandResizeBand, FInteractionState.BandResizeOrigH, FInteractionState.BandResizeBand.Height);
        FCommands.DoCommand(BandCmd);
        DoModified;
      end;
      FInteractionState.BandResizeBand := nil;
    end;

    dmRubberBand:
    begin
      FInteractionState.Rubbering := False;
      if DesignerApplyRubberBandSelection(
           FSelected,
           FBandLayouts,
           FInteractionState.RubberRect,
           ObjScreenRect,
           FOnSelectionChanged,
           Self) then
        DoSelectionChanged
      else
        Invalidate;
    end;
  end;

  FInteractionState.Mode := Ord(dmSelect);
  FInteractionState.DragStartBounds.Clear;
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
      if (FInteractionState.Mode = Ord(dmSelect)) and (FSelected.Count > 0) then
      begin
        DeleteSelected;
        Key := 0;
      end;

    VK_LEFT:
    begin
      if (ssShift in Shift) and not (ssCtrl in Shift) then
        DesignerResizeSelected(FSelected, -RESIZE_STEP, 0, MIN_KEYBOARD_OBJ_SZ, FCommands, DoModified, Self)
      else
        DesignerNudgeSelected(FSelected, -Step, 0, FCommands, DoModified, Self);
      Key := 0;
    end;
    VK_RIGHT:
    begin
      if (ssShift in Shift) and not (ssCtrl in Shift) then
        DesignerResizeSelected(FSelected, RESIZE_STEP, 0, MIN_KEYBOARD_OBJ_SZ, FCommands, DoModified, Self)
      else
        DesignerNudgeSelected(FSelected, Step, 0, FCommands, DoModified, Self);
      Key := 0;
    end;
    VK_UP:
    begin
      if (ssShift in Shift) and not (ssCtrl in Shift) then
        DesignerResizeSelected(FSelected, 0, -RESIZE_STEP, MIN_KEYBOARD_OBJ_SZ, FCommands, DoModified, Self)
      else
        DesignerNudgeSelected(FSelected, 0, -Step, FCommands, DoModified, Self);
      Key := 0;
    end;
    VK_DOWN:
    begin
      if (ssShift in Shift) and not (ssCtrl in Shift) then
        DesignerResizeSelected(FSelected, 0, RESIZE_STEP, MIN_KEYBOARD_OBJ_SZ, FCommands, DoModified, Self)
      else
        DesignerNudgeSelected(FSelected, 0, Step, FCommands, DoModified, Self);
      Key := 0;
    end;
    VK_ESCAPE:
    begin
      if FInteractionState.Mode = Ord(dmInsert) then
      begin
        FInteractionState.Mode := Ord(dmSelect);
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
