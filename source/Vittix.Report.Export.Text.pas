unit Vittix.Report.Export.Text;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.UserDataSet;

type
  TReportTextExporter = class
  public
    class procedure ExportToFile(
      AReport: TReportModel;
      ADataSet: TDataSet;
      ANamedDataSets: TDictionary<string, TDataSet>;
      AParameters: TStrings;
      const AFileName: string);
    class procedure ExportUserDataSetToFile(
      AReport: TReportModel;
      AUserDataSet: TVittixUserDataSet;
      ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
      AParameters: TStrings;
      const AFileName: string);
  end;

implementation

uses
  System.SysUtils,
  System.Variants,
  System.Generics.Defaults,
  Vittix.Report.Bands,
  Vittix.Report.Context,
  Vittix.Report.Expressions,
  Vittix.Report.Expression.Mode,
  Vittix.Report.Objects,
  Vittix.Report.Utils;

function ObjectSortComparer: IComparer<TReportObject>;
begin
  Result := TComparer<TReportObject>.Construct(
    function(const L, R: TReportObject): Integer
    begin
      Result := L.Bounds.Top - R.Bounds.Top;
      if Result = 0 then
        Result := L.Bounds.Left - R.Bounds.Left;
    end);
end;

function ShouldExportObject(AObject: TReportObject; const AContext: TExpressionContext): Boolean;
var
  V: Variant;
begin
  Result := Assigned(AObject) and AObject.Visible;
  if not Result or (Trim(AObject.PrintWhen) = '') then
    Exit;

  try
    V := TReportExpression.Evaluate(AObject.PrintWhen, AContext);
    Result := ConditionVariantToBool(V);
  except
    Result := False;
  end;
end;

function TextObjectValue(AObject: TReportTextObject; const AContext: TExpressionContext): string;
begin
  Result := '';
  if not Assigned(AObject) then
    Exit;

  if Trim(AObject.Expression) <> '' then
    Result := VarToStr(TReportExpression.Evaluate(AObject.Expression, AContext))
  else if Trim(AObject.DataField) <> '' then
  begin
    if (AContext.UserDataSet is TVittixUserDataSet) and
       TVittixUserDataSet(AContext.UserDataSet).Active then
      Result := VarToStr(TVittixUserDataSet(AContext.UserDataSet).GetValue(AObject.DataField))
    else if Assigned(AContext.DataSet) and AContext.DataSet.Active then
      Result := SafeFieldAsString(AContext.DataSet, AObject.DataField);
  end
  else
    Result := AObject.Text;
end;

function ResolveBandDataSet(
  ABand: TReportBand;
  APrimary: TDataSet;
  ANamedDataSets: TDictionary<string, TDataSet>): TDataSet;
begin
  Result := APrimary;
  if not Assigned(ABand) or (Trim(ABand.DataSetName) = '') then
    Exit;

  if Assigned(ANamedDataSets) and
     ANamedDataSets.TryGetValue(ABand.DataSetName, Result) then
    Exit;

  Result := nil;
end;

function CaptureBookmark(ADataSet: TDataSet; out ABookmark: TBookmark): Boolean;
begin
  ABookmark := nil;
  Result := Assigned(ADataSet) and DataSetSupportsBookmarks(ADataSet);
  if Result then
    ABookmark := ADataSet.GetBookmark;
end;

procedure RestoreBookmark(ADataSet: TDataSet; ABookmark: TBookmark;
  AHasBookmark: Boolean);
begin
  if not AHasBookmark then
    Exit;

  if Assigned(ADataSet) and (ABookmark <> nil) and ADataSet.BookmarkValid(ABookmark) then
    ADataSet.GotoBookmark(ABookmark);
  if Assigned(ADataSet) and (ABookmark <> nil) then
    ADataSet.FreeBookmark(ABookmark);
end;

procedure AppendBandText(
  ALines: TStrings;
  ABand: TReportBand;
  const AContext: TExpressionContext);
var
  Objects: TList<TReportObject>;
  Obj: TReportObject;
  Value: string;
  Row: string;
begin
  if not Assigned(ABand) or not ABand.Visible then
    Exit;

  Objects := TList<TReportObject>.Create;
  try
    for Obj in ABand.Children do
      Objects.Add(Obj);
    Objects.Sort(ObjectSortComparer);

    Row := '';
    for Obj in Objects do
    begin
      if not ShouldExportObject(Obj, AContext) then
        Continue;

      if Obj is TReportTextObject then
        Value := Trim(TextObjectValue(TReportTextObject(Obj), AContext))
      else
        Value := '';

      if Value = '' then
        Continue;

      if Row <> '' then
        Row := Row + #9;
      Row := Row + Value;
    end;

    if Row <> '' then
      ALines.Add(Row);
  finally
    Objects.Free;
  end;
end;

function ResolveBandUserDataSet(
  ABand: TReportBand;
  APrimary: TVittixUserDataSet;
  ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>): TVittixUserDataSet;
begin
  Result := APrimary;
  if not Assigned(ABand) or (Trim(ABand.DataSetName) = '') then
    Exit;

  if Assigned(ANamedUserDataSets) and
     ANamedUserDataSets.TryGetValue(ABand.DataSetName, Result) then
    Exit;

  Result := nil;
end;

function WrappedUserDataSet(AUserDataSet: TVittixUserDataSet): TDataSet;
begin
  Result := nil;
  if Assigned(AUserDataSet) and
     not Assigned(AUserDataSet.OnFirst) and
     not Assigned(AUserDataSet.OnNext) and
     not Assigned(AUserDataSet.OnEof) and
     Assigned(AUserDataSet.DataSet) and
     AUserDataSet.DataSet.Active then
    Result := AUserDataSet.DataSet;
end;

procedure AppendDetailBands(
  ALines: TStrings;
  AReport: TReportModel;
  APrimary: TDataSet;
  ANamedDataSets: TDictionary<string, TDataSet>;
  APrimaryUDS: TVittixUserDataSet;
  ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
  const ABaseContext: TExpressionContext);
var
  Obj: TReportObject;
  Band: TReportBand;
  DetailDS: TDataSet;
  DetailUDS: TVittixUserDataSet;
  WrappedDS: TDataSet;
  MasterFld: TField;
  DetailFld: TField;
  MasterValue: Variant;
  DetailValue: Variant;
  HasMasterLink: Boolean;
  Ctx: TExpressionContext;
  SaveBM: TBookmark;
  HasSaveBM: Boolean;
begin
  for Obj in AReport.Objects do
  begin
    if not (Obj is TReportBand) then
      Continue;

    Band := TReportBand(Obj);
    if Band.BandType <> btDetail then
      Continue;

    DetailUDS := nil;
    if Assigned(APrimaryUDS) or Assigned(ANamedUserDataSets) then
      DetailUDS := ResolveBandUserDataSet(Band, APrimaryUDS, ANamedUserDataSets);

    if Assigned(DetailUDS) and DetailUDS.Active then
    begin
      WrappedDS := WrappedUserDataSet(DetailUDS);
      HasSaveBM := False;
      SaveBM := nil;
      if Assigned(WrappedDS) then
      begin
        HasSaveBM := CaptureBookmark(WrappedDS, SaveBM);
        WrappedDS.DisableControls;
      end;
      try
        HasMasterLink := (Band.MasterField <> '') and (Band.DetailField <> '');
        if HasMasterLink then
        begin
          if Assigned(APrimaryUDS) and APrimaryUDS.Active then
            MasterValue := APrimaryUDS.GetValue(Band.MasterField)
          else if Assigned(APrimary) and APrimary.Active and
                  TryGetField(APrimary, Band.MasterField, MasterFld) then
            MasterValue := MasterFld.Value
          else
            HasMasterLink := False;
        end
        else
          MasterValue := Null;

        DetailUDS.First;
        while not DetailUDS.Eof do
        begin
          if HasMasterLink then
            DetailValue := DetailUDS.GetValue(Band.DetailField)
          else
            DetailValue := Null;

          if (not HasMasterLink) or
             (not VarIsNull(MasterValue) and not VarIsNull(DetailValue) and
              VarSameValue(DetailValue, MasterValue)) then
          begin
            Ctx := ABaseContext;
            Ctx.DataSet := nil;
            Ctx.UserDataSet := DetailUDS;
            AppendBandText(ALines, Band, Ctx);
          end;
          DetailUDS.Next;
        end;
      finally
        if Assigned(WrappedDS) then
        begin
          RestoreBookmark(WrappedDS, SaveBM, HasSaveBM);
          WrappedDS.EnableControls;
        end;
      end;
      Continue;
    end;

    DetailDS := ResolveBandDataSet(Band, APrimary, ANamedDataSets);
    if not Assigned(DetailDS) or not DetailDS.Active then
      Continue;

    HasSaveBM := CaptureBookmark(DetailDS, SaveBM);
    DetailDS.DisableControls;
    try
      HasMasterLink :=
        Assigned(APrimary) and APrimary.Active and
        (Band.MasterField <> '') and (Band.DetailField <> '') and
        TryGetField(APrimary, Band.MasterField, MasterFld) and
        TryGetField(DetailDS, Band.DetailField, DetailFld);

      if HasMasterLink then
        MasterValue := MasterFld.Value
      else
        MasterValue := Null;

      DetailDS.First;
      while not DetailDS.Eof do
      begin
        if (not HasMasterLink) or VarSameValue(DetailFld.Value, MasterValue) then
        begin
          Ctx := ABaseContext;
          Ctx.DataSet := DetailDS;
          Ctx.UserDataSet := nil;
          AppendBandText(ALines, Band, Ctx);
        end;
        DetailDS.Next;
      end;
    finally
      RestoreBookmark(DetailDS, SaveBM, HasSaveBM);
      DetailDS.EnableControls;
    end;
  end;
end;

procedure ExportToFileCore(
  AReport: TReportModel;
  ADataSet: TDataSet;
  ANamedDataSets: TDictionary<string, TDataSet>;
  AUserDataSet: TVittixUserDataSet;
  ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
  AParameters: TStrings;
  const AFileName: string);
var
  Lines: TStringList;
  Obj: TReportObject;
  Band: TReportBand;
  Ctx: TExpressionContext;
  RowNumber: Integer;
  SaveBM: TBookmark;
  HasSaveBM: Boolean;
  WrappedDS: TDataSet;
begin
  if not Assigned(AReport) then
    raise Exception.Create('Report model is not assigned.');

  Lines := TStringList.Create;
  try
    Ctx := Default(TExpressionContext);
    Ctx.ExpressionMode := emLegacy;
    if TReportExpression.ModeFromLanguageVersion(
      AReport.ExpressionLanguageVersion, Ctx.ExpressionMode) = False then
      Ctx.ExpressionMode := emLegacy; // unsupported -> safe legacy default
    Ctx.DataSet := ADataSet;
    Ctx.UserDataSet := AUserDataSet;
    Ctx.PageNumber := 1;
    Ctx.ReportTitle := AReport.Title;
    Ctx.ReportDate := Now;
    Ctx.Parameters := AParameters;

    for Obj in AReport.Objects do
      if (Obj is TReportBand) and
         (TReportBand(Obj).BandType in [btReportTitle, btPageHeader, btColumnHeader]) then
        AppendBandText(Lines, TReportBand(Obj), Ctx);

    if Assigned(AUserDataSet) and AUserDataSet.Active then
    begin
      WrappedDS := WrappedUserDataSet(AUserDataSet);
      HasSaveBM := False;
      SaveBM := nil;
      if Assigned(WrappedDS) then
      begin
        HasSaveBM := CaptureBookmark(WrappedDS, SaveBM);
        WrappedDS.DisableControls;
      end;
      try
        RowNumber := 0;
        AUserDataSet.First;
        while not AUserDataSet.Eof do
        begin
          Inc(RowNumber);
          Ctx.DataSet := nil;
          Ctx.UserDataSet := AUserDataSet;
          Ctx.RowNumber := RowNumber;

          for Obj in AReport.Objects do
            if Obj is TReportBand then
            begin
              Band := TReportBand(Obj);
              if Band.BandType = btMasterData then
              begin
                AppendBandText(Lines, Band, Ctx);
                AppendDetailBands(Lines, AReport, ADataSet, ANamedDataSets,
                  AUserDataSet, ANamedUserDataSets, Ctx);
              end;
            end;

          AUserDataSet.Next;
        end;
      finally
        if Assigned(WrappedDS) then
        begin
          RestoreBookmark(WrappedDS, SaveBM, HasSaveBM);
          WrappedDS.EnableControls;
        end;
      end;
    end
    else if Assigned(ADataSet) and ADataSet.Active then
    begin
      HasSaveBM := CaptureBookmark(ADataSet, SaveBM);
      ADataSet.DisableControls;
      try
        RowNumber := 0;
        ADataSet.First;
        while not ADataSet.Eof do
        begin
          Inc(RowNumber);
          Ctx.DataSet := ADataSet;
          Ctx.UserDataSet := nil;
          Ctx.RowNumber := RowNumber;

          for Obj in AReport.Objects do
            if Obj is TReportBand then
            begin
              Band := TReportBand(Obj);
              if Band.BandType = btMasterData then
              begin
                AppendBandText(Lines, Band, Ctx);
                AppendDetailBands(Lines, AReport, ADataSet, ANamedDataSets,
                  nil, nil, Ctx);
              end;
            end;

          ADataSet.Next;
        end;
      finally
        RestoreBookmark(ADataSet, SaveBM, HasSaveBM);
        ADataSet.EnableControls;
      end;
    end;

    Ctx.DataSet := ADataSet;
    Ctx.UserDataSet := AUserDataSet;
    Ctx.RowNumber := 0;
    for Obj in AReport.Objects do
      if (Obj is TReportBand) and
         (TReportBand(Obj).BandType in [btReportSummary, btPageFooter]) then
        AppendBandText(Lines, TReportBand(Obj), Ctx);

    Lines.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

class procedure TReportTextExporter.ExportToFile(
  AReport: TReportModel;
  ADataSet: TDataSet;
  ANamedDataSets: TDictionary<string, TDataSet>;
  AParameters: TStrings;
  const AFileName: string);
begin
  ExportToFileCore(AReport, ADataSet, ANamedDataSets, nil, nil, AParameters, AFileName);
end;

class procedure TReportTextExporter.ExportUserDataSetToFile(
  AReport: TReportModel;
  AUserDataSet: TVittixUserDataSet;
  ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
  AParameters: TStrings;
  const AFileName: string);
begin
  ExportToFileCore(AReport, nil, nil, AUserDataSet, ANamedUserDataSets, AParameters, AFileName);
end;

end.
