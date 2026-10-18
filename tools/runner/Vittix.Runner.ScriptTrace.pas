unit Vittix.Runner.ScriptTrace;

{
  Phase 3E-5: script-trace presentation extracted from Vittix.Runner.Console.

  This unit owns only script-trace rendering. Orchestration, execution,
  counters, formatting and output policy remain in the console. All output
  goes through the supplied writer callback; this unit never writes to
  stdout/stderr directly.
}

interface

uses
  System.SysUtils,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Context,
  Vittix.Report.Scripting,
  Vittix.Report.ScriptHost.Adapter;

type
  TScriptTraceWriter = reference to procedure(const ALine: string);

procedure WriteScriptTraceObject(
  const AAdapter: TReportScriptHostAdapter;
  const AObject: TReportObject;
  ALevel: Integer;
  const AWrite: TScriptTraceWriter);

procedure WriteScriptTraceTree(
  const AAdapter: TReportScriptHostAdapter;
  const AObject: TReportObject;
  ALevel: Integer;
  const AWrite: TScriptTraceWriter);

implementation

procedure WriteScriptTraceObject(const AAdapter: TReportScriptHostAdapter; const AObject: TReportObject;
  ALevel: Integer; const AWrite: TScriptTraceWriter);
var
  Ctx: TExpressionContext;
  DummyCanPrint: Boolean;
  ResultBefore: TScriptHostCommandResult;
  ResultAfter: TScriptHostCommandResult;
  Indent: string;
  ObjName: string;
  TraceLine: string;
begin
  if not Assigned(AObject) then
    Exit;

  Indent := StringOfChar(' ', ALevel * 2);
  ObjName := AObject.ClassName;
  if AObject.Name <> '' then
    ObjName := ObjName + ' "' + AObject.Name + '"';

  DummyCanPrint := True;
  Ctx := Default(TExpressionContext);

  if AObject.OnBeforePrint <> '' then
  begin
    ResultBefore := AAdapter.ExecuteBeforeObject(AObject, AObject.OnBeforePrint, Ctx, DummyCanPrint);
    AWrite(Indent + '[Before] ' + ObjName);
    if ResultBefore.TraceMessage <> '' then
    begin
      TraceLine := StringReplace(ResultBefore.TraceMessage, sLineBreak, sLineBreak + Indent + '  ', [rfReplaceAll]);
      AWrite(Indent + '  ' + ObjName + ':');
      AWrite(Indent + '    ' + TraceLine);
    end;
  end;

  if AObject.OnAfterPrint <> '' then
  begin
    ResultAfter := AAdapter.ExecuteAfterObject(AObject, AObject.OnAfterPrint, Ctx);
    AWrite(Indent + '[After ] ' + ObjName);
    if ResultAfter.TraceMessage <> '' then
    begin
      TraceLine := StringReplace(ResultAfter.TraceMessage, sLineBreak, sLineBreak + Indent + '  ', [rfReplaceAll]);
      AWrite(Indent + '  ' + ObjName + ':');
      AWrite(Indent + '    ' + TraceLine);
    end;
  end;
end;

procedure WriteScriptTraceTree(const AAdapter: TReportScriptHostAdapter; const AObject: TReportObject;
  ALevel: Integer; const AWrite: TScriptTraceWriter);
var
  Band: TReportBand;
  Child: TReportObject;
begin
  if not Assigned(AObject) then
    Exit;

  WriteScriptTraceObject(AAdapter, AObject, ALevel, AWrite);
  if AObject is TReportBand then
  begin
    Band := TReportBand(AObject);
    for Child in Band.Children do
      WriteScriptTraceTree(AAdapter, Child, ALevel + 1, AWrite);
  end;
end;

end.
