unit Vittix.Designer.RuntimeDemo;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.IOUtils,
  System.Math,
  Vcl.Forms, Vcl.StdCtrls, Vcl.Controls, Vcl.Graphics, Vcl.Clipbrd,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Context,
  Vittix.Report.Expressions,
  Vittix.Report.Engine,
  Vittix.Report.Serializer,
  Vittix.Report.ScriptHost.Adapter;

procedure RunRuntimeEventCallbackDemo(
  const ALoadReportModel: TFunc<TReportModel>;
  const AUseSampleDataSet: TProc;
  const AGetSampleDataSet: TFunc<TDataSet>);

implementation

type
  TRuntimeEventDemoHarness = class
  private
    FTrace: TStringList;
    FSkipObjectClassName: string;
    FSkipMasterDataBand: Boolean;
    FScriptAdapter: TReportScriptHostAdapter;
    procedure LogScriptUnsupported(const AReason: string);
  public
    BeforeReportCount: Integer;
    AfterReportCount: Integer;
    BeforeBandCount: Integer;
    AfterBandCount: Integer;
    BeforeObjectCount: Integer;
    AfterObjectCount: Integer;
    ScriptBeforeObjectCount: Integer;
    ScriptAfterObjectCount: Integer;
    SkippedBandCount: Integer;
    SkippedObjectCount: Integer;
    ScriptCanceledObjectCount: Integer;
    ScriptTextSetCount: Integer;
    ScriptUnsupportedCount: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure ResetCounts;
    procedure BeforeReport(Sender, AEngine: TObject; AReport: TReportModel;
      var ACancel: Boolean);
    procedure AfterReport(Sender, AEngine: TObject; AReport: TReportModel);
    procedure BeforeBand(Sender, AEngine: TObject; ABand: TReportBand;
      const Context: TExpressionContext; var ACanPrint: Boolean);
    procedure AfterBand(Sender, AEngine: TObject; ABand: TReportBand;
      const Context: TExpressionContext);
    procedure BeforeObject(Sender, AEngine: TObject; AObject: TReportObject;
      const Context: TExpressionContext; var ACanPrint: Boolean);
    procedure AfterObject(Sender, AEngine: TObject; AObject: TReportObject;
      const Context: TExpressionContext);
    procedure ScriptBeforeObject(AReport: TReportModel; AObject: TReportObject;
      const Script: string; var Context: TExpressionContext; var ACanPrint: Boolean);
    procedure ScriptAfterObject(AReport: TReportModel; AObject: TReportObject;
      const Script: string; var Context: TExpressionContext);
    property Trace: TStringList read FTrace;
    property SkipObjectClassName: string read FSkipObjectClassName write FSkipObjectClassName;
    property SkipMasterDataBand: Boolean read FSkipMasterDataBand write FSkipMasterDataBand;
  end;

var
  FRuntimeEventDemoOutput: string;

procedure RuntimeEventDemoCopyClick(Sender: TObject);
function BandTypeName(BT: TReportBandType): string;
procedure ShowResultDialog(const ALines: TStrings);

procedure RunRuntimeEventCallbackDemo(
  const ALoadReportModel: TFunc<TReportModel>;
  const AUseSampleDataSet: TProc;
  const AGetSampleDataSet: TFunc<TDataSet>);
const
  TracePreviewMax = 30;
var
  ReportModel: TReportModel;
  Engine: TReportEngine;
  SampleDataSet: TDataSet;
  Harness: TRuntimeEventDemoHarness;
  Lines: TStringList;
  BaselineTrace: TStringList;
  ObjectSkipTrace: TStringList;
  BandSkipTrace: TStringList;
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
  FN: string;
  I: Integer;
  BasePass: Boolean;
  ObjectSkipPass: Boolean;
  BandSkipPass: Boolean;
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

  function TraceHasOrdered(const ATrace: TStrings; const AParts: array of string): Boolean;
  var
    StartAt, J, I: Integer;
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
    StartIdx, EndIdx, I: Integer;
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

  procedure AddUnsupportedReasonCounts(const ATrace: TStrings; ACounts: TDictionary<string, Integer>);
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

  procedure AppendUnsupportedReasonSummary(ALines: TStrings; const ATraces: array of TStrings);
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
  if Assigned(AUseSampleDataSet) then
    AUseSampleDataSet;
  SampleDataSet := nil;
  if Assigned(AGetSampleDataSet) then
    SampleDataSet := AGetSampleDataSet;

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
  FieldDisplayFormatTrace := TStringList.Create;
  FieldEditMaskTrace := TStringList.Create;
  ImageStretchTrace := TStringList.Create;
  ImageCenterTrace := TStringList.Create;
  ImageProportionalTrace := TStringList.Create;
  ImageDataFieldTrace := TStringList.Create;
  try
    if not Assigned(ALoadReportModel) then
      raise Exception.Create('No report loader provided for runtime event demo.');

    ReportModel := ALoadReportModel();
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

    Lines.Add('');
    Lines.Add('Baseline trace preview:');
    for I := 0 to Min(TracePreviewMax - 1, BaselineTrace.Count - 1) do
      Lines.Add('  ' + BaselineTrace[I]);
    if BaselineTrace.Count > TracePreviewMax then
      Lines.Add(Format('  ... (%d more lines)', [BaselineTrace.Count - TracePreviewMax]));

    ShowResultDialog(Lines);
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
    ReportModel.Free;
  end;
end;

procedure RuntimeEventDemoCopyClick(Sender: TObject);
begin
  Clipboard.AsText := FRuntimeEventDemoOutput;
end;

function BandTypeName(BT: TReportBandType): string;
begin
  case BT of
    btReportTitle:   Result := 'Report Title';
    btPageHeader:    Result := 'Page Header';
    btMasterData:    Result := 'Master Data';
    btPageFooter:    Result := 'Page Footer';
    btReportSummary: Result := 'Summary';
    btGroupHeader:   Result := 'Group Header';
    btGroupFooter:   Result := 'Group Footer';
    btColumnHeader:  Result := 'Column Header';
    btDetail:        Result := 'Detail';
    btOverlay:       Result := 'Overlay';
  else
    Result := 'Band';
  end;
end;

procedure ShowResultDialog(const ALines: TStrings);
var
  ResultDlg: TForm;
  ResultMemo: TMemo;
  BtnClose: TButton;
  BtnCopy: TButton;
begin
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
    ResultMemo.Lines.Assign(ALines);

    BtnClose := TButton.Create(ResultDlg);
    BtnClose.Parent := ResultDlg;
    BtnClose.Caption := 'Close';
    BtnClose.ModalResult := mrOk;
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
    FRuntimeEventDemoOutput := ALines.Text;

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
end;

{ TRuntimeEventDemoHarness }

constructor TRuntimeEventDemoHarness.Create;
begin
  inherited Create;
  FTrace := TStringList.Create;
  FScriptAdapter := TReportScriptHostAdapter.Create;
  ResetCounts;
end;

procedure TRuntimeEventDemoHarness.LogScriptUnsupported(const AReason: string);
begin
  Inc(ScriptUnsupportedCount);
  FTrace.Add('ScriptUnsupported[' + AReason + ']: ' + AReason);
end;

procedure TRuntimeEventDemoHarness.ResetCounts;
begin
  BeforeReportCount := 0;
  AfterReportCount := 0;
  BeforeBandCount := 0;
  AfterBandCount := 0;
  BeforeObjectCount := 0;
  AfterObjectCount := 0;
  ScriptBeforeObjectCount := 0;
  ScriptAfterObjectCount := 0;
  SkippedBandCount := 0;
  SkippedObjectCount := 0;
  ScriptCanceledObjectCount := 0;
  ScriptTextSetCount := 0;
  ScriptUnsupportedCount := 0;
  FTrace.Clear;
  FSkipObjectClassName := '';
  FSkipMasterDataBand := False;
end;

destructor TRuntimeEventDemoHarness.Destroy;
begin
  FScriptAdapter.Free;
  FTrace.Free;
  inherited;
end;

procedure TRuntimeEventDemoHarness.BeforeReport(Sender, AEngine: TObject;
  AReport: TReportModel; var ACancel: Boolean);
begin
  Inc(BeforeReportCount);
  FTrace.Add('BeforeReport');
end;

procedure TRuntimeEventDemoHarness.AfterReport(Sender, AEngine: TObject;
  AReport: TReportModel);
begin
  Inc(AfterReportCount);
  FTrace.Add('AfterReport');
end;

procedure TRuntimeEventDemoHarness.BeforeBand(Sender, AEngine: TObject;
  ABand: TReportBand; const Context: TExpressionContext; var ACanPrint: Boolean);
begin
  Inc(BeforeBandCount);
  FTrace.Add('BeforeBand: ' + BandTypeName(ABand.BandType));
  if FSkipMasterDataBand and (ABand.BandType = btMasterData) then
  begin
    ACanPrint := False;
    Inc(SkippedBandCount);
    FTrace.Add('SkipBand: Master Data');
  end;
end;

procedure TRuntimeEventDemoHarness.AfterBand(Sender, AEngine: TObject;
  ABand: TReportBand; const Context: TExpressionContext);
begin
  Inc(AfterBandCount);
  FTrace.Add('AfterBand: ' + BandTypeName(ABand.BandType));
end;

procedure TRuntimeEventDemoHarness.BeforeObject(Sender, AEngine: TObject;
  AObject: TReportObject; const Context: TExpressionContext; var ACanPrint: Boolean);
begin
  Inc(BeforeObjectCount);
  FTrace.Add('BeforeObject: ' + AObject.ClassName);
  if (FSkipObjectClassName <> '') and SameText(AObject.ClassName, FSkipObjectClassName) then
  begin
    ACanPrint := False;
    Inc(SkippedObjectCount);
    FTrace.Add('SkipObject: ' + AObject.ClassName);
  end;
end;

procedure TRuntimeEventDemoHarness.AfterObject(Sender, AEngine: TObject;
  AObject: TReportObject; const Context: TExpressionContext);
begin
  Inc(AfterObjectCount);
  FTrace.Add('AfterObject: ' + AObject.ClassName);
end;

procedure TRuntimeEventDemoHarness.ScriptBeforeObject(AReport: TReportModel;
  AObject: TReportObject; const Script: string; var Context: TExpressionContext;
  var ACanPrint: Boolean);
var
  S: string;
  CmdResult: TScriptHostCommandResult;
begin
  Inc(ScriptBeforeObjectCount);
  FTrace.Add(Format('ScriptBeforeObject: %s "%s" text="%s"',
    [AObject.ClassName, AObject.Name, Script]));

  S := Trim(Script);
  CmdResult := FScriptAdapter.ExecuteBeforeObject(AObject, S, Context, ACanPrint);
  if CmdResult.Handled then
  begin
    if CmdResult.Canceled then
    begin
      Inc(ScriptCanceledObjectCount);
      FTrace.Add('ScriptCanceledObject: ' + AObject.ClassName);
    end;
    if CmdResult.TextSet then
    begin
      Inc(ScriptTextSetCount);
      FTrace.Add('ScriptSetText: ' + AObject.ClassName);
    end;
  end
  else if CmdResult.Unsupported then
    LogScriptUnsupported(CmdResult.Reason);
end;

procedure TRuntimeEventDemoHarness.ScriptAfterObject(AReport: TReportModel;
  AObject: TReportObject; const Script: string; var Context: TExpressionContext);
begin
  Inc(ScriptAfterObjectCount);
  FTrace.Add(Format('ScriptAfterObject: %s "%s" text="%s"',
    [AObject.ClassName, AObject.Name, Script]));
end;

end.
