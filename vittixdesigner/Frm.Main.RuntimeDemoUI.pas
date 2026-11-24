unit Frm.Main.RuntimeDemoUI;

{ UI driver for "Run Runtime Event Callback Demo" (post-v1.0 extraction).

  This is the former TfrmMain.RunRuntimeEventCallbackDemo method moved out of
  the production form verbatim (report §12: split Frm.Main.pas). The
  designer's sample-data state is injected through callbacks
  (AUseSampleDataSet / AGetSampleDataSet) so this unit never references the
  main form unit. The demo result text and its clipboard handler live here.
}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.StrUtils,
  System.Math, System.Variants, System.UITypes, System.IOUtils,
  System.Generics.Collections, System.Generics.Defaults,
  Vcl.Forms, Vcl.Controls, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Clipbrd, Vcl.Menus,
  Data.DB,
  Vittix.Report.Model, Vittix.Report.Objects, Vittix.Report.Bands,
  Vittix.Report.PageSettings, Vittix.Report.Serializer,
  Vittix.Report.Context, Vittix.Report.Expressions, Vittix.Report.Scripting,
  Vittix.Report.Engine, Vittix.Report.Renderer,
  Vittix.Report.Export.Commands,
  Vittix.Report.Objects.Barcode, Vittix.Report.Objects.Table,
  Vittix.Report.Objects.Chart, Vittix.Report.Objects.CrossTab,
  Vittix.Report.ScriptHost.Adapter,
  Frm.Main.RuntimeDemo, Frm.Main.SampleHelpers;

procedure RunRuntimeEventCallbackDemo(const AUseSampleDataSet: TProc;
  const AGetSampleDataSet: TFunc<TDataSet>;
  const AGetDesignerReportJSON: TFunc<string>;
  const ACopyClick: TNotifyEvent);
function RuntimeEventDemoOutput: string;

implementation

var
  // Demo result text, set at the end of the run and copied to the clipboard
  // by RuntimeEventDemoCopyClick (was TfrmMain.RuntimeEventDemoCopyClick,
  // which read the same-named form field).
  FRuntimeEventDemoOutput: string;

procedure RunRuntimeEventCallbackDemo(const AUseSampleDataSet: TProc;
  const AGetSampleDataSet: TFunc<TDataSet>;
  const AGetDesignerReportJSON: TFunc<string>;
  const ACopyClick: TNotifyEvent);
const
  TracePreviewMax = 30;
var
  ReportModel: TReportModel;
  Engine: TReportEngine;
  Harness: TRuntimeEventDemoHarness;
  SampleDataSet: TDataSet;
  Lines: TStringList;
  BaselineTrace: TStringList;
  ObjectSkipTrace: TStringList;
  BandSkipTrace: TStringList;
  FN: string;
  I: Integer;
  BasePass: Boolean;
  ObjectSkipPass: Boolean;
  BandSkipPass: Boolean;
  CountingInflationPass: Boolean;
  BaseBeforeBand: Integer;
  BaseAfterBand: Integer;
  BaseBeforeObject: Integer;
  BaseAfterObject: Integer;
  BaseScriptBeforeObject: Integer;
  BaseScriptAfterObject: Integer;
  ScriptCancelPass: Boolean;
  TargetOrderPass: Boolean;
  TargetCancelOrderPass: Boolean;
  FieldBindPass: Boolean;
  FieldResolveMissPass: Boolean;
  FieldResolveMissWithUnsupportedPass: Boolean;
  BackgroundPass: Boolean;
  VisiblePass: Boolean;
  AnchorRightPass: Boolean;
  AnchorBottomPass: Boolean;
  EscapedQuotePass: Boolean;
  WhitespacePass: Boolean;
  TrailingSemicolonPass: Boolean;
  UnknownCommandPass: Boolean;
  FieldSyntaxPass: Boolean;
  FieldNamePass: Boolean;
  ColorValuePass: Boolean;
  VisibleValuePass: Boolean;
  TextLiteralPass: Boolean;
  CanPrintValuePass: Boolean;
  MultiInvalidPass: Boolean;
  MixedValidInvalidPass: Boolean;
  CancelShortCircuitPass: Boolean;
  QuotedSemicolonWithUnsupportedPass: Boolean;
  ObjectTypeMismatchPass: Boolean;
  LowercaseTextKeyPass: Boolean;
  MixedCaseCanPrintPass: Boolean;
  MixedCaseVisiblePass: Boolean;
  MixedCaseBackgroundPass: Boolean;
  FontColorPass: Boolean;
  FontSizePass: Boolean;
  FontNamePass: Boolean;
  FontBoldPass: Boolean;
  FontItalicPass: Boolean;
  HAlignPass: Boolean;
  VAlignPass: Boolean;
  PrintWhenPass: Boolean;
  DataFieldPass: Boolean;
  ExpressionPass: Boolean;
  BorderColorPass: Boolean;
  ImageDataFieldPass: Boolean;
  TransparentPass: Boolean;
  AutoSizePass: Boolean;
  WordWrapPass: Boolean;
  BorderVisiblePass: Boolean;
  BorderWidthPass: Boolean;
  PaddingLeftPass: Boolean;
  PaddingTopPass: Boolean;
  PaddingRightPass: Boolean;
  PaddingBottomPass: Boolean;
  FontColorOnTruePass: Boolean;
  BackgroundOnTruePass: Boolean;
  BorderColorOnTruePass: Boolean;
  BackgroundConditionPass: Boolean;
  BorderColorConditionPass: Boolean;
  FontColorConditionPass: Boolean;
  FieldDisplayFormatPass: Boolean;
  FieldEditMaskPass: Boolean;
  ImageStretchPass: Boolean;
  ImageCenterPass: Boolean;
  ImageProportionalPass: Boolean;
  OverallPass: Boolean;
  ScriptCancelTrace: TStringList;
  FieldBindTrace: TStringList;
  FieldResolveMissTrace: TStringList;
  FieldResolveMissWithUnsupportedTrace: TStringList;
  BackgroundTrace: TStringList;
  VisibleTrace: TStringList;
  AnchorRightTrace: TStringList;
  AnchorBottomTrace: TStringList;
  EscapedQuoteTrace: TStringList;
  WhitespaceTrace: TStringList;
  TrailingSemicolonTrace: TStringList;
  UnknownCommandTrace: TStringList;
  FieldSyntaxTrace: TStringList;
  FieldNameTrace: TStringList;
  ColorValueTrace: TStringList;
  VisibleValueTrace: TStringList;
  TextLiteralTrace: TStringList;
  CanPrintValueTrace: TStringList;
  MultiInvalidTrace: TStringList;
  MixedValidInvalidTrace: TStringList;
  CancelShortCircuitTrace: TStringList;
  QuotedSemicolonWithUnsupportedTrace: TStringList;
  ObjectTypeMismatchTrace: TStringList;
  LowercaseTextKeyTrace: TStringList;
  MixedCaseCanPrintTrace: TStringList;
  MixedCaseVisibleTrace: TStringList;
  MixedCaseBackgroundTrace: TStringList;
  FontColorTrace: TStringList;
  FontSizeTrace: TStringList;
  FontNameTrace: TStringList;
  FontBoldTrace: TStringList;
  FontItalicTrace: TStringList;
  HAlignTrace: TStringList;
  VAlignTrace: TStringList;
  PrintWhenTrace: TStringList;
  DataFieldTrace: TStringList;
  ExpressionTrace: TStringList;
  BorderColorTrace: TStringList;
  TransparentTrace: TStringList;
  AutoSizeTrace: TStringList;
  WordWrapTrace: TStringList;
  BorderVisibleTrace: TStringList;
  BorderWidthTrace: TStringList;
  PaddingLeftTrace: TStringList;
  PaddingTopTrace: TStringList;
  PaddingRightTrace: TStringList;
  PaddingBottomTrace: TStringList;
  FontColorOnTrueTrace: TStringList;
  BackgroundOnTrueTrace: TStringList;
  BorderColorOnTrueTrace: TStringList;
  BackgroundConditionTrace: TStringList;
  BorderColorConditionTrace: TStringList;
  FontColorConditionTrace: TStringList;
  FieldDisplayFormatTrace: TStringList;
  FieldEditMaskTrace: TStringList;
  ImageStretchTrace: TStringList;
  ImageCenterTrace: TStringList;
  ImageProportionalTrace: TStringList;
  ImageDataFieldTrace: TStringList;
  Obj: TReportObject;
  Band: TReportBand;
  ChildObj: TReportObject;
  DemoScriptTarget: TReportObject;
  DemoFieldTarget: TReportFieldObject;
  DemoImageTarget: TReportImageObject;
  DemoNonTextTarget: TReportObject;
  ResultDlg: TForm;
  ResultMemo: TMemo;
  BtnCopy: TButton;
  BtnClose: TButton;
  function TraceHasOrdered(const ATrace: TStrings; const AParts: array of string): Boolean;
  var
    StartAt, I, J: Integer;
  begin
    Result := False;
    if not Assigned(ATrace) then
      Exit;

    StartAt := 0;
    for I := 0 to High(AParts) do
    begin
      J := StartAt;
      while J < ATrace.Count do
      begin
        if Pos(AParts[I], ATrace[J]) > 0 then
          Break;
        Inc(J);
      end;
      if J >= ATrace.Count then
        Exit(False);
      StartAt := J + 1;
    end;
    Result := True;
  end;
  function TraceWindowHasNoTargetObjectHooks(const ATrace: TStrings): Boolean;
  var
    I, StartIdx, EndIdx: Integer;
    S: string;
  begin
    Result := False;
    if not Assigned(ATrace) then
      Exit;

    StartIdx := -1;
    EndIdx := -1;
    for I := 0 to ATrace.Count - 1 do
    begin
      if (StartIdx < 0) and (Pos('ScriptCanceledObject: TReportTextObject', ATrace[I]) > 0) then
        StartIdx := I;
      if (StartIdx >= 0) and (Pos('AfterBand: Report Title', ATrace[I]) > 0) then
      begin
        EndIdx := I;
        Break;
      end;
    end;

    if (StartIdx < 0) or (EndIdx < 0) or (EndIdx <= StartIdx) then
      Exit(False);

    for I := StartIdx + 1 to EndIdx - 1 do
    begin
      S := ATrace[I];
      if (Pos('BeforeObject: TReportTextObject', S) > 0) or
         (Pos('ScriptAfterObject: TReportTextObject "txtTitle"', S) > 0) or
         (Pos('AfterObject: TReportTextObject', S) > 0) then
        Exit(False);
    end;

    Result := True;
  end;
  procedure AppendUnsupportedSummary(const ATitle: string; const ATrace: TStrings; ALines: TStrings);
  var
    U: TStringList;
    L: string;
    I: Integer;
  begin
    if not Assigned(ATrace) or not Assigned(ALines) then
      Exit;

    U := TStringList.Create;
    try
      U.Sorted := True;
      U.Duplicates := dupIgnore;
      for L in ATrace do
        if Pos('ScriptUnsupported', L) > 0 then
          U.Add(L);

      ALines.Add(Format('  %s unsupported count: %d', [ATitle, U.Count]));
      for I := 0 to Min(4, U.Count - 1) do
        ALines.Add('    ' + U[I]);
      if U.Count > 5 then
        ALines.Add(Format('    ... (%d more unsupported lines)', [U.Count - 5]));
    finally
      U.Free;
    end;
  end;
  procedure AddUnsupportedReasonCounts(const ATrace: TStrings;
    ACounts: TDictionary<string, Integer>);
  var
    L: string;
    P1: Integer;
    P2: Integer;
    Reason: string;
    C: Integer;
  begin
    if not Assigned(ATrace) or not Assigned(ACounts) then
      Exit;

    for L in ATrace do
    begin
      P1 := Pos('ScriptUnsupported[', L);
      if P1 <= 0 then
        Continue;
      P1 := P1 + Length('ScriptUnsupported[');
      P2 := Pos(']:', L);
      if (P2 <= P1) then
        Continue;
      Reason := Trim(Copy(L, P1, P2 - P1));
      if Reason = '' then
        Reason := 'Unknown';
      if ACounts.TryGetValue(Reason, C) then
        ACounts.AddOrSetValue(Reason, C + 1)
      else
        ACounts.Add(Reason, 1);
    end;
  end;
  procedure AppendUnsupportedReasonSummary(ALines: TStrings;
    const ATraces: array of TStrings);
  var
    Counts: TDictionary<string, Integer>;
    Pair: TPair<string, Integer>;
    OutLines: TStringList;
    I: Integer;
  begin
    if not Assigned(ALines) then
      Exit;

    Counts := TDictionary<string, Integer>.Create;
    OutLines := TStringList.Create;
    try
      for I := Low(ATraces) to High(ATraces) do
        AddUnsupportedReasonCounts(ATraces[I], Counts);

      ALines.Add('');
      ALines.Add('Unsupported reason summary:');
      if Counts.Count = 0 then
      begin
        ALines.Add('  none');
        Exit;
      end;

      for Pair in Counts do
        OutLines.Add(Format('  %s: %d', [Pair.Key, Pair.Value]));
      OutLines.Sort;
      for I := 0 to OutLines.Count - 1 do
        ALines.Add(OutLines[I]);
    finally
      OutLines.Free;
      Counts.Free;
    end;
  end;
begin
  AUseSampleDataSet();
  SampleDataSet := AGetSampleDataSet();

  ReportModel := nil;
  Engine := nil;
  Harness := nil;
  Lines := TStringList.Create;
  BaselineTrace := TStringList.Create;
  ObjectSkipTrace := TStringList.Create;
  BandSkipTrace := TStringList.Create;
  ScriptCancelTrace := TStringList.Create;
  FieldBindTrace := TStringList.Create;
  FieldResolveMissTrace := TStringList.Create;
  FieldResolveMissWithUnsupportedTrace := TStringList.Create;
  BackgroundTrace := TStringList.Create;
  VisibleTrace := TStringList.Create;
  AnchorRightTrace := TStringList.Create;
  AnchorBottomTrace := TStringList.Create;
  EscapedQuoteTrace := TStringList.Create;
  WhitespaceTrace := TStringList.Create;
  TrailingSemicolonTrace := TStringList.Create;
  UnknownCommandTrace := TStringList.Create;
  FieldSyntaxTrace := TStringList.Create;
  FieldNameTrace := TStringList.Create;
  ColorValueTrace := TStringList.Create;
  VisibleValueTrace := TStringList.Create;
  TextLiteralTrace := TStringList.Create;
  CanPrintValueTrace := TStringList.Create;
  MultiInvalidTrace := TStringList.Create;
  MixedValidInvalidTrace := TStringList.Create;
  CancelShortCircuitTrace := TStringList.Create;
  QuotedSemicolonWithUnsupportedTrace := TStringList.Create;
  ObjectTypeMismatchTrace := TStringList.Create;
  LowercaseTextKeyTrace := TStringList.Create;
  MixedCaseCanPrintTrace := TStringList.Create;
  MixedCaseVisibleTrace := TStringList.Create;
  MixedCaseBackgroundTrace := TStringList.Create;
  FontColorTrace := TStringList.Create;
  FontSizeTrace := TStringList.Create;
  FontNameTrace := TStringList.Create;
  FontBoldTrace := TStringList.Create;
  FontItalicTrace := TStringList.Create;
  HAlignTrace := TStringList.Create;
  VAlignTrace := TStringList.Create;
  PrintWhenTrace := TStringList.Create;
  DataFieldTrace := TStringList.Create;
  ExpressionTrace := TStringList.Create;
  BorderColorTrace := TStringList.Create;
  TransparentTrace := TStringList.Create;
  AutoSizeTrace := TStringList.Create;
  WordWrapTrace := TStringList.Create;
  BorderVisibleTrace := TStringList.Create;
  BorderWidthTrace := TStringList.Create;
  PaddingLeftTrace := TStringList.Create;
  PaddingTopTrace := TStringList.Create;
  PaddingRightTrace := TStringList.Create;
  PaddingBottomTrace := TStringList.Create;
  FontColorOnTrueTrace := TStringList.Create;
  BackgroundOnTrueTrace := TStringList.Create;
  BorderColorOnTrueTrace := TStringList.Create;
  BackgroundConditionTrace := TStringList.Create;
  BorderColorConditionTrace := TStringList.Create;
  FontColorConditionTrace := TStringList.Create;
  FieldDisplayFormatTrace := TStringList.Create;
  FieldEditMaskTrace := TStringList.Create;
  ImageStretchTrace := TStringList.Create;
  ImageCenterTrace := TStringList.Create;
  ImageProportionalTrace := TStringList.Create;
  ImageDataFieldTrace := TStringList.Create;
  try
    FN := GetRegressionReportPath('01_simple_masterdata.vrt');
    if TFile.Exists(FN) then
      ReportModel := TReportSerializer.LoadFromFile(FN)
    else if Assigned(AGetDesignerReportJSON) and
            (AGetDesignerReportJSON() <> '') then
      ReportModel := TReportSerializer.LoadFromJSON(
        AGetDesignerReportJSON())
    else
      raise Exception.Create('Could not load a report for runtime event demo.');

    Harness := TRuntimeEventDemoHarness.Create;
    DemoScriptTarget := nil;
    DemoFieldTarget := nil;
    DemoImageTarget := nil;
    DemoNonTextTarget := nil;
    for Obj in ReportModel.Objects do
    begin
      if Obj is TReportTextObject then
      begin
        if not Assigned(DemoScriptTarget) then
          DemoScriptTarget := Obj;
      end
      else if (Obj is TReportFieldObject) and not Assigned(DemoFieldTarget) then
        DemoFieldTarget := TReportFieldObject(Obj)
      else if (Obj is TReportImageObject) and not Assigned(DemoImageTarget) then
        DemoImageTarget := TReportImageObject(Obj)
      else if (not (Obj is TReportBand)) and not Assigned(DemoNonTextTarget) then
        DemoNonTextTarget := Obj;

      if Assigned(DemoScriptTarget) and Assigned(DemoFieldTarget) and Assigned(DemoImageTarget) and Assigned(DemoNonTextTarget) then
        Break;
    end;

    if not Assigned(DemoScriptTarget) then
    begin
      for Obj in ReportModel.Objects do
      begin
        if Obj is TReportBand then
        begin
          Band := TReportBand(Obj);
          for ChildObj in Band.Children do
          begin
            if (ChildObj is TReportTextObject) and not Assigned(DemoScriptTarget) then
              DemoScriptTarget := ChildObj
            else if (ChildObj is TReportFieldObject) and not Assigned(DemoFieldTarget) then
              DemoFieldTarget := TReportFieldObject(ChildObj)
            else if (ChildObj is TReportImageObject) and not Assigned(DemoImageTarget) then
              DemoImageTarget := TReportImageObject(ChildObj)
            else if (not (ChildObj is TReportTextObject)) and not Assigned(DemoNonTextTarget) then
              DemoNonTextTarget := ChildObj;
            if Assigned(DemoScriptTarget) and Assigned(DemoFieldTarget) and Assigned(DemoImageTarget) and Assigned(DemoNonTextTarget) then
              Break;
          end;
        end;
        if Assigned(DemoScriptTarget) and Assigned(DemoFieldTarget) and Assigned(DemoImageTarget) and Assigned(DemoNonTextTarget) then
          Break;
      end;
    end;

    if not Assigned(DemoNonTextTarget) then
    begin
      for Obj in ReportModel.Objects do
      begin
        if Obj is TReportBand then
        begin
          Band := TReportBand(Obj);
          DemoNonTextTarget := TReportLineObject.Create;
          DemoNonTextTarget.Name := 'rtDemoObjectTypeMismatch';
          DemoNonTextTarget.Bounds := Rect(12, 28, 180, 30);
          Band.Children.Add(DemoNonTextTarget);
          Break;
        end;
      end;
    end;

    if not Assigned(DemoImageTarget) then
    begin
      for Obj in ReportModel.Objects do
      begin
        if Obj is TReportBand then
        begin
          Band := TReportBand(Obj);
          DemoImageTarget := TReportImageObject.Create;
          DemoImageTarget.Name := 'rtDemoImageObject';
          DemoImageTarget.Bounds := Rect(200, 3, 300, 58);
          DemoImageTarget.DataField := 'ImagePath';
          Band.Children.Add(DemoImageTarget);
          Break;
        end;
      end;
    end;

    if Assigned(DemoScriptTarget) then
    begin
      if Trim(DemoScriptTarget.OnBeforePrint) = '' then
        DemoScriptTarget.OnBeforePrint := 'Text := ''Demo Title''';
      if Trim(DemoScriptTarget.OnAfterPrint) = '' then
        DemoScriptTarget.OnAfterPrint := 'DemoObjectAfter';
    end;

    if Assigned(DemoFieldTarget) then
    begin
      if Trim(DemoFieldTarget.OnBeforePrint) = '' then
        DemoFieldTarget.OnBeforePrint := 'DisplayFormat := #,##0.00; EditMask := ''!99;0;_''';
      if Trim(DemoFieldTarget.OnAfterPrint) = '' then
        DemoFieldTarget.OnAfterPrint := 'DemoFieldAfter';
    end;

    if Assigned(DemoImageTarget) then
    begin
      if Trim(DemoImageTarget.OnBeforePrint) = '' then
        DemoImageTarget.OnBeforePrint := 'Stretch := False; Center := True; Proportional := False';
      if Trim(DemoImageTarget.OnAfterPrint) = '' then
        DemoImageTarget.OnAfterPrint := 'DemoImageAfter';
    end;

    if not Assigned(DemoScriptTarget) then
      raise Exception.Create('Could not find text object for runtime event demo.');
    if not Assigned(DemoFieldTarget) then
      raise Exception.Create('Could not find field object for runtime event demo.');
    if not Assigned(DemoImageTarget) then
      raise Exception.Create('Could not find image object for runtime event demo.');

    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;

    BaseBeforeBand := Harness.BeforeBandCount;
    BaseAfterBand := Harness.AfterBandCount;
    BaseBeforeObject := Harness.BeforeObjectCount;
    BaseAfterObject := Harness.AfterObjectCount;
    BaseScriptBeforeObject := Harness.ScriptBeforeObjectCount;
    BaseScriptAfterObject := Harness.ScriptAfterObjectCount;
    BaselineTrace.Assign(Harness.Trace);

    BasePass :=
      (Harness.BeforeReportCount = 1) and
      (Harness.AfterReportCount = 1) and
      (Harness.BeforeBandCount > 0) and
      (Harness.AfterBandCount > 0) and
      (Harness.BeforeObjectCount > 0) and
      (Harness.AfterObjectCount > 0) and
      (Harness.BeforeBandCount >= Harness.AfterBandCount) and
      (Harness.BeforeObjectCount >= Harness.AfterObjectCount) and
      (Harness.ScriptBeforeObjectCount > 0) and
      (Harness.ScriptAfterObjectCount > 0);
    CountingInflationPass :=
      (Harness.BeforeReportCount = 1) and
      (Harness.AfterReportCount = 1);
    TargetOrderPass := TraceHasOrdered(BaselineTrace, [
      'ScriptBeforeObject: TReportTextObject "txtTitle"',
      'BeforeObject: TReportTextObject',
      'ScriptAfterObject: TReportTextObject "txtTitle"',
      'AfterObject: TReportTextObject'
    ]);

    Lines.Add('');
    Lines.Add('Baseline summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  ScriptBeforeObject=%d ScriptAfterObject=%d  ScriptSetText=%d ScriptUnsupported=%d  SkippedObject=%d SkippedBand=%d ScriptCanceled=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.ScriptBeforeObjectCount, Harness.ScriptAfterObjectCount,
       Harness.ScriptTextSetCount, Harness.ScriptUnsupportedCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount,
       Harness.ScriptCanceledObjectCount]));
    if BasePass then
      Lines.Add('  Baseline: PASS')
    else
      Lines.Add('  Baseline: FAIL');
    if CountingInflationPass then
      Lines.Add('  Counting-pass inflation check: PASS')
    else
      Lines.Add('  Counting-pass inflation check: FAIL');
    if TargetOrderPass then
      Lines.Add('  Target object order check: PASS')
    else
      Lines.Add('  Target object order check: FAIL');

    Harness.ResetCounts;
    Harness.SkipObjectClassName := 'TReportTextObject';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ObjectSkipPass := Harness.SkippedObjectCount > 0;
    ObjectSkipTrace.Assign(Harness.Trace);
    Lines.Add('');
    Lines.Add('Object-skip summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  ScriptBeforeObject=%d ScriptAfterObject=%d  ScriptSetText=%d ScriptUnsupported=%d  SkippedObject=%d SkippedBand=%d ScriptCanceled=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.ScriptBeforeObjectCount, Harness.ScriptAfterObjectCount,
       Harness.ScriptTextSetCount, Harness.ScriptUnsupportedCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount,
       Harness.ScriptCanceledObjectCount]));
    if ObjectSkipPass then
      Lines.Add(Format('Object skip subtest (skip %s): PASS (SkippedObjectCount=%d)',
        ['TReportTextObject', Harness.SkippedObjectCount]))
    else
      Lines.Add(Format('Object skip subtest (skip %s): FAIL (SkippedObjectCount=%d)',
        ['TReportTextObject', Harness.SkippedObjectCount]));

    Harness.ResetCounts;
    Harness.SkipMasterDataBand := True;
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BandSkipPass := Harness.SkippedBandCount > 0;
    BandSkipTrace.Assign(Harness.Trace);
    Lines.Add('');
    Lines.Add('Band-skip summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  ScriptBeforeObject=%d ScriptAfterObject=%d  ScriptSetText=%d ScriptUnsupported=%d  SkippedObject=%d SkippedBand=%d ScriptCanceled=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.ScriptBeforeObjectCount, Harness.ScriptAfterObjectCount,
       Harness.ScriptTextSetCount, Harness.ScriptUnsupportedCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount,
       Harness.ScriptCanceledObjectCount]));
    if BandSkipPass then
      Lines.Add(Format('Band skip subtest (skip Master Data): PASS (SkippedBandCount=%d)',
        [Harness.SkippedBandCount]))
    else
      Lines.Add(Format('Band skip subtest (skip Master Data): FAIL (SkippedBandCount=%d)',
        [Harness.SkippedBandCount]));
    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'CanPrint := False';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ScriptCancelPass := Harness.ScriptCanceledObjectCount > 0;
    ScriptCancelTrace.Assign(Harness.Trace);
    Lines.Add('');
    Lines.Add('Script-host cancel summary:');
    Lines.Add(Format('  BeforeReport=%d AfterReport=%d  BeforeBand=%d AfterBand=%d  BeforeObject=%d AfterObject=%d  ScriptBeforeObject=%d ScriptAfterObject=%d  ScriptSetText=%d ScriptUnsupported=%d  SkippedObject=%d SkippedBand=%d ScriptCanceled=%d',
      [Harness.BeforeReportCount, Harness.AfterReportCount,
       Harness.BeforeBandCount, Harness.AfterBandCount,
       Harness.BeforeObjectCount, Harness.AfterObjectCount,
       Harness.ScriptBeforeObjectCount, Harness.ScriptAfterObjectCount,
       Harness.ScriptTextSetCount, Harness.ScriptUnsupportedCount,
       Harness.SkippedObjectCount, Harness.SkippedBandCount,
       Harness.ScriptCanceledObjectCount]));
    if ScriptCancelPass then
      Lines.Add('Script-host CanPrint=False subtest: PASS')
    else
      Lines.Add('Script-host CanPrint=False subtest: FAIL');
    TargetCancelOrderPass := TraceHasOrdered(ScriptCancelTrace, [
      'ScriptBeforeObject: TReportTextObject "txtTitle" text="CanPrint := False"',
      'ScriptCanceledObject: TReportTextObject'
    ]) and
      TraceWindowHasNoTargetObjectHooks(ScriptCancelTrace);
    if TargetCancelOrderPass then
      Lines.Add('  Target object cancel-order check: PASS')
    else
      Lines.Add('  Target object cancel-order check: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
    begin
      DemoScriptTarget.OnBeforePrint := 'Text := Field(''CustomerName'')';
      DemoScriptTarget.OnAfterPrint := 'DemoObjectAfter';
    end;
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldBindTrace.Assign(Harness.Trace);
    FieldBindPass :=
      (Pos('ScriptSetTextFromField: TReportTextObject "txtTitle" <- Field("CustomerName")',
        FieldBindTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    Lines.Add('');
    if FieldBindPass then
      Lines.Add('Field() text-binding subtest: PASS')
    else
      Lines.Add('Field() text-binding subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := Field(''NoSuchField'')';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldResolveMissTrace.Assign(Harness.Trace);
    FieldResolveMissPass :=
      (Pos('ScriptFieldResolveMiss: NoSuchField', FieldResolveMissTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptUnsupported[', FieldResolveMissTrace.Text) = 0);
    if FieldResolveMissPass then
      Lines.Add('Field() missing-field resolve subtest: PASS')
    else
      Lines.Add('Field() missing-field resolve subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := Field(''NoSuchField''); Foo := 1';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldResolveMissWithUnsupportedTrace.Assign(Harness.Trace);
    FieldResolveMissWithUnsupportedPass :=
      (Pos('ScriptFieldResolveMiss: NoSuchField', FieldResolveMissWithUnsupportedTrace.Text) > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', FieldResolveMissWithUnsupportedTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 1);
    if FieldResolveMissWithUnsupportedPass then
      Lines.Add('Field() resolve-miss + unsupported subtest: PASS')
    else
      Lines.Add('Field() resolve-miss + unsupported subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Background := clYellow';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BackgroundTrace.Assign(Harness.Trace);
    BackgroundPass :=
      (Pos('ScriptSetBackground: TReportTextObject "txtTitle" -> clYellow', BackgroundTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BackgroundPass then
      Lines.Add('Background command subtest: PASS')
    else
      Lines.Add('Background command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Visible := False';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    VisibleTrace.Assign(Harness.Trace);
    VisiblePass :=
      (Pos('ScriptSetVisible: TReportTextObject "txtTitle" -> False', VisibleTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if VisiblePass then
      Lines.Add('Visible command subtest: PASS')
    else
      Lines.Add('Visible command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'AnchorRight := True';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    AnchorRightTrace.Assign(Harness.Trace);
    AnchorRightPass :=
      (Pos('ScriptSetAnchorRight: TReportTextObject "txtTitle" -> True', AnchorRightTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if AnchorRightPass then
      Lines.Add('AnchorRight command subtest: PASS')
    else
      Lines.Add('AnchorRight command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'AnchorBottom := True';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    AnchorBottomTrace.Assign(Harness.Trace);
    AnchorBottomPass :=
      (Pos('ScriptSetAnchorBottom: TReportTextObject "txtTitle" -> True', AnchorBottomTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if AnchorBottomPass then
      Lines.Add('AnchorBottom command subtest: PASS')
    else
      Lines.Add('AnchorBottom command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := ''O''''Reilly''';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    EscapedQuoteTrace.Assign(Harness.Trace);
    EscapedQuotePass :=
      (Harness.ScriptTextSetCount > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptSetText: TReportTextObject', EscapedQuoteTrace.Text) > 0) and
      (Pos('Reilly', EscapedQuoteTrace.Text) > 0);
    if EscapedQuotePass then
      Lines.Add('Escaped quote literal subtest: PASS')
    else
      Lines.Add('Escaped quote literal subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := '  Visible   :=   True ;   Text := ''WS''   ';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    WhitespaceTrace.Assign(Harness.Trace);
    WhitespacePass :=
      (Harness.ScriptTextSetCount > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptSetVisible: TReportTextObject', WhitespaceTrace.Text) > 0) and
      (Pos('-> True', WhitespaceTrace.Text) > 0) and
      (Pos('ScriptSetText: TReportTextObject', WhitespaceTrace.Text) > 0) and
      (Pos('WS', WhitespaceTrace.Text) > 0);
    if WhitespacePass then
      Lines.Add('Whitespace normalization subtest: PASS')
    else
      Lines.Add('Whitespace normalization subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := ''Tail''; ; ;';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    TrailingSemicolonTrace.Assign(Harness.Trace);
    TrailingSemicolonPass :=
      (Harness.ScriptTextSetCount > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptSetText: TReportTextObject', TrailingSemicolonTrace.Text) > 0) and
      (Pos('Tail', TrailingSemicolonTrace.Text) > 0);
    if TrailingSemicolonPass then
      Lines.Add('Trailing semicolon subtest: PASS')
    else
      Lines.Add('Trailing semicolon subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Foo := 1';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    UnknownCommandTrace.Assign(Harness.Trace);
    UnknownCommandPass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', UnknownCommandTrace.Text) > 0);
    if UnknownCommandPass then
      Lines.Add('Unknown command subtest: PASS')
    else
      Lines.Add('Unknown command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := Field(CustomerName)';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldSyntaxTrace.Assign(Harness.Trace);
    FieldSyntaxPass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[FieldSyntax]: Text := Field(CustomerName)', FieldSyntaxTrace.Text) > 0);
    if FieldSyntaxPass then
      Lines.Add('Field syntax subtest: PASS')
    else
      Lines.Add('Field syntax subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := Field(''   '')';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldNameTrace.Assign(Harness.Trace);
    FieldNamePass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[FieldName]: Text := Field(''   '')', FieldNameTrace.Text) > 0);
    if FieldNamePass then
      Lines.Add('Field name subtest: PASS')
    else
      Lines.Add('Field name subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Background := clNotAColor';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ColorValueTrace.Assign(Harness.Trace);
    ColorValuePass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[ColorValue]: Background := clNotAColor', ColorValueTrace.Text) > 0);
    if ColorValuePass then
      Lines.Add('Color value subtest: PASS')
    else
      Lines.Add('Color value subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Visible := Maybe';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    VisibleValueTrace.Assign(Harness.Trace);
    VisibleValuePass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[VisibleValue]: Visible := Maybe', VisibleValueTrace.Text) > 0);
    if VisibleValuePass then
      Lines.Add('Visible value subtest: PASS')
    else
      Lines.Add('Visible value subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := Demo';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    TextLiteralTrace.Assign(Harness.Trace);
    TextLiteralPass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[TextLiteral]: Text := Demo', TextLiteralTrace.Text) > 0);
    if TextLiteralPass then
      Lines.Add('Text literal subtest: PASS')
    else
      Lines.Add('Text literal subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'CanPrint := Maybe';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    CanPrintValueTrace.Assign(Harness.Trace);
    CanPrintValuePass :=
      (Harness.ScriptUnsupportedCount > 0) and
      (Pos('ScriptUnsupported[CanPrintValue]: CanPrint := Maybe', CanPrintValueTrace.Text) > 0);
    if CanPrintValuePass then
      Lines.Add('CanPrint value subtest: PASS')
    else
      Lines.Add('CanPrint value subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Foo := 1; Visible := Maybe; Text := Demo; Foo := 1';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    MultiInvalidTrace.Assign(Harness.Trace);
    MultiInvalidPass :=
      (Harness.ScriptUnsupportedCount >= 4) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', MultiInvalidTrace.Text) > 0) and
      (Pos('ScriptUnsupported[VisibleValue]: Visible := Maybe', MultiInvalidTrace.Text) > 0) and
      (Pos('ScriptUnsupported[TextLiteral]: Text := Demo', MultiInvalidTrace.Text) > 0);
    if MultiInvalidPass then
      Lines.Add('Multi-invalid aggregation subtest: PASS')
    else
      Lines.Add('Multi-invalid aggregation subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := ''OK''; Foo := 1; Visible := True; Text := Demo';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    MixedValidInvalidTrace.Assign(Harness.Trace);
    MixedValidInvalidPass :=
      (Harness.ScriptTextSetCount > 0) and
      (Harness.ScriptUnsupportedCount >= 2) and
      (Pos('ScriptSetText: TReportTextObject "txtTitle" -> "OK"', MixedValidInvalidTrace.Text) > 0) and
      (Pos('ScriptSetVisible: TReportTextObject "txtTitle" -> True', MixedValidInvalidTrace.Text) > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', MixedValidInvalidTrace.Text) > 0) and
      (Pos('ScriptUnsupported[TextLiteral]: Text := Demo', MixedValidInvalidTrace.Text) > 0);
    if MixedValidInvalidPass then
      Lines.Add('Mixed valid+invalid sequence subtest: PASS')
    else
      Lines.Add('Mixed valid+invalid sequence subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'CanPrint := False; Foo := 1; Text := Demo';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    CancelShortCircuitTrace.Assign(Harness.Trace);
    CancelShortCircuitPass :=
      (Harness.ScriptCanceledObjectCount > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptCanceledObject: TReportTextObject', CancelShortCircuitTrace.Text) > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', CancelShortCircuitTrace.Text) = 0) and
      (Pos('ScriptUnsupported[TextLiteral]: Text := Demo', CancelShortCircuitTrace.Text) = 0) and
      TraceWindowHasNoTargetObjectHooks(CancelShortCircuitTrace);
    if CancelShortCircuitPass then
      Lines.Add('CanPrint short-circuit mixed sequence subtest: PASS')
    else
      Lines.Add('CanPrint short-circuit mixed sequence subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Text := ''A;B''; Foo := 1';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    QuotedSemicolonWithUnsupportedTrace.Assign(Harness.Trace);
    QuotedSemicolonWithUnsupportedPass :=
      (Harness.ScriptTextSetCount > 0) and
      (Harness.ScriptUnsupportedCount = 1) and
      (Pos('ScriptSetText: TReportTextObject "txtTitle" -> "A;B"', QuotedSemicolonWithUnsupportedTrace.Text) > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', QuotedSemicolonWithUnsupportedTrace.Text) > 0);
    if QuotedSemicolonWithUnsupportedPass then
      Lines.Add('Quoted semicolon + unsupported subtest: PASS')
    else
      Lines.Add('Quoted semicolon + unsupported subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'text := ''lower''';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    LowercaseTextKeyTrace.Assign(Harness.Trace);
    LowercaseTextKeyPass :=
      (Pos('ScriptSetText: TReportTextObject "txtTitle" -> "lower"', LowercaseTextKeyTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if LowercaseTextKeyPass then
      Lines.Add('Lowercase key subtest (text): PASS')
    else
      Lines.Add('Lowercase key subtest (text): FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'cAnPrInT := False; Foo := 1';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    MixedCaseCanPrintTrace.Assign(Harness.Trace);
    MixedCaseCanPrintPass :=
      (Harness.ScriptCanceledObjectCount > 0) and
      (Harness.ScriptUnsupportedCount = 0) and
      (Pos('ScriptCanceledObject: TReportTextObject', MixedCaseCanPrintTrace.Text) > 0) and
      (Pos('ScriptUnsupported[UnknownCommand]: Foo := 1', MixedCaseCanPrintTrace.Text) = 0);
    if MixedCaseCanPrintPass then
      Lines.Add('Mixed-case key subtest (CanPrint): PASS')
    else
      Lines.Add('Mixed-case key subtest (CanPrint): FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'VISIBLE := True';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    MixedCaseVisibleTrace.Assign(Harness.Trace);
    MixedCaseVisiblePass :=
      (Pos('ScriptSetVisible: TReportTextObject "txtTitle" -> True', MixedCaseVisibleTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if MixedCaseVisiblePass then
      Lines.Add('Mixed-case key subtest (VISIBLE): PASS')
    else
      Lines.Add('Mixed-case key subtest (VISIBLE): FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BaCkGrOuNd := clYellow';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    MixedCaseBackgroundTrace.Assign(Harness.Trace);
    MixedCaseBackgroundPass :=
      (Pos('ScriptSetBackground: TReportTextObject "txtTitle" -> clYellow', MixedCaseBackgroundTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if MixedCaseBackgroundPass then
      Lines.Add('Mixed-case key subtest (BaCkGrOuNd): PASS')
    else
      Lines.Add('Mixed-case key subtest (BaCkGrOuNd): FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontColor := clNavy';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontColorTrace.Assign(Harness.Trace);
    FontColorPass :=
      (Pos('ScriptSetFontColor: TReportTextObject "txtTitle" -> clNavy', FontColorTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontColorPass then
      Lines.Add('FontColor command subtest: PASS')
    else
      Lines.Add('FontColor command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontSize := 14';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontSizeTrace.Assign(Harness.Trace);
    FontSizePass :=
      (Pos('ScriptSetFontSize: TReportTextObject "txtTitle" -> 14', FontSizeTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontSizePass then
      Lines.Add('FontSize command subtest: PASS')
    else
      Lines.Add('FontSize command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontName := Arial';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontNameTrace.Assign(Harness.Trace);
    FontNamePass :=
      (Pos('ScriptSetFontName: TReportTextObject "txtTitle" -> "Arial"', FontNameTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontNamePass then
      Lines.Add('FontName command subtest: PASS')
    else
      Lines.Add('FontName command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontBold := True';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontBoldTrace.Assign(Harness.Trace);
    FontBoldPass :=
      (Pos('ScriptSetFontBold: TReportTextObject "txtTitle" -> True', FontBoldTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontBoldPass then
      Lines.Add('FontBold command subtest: PASS')
    else
      Lines.Add('FontBold command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontItalic := True';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontItalicTrace.Assign(Harness.Trace);
    FontItalicPass :=
      (Pos('ScriptSetFontItalic: TReportTextObject "txtTitle" -> True', FontItalicTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontItalicPass then
      Lines.Add('FontItalic command subtest: PASS')
    else
      Lines.Add('FontItalic command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'HAlign := Center';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    HAlignTrace.Assign(Harness.Trace);
    HAlignPass :=
      (Pos('ScriptSetHAlign: TReportTextObject "txtTitle" -> Center', HAlignTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if HAlignPass then
      Lines.Add('HAlign command subtest: PASS')
    else
      Lines.Add('HAlign command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'VAlign := Bottom';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    VAlignTrace.Assign(Harness.Trace);
    VAlignPass :=
      (Pos('ScriptSetVAlign: TReportTextObject "txtTitle" -> Bottom', VAlignTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if VAlignPass then
      Lines.Add('VAlign command subtest: PASS')
    else
      Lines.Add('VAlign command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'PrintWhen := Value > 0';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    PrintWhenTrace.Assign(Harness.Trace);
    PrintWhenPass :=
      (Pos('ScriptSetPrintWhen: TReportTextObject "txtTitle" -> "Value > 0"', PrintWhenTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if PrintWhenPass then
      Lines.Add('PrintWhen command subtest: PASS')
    else
      Lines.Add('PrintWhen command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'DataField := CustomerName';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    DataFieldTrace.Assign(Harness.Trace);
    DataFieldPass :=
      (Pos('ScriptSetDataField: TReportTextObject "txtTitle" -> "CustomerName"', DataFieldTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if DataFieldPass then
      Lines.Add('DataField command subtest: PASS')
    else
      Lines.Add('DataField command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Expression := Value + 1';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ExpressionTrace.Assign(Harness.Trace);
    ExpressionPass :=
      (Pos('ScriptSetExpression: TReportTextObject "txtTitle" -> "Value + 1"', ExpressionTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if ExpressionPass then
      Lines.Add('Expression command subtest: PASS')
    else
      Lines.Add('Expression command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoFieldTarget) then
      DemoFieldTarget.Visible := True;
    if Assigned(DemoFieldTarget) then
      DemoFieldTarget.OnBeforePrint := 'DisplayFormat := #,##0.00; EditMask := ''!99;0;_''';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FieldDisplayFormatTrace.Assign(Harness.Trace);
    FieldDisplayFormatPass :=
      (Pos('ScriptSetDisplayFormat: TReportFieldObject', FieldDisplayFormatTrace.Text) > 0) and
      (Pos('ScriptSetEditMask: TReportFieldObject', FieldDisplayFormatTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FieldDisplayFormatPass then
      Lines.Add('Field DisplayFormat/EditMask command subtest: PASS')
    else
      Lines.Add('Field DisplayFormat/EditMask command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoImageTarget) then
      DemoImageTarget.Visible := True;
    if Assigned(DemoImageTarget) then
      DemoImageTarget.OnBeforePrint := 'DataField := ImagePath; Stretch := False; Center := True; Proportional := False';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    ImageStretchTrace.Assign(Harness.Trace);
    ImageStretchPass :=
      (Pos('ScriptSetStretch: TReportImageObject', ImageStretchTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    ImageCenterPass := (Pos('ScriptSetCenter: TReportImageObject', ImageStretchTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    ImageProportionalPass := (Pos('ScriptSetProportional: TReportImageObject', ImageStretchTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if ImageStretchPass and ImageCenterPass and ImageProportionalPass then
      Lines.Add('Image fit command subtest: PASS')
    else
      Lines.Add('Image fit command subtest: FAIL');

    ImageDataFieldTrace.Assign(Harness.Trace);
    ImageDataFieldPass :=
      (Pos('ScriptSetDataField: TReportImageObject "rtDemoImageObject" -> "ImagePath"', ImageDataFieldTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if ImageDataFieldPass then
      Lines.Add('Image DataField command subtest: PASS')
    else
      Lines.Add('Image DataField command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BorderColor := clOlive';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BorderColorTrace.Assign(Harness.Trace);
    BorderColorPass :=
      (Pos('ScriptSetBorderColor: TReportTextObject "txtTitle" -> clOlive', BorderColorTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BorderColorPass then
      Lines.Add('BorderColor command subtest: PASS')
    else
      Lines.Add('BorderColor command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'Transparent := False';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    TransparentTrace.Assign(Harness.Trace);
    TransparentPass :=
      (Pos('ScriptSetTransparent: TReportTextObject "txtTitle" -> False', TransparentTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if TransparentPass then
      Lines.Add('Transparent command subtest: PASS')
    else
      Lines.Add('Transparent command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'AutoSize := True';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    AutoSizeTrace.Assign(Harness.Trace);
    AutoSizePass :=
      (Pos('ScriptSetAutoSize: TReportTextObject "txtTitle" -> True', AutoSizeTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if AutoSizePass then
      Lines.Add('AutoSize command subtest: PASS')
    else
      Lines.Add('AutoSize command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'WordWrap := True';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    WordWrapTrace.Assign(Harness.Trace);
    WordWrapPass :=
      (Pos('ScriptSetWordWrap: TReportTextObject "txtTitle" -> True', WordWrapTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if WordWrapPass then
      Lines.Add('WordWrap command subtest: PASS')
    else
      Lines.Add('WordWrap command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BorderVisible := True';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BorderVisibleTrace.Assign(Harness.Trace);
    BorderVisiblePass :=
      (Pos('ScriptSetBorderVisible: TReportTextObject "txtTitle" -> True', BorderVisibleTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BorderVisiblePass then
      Lines.Add('BorderVisible command subtest: PASS')
    else
      Lines.Add('BorderVisible command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BorderWidth := 3';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BorderWidthTrace.Assign(Harness.Trace);
    BorderWidthPass :=
      (Pos('ScriptSetBorderWidth: TReportTextObject "txtTitle" -> 3', BorderWidthTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BorderWidthPass then
      Lines.Add('BorderWidth command subtest: PASS')
    else
      Lines.Add('BorderWidth command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'PaddingLeft := 12';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    PaddingLeftTrace.Assign(Harness.Trace);
    PaddingLeftPass :=
      (Pos('ScriptSetPaddingLeft: TReportTextObject "txtTitle" -> 12', PaddingLeftTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if PaddingLeftPass then
      Lines.Add('PaddingLeft command subtest: PASS')
    else
      Lines.Add('PaddingLeft command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'PaddingTop := 7';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    PaddingTopTrace.Assign(Harness.Trace);
    PaddingTopPass :=
      (Pos('ScriptSetPaddingTop: TReportTextObject "txtTitle" -> 7', PaddingTopTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if PaddingTopPass then
      Lines.Add('PaddingTop command subtest: PASS')
    else
      Lines.Add('PaddingTop command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'PaddingRight := 9';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    PaddingRightTrace.Assign(Harness.Trace);
    PaddingRightPass :=
      (Pos('ScriptSetPaddingRight: TReportTextObject "txtTitle" -> 9', PaddingRightTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if PaddingRightPass then
      Lines.Add('PaddingRight command subtest: PASS')
    else
      Lines.Add('PaddingRight command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'PaddingBottom := 4';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    PaddingBottomTrace.Assign(Harness.Trace);
    PaddingBottomPass :=
      (Pos('ScriptSetPaddingBottom: TReportTextObject "txtTitle" -> 4', PaddingBottomTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if PaddingBottomPass then
      Lines.Add('PaddingBottom command subtest: PASS')
    else
      Lines.Add('PaddingBottom command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontColorOnTrue := clMaroon';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontColorOnTrueTrace.Assign(Harness.Trace);
    FontColorOnTruePass :=
      (Pos('ScriptSetFontColorOnTrue: TReportTextObject "txtTitle" -> clMaroon', FontColorOnTrueTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontColorOnTruePass then
      Lines.Add('FontColorOnTrue command subtest: PASS')
    else
      Lines.Add('FontColorOnTrue command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BackgroundOnTrue := clYellow';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BackgroundOnTrueTrace.Assign(Harness.Trace);
    BackgroundOnTruePass :=
      (Pos('ScriptSetBackgroundOnTrue: TReportTextObject "txtTitle" -> clYellow', BackgroundOnTrueTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BackgroundOnTruePass then
      Lines.Add('BackgroundOnTrue command subtest: PASS')
    else
      Lines.Add('BackgroundOnTrue command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BorderColorOnTrue := clRed';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BorderColorOnTrueTrace.Assign(Harness.Trace);
    BorderColorOnTruePass :=
      (Pos('ScriptSetBorderColorOnTrue: TReportTextObject "txtTitle" -> clRed', BorderColorOnTrueTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BorderColorOnTruePass then
      Lines.Add('BorderColorOnTrue command subtest: PASS')
    else
      Lines.Add('BorderColorOnTrue command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BackgroundCondition := Value > 0';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BackgroundConditionTrace.Assign(Harness.Trace);
    BackgroundConditionPass :=
      (Pos('ScriptSetBackgroundCondition: TReportTextObject "txtTitle" -> "Value > 0"', BackgroundConditionTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BackgroundConditionPass then
      Lines.Add('BackgroundCondition command subtest: PASS')
    else
      Lines.Add('BackgroundCondition command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'BorderColorCondition := Value < 100';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    BorderColorConditionTrace.Assign(Harness.Trace);
    BorderColorConditionPass :=
      (Pos('ScriptSetBorderColorCondition: TReportTextObject "txtTitle" -> "Value < 100"', BorderColorConditionTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if BorderColorConditionPass then
      Lines.Add('BorderColorCondition command subtest: PASS')
    else
      Lines.Add('BorderColorCondition command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.Visible := True;
    if Assigned(DemoScriptTarget) then
      DemoScriptTarget.OnBeforePrint := 'FontColorCondition := Value > 0';
    Engine := TReportEngine.Create(ReportModel, SampleDataSet);
    try
      Engine.OnBeforePrintReport := Harness.BeforeReport;
      Engine.OnAfterPrintReport := Harness.AfterReport;
      Engine.OnBeforeBand := Harness.BeforeBand;
      Engine.OnAfterBand := Harness.AfterBand;
      Engine.OnBeforeObject := Harness.BeforeObject;
      Engine.OnAfterObject := Harness.AfterObject;
      Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
      Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
      Engine.Prepare;
    finally
      Engine.Free;
      Engine := nil;
    end;
    FontColorConditionTrace.Assign(Harness.Trace);
    FontColorConditionPass :=
      (Pos('ScriptSetFontColorCondition: TReportTextObject "txtTitle" -> "Value > 0"', FontColorConditionTrace.Text) > 0) and
      (Harness.ScriptUnsupportedCount = 0);
    if FontColorConditionPass then
      Lines.Add('FontColorCondition command subtest: PASS')
    else
      Lines.Add('FontColorCondition command subtest: FAIL');

    Harness.ResetCounts;
    if Assigned(DemoNonTextTarget) then
    begin
      DemoNonTextTarget.OnBeforePrint := 'Text := ''X''; Background := clYellow';
      Engine := TReportEngine.Create(ReportModel, SampleDataSet);
      try
        Engine.OnBeforePrintReport := Harness.BeforeReport;
        Engine.OnAfterPrintReport := Harness.AfterReport;
        Engine.OnBeforeBand := Harness.BeforeBand;
        Engine.OnAfterBand := Harness.AfterBand;
        Engine.OnBeforeObject := Harness.BeforeObject;
        Engine.OnAfterObject := Harness.AfterObject;
        Engine.ScriptEngine.OnObjectBeforePrint := Harness.ScriptBeforeObject;
        Engine.ScriptEngine.OnObjectAfterPrint := Harness.ScriptAfterObject;
        Engine.Prepare;
      finally
        Engine.Free;
        Engine := nil;
      end;
      ObjectTypeMismatchTrace.Assign(Harness.Trace);
      ObjectTypeMismatchPass :=
        (Harness.ScriptUnsupportedCount >= 2) and
        (Pos('ScriptUnsupported[ObjectType]: ' + DemoNonTextTarget.ClassName, ObjectTypeMismatchTrace.Text) > 0);
      if ObjectTypeMismatchPass then
        Lines.Add('Object-type mismatch subtest: PASS')
      else
        Lines.Add('Object-type mismatch subtest: FAIL');
    end
    else
    begin
      // Some reports may not include a non-text object target.
      ObjectTypeMismatchPass := True;
      ObjectTypeMismatchTrace.Clear;
      Lines.Add('Object-type mismatch subtest: SKIP (no non-text object target)');
    end;

    Lines.Add('');
    Lines.Add('Parser edge-case summary:');
    if EscapedQuotePass then
      Lines.Add('  EscapedQuote: PASS')
    else
      Lines.Add('  EscapedQuote: FAIL');
    if WhitespacePass then
      Lines.Add('  WhitespaceNormalization: PASS')
    else
      Lines.Add('  WhitespaceNormalization: FAIL');
    if TrailingSemicolonPass then
      Lines.Add('  TrailingSemicolon: PASS')
    else
      Lines.Add('  TrailingSemicolon: FAIL');

    OverallPass :=
      BasePass and
      CountingInflationPass and
      TargetOrderPass and
      ObjectSkipPass and
      BandSkipPass and
      ScriptCancelPass and
      TargetCancelOrderPass and
      FieldBindPass and
      FieldResolveMissPass and
      FieldResolveMissWithUnsupportedPass and
      BackgroundPass and
      VisiblePass and
      AnchorRightPass and
      AnchorBottomPass and
      EscapedQuotePass and
      WhitespacePass and
      TrailingSemicolonPass and
      UnknownCommandPass and
      FieldSyntaxPass and
      FieldNamePass and
      ColorValuePass and
      VisibleValuePass and
      TextLiteralPass and
      CanPrintValuePass and
      MultiInvalidPass and
      MixedValidInvalidPass and
      CancelShortCircuitPass and
      QuotedSemicolonWithUnsupportedPass and
      ObjectTypeMismatchPass and
      LowercaseTextKeyPass and
      MixedCaseCanPrintPass and
      MixedCaseVisiblePass and
      MixedCaseBackgroundPass and
      FontColorPass and
      FontSizePass and
      FontNamePass and
      FontBoldPass and
      FontItalicPass and
      HAlignPass and
      VAlignPass and
      PrintWhenPass and
      DataFieldPass and
      ExpressionPass and
      FontColorConditionPass and
      FieldDisplayFormatPass and
      ImageStretchPass and
      ImageCenterPass and
      ImageProportionalPass and
      ImageDataFieldPass and
      BorderColorPass and
      AnchorBottomPass and
      TransparentPass and
      AutoSizePass and
      WordWrapPass and
      BorderVisiblePass and
      BorderWidthPass and
      PaddingLeftPass and
      PaddingTopPass and
      PaddingRightPass and
      PaddingBottomPass and
      FontColorOnTruePass and
      BackgroundOnTruePass and
      BorderColorOnTruePass and
      BackgroundConditionPass and
      BorderColorConditionPass;
    Lines.Insert(0, '');
    if OverallPass then
      Lines.Insert(0, 'Overall: PASS')
    else
      Lines.Insert(0, 'Overall: FAIL');
    Lines.Insert(1, 'Runtime Event Callback Demo');
    while (Lines.Count > 2) and SameText(Lines[2], 'Runtime Event Callback Demo') do
      Lines.Delete(2);

    Lines.Add('');
    Lines.Add('Callback inflation guard:');
    Lines.Add(Format('  Baseline BeforeBand=%d, AfterBand=%d',
      [BaseBeforeBand, BaseAfterBand]));
    Lines.Add(Format('  Baseline BeforeObject=%d, AfterObject=%d',
      [BaseBeforeObject, BaseAfterObject]));
    Lines.Add(Format('  Baseline ScriptBeforeObject=%d, ScriptAfterObject=%d',
      [BaseScriptBeforeObject, BaseScriptAfterObject]));

    Lines.Add('');
    Lines.Add('Unsupported command diagnostics:');
    AppendUnsupportedSummary('Baseline', BaselineTrace, Lines);
    AppendUnsupportedSummary('Object-skip', ObjectSkipTrace, Lines);
    AppendUnsupportedSummary('Band-skip', BandSkipTrace, Lines);
    AppendUnsupportedSummary('Script-host cancel', ScriptCancelTrace, Lines);
    AppendUnsupportedSummary('Field() binding', FieldBindTrace, Lines);
    AppendUnsupportedSummary('Field() resolve miss', FieldResolveMissTrace, Lines);
    AppendUnsupportedSummary('Field() resolve miss + unsupported', FieldResolveMissWithUnsupportedTrace, Lines);
    AppendUnsupportedSummary('Background', BackgroundTrace, Lines);
    AppendUnsupportedSummary('Visible', VisibleTrace, Lines);
    AppendUnsupportedSummary('AnchorRight', AnchorRightTrace, Lines);
    AppendUnsupportedSummary('Escaped quote', EscapedQuoteTrace, Lines);
    AppendUnsupportedSummary('Whitespace normalization', WhitespaceTrace, Lines);
    AppendUnsupportedSummary('Trailing semicolon', TrailingSemicolonTrace, Lines);
    AppendUnsupportedSummary('Unknown command', UnknownCommandTrace, Lines);
    AppendUnsupportedSummary('Field syntax', FieldSyntaxTrace, Lines);
    AppendUnsupportedSummary('Field name', FieldNameTrace, Lines);
    AppendUnsupportedSummary('Color value', ColorValueTrace, Lines);
    AppendUnsupportedSummary('Visible value', VisibleValueTrace, Lines);
    AppendUnsupportedSummary('Text literal', TextLiteralTrace, Lines);
    AppendUnsupportedSummary('CanPrint value', CanPrintValueTrace, Lines);
    AppendUnsupportedSummary('Multi-invalid aggregation', MultiInvalidTrace, Lines);
    AppendUnsupportedSummary('Mixed valid+invalid sequence', MixedValidInvalidTrace, Lines);
    AppendUnsupportedSummary('CanPrint short-circuit mixed sequence', CancelShortCircuitTrace, Lines);
    AppendUnsupportedSummary('Quoted semicolon + unsupported', QuotedSemicolonWithUnsupportedTrace, Lines);
    AppendUnsupportedSummary('Object-type mismatch', ObjectTypeMismatchTrace, Lines);
    AppendUnsupportedSummary('Lowercase key (text)', LowercaseTextKeyTrace, Lines);
    AppendUnsupportedSummary('Mixed-case key (CanPrint)', MixedCaseCanPrintTrace, Lines);
    AppendUnsupportedSummary('Mixed-case key (VISIBLE)', MixedCaseVisibleTrace, Lines);
    AppendUnsupportedSummary('Mixed-case key (BaCkGrOuNd)', MixedCaseBackgroundTrace, Lines);
    AppendUnsupportedSummary('BorderColor', BorderColorTrace, Lines);
    AppendUnsupportedSummary('FontSize', FontSizeTrace, Lines);
    AppendUnsupportedSummary('FontName', FontNameTrace, Lines);
    AppendUnsupportedSummary('FontBold', FontBoldTrace, Lines);
    AppendUnsupportedSummary('FontItalic', FontItalicTrace, Lines);
    AppendUnsupportedSummary('HAlign', HAlignTrace, Lines);
    AppendUnsupportedSummary('VAlign', VAlignTrace, Lines);
    AppendUnsupportedSummary('PrintWhen', PrintWhenTrace, Lines);
    AppendUnsupportedSummary('DataField', DataFieldTrace, Lines);
    AppendUnsupportedSummary('Expression', ExpressionTrace, Lines);
    AppendUnsupportedSummary('FontColorCondition', FontColorConditionTrace, Lines);
    AppendUnsupportedSummary('AnchorBottom', AnchorBottomTrace, Lines);
    AppendUnsupportedSummary('FieldDisplayFormat', FieldDisplayFormatTrace, Lines);
    AppendUnsupportedSummary('ImageStretch', ImageStretchTrace, Lines);
    AppendUnsupportedSummary('ImageDataField', ImageDataFieldTrace, Lines);
    AppendUnsupportedSummary('Transparent', TransparentTrace, Lines);
    AppendUnsupportedSummary('AutoSize', AutoSizeTrace, Lines);
    AppendUnsupportedSummary('WordWrap', WordWrapTrace, Lines);
    AppendUnsupportedSummary('BorderVisible', BorderVisibleTrace, Lines);
    AppendUnsupportedSummary('BorderWidth', BorderWidthTrace, Lines);
    AppendUnsupportedSummary('PaddingLeft', PaddingLeftTrace, Lines);
    AppendUnsupportedSummary('PaddingTop', PaddingTopTrace, Lines);
    AppendUnsupportedSummary('PaddingRight', PaddingRightTrace, Lines);
    AppendUnsupportedSummary('PaddingBottom', PaddingBottomTrace, Lines);
    AppendUnsupportedSummary('FontColorOnTrue', FontColorOnTrueTrace, Lines);
    AppendUnsupportedSummary('BackgroundOnTrue', BackgroundOnTrueTrace, Lines);
    AppendUnsupportedSummary('BorderColorOnTrue', BorderColorOnTrueTrace, Lines);
    AppendUnsupportedSummary('BackgroundCondition', BackgroundConditionTrace, Lines);
    AppendUnsupportedSummary('BorderColorCondition', BorderColorConditionTrace, Lines);
    AppendUnsupportedReasonSummary(Lines,
      [BaselineTrace, ObjectSkipTrace, BandSkipTrace, ScriptCancelTrace, FieldBindTrace,
       FieldResolveMissTrace, FieldResolveMissWithUnsupportedTrace, BackgroundTrace, VisibleTrace, EscapedQuoteTrace, WhitespaceTrace, TrailingSemicolonTrace,
       UnknownCommandTrace, FieldSyntaxTrace, FieldNameTrace, ColorValueTrace,
       VisibleValueTrace, TextLiteralTrace, CanPrintValueTrace, MultiInvalidTrace,
       MixedValidInvalidTrace, CancelShortCircuitTrace, QuotedSemicolonWithUnsupportedTrace,
       ObjectTypeMismatchTrace, LowercaseTextKeyTrace, MixedCaseCanPrintTrace,
       MixedCaseVisibleTrace, MixedCaseBackgroundTrace, FontColorTrace, FontSizeTrace,
       FontNameTrace, BorderColorTrace, TransparentTrace, AutoSizeTrace, WordWrapTrace, BorderVisibleTrace,
       BorderWidthTrace, PaddingLeftTrace, PaddingTopTrace, PaddingRightTrace,
       PaddingBottomTrace, FontColorOnTrueTrace, BackgroundOnTrueTrace,
       BorderColorOnTrueTrace, BackgroundConditionTrace, ImageStretchTrace,
       ImageDataFieldTrace, ImageCenterTrace, ImageProportionalTrace,
       BorderColorConditionTrace]);

    Lines.Add('');
    Lines.Add('Baseline trace preview:');
    for I := 0 to Min(TracePreviewMax - 1, BaselineTrace.Count - 1) do
      Lines.Add('  ' + BaselineTrace[I]);
    if BaselineTrace.Count > TracePreviewMax then
      Lines.Add(Format('  ... (%d more lines)', [BaselineTrace.Count - TracePreviewMax]));

    Lines.Add('');
    Lines.Add('Object-skip trace preview:');
    for I := 0 to Min(TracePreviewMax - 1, ObjectSkipTrace.Count - 1) do
      Lines.Add('  ' + ObjectSkipTrace[I]);
    if ObjectSkipTrace.Count > TracePreviewMax then
      Lines.Add(Format('  ... (%d more lines)', [ObjectSkipTrace.Count - TracePreviewMax]));

    Lines.Add('');
    Lines.Add('Band-skip trace preview:');
    for I := 0 to Min(TracePreviewMax - 1, BandSkipTrace.Count - 1) do
      Lines.Add('  ' + BandSkipTrace[I]);
    if BandSkipTrace.Count > TracePreviewMax then
      Lines.Add(Format('  ... (%d more lines)', [BandSkipTrace.Count - TracePreviewMax]));

    Lines.Add('');
    Lines.Add('Script-host cancel trace preview:');
    for I := 0 to Min(TracePreviewMax - 1, ScriptCancelTrace.Count - 1) do
      Lines.Add('  ' + ScriptCancelTrace[I]);
    if ScriptCancelTrace.Count > TracePreviewMax then
      Lines.Add(Format('  ... (%d more lines)', [ScriptCancelTrace.Count - TracePreviewMax]));

    ResultDlg := TForm.Create(nil);
    try
      ResultDlg.Caption := 'Runtime Event Callback Demo Result';
      ResultDlg.Position := poScreenCenter;
      ResultDlg.Width := 900;
      ResultDlg.Height := 700;
      ResultDlg.BorderStyle := bsSizeable;

      ResultMemo := TMemo.Create(ResultDlg);
      ResultMemo.Parent := ResultDlg;
      ResultMemo.Align := alClient;
      ResultMemo.ReadOnly := True;
      ResultMemo.ScrollBars := ssBoth;
      ResultMemo.WordWrap := False;
      ResultMemo.Font.Name := 'Consolas';
      ResultMemo.Font.Size := 10;
      ResultMemo.Lines.Text := Lines.Text;

      BtnClose := TButton.Create(ResultDlg);
      BtnClose.Parent := ResultDlg;
      BtnClose.Caption := 'Close';
      BtnClose.ModalResult := mrOK;
      BtnClose.Anchors := [akRight, akBottom];
      BtnClose.Width := 90;
      BtnClose.Height := 28;
      BtnClose.Left := ResultDlg.ClientWidth - BtnClose.Width - 12;
      BtnClose.Top := ResultDlg.ClientHeight - BtnClose.Height - 8;

      BtnCopy := TButton.Create(ResultDlg);
      BtnCopy.Parent := ResultDlg;
      BtnCopy.Caption := 'Copy';
      BtnCopy.Hint := 'Copy full demo output to clipboard';
      BtnCopy.ShowHint := True;
      BtnCopy.Anchors := [akRight, akBottom];
      BtnCopy.Width := 90;
      BtnCopy.Height := 28;
      BtnCopy.Left := BtnClose.Left - BtnCopy.Width - 8;
      BtnCopy.Top := BtnClose.Top;
      FRuntimeEventDemoOutput := ResultMemo.Lines.Text;
      BtnCopy.OnClick := ACopyClick;

      ResultMemo.AlignWithMargins := True;
      ResultMemo.Margins.Left := 8;
      ResultMemo.Margins.Top := 8;
      ResultMemo.Margins.Right := 8;
      ResultMemo.Margins.Bottom := BtnClose.Height + 16;

      ResultDlg.ActiveControl := BtnClose;
      ResultDlg.ShowModal;
    finally
      ResultDlg.Free;
    end;
  finally
    VisibleTrace.Free;
    AnchorRightTrace.Free;
    BackgroundTrace.Free;
    FieldBindTrace.Free;
    FieldResolveMissTrace.Free;
    FieldResolveMissWithUnsupportedTrace.Free;
    CanPrintValueTrace.Free;
    MultiInvalidTrace.Free;
    MixedValidInvalidTrace.Free;
    CancelShortCircuitTrace.Free;
    QuotedSemicolonWithUnsupportedTrace.Free;
    ObjectTypeMismatchTrace.Free;
    LowercaseTextKeyTrace.Free;
    MixedCaseCanPrintTrace.Free;
    MixedCaseVisibleTrace.Free;
    MixedCaseBackgroundTrace.Free;
    FontColorTrace.Free;
    FontSizeTrace.Free;
    FontNameTrace.Free;
    FontBoldTrace.Free;
    FontItalicTrace.Free;
    HAlignTrace.Free;
    VAlignTrace.Free;
    PrintWhenTrace.Free;
    DataFieldTrace.Free;
    ExpressionTrace.Free;
    FontColorConditionTrace.Free;
    AnchorBottomTrace.Free;
    FieldDisplayFormatTrace.Free;
    ImageStretchTrace.Free;
    ImageDataFieldTrace.Free;
    ImageCenterTrace.Free;
    ImageProportionalTrace.Free;
    BorderColorTrace.Free;
    TransparentTrace.Free;
    AutoSizeTrace.Free;
    WordWrapTrace.Free;
    BorderVisibleTrace.Free;
    BorderWidthTrace.Free;
    PaddingLeftTrace.Free;
    PaddingTopTrace.Free;
    PaddingRightTrace.Free;
    PaddingBottomTrace.Free;
    FontColorOnTrueTrace.Free;
    BackgroundOnTrueTrace.Free;
    BorderColorOnTrueTrace.Free;
    BackgroundConditionTrace.Free;
    BorderColorConditionTrace.Free;
    TextLiteralTrace.Free;
    VisibleValueTrace.Free;
    ColorValueTrace.Free;
    FieldNameTrace.Free;
    FieldSyntaxTrace.Free;
    TrailingSemicolonTrace.Free;
    UnknownCommandTrace.Free;
    WhitespaceTrace.Free;
    EscapedQuoteTrace.Free;
    ScriptCancelTrace.Free;
    BandSkipTrace.Free;
    ObjectSkipTrace.Free;
    BaselineTrace.Free;
    Lines.Free;
    Harness.Free;
    Engine.Free;
    ReportModel.Free;
  end;
end;

function RuntimeEventDemoOutput: string;
begin
  // Read by the designer's copy handler (TfrmMain.RuntimeEventDemoCopyClick)
  // which is wired as the result dialog's Copy button OnClick.
  Result := FRuntimeEventDemoOutput;
end;

end.
