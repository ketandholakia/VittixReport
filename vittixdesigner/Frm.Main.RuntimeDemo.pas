unit Frm.Main.RuntimeDemo;

interface

uses
  System.Classes,
  System.SysUtils,
  System.StrUtils,
  Vittix.Report.Context,
  Vittix.Report.Bands,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.ScriptHost.Adapter;

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

implementation

constructor TRuntimeEventDemoHarness.Create;
begin
  inherited Create;
  FTrace := TStringList.Create;
  FScriptAdapter := TReportScriptHostAdapter.Create;
  ResetCounts;
end;

destructor TRuntimeEventDemoHarness.Destroy;
begin
  FScriptAdapter.Free;
  FTrace.Free;
  inherited;
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
  FTrace.Add('BeforeBand: ' + ABand.ClassName);
  if FSkipMasterDataBand and (ABand.BandType = btMasterData) then
  begin
    ACanPrint := False;
    Inc(SkippedBandCount);
    FTrace.Add('SkipBand: ' + ABand.ClassName);
  end;
end;

procedure TRuntimeEventDemoHarness.AfterBand(Sender, AEngine: TObject;
  ABand: TReportBand; const Context: TExpressionContext);
begin
  Inc(AfterBandCount);
  FTrace.Add('AfterBand: ' + ABand.ClassName);
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
  TraceLines: TStringList;
  Line: string;
begin
  Inc(ScriptBeforeObjectCount);
  FTrace.Add(Format('ScriptBeforeObject: %s "%s" text="%s"',
    [AObject.ClassName, AObject.Name, Script]));

  S := Trim(Script);

  CmdResult := FScriptAdapter.ExecuteBeforeObject(AObject, S, Context, ACanPrint);
  if CmdResult.Handled then
  begin
    Inc(ScriptTextSetCount, CmdResult.TextSetCount);
    if CmdResult.Canceled then
      Inc(ScriptCanceledObjectCount);
    Inc(ScriptUnsupportedCount, CmdResult.UnsupportedCount);
    if CmdResult.TraceMessage <> '' then
    begin
      TraceLines := TStringList.Create;
      try
        TraceLines.Text := CmdResult.TraceMessage;
        for Line in TraceLines do
          if Trim(Line) <> '' then
            FTrace.Add(Line);
      finally
        TraceLines.Free;
      end;
    end;
    Exit;
  end;

  LogScriptUnsupported('ScriptUnsupported[UnknownCommand]: ' + S);
end;

procedure TRuntimeEventDemoHarness.ScriptAfterObject(AReport: TReportModel;
  AObject: TReportObject; const Script: string; var Context: TExpressionContext);
begin
  Inc(ScriptAfterObjectCount);
  FTrace.Add(Format('ScriptAfterObject: %s "%s" text="%s"',
    [AObject.ClassName, AObject.Name, Script]));
end;

procedure TRuntimeEventDemoHarness.LogScriptUnsupported(const AReason: string);
begin
  Inc(ScriptUnsupportedCount);
  FTrace.Add(AReason);
end;

end.
