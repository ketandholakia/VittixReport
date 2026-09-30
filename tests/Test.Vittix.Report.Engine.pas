unit Test.Vittix.Report.Engine;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Types,
  System.Variants,
  Vcl.Graphics,
  Vcl.Imaging.PNGImage,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.Objects.Chart,
  Vittix.Report.Objects.CrossTab,
  Vittix.Report.UserDataSet,
  Vittix.Report.Renderer,
  Vittix.Report.Expressions,
  Vittix.Report.TraversalDiagnostics,
  Vittix.Report.Export.Commands;

type
  [TestFixture]
  TTestReportEngine = class
  private
    FReport: TReportModel;
    FDataSet: TClientDataSet;
    FEngine: TReportEngine;
    class function BitmapsDiffer(const A, B: TBitmap): Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_H01_DatasetStatePreservation;

    [Test]
    procedure Test_C01_FooterPageBreakRecursion;

    [Test]
    procedure Test_CrossTabCache_ResetBetweenPrepares;
    [Test]
    procedure Test_ChartCache_ResetBetweenPrepares;
    [Test]
    procedure Test_GroupBreak_NullTransitions_Fire;
    [Test]
    procedure Test_GroupBreak_TypeFlap_Fires;
    [Test]
    procedure Test_DP18_CrossTabTallerThanBand_NoBleedIntoNextBand;
    [Test]
    procedure Test_DP29_RowScopedAggregates_DoNotGrowCache;
    [Test]
    procedure Test_DP29_AggregateCache_CapEnforced_FIFO;
  end;

  { Event harness for a purely event-driven TVittixUserDataSet whose group
    column returns deliberately type-flapped Variants. }
  TUDSFlapHarness = class
  public
    Row: Integer;
    GValues: TArray<Variant>;
    procedure DoFirst(Sender: TObject);
    procedure DoNext(Sender: TObject);
    procedure DoEof(Sender: TObject; var AEof: Boolean);
    procedure DoGetValue(Sender: TObject; const AFieldName: string;
      var AValue: Variant);
  end;

implementation

{ TTestReportEngine }

procedure TTestReportEngine.Setup;
begin
  FReport := TReportModel.Create;
  FDataSet := TClientDataSet.Create(nil);
  FDataSet.FieldDefs.Add('ID', ftInteger, 0, False);
  FDataSet.FieldDefs.Add('Name', ftString, 50, False);
  FDataSet.CreateDataSet;
  
  // Add some sample data
  FDataSet.AppendRecord([1, 'First']);
  FDataSet.AppendRecord([2, 'Second']);
  FDataSet.AppendRecord([3, 'Third']);
  
  FEngine := TReportEngine.Create(FReport, FDataSet);
end;

procedure TTestReportEngine.TearDown;
begin
  FEngine.Free;
  FDataSet.Free;
  FReport.Free;
end;

procedure TTestReportEngine.Test_H01_DatasetStatePreservation;
var
  ExpectedID: Integer;
begin
  // Set dataset to a specific position
  FDataSet.First;
  FDataSet.Next; // Now at ID = 2
  ExpectedID := FDataSet.FieldByName('ID').AsInteger;
  
  // Add a master band so the engine actually traverses the dataset
  var LMasterBand := TReportBand.Create;
  LMasterBand.BandType := btMasterData;
  LMasterBand.Height := 20;
  FReport.Objects.Add(LMasterBand);

  // Run the report
  FEngine.Prepare;

  // Verify the dataset is NOT at EOF and is at the same record
  Assert.IsFalse(FDataSet.Eof, 'Dataset should not be at EOF after Prepare');
  Assert.AreEqual(ExpectedID, FDataSet.FieldByName('ID').AsInteger, 'Dataset position should be restored');
end;

procedure TTestReportEngine.Test_C01_FooterPageBreakRecursion;
var
  LFooterBand: TReportBand;
  LChildObj: TReportTextObject;
begin
  // Set up a simple master band to force at least one page
  var LMasterBand := TReportBand.Create;
  LMasterBand.BandType := btMasterData;
  LMasterBand.Height := 20;
  FReport.Objects.Add(LMasterBand);

  // Set up a footer band with an object that requests a page break
  LFooterBand := TReportBand.Create;
  LFooterBand.BandType := btPageFooter;
  LFooterBand.Height := 50;

  LChildObj := TReportTextObject.Create;
  LChildObj.PageBreakBefore := True; // This is the malicious property causing C-01
  LFooterBand.Children.Add(LChildObj);
  FReport.Objects.Add(LFooterBand);

  // If C-01 is present, this will cause a Stack Overflow
  // If guarded properly, Prepare will complete successfully
  FEngine.Prepare;

  // If we reach here without a stack overflow, the test passes
  Assert.Pass('No infinite recursion triggered by footer page break');
end;

{ DP-12 / H-6 helpers }

function LoadPngBitmap(const APath: string): TBitmap;
var
  Png: TPngImage;
begin
  Png := TPngImage.Create;
  try
    Png.LoadFromFile(APath);
    Result := TBitmap.Create;
    try
      Result.PixelFormat := pf32bit;
      Result.Assign(Png);
    except
      Result.Free;
      raise;
    end;
  finally
    Png.Free;
  end;
end;

class function TTestReportEngine.BitmapsDiffer(const A, B: TBitmap): Boolean;
var
  X, Y: Integer;
  RowA, RowB: PByteArray;
begin
  Result := False;
  if (A.Width <> B.Width) or (A.Height <> B.Height) then
    Exit(True);
  for Y := 0 to A.Height - 1 do
  begin
    RowA := A.ScanLine[Y];
    RowB := B.ScanLine[Y];
    for X := 0 to (A.Width * 4) - 1 do
      if RowA[X] <> RowB[X] then
        Exit(True);
  end;
end;

function FirstImageSourceForDoc(ADoc: TReportExportDocument): string;
var
  Cmd: TReportExportCommand;
begin
  Result := '';
  for Cmd in ADoc.Pages[0].Commands do
    if Cmd is TReportExportImageCommand then
      Exit(TReportExportImageCommand(Cmd).Source);
end;

{ Builds one summary band (printed once) holding AObj as a band child -
  the normal placement, which is exactly what the engine's per-pass cache
  reset must reach. Renders twice with one mutated Amount value and hands
  back the two captured rasterizations. The export document deletes its
  temp PNGs on free, so the captures are loaded BEFORE the documents die.
  Caller owns both bitmaps. }
procedure RenderCapturedTwice(ADataSet: TClientDataSet; AObj: TReportObject;
  out ABmp1, ABmp2: TBitmap);
var
  Model: TReportModel;
  Band: TReportBand;
  Engine: TReportEngine;
  Doc1, Doc2: TReportExportDocument;
begin
  ABmp1 := nil;
  ABmp2 := nil;
  Model := TReportModel.Create;
  try
    Band := TReportBand.Create;
    Band.BandType := btReportSummary;
    Band.Height := 160;
    AObj.Bounds := Rect(10, 10, 300, 150);
    Band.Children.Add(AObj);
    Model.Objects.Add(Band);

    Doc1 := TReportExportDocument.Create;
    try
      Doc2 := TReportExportDocument.Create;
      try
        Engine := TReportEngine.Create(Model, ADataSet);
        try
          Engine.ExportDocument := Doc1;
          Engine.Prepare;
          ABmp1 := LoadPngBitmap(FirstImageSourceForDoc(Doc1));
          try
            // Change one data value; shape stays the same. A latched data
            // cache re-renders the OLD values (H-6).
            ADataSet.First;
            ADataSet.Edit;
            ADataSet.FieldByName('Amount').AsFloat := 999;
            ADataSet.Post;

            Engine.ExportDocument := Doc2;
            Engine.Prepare;
            ABmp2 := LoadPngBitmap(FirstImageSourceForDoc(Doc2));
          except
            FreeAndNil(ABmp1);
            raise;
          end;
        finally
          Engine.Free;
        end;
      finally
        Doc2.Free;
        Doc1.Free;
      end;
    finally
      Doc1 := nil;
    end;
  finally
    Model.Free;
  end;
end;

procedure TTestReportEngine.Test_CrossTabCache_ResetBetweenPrepares;
var
  DS: TClientDataSet;
  CT: TReportCrossTabObject;
  Bmp1, Bmp2: TBitmap;
begin
  // DP-12 / H-6: FMatrixPrepared latched for the object's lifetime, so
  // re-preparing the same model against changed data drew the stale
  // crosstab. Render twice with one mutated cell; the second capture must
  // differ (pre-fix both captures are identical).
  DS := TClientDataSet.Create(nil);
  try
    DS.FieldDefs.Add('Region', ftString, 20);
    DS.FieldDefs.Add('Product', ftString, 20);
    DS.FieldDefs.Add('Amount', ftFloat);
    DS.CreateDataSet;
    DS.AppendRecord(['East', 'A', 10.0]);
    DS.AppendRecord(['East', 'B', 20.0]);
    DS.AppendRecord(['West', 'A', 30.0]);
    DS.AppendRecord(['West', 'B', 40.0]);
    DS.First;

    CT := TReportCrossTabObject.Create;
    CT.RowField := 'Region';
    CT.ColumnField := 'Product';
    CT.CellField := 'Amount';
    CT.Aggregate := caSum;

    RenderCapturedTwice(DS, CT, Bmp1, Bmp2);
    try
      Assert.IsTrue(BitmapsDiffer(Bmp1, Bmp2),
        'second render must reflect the changed data; identical captures ' +
        'mean the crosstab data cache stayed latched across prepares');
    finally
      Bmp2.Free;
      Bmp1.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TTestReportEngine.Test_ChartCache_ResetBetweenPrepares;
var
  DS: TClientDataSet;
  Chart: TReportChartObject;
  Bmp1, Bmp2: TBitmap;
begin
  // Same contract for TReportChartObject (FDataPrepared latch): bar heights
  // must follow the mutated value in the second render.
  DS := TClientDataSet.Create(nil);
  try
    DS.FieldDefs.Add('Region', ftString, 20);
    DS.FieldDefs.Add('Product', ftString, 20);
    DS.FieldDefs.Add('Amount', ftFloat);
    DS.CreateDataSet;
    DS.AppendRecord(['East', 'A', 10.0]);
    DS.AppendRecord(['East', 'B', 20.0]);
    DS.AppendRecord(['West', 'A', 30.0]);
    DS.AppendRecord(['West', 'B', 40.0]);
    DS.First;

    Chart := TReportChartObject.Create;
    Chart.ChartType := ctBar;
    Chart.DataFieldLabel := 'Product';
    Chart.DataFieldValue := 'Amount';
    Chart.ShowLegend := False;

    RenderCapturedTwice(DS, Chart, Bmp1, Bmp2);
    try
      Assert.IsTrue(BitmapsDiffer(Bmp1, Bmp2),
        'second render must reflect the changed data; identical captures ' +
        'mean the chart data cache stayed latched across prepares');
    finally
      Bmp2.Free;
      Bmp1.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TTestReportEngine.Test_GroupBreak_NullTransitions_Fire;
var
  DS: TClientDataSet;
  Model: TReportModel;
  GH, GF: TReportBand;
  Txt: TReportTextObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Cmd: TReportExportCommand;
  HeaderCount: Integer;
begin
  // DP-16 / M-6: DetectGroupBreak compared 'NewValue <> FLastGroupValues'.
  // With a non-Null stored value and a NULL field the '<>' yields Null
  // (falsy), so value->NULL transitions NEVER fired a group break, and
  // type-flapped values could be coerced-equal. Trace for [NULL,'A',NULL,'B']:
  // pre-fix only the initial open fires (1 header); post-fix all four
  // transitions fire (4 headers, footer between each).
  DS := TClientDataSet.Create(nil);
  try
    DS.FieldDefs.Add('G', ftString, 10);
    DS.CreateDataSet;
    DS.AppendRecord([Null]);
    DS.AppendRecord(['A']);
    DS.AppendRecord([Null]);
    DS.AppendRecord(['B']);
    DS.First;
    // The test is only meaningful if the rows really carry NULL variants.
    Assert.IsTrue(VarIsNull(DS.FieldByName('G').Value), 'fixture row1 must be NULL');
    DS.Next;
    Assert.IsFalse(VarIsNull(DS.FieldByName('G').Value), 'fixture row2 must be ''A''');
    DS.Next;
    Assert.IsTrue(VarIsNull(DS.FieldByName('G').Value), 'fixture row3 must be NULL');
    DS.Next;
    Assert.IsFalse(VarIsNull(DS.FieldByName('G').Value), 'fixture row4 must be ''B''');
    DS.First;

    Model := TReportModel.Create;
    try
      GH := TReportBand.Create;
      GH.BandType := btGroupHeader;
      GH.GroupField := 'G';
      GH.GroupLevel := 0;
      GH.Height := 20;
      Txt := TReportTextObject.Create;
      Txt.Text := 'GRP';
      Txt.Bounds := Rect(10, 2, 100, 18);
      GH.Children.Add(Txt);
      Model.Objects.Add(GH);

      GF := TReportBand.Create;
      GF.BandType := btGroupFooter;
      GF.GroupField := 'G';
      GF.GroupLevel := 0;
      GF.Height := 20;
      Model.Objects.Add(GF);

      Engine := TReportEngine.Create(Model, DS);
      try
        Doc := TReportExportDocument.Create;
        try
          Engine.ExportDocument := Doc;
          Engine.Prepare;

          HeaderCount := 0;
          for Cmd in Doc.Pages[0].Commands do
            if (Cmd is TReportExportTextCommand) and
               (TReportExportTextCommand(Cmd).Text = 'GRP') then
              Inc(HeaderCount);

          Assert.AreEqual(4, HeaderCount,
            'each NULL<->value group transition must fire a header ' +
            '(pre-fix: 1 - value->NULL transitions never broke)');
        finally
          Doc.Free;
        end;
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

{ TUDSFlapHarness }

procedure TUDSFlapHarness.DoFirst(Sender: TObject);
begin
  Row := 0;
end;

procedure TUDSFlapHarness.DoNext(Sender: TObject);
begin
  Inc(Row);
end;

procedure TUDSFlapHarness.DoEof(Sender: TObject; var AEof: Boolean);
begin
  AEof := Row > High(GValues);
end;

procedure TUDSFlapHarness.DoGetValue(Sender: TObject; const AFieldName: string;
  var AValue: Variant);
begin
  if AFieldName = 'G' then
    AValue := GValues[Row];
end;

procedure TTestReportEngine.Test_GroupBreak_TypeFlap_Fires;
var
  UDS: TVittixUserDataSet;
  Harness: TUDSFlapHarness;
  Model: TReportModel;
  GH, GF: TReportBand;
  Txt: TReportTextObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Cmd: TReportExportCommand;
  HeaderCount: Integer;
begin
  // DP-16 / M-6 (the coercion face): DetectGroupBreak compared with
  // '<>', which coerces across variant types - integer 1 and string '1'
  // compared equal, so adjacent rows with type-flapped values silently
  // merged into one group. UDS rows are raw Variants, so this is a
  // realistic host-data shape. VarSameValue compares without coercion.
  Harness := TUDSFlapHarness.Create;
  try
    Harness.Row := 0;
    Harness.GValues := TArray<Variant>.Create(1, '1');  // integer vs string

    UDS := TVittixUserDataSet.Create(nil);
    try
      UDS.OnFirst := Harness.DoFirst;
      UDS.OnNext := Harness.DoNext;
      UDS.OnEof := Harness.DoEof;
      UDS.OnGetValue := Harness.DoGetValue;

      Model := TReportModel.Create;
      try
        GH := TReportBand.Create;
        GH.BandType := btGroupHeader;
        GH.GroupField := 'G';
        GH.GroupLevel := 0;
        GH.Height := 20;
        Txt := TReportTextObject.Create;
        Txt.Text := 'GRP';
        Txt.Bounds := Rect(10, 2, 100, 18);
        GH.Children.Add(Txt);
        Model.Objects.Add(GH);

        GF := TReportBand.Create;
        GF.BandType := btGroupFooter;
        GF.GroupField := 'G';
        GF.GroupLevel := 0;
        GF.Height := 20;
        Model.Objects.Add(GF);

        Engine := TReportEngine.Create(Model, UDS, nil, nil);
        try
          Doc := TReportExportDocument.Create;
          try
            Engine.ExportDocument := Doc;
            Engine.Prepare;

            HeaderCount := 0;
            for Cmd in Doc.Pages[0].Commands do
              if (Cmd is TReportExportTextCommand) and
                 (TReportExportTextCommand(Cmd).Text = 'GRP') then
                Inc(HeaderCount);

            Assert.AreEqual(2, HeaderCount,
              'integer 1 and string ''1'' are distinct group values; ' +
              'pre-fix they coerced equal and merged into one group');
          finally
            Doc.Free;
          end;
        finally
          Engine.Free;
        end;
      finally
        Model.Free;
      end;
    finally
      UDS.Free;
    end;
  finally
    Harness.Free;
  end;
end;

procedure TTestReportEngine.Test_DP18_CrossTabTallerThanBand_NoBleedIntoNextBand;
var
  DS: TClientDataSet;
  Model: TReportModel;
  TitleBand, SummaryBand: TReportBand;
  CT: TReportCrossTabObject;
  Engine: TReportEngine;
  Renderer: TReportRenderer;
  Probe: TBitmap;
  Pw, Ph: Integer;
  PmLeft, PmTop: Integer;
  X, Y: Integer;
  Row: PByteArray;
  Pixel: Cardinal;
  InsideCount, BelowCount: Integer;
begin
  // DP-18 / M-8: the crosstab's prepared matrix is only available during
  // the rendering pass, so the grid can be far taller than the band that
  // hosts it.  Without a clip the grid painted straight over the following
  // band; the fix clips Draw to the object's bounds.
  DS := TClientDataSet.Create(nil);
  try
    DS.FieldDefs.Add('Region', ftString, 20);
    DS.FieldDefs.Add('Product', ftString, 20);
    DS.FieldDefs.Add('Amount', ftFloat);
    DS.CreateDataSet;
    // 8 regions x 2 products -> a 10-row grid, far taller than the 40px
    // band the object sits in and taller than the object's own bounds.
    for var I := 1 to 8 do
    begin
      DS.AppendRecord([Format('R%.2d', [I]), 'A', I * 10.0]);
      DS.AppendRecord([Format('R%.2d', [I]), 'B', I * 20.0]);
    end;
    DS.First;

    Model := TReportModel.Create;
    try
      // Band A: a small title band hosting the over-tall crosstab.
      TitleBand := TReportBand.Create;
      TitleBand.BandType := btReportTitle;
      TitleBand.Height := 40;

      CT := TReportCrossTabObject.Create;
      CT.Name := 'bleedingCrosstab';
      CT.RowField := 'Region';
      CT.ColumnField := 'Product';
      CT.CellField := 'Amount';
      CT.Bounds := Rect(10, 10, 300, 30);
      TitleBand.Children.Add(CT);
      Model.Objects.Add(TitleBand);

      // Band B: an empty summary band directly below band A.  It draws
      // nothing itself, so any non-white pixel in its page area can only be
      // crosstab content that bled out of band A.
      SummaryBand := TReportBand.Create;
      SummaryBand.BandType := btReportSummary;
      SummaryBand.Height := 60;
      Model.Objects.Add(SummaryBand);

      Pw := Model.PageSettings.PageWidth;
      Ph := Model.PageSettings.PageHeight;
      PmLeft := Model.PageSettings.Margins.Left;
      PmTop := Model.PageSettings.Margins.Top;

      Engine := TReportEngine.Create(Model, DS, nil, nil);
      try
        Renderer := TReportRenderer.Create;
        try
          Renderer.Render(Engine, Pw, Ph);
          Assert.IsTrue(Renderer.Pages.Count >= 1, 'report must produce a page');

          Probe := TBitmap.Create;
          try
            Probe.PixelFormat := pf32bit;
            Probe.SetSize(Pw, Ph);
            Probe.Canvas.Brush.Color := clWhite;
            Probe.Canvas.FillRect(Rect(0, 0, Pw, Ph));
            Probe.Canvas.StretchDraw(Rect(0, 0, Pw, Ph),
              Renderer.Pages[0].Metafile);

            // Sanity: the clipped grid must still draw inside the bounds
            // (the fix must clip, not suppress).
            InsideCount := 0;
            for Y := PmTop + 12 to PmTop + 28 do
            begin
              Row := Probe.ScanLine[Y];
              for X := PmLeft + 12 to PmLeft + 288 do
              begin
                Pixel := PCardinal(@Row[X * 4])^ and $00FFFFFF;
                if Pixel <> $00FFFFFF then
                  Inc(InsideCount);
              end;
            end;
            Assert.IsTrue(InsideCount > 0,
              'crosstab grid must still be drawn inside its own bounds');

            // The guard: nothing may appear below band A's bottom edge.
            BelowCount := 0;
            for Y := PmTop + TitleBand.Height + 2 to Ph - 1 do
            begin
              Row := Probe.ScanLine[Y];
              for X := 0 to Pw - 1 do
              begin
                Pixel := PCardinal(@Row[X * 4])^ and $00FFFFFF;
                if Pixel <> $00FFFFFF then
                  Inc(BelowCount);
              end;
            end;
            Assert.AreEqual(0, BelowCount,
              Format('crosstab content must not bleed below its band ' +
                '(%d non-white pixel(s) found below band A)', [BelowCount]));
          finally
            Probe.Free;
          end;
        finally
          Renderer.Free;
        end;
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TTestReportEngine.Test_DP29_RowScopedAggregates_DoNotGrowCache;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Context: TExpressionContext;
  I: Integer;
  V: Variant;
  Snapshot: TReportTraversalSnapshot;
begin
  // DP-29 / M-3: a per-row aggregate evaluation used to append one cache
  // entry per row (each with a distinct RowNumber - never reusable by the
  // next row), so a 10k-row pass left 10k entries and quadratic match
  // scans behind it.  Row-scoped duplicates must collapse to a single
  // entry instead.
  DS := TClientDataSet.Create(nil);
  try
    DS.FieldDefs.Add('Amount', ftFloat);
    DS.CreateDataSet;
    for I := 1 to 24 do
      DS.AppendRecord([I * 10.0]);
    DS.First;

    Model := TReportModel.Create;
    try
      Engine := TReportEngine.Create(Model, DS, nil, nil);
      try
        Context := Default(TExpressionContext);
        Context.DataSet := DS;
        Context.Hooks := Engine;
        Context.Parameters := Engine.Parameters;
        Context.Variables := Model.Variables;

        TReportTraversalDiagnostics.Reset;
        V := Null;
        for I := 1 to 10000 do
        begin
          Context.RowNumber := I;
          V := TReportExpression.Evaluate('SUM([Amount])', Context);
        end;
        Snapshot := TReportTraversalDiagnostics.Snapshot;

        Assert.AreEqual(3000.0, Double(V), 0.0001, 'sum of 10..240');
        Assert.AreEqual(10000, Snapshot.AggregateEvaluations,
          'all row-scoped evaluations must run');
        Assert.IsTrue(Snapshot.AggregateCacheEntries <= 64,
          Format('row-scoped re-evaluations must not accumulate cache ' +
            'entries (%d after 10000 rows)',
            [Snapshot.AggregateCacheEntries]));

        // The collapsed entry still serves its row: re-evaluating in the
        // newest row context must be a cache hit.
        TReportTraversalDiagnostics.Reset;
        V := TReportExpression.Evaluate('SUM([Amount])', Context);
        Snapshot := TReportTraversalDiagnostics.Snapshot;
        Assert.AreEqual(1, Snapshot.AggregateCacheHits,
          'the same-row re-evaluation must be served from the cache');
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TTestReportEngine.Test_DP29_AggregateCache_CapEnforced_FIFO;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Context: TExpressionContext;
  Variables: TStringList;
  I: Integer;
  V: Variant;
  Snapshot: TReportTraversalSnapshot;
begin
  // DP-29 / M-3: entries that legitimately differ (here: a distinct
  // variable text per evaluation) must still be bounded - the oldest
  // entries fall off first once the cache cap is reached.
  DS := TClientDataSet.Create(nil);
  try
    DS.FieldDefs.Add('Amount', ftFloat);
    DS.CreateDataSet;
    DS.AppendRecord([10.0]);
    DS.First;

    Model := TReportModel.Create;
    try
      Engine := TReportEngine.Create(Model, DS, nil, nil);
      try
        Variables := TStringList.Create;
        try
          Context := Default(TExpressionContext);
          Context.DataSet := DS;
          Context.Hooks := Engine;
          Context.Parameters := Engine.Parameters;
          Context.Variables := Variables;

          TReportTraversalDiagnostics.Reset;
          V := Null;
          for I := 1 to 5000 do
          begin
            Variables.Values['Iter'] := IntToStr(I);
            V := TReportExpression.Evaluate('SUM([Amount])', Context);
          end;
          Snapshot := TReportTraversalDiagnostics.Snapshot;

          Assert.AreEqual(10.0, Double(V), 0.0001);
          Assert.AreEqual(4096, Snapshot.AggregateCacheEntries,
            Format('the aggregate cache must be capped at 4096 entries ' +
              '(got %d after 5000 distinct evaluations)',
              [Snapshot.AggregateCacheEntries]));
        finally
          Variables.Free;
        end;
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestReportEngine);

end.
