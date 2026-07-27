import re

def main():
    file_path = "source/Vittix.Report.Engine.pas"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Change class declaration
    content = content.replace("  TReportEngine = class\n", "  TReportEngine = class(TObject, IInterface, IReportRenderHooks)\n")

    # 2. Add IInterface and IReportRenderHooks methods to public section
    old_public = "  public\n    constructor Create;"
    new_public = """  public
    // IInterface implementation
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;

    // IReportRenderHooks implementation
    procedure InvokeBeforeObjectPrint(Sender: TObject; const Context: TExpressionContext; var ACanPrint: Boolean);
    procedure InvokeAfterObjectPrint(Sender: TObject; const Context: TExpressionContext);
    function GetNamedDataSet(const AName: string): TDataSet;

    constructor Create;"""
    content = content.replace(old_public, new_public)

    # 3. Rename HandleBeforeObjectPrint/HandleAfterObjectPrint in private
    content = re.sub(
        r"    procedure HandleBeforeObjectPrint\(\s*AObject: TReportObject;\s*const Context: TExpressionContext;\s*var ACanPrint: Boolean\);\s*"
        r"    procedure HandleAfterObjectPrint\(\s*AObject: TReportObject;\s*const Context: TExpressionContext\);\s*",
        "", content)

    # 4. Inject Ctx.Hooks := Self;
    content = content.replace("var Ctx2: TExpressionContext := Default(TExpressionContext);", 
                              "var Ctx2: TExpressionContext := Default(TExpressionContext);\n          Ctx2.Hooks := Self;")
    content = content.replace("Ctx := Default(TExpressionContext);\n  Ctx.DataSet     := ADataSet;", 
                              "Ctx := Default(TExpressionContext);\n  Ctx.Hooks := Self;\n  Ctx.DataSet     := ADataSet;")
    content = content.replace("var Ctx0: TExpressionContext := Default(TExpressionContext);", 
                              "var Ctx0: TExpressionContext := Default(TExpressionContext);\n    Ctx0.Hooks := Self;")

    # 5. Remove globals from ExecutePass
    content = re.sub(
        r"  FIsRenderingPass := AReportProgress;\s*"
        r"  SetReportNamedDataSets\(FNamedDataSets\);\s*"
        r"  if FIsRenderingPass then\s*"
        r"    SetReportObjectRenderHooks\(HandleBeforeObjectPrint, HandleAfterObjectPrint\)\s*"
        r"  else\s*"
        r"    ClearReportObjectRenderHooks;\s*",
        "  FIsRenderingPass := AReportProgress;\n", content)

    content = re.sub(
        r"  finally\s*"
        r"    ClearReportObjectRenderHooks;\s*"
        r"    FIsRenderingPass := False;\s*"
        r"    SetReportNamedDataSets\(nil\);\s*"
        r"  end;",
        "  finally\n    FIsRenderingPass := False;\n  end;", content)

    # 6. Change implementation of HandleBeforeObjectPrint and HandleAfterObjectPrint
    old_before = """procedure TReportEngine.HandleBeforeObjectPrint(
  AObject: TReportObject;
  const Context: TExpressionContext;
  var ACanPrint: Boolean);"""
    new_before = """procedure TReportEngine.InvokeBeforeObjectPrint(
  Sender: TObject;
  const Context: TExpressionContext;
  var ACanPrint: Boolean);
var
  AObject: TReportObject;
begin
  AObject := Sender as TReportObject;"""
    content = content.replace(old_before + "\nbegin", new_before)

    old_after = """procedure TReportEngine.HandleAfterObjectPrint(
  AObject: TReportObject;
  const Context: TExpressionContext);"""
    new_after = """procedure TReportEngine.InvokeAfterObjectPrint(
  Sender: TObject;
  const Context: TExpressionContext);
var
  AObject: TReportObject;
begin
  AObject := Sender as TReportObject;"""
    content = content.replace(old_after + "\nbegin", new_after)

    # 7. Add IInterface implementations and GetNamedDataSet
    impl = """
function TReportEngine.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

function TReportEngine._AddRef: Integer;
begin
  Result := -1;
end;

function TReportEngine._Release: Integer;
begin
  Result := -1;
end;

function TReportEngine.GetNamedDataSet(const AName: string): TDataSet;
begin
  if not FNamedDataSets.TryGetValue(AName, Result) then
    Result := nil;
end;

end.
"""
    content = content.replace("end.\n", impl)
    if "end." in content and not content.endswith(impl):
         # fallback if the above replace didn't hit
         content = content.rsplit("end.", 1)[0] + impl

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print("Success")

if __name__ == '__main__':
    main()
