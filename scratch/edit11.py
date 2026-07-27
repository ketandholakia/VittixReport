import re

def process():
    file_path = "source/Vittix.Report.ScriptHost.Adapter.pas"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Add System.Generics.Collections
    if "System.Generics.Collections" not in content:
        content = content.replace("uses\n  System.SysUtils,", "uses\n  System.SysUtils,\n  System.Generics.Collections,")

    # 2. Add types and class modifications
    class_decl = """type
  TScriptCommandHandler = reference to procedure(
    AObject: TReportObject;
    const Value, AScript: string;
    var Context: TExpressionContext;
    var ACanPrint: Boolean;
    var Result: TScriptHostCommandResult
  );

  TReportScriptHostAdapter = class
  private
    FHandlers: TDictionary<string, TScriptCommandHandler>;
    procedure InitHandlers;
"""
    content = content.replace("type\n  TReportScriptHostAdapter = class\n  private", class_decl)
    
    # 3. Add constructor/destructor to public
    content = content.replace("    public\n      procedure EngineObjectBeforePrint", "    public\n      constructor Create;\n      destructor Destroy; override;\n      procedure EngineObjectBeforePrint")

    # 4. Extract blocks
    blocks = re.findall(r"  if Key = '([a-z]+)' then\s*begin\s*(.*?)\s*Exit;\s*end;", content, re.DOTALL)
    
    # 5. Build InitHandlers
    init_handlers = "constructor TReportScriptHostAdapter.Create;\nbegin\n  inherited;\n  FHandlers := TDictionary<string, TScriptCommandHandler>.Create;\n  InitHandlers;\nend;\n\n"
    init_handlers += "destructor TReportScriptHostAdapter.Destroy;\nbegin\n  FHandlers.Free;\n  inherited;\nend;\n\n"
    init_handlers += "procedure TReportScriptHostAdapter.InitHandlers;\nbegin\n"
    
    for key, block in blocks:
        # Indent block
        lines = block.split('\n')
        indented_block = "\n".join(["    " + line for line in lines])
        
        handler = f"""  FHandlers.Add('{key}', procedure(
    AObject: TReportObject;
    const Value, AScript: string;
    var Context: TExpressionContext;
    var ACanPrint: Boolean;
    var Result: TScriptHostCommandResult
  )
  var
    B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
  begin
{indented_block}
  end);
"""
        init_handlers += handler
        
    init_handlers += "end;\n\n"
    
    # Insert init_handlers right before ExecuteSingleBeforeObject
    content = content.replace("function TReportScriptHostAdapter.ExecuteSingleBeforeObject", init_handlers + "function TReportScriptHostAdapter.ExecuteSingleBeforeObject")

    # 6. Replace ExecuteSingleBeforeObject body
    old_body_match = re.search(r"(function TReportScriptHostAdapter\.ExecuteSingleBeforeObject.*?)begin(.*?)Result\.Handled := True;\n\n(.*?)  Result\.Handled := True;\n  Result\.Unsupported := True;", content, re.DOTALL)
    
    if old_body_match:
        func_sig = old_body_match.group(1)
        initial_setup = old_body_match.group(2) # up to parsing Key/Value
        
        new_body = func_sig + """var
  Handler: TScriptCommandHandler;
begin""" + initial_setup + """
  if FHandlers.TryGetValue(Key, Handler) then
  begin
    Result.Handled := True;
    Handler(AObject, Value, AScript, Context, ACanPrint, Result);
  end
  else
  begin
    Result.Handled := True;
    Result.Unsupported := True;
    Result.UnsupportedCount := 1;
    Result.TraceMessage := 'ScriptUnsupported[UnknownCommand]: ' + AScript;
  end;
"""
        # And we need to remove the rest until the end of function
        full_old_func = re.search(r"(function TReportScriptHostAdapter\.ExecuteSingleBeforeObject.*?^end;)", content, re.DOTALL | re.MULTILINE).group(1)
        new_func = new_body + "end;"
        content = content.replace(full_old_func, new_func)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

process()
print("Success")
