unit Vittix.Report.Objects.CrossTab;

interface

uses
  System.Classes,
  System.Types,
  System.SysUtils,
  System.Variants,
  System.Generics.Collections,
  Vcl.Graphics,
  Data.DB,
  Vittix.Report.Objects,
  Vittix.Report.Context;

type
  TCrossTabAggregate = (caSum, caCount, caMin, caMax, caAverage, caNone);

  TReportCrossTabObject = class(TReportObject)
  private
    FDataSetName: string;
    FRowField: string;
    FColumnField: string;
    FCellField: string;
    FAggregate: TCrossTabAggregate;
    FShowRowGrandTotals: Boolean;
    FShowColGrandTotals: Boolean;
    FGridColor: TColor;
    FHeaderColor: TColor;
    FFont: TFont;
    FHeaderFont: TFont;
    FCellFormat: string;

    FMatrixPrepared: Boolean;
    FRowValues: TList<Variant>;
    FColValues: TList<Variant>;
    // Key: <RowIndex>_<ColIndex> -> Variant (Value)
    FMatrixData: TDictionary<string, Variant>;
    // Key: <RowIndex> or <ColIndex>
    FRowTotals: TDictionary<Integer, Variant>;
    FColTotals: TDictionary<Integer, Variant>;
    FGrandTotal: Variant;
    FCounts: TDictionary<string, Integer>; // Used for Averages

    procedure SetFont(const Value: TFont);
    procedure SetHeaderFont(const Value: TFont);

    procedure ClearMatrix;
    function ResolveDataSet(const Context: TExpressionContext): TDataSet;
    procedure PrepareMatrix(const Context: TExpressionContext);
    
    procedure AggregateValue(AValue: Variant; var ACurrent: Variant; var ACount: Integer);
    function FormatCell(const AValue: Variant): string;
  public
    constructor Create; override;
    destructor Destroy; override;
    
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    function MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer; override;
    
    class function DisplayName: string; override;
  published
    property DataSetName: string read FDataSetName write FDataSetName;
    property RowField: string read FRowField write FRowField;
    property ColumnField: string read FColumnField write FColumnField;
    property CellField: string read FCellField write FCellField;
    property Aggregate: TCrossTabAggregate read FAggregate write FAggregate default caSum;
    property ShowRowGrandTotals: Boolean read FShowRowGrandTotals write FShowRowGrandTotals default True;
    property ShowColGrandTotals: Boolean read FShowColGrandTotals write FShowColGrandTotals default True;
    property GridColor: TColor read FGridColor write FGridColor default clGray;
    property HeaderColor: TColor read FHeaderColor write FHeaderColor default $00F0F0F0;
    property Font: TFont read FFont write SetFont;
    property HeaderFont: TFont read FHeaderFont write SetHeaderFont;
    property CellFormat: string read FCellFormat write FCellFormat;
  end;

implementation

uses
  System.Math,
  System.Generics.Defaults,
  Vittix.Report.Expressions;

{ TReportCrossTabObject }

constructor TReportCrossTabObject.Create;
begin
  inherited;
  Bounds := Rect(10, 10, 300, 150);
  FAggregate := caSum;
  FShowRowGrandTotals := True;
  FShowColGrandTotals := True;
  FGridColor := clGray;
  FHeaderColor := $00F0F0F0;
  
  FFont := TFont.Create;
  FFont.Name := 'Arial';
  FFont.Size := 9;
  
  FHeaderFont := TFont.Create;
  FHeaderFont.Name := 'Arial';
  FHeaderFont.Size := 9;
  FHeaderFont.Style := [fsBold];
  
  FRowValues := TList<Variant>.Create;
  FColValues := TList<Variant>.Create;
  FMatrixData := TDictionary<string, Variant>.Create;
  FRowTotals := TDictionary<Integer, Variant>.Create;
  FColTotals := TDictionary<Integer, Variant>.Create;
  FCounts := TDictionary<string, Integer>.Create;
  FMatrixPrepared := False;
end;

destructor TReportCrossTabObject.Destroy;
begin
  FFont.Free;
  FHeaderFont.Free;
  FRowValues.Free;
  FColValues.Free;
  FMatrixData.Free;
  FRowTotals.Free;
  FColTotals.Free;
  FCounts.Free;
  inherited;
end;

procedure TReportCrossTabObject.SetFont(const Value: TFont);
begin
  FFont.Assign(Value);
end;

procedure TReportCrossTabObject.SetHeaderFont(const Value: TFont);
begin
  FHeaderFont.Assign(Value);
end;

class function TReportCrossTabObject.DisplayName: string;
begin
  Result := 'Cross-Tab';
end;

procedure TReportCrossTabObject.ClearMatrix;
begin
  FRowValues.Clear;
  FColValues.Clear;
  FMatrixData.Clear;
  FRowTotals.Clear;
  FColTotals.Clear;
  FCounts.Clear;
  FGrandTotal := Null;
  FMatrixPrepared := False;
end;

function TReportCrossTabObject.ResolveDataSet(const Context: TExpressionContext): TDataSet;
begin
  Result := Context.DataSet; // Default fallback
  if FDataSetName <> '' then
  begin
    if Assigned(Context.Hooks) then
      Result := Context.Hooks.GetNamedDataSet(FDataSetName);
  end;
end;

procedure TReportCrossTabObject.AggregateValue(AValue: Variant; var ACurrent: Variant; var ACount: Integer);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then Exit;
  
  case FAggregate of
    caSum, caAverage:
      begin
        if VarIsNull(ACurrent) then
          ACurrent := AValue
        else
          ACurrent := ACurrent + AValue;
        Inc(ACount);
      end;
    caCount:
      begin
        if VarIsNull(ACurrent) then
          ACurrent := 1
        else
          ACurrent := ACurrent + 1;
      end;
    caMin:
      begin
        if VarIsNull(ACurrent) then
          ACurrent := AValue
        else if AValue < ACurrent then
          ACurrent := AValue;
      end;
    caMax:
      begin
        if VarIsNull(ACurrent) then
          ACurrent := AValue
        else if AValue > ACurrent then
          ACurrent := AValue;
      end;
    caNone:
      ACurrent := AValue;
  end;
end;

procedure TReportCrossTabObject.PrepareMatrix(const Context: TExpressionContext);
var
  DS: TDataSet;
  RowVal, ColVal, CellVal: Variant;
  BM: TBookmark;
  RowIdx, ColIdx: Integer;
  Key: string;
  CurVal: Variant;
  CurCount: Integer;
begin
  if FMatrixPrepared then Exit;
  ClearMatrix;
  
  if (FRowField = '') or (FColumnField = '') or (FCellField = '') then
  begin
    FMatrixPrepared := True;
    Exit;
  end;
  
  DS := ResolveDataSet(Context);
  if not Assigned(DS) or not DS.Active then
  begin
    FMatrixPrepared := True;
    Exit;
  end;
  
  BM := DS.GetBookmark;
  DS.DisableControls;
  try
    DS.First;
    while not DS.Eof do
    begin
      RowVal := DS.FieldByName(FRowField).Value;
      ColVal := DS.FieldByName(FColumnField).Value;
      CellVal := DS.FieldByName(FCellField).Value;
      
      if VarIsNull(RowVal) then RowVal := '(Null)';
      if VarIsNull(ColVal) then ColVal := '(Null)';
      
      RowIdx := FRowValues.IndexOf(RowVal);
      if RowIdx < 0 then
      begin
        RowIdx := FRowValues.Add(RowVal);
      end;
      
      ColIdx := FColValues.IndexOf(ColVal);
      if ColIdx < 0 then
      begin
        ColIdx := FColValues.Add(ColVal);
      end;
      
      Key := IntToStr(RowIdx) + '_' + IntToStr(ColIdx);
      if FMatrixData.TryGetValue(Key, CurVal) then
        FCounts.TryGetValue(Key, CurCount)
      else
      begin
        CurVal := Null;
        CurCount := 0;
      end;
      
      AggregateValue(CellVal, CurVal, CurCount);
      FMatrixData.AddOrSetValue(Key, CurVal);
      FCounts.AddOrSetValue(Key, CurCount);
      
      if FRowTotals.TryGetValue(RowIdx, CurVal) then
        FCounts.TryGetValue('R' + IntToStr(RowIdx), CurCount)
      else
      begin
        CurVal := Null;
        CurCount := 0;
      end;
      AggregateValue(CellVal, CurVal, CurCount);
      FRowTotals.AddOrSetValue(RowIdx, CurVal);
      FCounts.AddOrSetValue('R' + IntToStr(RowIdx), CurCount);
      
      if FColTotals.TryGetValue(ColIdx, CurVal) then
        FCounts.TryGetValue('C' + IntToStr(ColIdx), CurCount)
      else
      begin
        CurVal := Null;
        CurCount := 0;
      end;
      AggregateValue(CellVal, CurVal, CurCount);
      FColTotals.AddOrSetValue(ColIdx, CurVal);
      FCounts.AddOrSetValue('C' + IntToStr(ColIdx), CurCount);
      
      CurCount := 0;
      FCounts.TryGetValue('G', CurCount);
      AggregateValue(CellVal, FGrandTotal, CurCount);
      FCounts.AddOrSetValue('G', CurCount);

      DS.Next;
    end;
  finally
    if FAggregate = caAverage then
    begin
      for Key in FMatrixData.Keys do
      begin
        if FCounts.TryGetValue(Key, CurCount) and (CurCount > 0) then
          FMatrixData[Key] := FMatrixData[Key] / CurCount;
      end;
      for RowIdx in FRowTotals.Keys do
      begin
        if FCounts.TryGetValue('R' + IntToStr(RowIdx), CurCount) and (CurCount > 0) then
          FRowTotals[RowIdx] := FRowTotals[RowIdx] / CurCount;
      end;
      for ColIdx in FColTotals.Keys do
      begin
        if FCounts.TryGetValue('C' + IntToStr(ColIdx), CurCount) and (CurCount > 0) then
          FColTotals[ColIdx] := FColTotals[ColIdx] / CurCount;
      end;
      if FCounts.TryGetValue('G', CurCount) and (CurCount > 0) then
        FGrandTotal := FGrandTotal / CurCount;
    end;
    
    // Sort axes natively using variants
    FRowValues.Sort(TComparer<Variant>.Default);
    FColValues.Sort(TComparer<Variant>.Default);

    if DS.BookmarkValid(BM) then
      DS.GotoBookmark(BM);
    DS.FreeBookmark(BM);
    DS.EnableControls;
  end;
  
  FMatrixPrepared := True;
end;

function TReportCrossTabObject.FormatCell(const AValue: Variant): string;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit('');
    
  if FCellFormat <> '' then
  begin
    try
      if VarType(AValue) in [varDouble, varSingle, varCurrency, varInteger, varSmallint, varShortInt, varByte, varWord, varLongWord, varInt64] then
        Result := FormatFloat(FCellFormat, AValue)
      else
        Result := VarToStrDef(AValue, '');
    except
      Result := VarToStrDef(AValue, '');
    end;
  end
  else
    Result := VarToStrDef(AValue, '');
end;

function TReportCrossTabObject.MeasuredBottom(C: TCanvas; const Context: TExpressionContext): Integer;
var
  TotalRows: Integer;
  RowHeight: Integer;
begin
  if not Context.IsCountingPass then
    PrepareMatrix(Context);
    
  TotalRows := 1; 
  TotalRows := TotalRows + Max(1, FRowValues.Count);
  if FShowColGrandTotals then
    Inc(TotalRows);
    
  C.Font.Assign(FFont);
  RowHeight := C.TextHeight('Wg') + 8;
  
  Result := Bounds.Top + (TotalRows * RowHeight);
end;

procedure TReportCrossTabObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  TotalRows, TotalCols: Integer;
  RowHeight, ColWidth: Integer;
  DrawRect: TRect;
  R, C_Idx: Integer;
  Y, X: Integer;
  ValStr: string;
  V: Variant;
  CellRect: TRect;
  TextX, TextY: Integer;
begin
  if not Context.IsCountingPass then
    PrepareMatrix(Context);
    
  C.Font.Assign(FFont);
  RowHeight := C.TextHeight('Wg') + 8;
  
  TotalRows := 1 + Max(1, FRowValues.Count);
  if FShowColGrandTotals then Inc(TotalRows);
  
  TotalCols := 1 + Max(1, FColValues.Count);
  if FShowRowGrandTotals then Inc(TotalCols);
  
  DrawRect := Bounds;
  DrawRect.Bottom := DrawRect.Top + (TotalRows * RowHeight);
  ColWidth := Max(30, (DrawRect.Right - DrawRect.Left) div TotalCols);
  DrawRect.Right := DrawRect.Left + (TotalCols * ColWidth);
  
  C.Brush.Style := bsSolid;
  C.Brush.Color := clWhite;
  C.FillRect(DrawRect);
  
  C.Pen.Color := FGridColor;
  C.Pen.Style := psSolid;
  C.Pen.Width := 1;
  
  Y := DrawRect.Top;
  for R := 0 to TotalRows - 1 do
  begin
    X := DrawRect.Left;
    for C_Idx := 0 to TotalCols - 1 do
    begin
      CellRect := Rect(X, Y, X + ColWidth, Y + RowHeight);
      
      if (R = 0) or (C_Idx = 0) or (R = TotalRows - 1) and FShowColGrandTotals or (C_Idx = TotalCols - 1) and FShowRowGrandTotals then
      begin
        C.Brush.Color := FHeaderColor;
        C.FillRect(CellRect);
        C.Font.Assign(FHeaderFont);
      end
      else
      begin
        C.Brush.Color := clWhite;
        C.Font.Assign(FFont);
      end;
      
      C.Brush.Style := bsClear;
      C.Rectangle(CellRect);
      
      ValStr := '';
      if (R = 0) and (C_Idx = 0) then
        ValStr := ''
      else if (R = 0) and (C_Idx < TotalCols - 1 - Ord(FShowRowGrandTotals) + 1) then
      begin
        if C_Idx - 1 < FColValues.Count then
          ValStr := VarToStrDef(FColValues[C_Idx - 1], '')
        else
          ValStr := '';
      end
      else if (C_Idx = 0) and (R < TotalRows - 1 - Ord(FShowColGrandTotals) + 1) then
      begin
        if R - 1 < FRowValues.Count then
          ValStr := VarToStrDef(FRowValues[R - 1], '')
        else
          ValStr := '';
      end
      else if (R = 0) and FShowRowGrandTotals and (C_Idx = TotalCols - 1) then
        ValStr := 'Grand Total'
      else if (C_Idx = 0) and FShowColGrandTotals and (R = TotalRows - 1) then
        ValStr := 'Grand Total'
      else if FShowRowGrandTotals and FShowColGrandTotals and (R = TotalRows - 1) and (C_Idx = TotalCols - 1) then
        ValStr := FormatCell(FGrandTotal)
      else if FShowRowGrandTotals and (C_Idx = TotalCols - 1) then
      begin
        if FRowTotals.TryGetValue(R - 1, V) then ValStr := FormatCell(V);
      end
      else if FShowColGrandTotals and (R = TotalRows - 1) then
      begin
        if FColTotals.TryGetValue(C_Idx - 1, V) then ValStr := FormatCell(V);
      end
      else
      begin
        if FMatrixData.TryGetValue(IntToStr(R - 1) + '_' + IntToStr(C_Idx - 1), V) then
          ValStr := FormatCell(V);
      end;
      
      if ValStr <> '' then
      begin
        TextX := CellRect.Left + 4;
        TextY := CellRect.Top + 4;
        C.TextOut(TextX, TextY, ValStr);
      end;
      
      Inc(X, ColWidth);
    end;
    Inc(Y, RowHeight);
  end;
  
  if Selected then
    DrawSelection(C);
end;

initialization
  RegisterReportObject(TReportCrossTabObject);

end.
