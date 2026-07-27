import re
import sys

def main():
    file_path = "source/Vittix.Report.Objects.pas"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Remove from Interface
    content = re.sub(
        r"procedure SetReportNamedDataSets\(ANamedDataSets: TDictionary<string, TDataSet>\);\s*"
        r"procedure SetReportObjectRenderHooks\(\s*const ABeforePrint: TReportObjectBeforePrintEvent;\s*const AAfterPrint: TReportObjectAfterPrintEvent\);\s*"
        r"procedure ClearReportObjectRenderHooks;\s*",
        "", content)

    # 2. Remove globals
    content = re.sub(
        r"  GNamedDataSets: TDictionary<string, TDataSet>;\s*"
        r"  GBeforeObjectPrint: TReportObjectBeforePrintEvent;\s*"
        r"  GAfterObjectPrint: TReportObjectAfterPrintEvent;\s*",
        "", content)

    # 3. Remove implementations
    content = re.sub(
        r"procedure SetReportObjectRenderHooks\(\s*const ABeforePrint: TReportObjectBeforePrintEvent;\s*const AAfterPrint: TReportObjectAfterPrintEvent\);\s*"
        r"begin\s*"
        r"  GBeforeObjectPrint := ABeforePrint;\s*"
        r"  GAfterObjectPrint := AAfterPrint;\s*"
        r"end;\s*"
        r"procedure ClearReportObjectRenderHooks;\s*"
        r"begin\s*"
        r"  GBeforeObjectPrint := nil;\s*"
        r"  GAfterObjectPrint := nil;\s*"
        r"end;\s*",
        "", content)

    # 4. Update DrawReportObjectWithHooks
    old_draw = """procedure DrawReportObjectWithHooks(
  AObject: TReportObject;
  C: TCanvas;
  const Context: TExpressionContext);
var
  CanPrint: Boolean;
begin
  if not Assigned(AObject) then
    Exit;

  // Required execution order:
  // PrintWhen -> persisted/runtime before-hooks -> draw -> persisted/runtime after-hooks.
  // Evaluate PrintWhen first so object hooks are skipped when the object will not print.
  if not ShouldPrintObject(AObject, Context) then
    Exit;

  CanPrint := True;
  if Assigned(GBeforeObjectPrint) then
    GBeforeObjectPrint(AObject, Context, CanPrint);
  if not CanPrint then
    Exit;

  GPrecheckedObjectForPrintWhen := AObject;
  try
    AObject.Draw(C, Context);
  finally
    GPrecheckedObjectForPrintWhen := nil;
  end;

  if Assigned(GAfterObjectPrint) then
    GAfterObjectPrint(AObject, Context);
end;"""

    new_draw = """procedure DrawReportObjectWithHooks(
  AObject: TReportObject;
  C: TCanvas;
  const Context: TExpressionContext);
var
  CanPrint: Boolean;
begin
  if not Assigned(AObject) then
    Exit;

  // Required execution order:
  // PrintWhen -> persisted/runtime before-hooks -> draw -> persisted/runtime after-hooks.
  // Evaluate PrintWhen first so object hooks are skipped when the object will not print.
  if not ShouldPrintObject(AObject, Context) then
    Exit;

  CanPrint := True;
  if Assigned(Context.Hooks) then
    Context.Hooks.InvokeBeforeObjectPrint(AObject, Context, CanPrint);
  if not CanPrint then
    Exit;

  GPrecheckedObjectForPrintWhen := AObject;
  try
    AObject.Draw(C, Context);
  finally
    GPrecheckedObjectForPrintWhen := nil;
  end;

  if Assigned(Context.Hooks) then
    Context.Hooks.InvokeAfterObjectPrint(AObject, Context);
end;"""
    content = content.replace(old_draw, new_draw)

    # 5. Remove SetReportNamedDataSets implementation
    content = re.sub(
        r"procedure SetReportNamedDataSets\(ANamedDataSets: TDictionary<string, TDataSet>\);\s*"
        r"begin\s*"
        r"  GNamedDataSets := ANamedDataSets;\s*"
        r"end;\s*",
        "", content)

    # 6. Update ResolveSubReportDataSet
    old_resolve = """function ResolveSubReportDataSet(Obj: TReportSubReportObject;
  const Context: TExpressionContext): TDataSet;
begin
  Result := Context.DataSet;
  if Trim(Obj.FDataSetName) = '' then
    Exit;

  Result := nil;
  try
    if Assigned(GNamedDataSets) then
      if not GNamedDataSets.TryGetValue(Obj.FDataSetName, Result) then
        Result := nil;
  except
    Result := nil;
  end;
end;"""
    new_resolve = """function ResolveSubReportDataSet(Obj: TReportSubReportObject;
  const Context: TExpressionContext): TDataSet;
begin
  Result := Context.DataSet;
  if Trim(Obj.FDataSetName) = '' then
    Exit;

  Result := nil;
  try
    if Assigned(Context.Hooks) then
      Result := Context.Hooks.GetNamedDataSet(Obj.FDataSetName);
  except
    Result := nil;
  end;
end;"""
    content = content.replace(old_resolve, new_resolve)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print("Success")

if __name__ == '__main__':
    main()
