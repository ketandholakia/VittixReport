import re

def main():
    file_path = "source/Vittix.Report.Engine.pas"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Add IInterface and IReportRenderHooks methods to public section
    new_methods = """
    // IInterface implementation
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;

    // IReportRenderHooks implementation
    procedure InvokeBeforeObjectPrint(Sender: TObject; const Context: TExpressionContext; var ACanPrint: Boolean);
    procedure InvokeAfterObjectPrint(Sender: TObject; const Context: TExpressionContext);
    function GetNamedDataSet(const AName: string): TDataSet;
"""
    content = content.replace("  public\n", "  public" + new_methods)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print("Success")

if __name__ == '__main__':
    main()
