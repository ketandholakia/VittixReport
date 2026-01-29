unit Vittix.Report.Engine;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.Graphics,
  System.Variants, // Keep for 'Null'
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Bands;

type
  EReportException = class(Exception);

type
  TReportEngine = class
  private
    FReport: TReportModel;
    FDataSet: TDataSet;
    FPages: TObjectList<TMetafile>;

    FCurrentPage: TMetafile;
    FCanvas: TMetafileCanvas;
    FCurrentY: Integer;
    FPageWidth, FPageHeight: Integer;

    FTitleBand: TReportBand;
    FHeaderBand: TReportBand;
    FMasterBand: TReportBand;
    FFooterBand: TReportBand;
    FSummaryBand: TReportBand;

    FGroupStartBookmark: TBookmark;
    FGroupEndBookmark: TBookmark;
    
    FGroupHeaders: TObjectList<TReportBand>;
    FGroupFooters: TObjectList<TReportBand>;
    FLastGroupValues: array of Variant;

    procedure CacheBands;
    procedure StartNewPage;
    procedure EndCurrentPage;
    procedure PrintBand(ABand: TReportBand);
    function CheckSpace(RequiredHeight: Integer): Boolean;

  public
    constructor Create(AReport: TReportModel; ADataSet: TDataSet);
    destructor Destroy; override;
    
    const
      PAGE_WIDTH = 793;
      PAGE_HEIGHT = 1122;

    procedure Prepare;

    property Pages: TObjectList<TMetafile> read FPages;
    property GroupStartBookmark: TBookmark read FGroupStartBookmark;
    property GroupEndBookmark: TBookmark read FGroupEndBookmark;
  end;

implementation

uses // Move specific unit dependencies to implementation to break cycle
  Winapi.Windows,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  System.Types,
  System.Generics.Defaults;
{ ================= Constructor ================= }

constructor TReportEngine.Create(
  AReport: TReportModel;
  ADataSet: TDataSet);
begin
  FReport := AReport;
  FDataSet := ADataSet;
  FPages := TObjectList<TMetafile>.Create(True);
  
  FGroupHeaders := TObjectList<TReportBand>.Create(False); // Don't own - bands owned by report
  FGroupFooters := TObjectList<TReportBand>.Create(False);

  { A4 approx @ 96 DPI }
  FPageWidth := 793;
  FPageHeight := 1122;
end;

destructor TReportEngine.Destroy;
begin
  FPages.Free;
  FGroupHeaders.Free;
  FGroupFooters.Free;
  inherited;
end;

{ ================= Band Cache ================= }

procedure TReportEngine.CacheBands;
var
  Obj: TReportObject;
begin
  FTitleBand := nil;
  FHeaderBand := nil;
  FMasterBand := nil;
  FFooterBand := nil;
  FSummaryBand := nil;
  
  FGroupHeaders.Clear;
  FGroupFooters.Clear;

  for Obj in FReport.Objects do
    if Obj is TReportBand then
      case TReportBand(Obj).BandType of
        btReportTitle:   FTitleBand := TReportBand(Obj);
        btPageHeader:    FHeaderBand := TReportBand(Obj);
        btMasterData:    FMasterBand := TReportBand(Obj);
        btPageFooter:    FFooterBand := TReportBand(Obj);
        btReportSummary: FSummaryBand := TReportBand(Obj);
        
        btGroupHeader:   FGroupHeaders.Add(TReportBand(Obj));
        btGroupFooter:   FGroupFooters.Add(TReportBand(Obj));
      end;
      
  FGroupHeaders.Sort(TComparer<TReportBand>.Construct(
    function(const L, R: TReportBand): Integer
    begin
      Result := L.GroupLevel - R.GroupLevel;
    end));
    
  FGroupFooters.Sort(TComparer<TReportBand>.Construct(
    function(const L, R: TReportBand): Integer
    begin
      Result := R.GroupLevel - L.GroupLevel;  // Reverse for footers
    end));
end;

{ ================= Page Lifecycle ================= }

procedure TReportEngine.StartNewPage;
begin
  EndCurrentPage;

  FCurrentPage := TMetafile.Create;
  FCurrentPage.Width := FPageWidth;
  FCurrentPage.Height := FPageHeight;

  FCanvas := TMetafileCanvas.Create(FCurrentPage, 0);
  FCurrentY := 40; // top margin
end;

procedure TReportEngine.EndCurrentPage;
begin
  if not Assigned(FCanvas) then Exit;

  { footer forced to bottom }
  if Assigned(FFooterBand) and (FFooterBand.Height > 0) then
  begin
    FCurrentY := FPageHeight - 40 - FFooterBand.Height;
    PrintBand(FFooterBand);
  end;

  FCanvas.Free; // finalize metafile
  FCanvas := nil;

  if Assigned(FCurrentPage) then
    FPages.Add(FCurrentPage);
end;

{ ================= Space Check ================= }

function TReportEngine.CheckSpace(
  RequiredHeight: Integer): Boolean;
begin
  if RequiredHeight <= 0 then
    RequiredHeight := 1;

  Result :=
    (FCurrentY + RequiredHeight) <
    (FPageHeight - 40);
end;

{ ================= Band Printing ================= }

procedure TReportEngine.PrintBand(ABand: TReportBand);
var
  SavedOrigin: TPoint;
  Ctx: TExpressionContext;
begin
  if not Assigned(ABand) then Exit;
  if not Assigned(FCanvas) then Exit;
  if ABand.Height <= 0 then Exit;

  SetWindowOrgEx(
    FCanvas.Handle,
    0,
    -FCurrentY,
    @SavedOrigin);

  Ctx.DataSet := FDataSet;
  Ctx.GroupStart := FGroupStartBookmark;
  Ctx.GroupEnd := FGroupEndBookmark;

  try
    ABand.Draw(FCanvas, Ctx);
  finally
    SetWindowOrgEx(
      FCanvas.Handle,
      SavedOrigin.X,
      SavedOrigin.Y,
      nil);
  end;

  Inc(FCurrentY, ABand.Height);
end;

{ ================= Main Loop ================= }

procedure TReportEngine.Prepare;
var
  i: Integer;
  GH, GF: TReportBand;
  NewValue: Variant;
  BreakLevel: Integer;
begin
  try
    FPages.Clear;
    CacheBands;

    if not Assigned(FMasterBand) then
      raise EReportException.Create(
        'Report must have a MasterData band');

    if not Assigned(FDataSet) then
      raise EReportException.Create(
        'DataSet must be assigned to the report engine.');

    if not FDataSet.Active then
      raise EReportException.Create(
        'DataSet must be active to generate the report.');

    StartNewPage;

    { Title once }
    if Assigned(FTitleBand) then
      PrintBand(FTitleBand);

    { Header first page }
    if Assigned(FHeaderBand) then
      PrintBand(FHeaderBand);

    SetLength(FLastGroupValues, FGroupHeaders.Count);
    for i := 0 to High(FLastGroupValues) do
      FLastGroupValues[i] := Null;

    FGroupStartBookmark := nil; // Initialize
    FGroupEndBookmark := nil;   // Initialize

    // LastGroupValue is a local variable, not a field.
    // It's used in the previous version of the Prepare method,
    // but with multi-level grouping, FLastGroupValues array handles this.
    // The original prompt's 'LastGroupValue := Null;' is no longer needed here.

    { Master data loop }
    if Assigned(FDataSet) and FDataSet.Active then
    begin
      FDataSet.First;

      while not FDataSet.Eof do
      begin
        { -------- GROUP SUPPORT -------- }
        // Detect break level
        BreakLevel := -1;
        for i := 0 to FGroupHeaders.Count-1 do
        begin
          GH := FGroupHeaders[i];
          if GH.GroupField <> '' then // Only consider groups with a field
          begin
            NewValue := FDataSet.FieldByName(GH.GroupField).Value;

            if VarIsNull(FLastGroupValues[i]) or
               (NewValue <> FLastGroupValues[i]) then
            begin
              BreakLevel := i;
              Break;
            end;
          end;
        end;

        // Close lower groups first (from lowest level up to BreakLevel)
        if BreakLevel >= 0 then
        begin
          FGroupEndBookmark := FDataSet.GetBookmark; // Mark end of previous group range
          for i := 0 to FGroupFooters.Count-1 do
          begin
            GF := FGroupFooters[i];
            if GF.GroupLevel >= BreakLevel then
              PrintBand(GF);
          end;
        end;

        // Open new groups top-down (from BreakLevel down to lowest level)
        if BreakLevel >= 0 then
        begin
          for i := BreakLevel to FGroupHeaders.Count-1 do
          begin
            GH := FGroupHeaders[i];

            if GH.StartNewPage then
              StartNewPage;

            PrintBand(GH);

            FLastGroupValues[i] :=
              FDataSet.FieldByName(GH.GroupField).Value;
          end;
          FGroupStartBookmark := FDataSet.GetBookmark; // Mark start of new group range
        end;

        { -------- PAGE BREAK -------- }
        if not CheckSpace(FMasterBand.Height) then
        begin
          StartNewPage;
          if Assigned(FHeaderBand) then
            PrintBand(FHeaderBand);
        end;
        { -------- PRINT RECORD -------- }
        PrintBand(FMasterBand);
        FDataSet.Next;
      end;
    end;

    { close last group }
    // After the loop, FDataSet is at EOF. The FGroupEndBookmark for the LAST group is effectively EOF.
    FGroupEndBookmark := FDataSet.GetBookmark;
    for GF in FGroupFooters do
      PrintBand(GF);

    if Assigned(FSummaryBand) then
    begin
      if not CheckSpace(FSummaryBand.Height) then
        StartNewPage;

      PrintBand(FSummaryBand);
    end;

    EndCurrentPage;
  except
    on E: EReportException do
      raise; // Re-raise custom report exceptions
    on E: Exception do
      raise EReportException.CreateFmt('Error preparing report: %s', [E.Message]);
  end;
end;

end.
