unit Test.Vittix.Report.Objects.CrossTab;

{
  Test.Vittix.Report.Objects.CrossTab
  ===================================
  Crash-hardening tests for TReportCrossTabObject (DP-11/H-5).

  PrepareMatrix used DS.FieldByName per record (raises EDatabaseError on a
  typo'd field) and aggregated cell values with unguarded Variant arithmetic
  (a non-numeric cell among numeric ones raises on '+' / '/'), so one bad
  field name or one messy cell aborted the whole report render.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Context,
  Vittix.Report.Objects,
  Vittix.Report.Objects.CrossTab;

type
  [TestFixture]
  TTestCrossTabHardening = class
  private
    function CreateNumericDS: TClientDataSet;
    function CreateMessyCellDS: TClientDataSet;
    procedure RenderCrossTab(ACT: TReportCrossTabObject; ADS: TDataSet;
      out ABmp: TBitmap);
    class function BitmapsDiffer(const A, B: TBitmap): Boolean;
  public
    [Test]
    procedure Test_MissingCellField_DoesNotRaise;
    [Test]
    procedure Test_TextCells_WithAverage_DoesNotRaise;
    [Test]
    procedure Test_NumericHappyPath_DrawsPopulatedGrid;
  end;

implementation

{ TTestCrossTabHardening }

function TTestCrossTabHardening.CreateNumericDS: TClientDataSet;
begin
  // 2 regions x 2 products, numeric amounts.
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('Region', ftString, 20);
  Result.FieldDefs.Add('Product', ftString, 20);
  Result.FieldDefs.Add('Amount', ftFloat);
  Result.CreateDataSet;
  Result.AppendRecord(['East', 'A', 10.0]);
  Result.AppendRecord(['East', 'B', 20.0]);
  Result.AppendRecord(['West', 'A', 30.0]);
  Result.AppendRecord(['West', 'B', 40.0]);
  Result.First;
end;

function TTestCrossTabHardening.CreateMessyCellDS: TClientDataSet;
begin
  // Real-world messy data: a text column aggregated as a number. Pre-fix,
  // caSum silently concatenated ('N/A'+'5'+'7' -> 'N/A57') and caAverage
  // then raised on the finalize division (string / count), aborting the
  // render. caAverage gives the reproducible raise.
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('Region', ftString, 20);
  Result.FieldDefs.Add('Product', ftString, 20);
  Result.FieldDefs.Add('Amount', ftString, 20);
  Result.CreateDataSet;
  Result.AppendRecord(['East', 'A', 'N/A']);
  Result.AppendRecord(['East', 'B', '5']);
  Result.AppendRecord(['West', 'A', '7']);
  Result.First;
end;

procedure TTestCrossTabHardening.RenderCrossTab(ACT: TReportCrossTabObject;
  ADS: TDataSet; out ABmp: TBitmap);
var
  Ctx: TExpressionContext;
begin
  ABmp := TBitmap.Create;
  try
    ABmp.PixelFormat := pf32bit;
    ABmp.SetSize(320, 200);
    ABmp.Canvas.Brush.Color := clWhite;
    ABmp.Canvas.FillRect(Rect(0, 0, ABmp.Width, ABmp.Height));

    ACT.Bounds := Rect(10, 10, 310, 190);
    Ctx := Default(TExpressionContext);
    Ctx.DataSet := ADS;
    ACT.Draw(ABmp.Canvas, Ctx);
  except
    ABmp.Free;
    raise;
  end;
end;

class function TTestCrossTabHardening.BitmapsDiffer(const A, B: TBitmap): Boolean;
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

procedure TTestCrossTabHardening.Test_MissingCellField_DoesNotRaise;
var
  DS: TClientDataSet;
  ACT: TReportCrossTabObject;
  Bmp: TBitmap;
begin
  // Pre-fix: DS.FieldByName('NoSuchField') raised EDatabaseError on the
  // first record, aborting the whole report render. The hardened crosstab
  // renders an empty table instead (with a DEBUG diagnostic).
  DS := CreateNumericDS;
  try
    ACT := TReportCrossTabObject.Create;
    try
      ACT.RowField := 'Region';
      ACT.ColumnField := 'Product';
      ACT.CellField := 'NoSuchField';
      ACT.Aggregate := caSum;

      RenderCrossTab(ACT, DS, Bmp);
      try
        Assert.IsTrue(Assigned(Bmp), 'render must complete with a missing cell field');
      finally
        Bmp.Free;
      end;
    finally
      ACT.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TTestCrossTabHardening.Test_TextCells_WithAverage_DoesNotRaise;
var
  DS: TClientDataSet;
  ACT: TReportCrossTabObject;
  Bmp: TBitmap;
begin
  // Pre-fix: AggregateValue concatenated the text cells, then the caAverage
  // finalize divided the concatenated string by the count, raising a
  // variant-conversion error that aborted the render. Non-numeric cells
  // must be skipped (and counted for the DEBUG diagnostic), not fatal.
  DS := CreateMessyCellDS;
  try
    ACT := TReportCrossTabObject.Create;
    try
      ACT.RowField := 'Region';
      ACT.ColumnField := 'Product';
      ACT.CellField := 'Amount';
      ACT.Aggregate := caAverage;

      RenderCrossTab(ACT, DS, Bmp);
      try
        Assert.IsTrue(Assigned(Bmp), 'render must complete with non-numeric cells');
      finally
        Bmp.Free;
      end;
    finally
      ACT.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TTestCrossTabHardening.Test_NumericHappyPath_DrawsPopulatedGrid;
var
  DS: TClientDataSet;
  ACTGood, ACTMissing: TReportCrossTabObject;
  BmpGood, BmpMissing: TBitmap;
begin
  // Regression guard: the hardened field resolution must not change the
  // populated output. A fully-resolving crosstab draws MORE content than
  // the empty table a missing field yields - the renders must differ.
  DS := CreateNumericDS;
  try
    ACTGood := TReportCrossTabObject.Create;
    try
      ACTGood.RowField := 'Region';
      ACTGood.ColumnField := 'Product';
      ACTGood.CellField := 'Amount';
      ACTGood.Aggregate := caSum;
      RenderCrossTab(ACTGood, DS, BmpGood);
      try
        ACTMissing := TReportCrossTabObject.Create;
        try
          ACTMissing.RowField := 'Region';
          ACTMissing.ColumnField := 'Product';
          ACTMissing.CellField := 'NoSuchField';
          ACTMissing.Aggregate := caSum;
          RenderCrossTab(ACTMissing, DS, BmpMissing);
          try
            Assert.IsTrue(BitmapsDiffer(BmpGood, BmpMissing),
              'the populated numeric crosstab must render content the ' +
              'empty (missing-field) table does not have');
          finally
            BmpMissing.Free;
          end;
        finally
          ACTMissing.Free;
        end;
      finally
        BmpGood.Free;
      end;
    finally
      ACTGood.Free;
    end;
  finally
    DS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCrossTabHardening);

end.
