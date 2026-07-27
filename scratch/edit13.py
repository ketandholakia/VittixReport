import re

def process():
    file_path = "source/Vittix.Report.ScriptHost.Adapter.pas"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Re-checkout file first
    import subprocess
    subprocess.run(["git", "checkout", "source/Vittix.Report.ScriptHost.Adapter.pas"], check=True)
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    if "System.Generics.Collections" not in content:
        content = content.replace("uses\n  System.SysUtils,", "uses\n  System.SysUtils,\n  System.Generics.Collections,")

    class_decl = """type
  TScriptCommandHandler = reference to procedure(
    AObject: TReportObject;
    const Value, AScript: string;
    var Context: TExpressionContext;
    var ACanPrint: Boolean;
    var AResult: TScriptHostCommandResult
  );

  TReportScriptHostAdapter = class
  private
    FHandlers: TDictionary<string, TScriptCommandHandler>;
    procedure InitHandlers;
"""
    content = content.replace("type\n  TReportScriptHostAdapter = class\n  private", class_decl)
    content = content.replace("    public\n      procedure EngineObjectBeforePrint", "    public\n      constructor Create;\n      destructor Destroy; override;\n      procedure EngineObjectBeforePrint")

    old_body_match = re.search(r"(function TReportScriptHostAdapter\.ExecuteSingleBeforeObject.*?)begin(.*?)Result\.Handled := True;\n(.*?)Result\.Handled := True;\n  Result\.Unsupported := True;", content, re.DOTALL)
    
    func_sig = old_body_match.group(1)
    initial_setup = old_body_match.group(2)
    big_if_chain = old_body_match.group(3)
    
    parts = big_if_chain.split("\n  if Key = '")
    
    handlers_code = ""
    
    for i in range(1, len(parts)):
        part = parts[i]
        key = part.split("'", 1)[0]
        
        # We know part looks like: "xyz' then\n  begin\n...Exit;\n  end;\n"
        # Let's extract the block cleanly using regex on this specific part:
        match = re.search(r"' then\s*begin\s*(.*)Exit;\s*end;", part, re.DOTALL)
        if match:
            body = match.group(1).strip()
            
            body = body.replace("Result.", "AResult.")
            body = body.replace("Result :=", "AResult :=")
            
            indented_body = "\n".join(["    " + line for line in body.split("\n")])
            
            handler = f"""  FHandlers.Add('{key}', procedure(
    AObject: TReportObject;
    const Value, AScript: string;
    var Context: TExpressionContext;
    var ACanPrint: Boolean;
    var AResult: TScriptHostCommandResult
  )
  var
    B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
  begin
{indented_body}
  end);
"""
            handlers_code += handler

    init_handlers = "constructor TReportScriptHostAdapter.Create;\nbegin\n  inherited;\n  FHandlers := TDictionary<string, TScriptCommandHandler>.Create;\n  InitHandlers;\nend;\n\n"
    init_handlers += "destructor TReportScriptHostAdapter.Destroy;\nbegin\n  FHandlers.Free;\n  inherited;\nend;\n\n"
    init_handlers += "procedure TReportScriptHostAdapter.InitHandlers;\nbegin\n" + handlers_code + "end;\n\n"
    
    content = content.replace("function TReportScriptHostAdapter.ExecuteSingleBeforeObject", init_handlers + "function TReportScriptHostAdapter.ExecuteSingleBeforeObject")

    new_body = func_sig + """var
  Handler: TScriptCommandHandler;
begin""" + initial_setup + """  Result.Handled := True;
  
  if FHandlers.TryGetValue(Key, Handler) then
  begin
    Handler(AObject, Value, AScript, Context, ACanPrint, Result);
  end
  else
  begin
    Result.Unsupported := True;
    Result.UnsupportedCount := 1;
    Result.TraceMessage := 'ScriptUnsupported[UnknownCommand]: ' + AScript;
  end;
"""
    full_old_func = re.search(r"(function TReportScriptHostAdapter\.ExecuteSingleBeforeObject.*?^end;)", content, re.DOTALL | re.MULTILINE).group(1)
    new_func = new_body + "end;"
    content = content.replace(full_old_func, new_func)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

process()
print("Success")
