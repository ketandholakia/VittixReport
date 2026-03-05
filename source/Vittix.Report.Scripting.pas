unit Vittix.Report.Scripting;

interface

uses
  System.Classes,
  Vittix.Report.Context;

type
  TReportScriptEvent = procedure(const Script: string; var Context: TExpressionContext) of object;

  TReportScriptEngine = class(TComponent)
  private
    FOnBeforePrint: TReportScriptEvent;
    FOnAfterPrint: TReportScriptEvent;
  public
    procedure ExecuteBeforePrint(const Script: string; var Context: TExpressionContext);
    procedure ExecuteAfterPrint(const Script: string; var Context: TExpressionContext);
  published
    property OnBeforePrint: TReportScriptEvent read FOnBeforePrint write FOnBeforePrint;
    property OnAfterPrint: TReportScriptEvent read FOnAfterPrint write FOnAfterPrint;
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

end.
