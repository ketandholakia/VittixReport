import sys

def process():
    with open("source/Vittix.Report.ScriptHost.Adapter.pas", "r", encoding="utf-8") as f:
        lines = f.readlines()

    out_lines = []
    i = 0
    in_execute_single = False
    
    # We will collect handlers here
    handlers = []
    
    while i < len(lines):
        line = lines[i]
        
        if "uses" in line and "System.Generics.Collections" not in "".join(lines[:30]):
            out_lines.append(line)
            if "System.SysUtils," in line:
                out_lines.append("  System.Generics.Collections,\n")
            i += 1
            continue

        if "TReportScriptHostAdapter = class" in line:
            out_lines.append("""  TScriptCommandHandler = reference to procedure(
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
""")
            i += 1
            continue
            
        if "    public" in line and "procedure EngineObjectBeforePrint" in lines[i+1]:
            out_lines.append("    public\n      constructor Create;\n      destructor Destroy; override;\n")
            out_lines.append(line)
            i += 1
            continue

        if "function TReportScriptHostAdapter.ExecuteSingleBeforeObject" in line:
            # Skip until we hit the first "if Key = 'canprint' then"
            func_lines = []
            while i < len(lines):
                func_lines.append(lines[i])
                if "if Key = 'canprint' then" in lines[i]:
                    func_lines.pop() # remove this line
                    break
                i += 1
                
            out_lines.extend(func_lines)
            
            # Now parse blocks
            while i < len(lines):
                if lines[i].strip() == "Result.Handled := True;" and "ScriptUnsupported[UnknownCommand]" in lines[i+2]:
                    # We reached the end of the blocks
                    break
                    
                if "if Key = '" in lines[i]:
                    key = lines[i].split("'")[1]
                    i += 1 # "begin"
                    block_lines = []
                    while i < len(lines):
                        if lines[i].strip() == "end;" and i > 0 and "Exit;" in lines[i-1]:
                            break
                        block_lines.append(lines[i])
                        i += 1
                    # pop the "Exit;" line
                    if block_lines and "Exit;" in block_lines[-1]:
                        block_lines.pop()
                    handlers.append((key, block_lines))
                    i += 1 # skip end;
                else:
                    i += 1
                    
            # generate InitHandlers
            out_lines.append("  Result.Handled := True;\n")
            out_lines.append("  if FHandlers.TryGetValue(Key, Handler) then\n")
            out_lines.append("    Handler(AObject, Value, AScript, Context, ACanPrint, Result)\n")
            out_lines.append("  else\n")
            out_lines.append("  begin\n")
            out_lines.append("    Result.Unsupported := True;\n")
            out_lines.append("    Result.UnsupportedCount := 1;\n")
            out_lines.append("    Result.TraceMessage := 'ScriptUnsupported[UnknownCommand]: ' + AScript;\n")
            out_lines.append("  end;\n")
            out_lines.append("end;\n\n")
            
            # Skip to the end of ExecuteSingleBeforeObject in original code
            while i < len(lines):
                if lines[i].startswith("end;"):
                    i += 1
                    break
                i += 1

            # Append the InitHandlers and constructor
            out_lines.append("constructor TReportScriptHostAdapter.Create;\n")
            out_lines.append("begin\n")
            out_lines.append("  inherited;\n")
            out_lines.append("  FHandlers := TDictionary<string, TScriptCommandHandler>.Create;\n")
            out_lines.append("  InitHandlers;\n")
            out_lines.append("end;\n\n")
            
            out_lines.append("destructor TReportScriptHostAdapter.Destroy;\n")
            out_lines.append("begin\n")
            out_lines.append("  FHandlers.Free;\n")
            out_lines.append("  inherited;\n")
            out_lines.append("end;\n\n")

            out_lines.append("procedure TReportScriptHostAdapter.InitHandlers;\n")
            out_lines.append("begin\n")
            
            for key, block in handlers:
                out_lines.append(f"  FHandlers.Add('{key}', procedure(\n")
                out_lines.append("    AObject: TReportObject;\n")
                out_lines.append("    const Value, AScript: string;\n")
                out_lines.append("    var Context: TExpressionContext;\n")
                out_lines.append("    var ACanPrint: Boolean;\n")
                out_lines.append("    var AResult: TScriptHostCommandResult\n")
                out_lines.append("  )\n")
                out_lines.append("  var\n")
                out_lines.append("    B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;\n")
                out_lines.append("  begin\n")
                for bl in block:
                    out_lines.append(bl.replace("Result.", "AResult.").replace("Result :=", "AResult :="))
                out_lines.append("  end);\n\n")
                
            out_lines.append("end;\n\n")
            
            continue
            
        out_lines.append(line)
        i += 1
        
    # We also need to add "Handler: TScriptCommandHandler;" to ExecuteSingleBeforeObject
    for j in range(len(out_lines)):
        if "function TReportScriptHostAdapter.ExecuteSingleBeforeObject" in out_lines[j]:
            k = j
            while "begin" not in out_lines[k]:
                k += 1
            out_lines.insert(k, "    Handler: TScriptCommandHandler;\n")
            break

    with open("source/Vittix.Report.ScriptHost.Adapter.pas", "w", encoding="utf-8") as f:
        f.writelines(out_lines)

process()
print("Success")
