import subprocess, re

def main():
    subprocess.run(["git", "checkout", "source/Vittix.Report.ScriptHost.Adapter.pas"], check=True)
    with open("source/Vittix.Report.ScriptHost.Adapter.pas", "r", encoding="utf-8") as f:
        content = f.read()
        
    if "System.Generics.Collections" not in content:
        content = re.sub(r"uses\s*System\.SysUtils,", "uses\n  System.SysUtils,\n  System.Generics.Collections,", content)

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
    content = re.sub(r"type\s+TReportScriptHostAdapter\s*=\s*class\s+private", class_decl, content)
    content = re.sub(r"public\s+procedure EngineObjectBeforePrint", "public\n      constructor Create;\n      destructor Destroy; override;\n      procedure EngineObjectBeforePrint", content)

    old_body_match = re.search(r"(function TReportScriptHostAdapter\.ExecuteSingleBeforeObject.*?)begin(.*?)Result\.Handled := True;\n(.*?)Result\.Handled := True;\n  Result\.Unsupported := True;", content, re.DOTALL)
    
    func_sig = old_body_match.group(1)
    initial_setup = old_body_match.group(2)
    big_if_chain = old_body_match.group(3)
    
    parts = big_if_chain.split("\n  if Key = '")
    handlers_code = ""
    
    for i in range(1, len(parts)):
        part = parts[i]
        key = part.split("'", 1)[0]
        
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

    with open("source/Vittix.Report.ScriptHost.Adapter.pas", "w", encoding="utf-8") as f:
        f.write(content)

main()
print("Success")
