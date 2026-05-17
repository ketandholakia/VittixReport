unit Vittix.Report.Scripting;

interface

uses
  System.Classes,
  Vittix.Report.Context,
  Vittix.Report.Objects,
  Vittix.Report.Model;

type
  TReportScriptEvent = procedure(const Script: string; var Context: TExpressionContext) of object;
  TReportObjectScriptBeforeEvent = procedure(
    AReport: TReportModel;
    AObject: TReportObject;
    const Script: string;
    var Context: TExpressionContext;
    var ACanPrint: Boolean) of object;
  TReportObjectScriptAfterEvent = procedure(
    AReport: TReportModel;
    AObject: TReportObject;
    const Script: string;
    var Context: TExpressionContext) of object;

  TReportScriptEngine = class(TComponent)
  private
    FOnBeforePrint: TReportScriptEvent;
    FOnAfterPrint: TReportScriptEvent;
    FOnObjectBeforePrint: TReportObjectScriptBeforeEvent;
    FOnObjectAfterPrint: TReportObjectScriptAfterEvent;
  public
    procedure ExecuteBeforePrint(const Script: string; var Context: TExpressionContext);
    procedure ExecuteAfterPrint(const Script: string; var Context: TExpressionContext);
    procedure ExecuteObjectBeforePrint(
      AReport: TReportModel;
      AObject: TReportObject;
      const Script: string;
      var Context: TExpressionContext;
      var ACanPrint: Boolean);
    procedure ExecuteObjectAfterPrint(
      AReport: TReportModel;
      AObject: TReportObject;
      const Script: string;
      var Context: TExpressionContext);
  published
    property OnBeforePrint: TReportScriptEvent read FOnBeforePrint write FOnBeforePrint;
    property OnAfterPrint: TReportScriptEvent read FOnAfterPrint write FOnAfterPrint;
    property OnObjectBeforePrint: TReportObjectScriptBeforeEvent
      read FOnObjectBeforePrint write FOnObjectBeforePrint;
    property OnObjectAfterPrint: TReportObjectScriptAfterEvent
      read FOnObjectAfterPrint write FOnObjectAfterPrint;
  end;

implementation

procedure TReportScriptEngine.ExecuteBeforePrint(const Script: string; var Context: TExpressionContext);
begin
  if Assigned(FOnBeforePrint) then
    FOnBeforePrint(Script, Context);
end;

procedure TReportScriptEngine.ExecuteAfterPrint(const Script: string; var Context: TExpressionContext);
begin
  if Assigned(FOnAfterPrint) then
    FOnAfterPrint(Script, Context);
end;

procedure TReportScriptEngine.ExecuteObjectBeforePrint(
  AReport: TReportModel;
  AObject: TReportObject;
  const Script: string;
  var Context: TExpressionContext;
  var ACanPrint: Boolean);
begin
  if Assigned(FOnObjectBeforePrint) then
    FOnObjectBeforePrint(AReport, AObject, Script, Context, ACanPrint);
end;

procedure TReportScriptEngine.ExecuteObjectAfterPrint(
  AReport: TReportModel;
  AObject: TReportObject;
  const Script: string;
  var Context: TExpressionContext);
begin
  if Assigned(FOnObjectAfterPrint) then
    FOnObjectAfterPrint(AReport, AObject, Script, Context);
end;

end.
