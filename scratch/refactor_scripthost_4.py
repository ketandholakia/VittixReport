import subprocess

def main():
    subprocess.run(["git", "checkout", "source/Vittix.Report.ScriptHost.Adapter.pas"], check=True)
    with open("source/Vittix.Report.ScriptHost.Adapter.pas", "r", encoding="utf-8") as f:
        lines = f.readlines()

    out_lines = []
    i = 0
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

""")
            out_lines.append(line)
            out_lines.append(lines[i+1]) # private
            out_lines.append("    FHandlers: TDictionary<string, TScriptCommandHandler>;\n")
            out_lines.append("    procedure InitHandlers;\n")
            i += 2
            continue
            
        if "    procedure EngineObjectBeforePrint" in line:
            out_lines.append("    constructor Create;\n")
            out_lines.append("    destructor Destroy; override;\n")
            out_lines.append(line)
            i += 1
            continue

        if "function TReportScriptHostAdapter.ExecuteSingleBeforeObject" in line:
            func_lines = []
            while i < len(lines):
                func_lines.append(lines[i])
                if "if Key = 'canprint' then" in lines[i]:
                    func_lines.pop()
                    break
                i += 1
            
            out_lines.extend(func_lines)
            
            while i < len(lines):
                if lines[i].strip() == "Result.Handled := True;" and "ScriptUnsupported[UnknownCommand]" in lines[i+2]:
                    while i < len(lines):
                        if lines[i].startswith("end;"):
                            i += 1
                            break
                        i += 1
                    break
                    
                if "if Key = '" in lines[i]:
                    key = lines[i].split("'")[1]
                    i += 1
                    
                    if lines[i].strip() == "begin":
                        i += 1
                    
                    block_lines = []
                    while i < len(lines):
                        if lines[i].strip() == "end;" and i > 0 and "Exit;" in lines[i-1]:
                            # skip this end;
                            break
                        block_lines.append(lines[i])
                        i += 1
                        
                    if block_lines and "Exit;" in block_lines[-1]:
                        block_lines.pop()
                    
                    # Fix anchorright bug from original Delphi code
                    if key == "anchorright":
                        # Original:
                        # else if SameText(Value, 'False') then
                        #   B := False
                        # Result.Unsupported := True;
                        for j in range(len(block_lines)):
                            if "B := False" in block_lines[j] and j+1 < len(block_lines) and "Result.Unsupported" in block_lines[j+1]:
                                block_lines.insert(j+1, "      else\n      begin\n")
                                for k in range(j+2, len(block_lines)):
                                    if "AObject." in block_lines[k]:
                                        block_lines.insert(k, "      end;\n")
                                        break
                                break
                                
                    handlers.append((key, block_lines))
                    i += 1 # skip end;
                else:
                    i += 1
                    
            out_lines.append("  Result.Handled := True;\n")
            out_lines.append("  if FHandlers.TryGetValue(Key, Handler) then\n")
            out_lines.append("  begin\n")
            out_lines.append("    Handler(AObject, Value, AScript, Context, ACanPrint, Result);\n")
            out_lines.append("  end\n")
            out_lines.append("  else\n")
            out_lines.append("  begin\n")
            out_lines.append("    Result.Unsupported := True;\n")
            out_lines.append("    Result.UnsupportedCount := 1;\n")
            out_lines.append("    Result.TraceMessage := 'ScriptUnsupported[UnknownCommand]: ' + AScript;\n")
            out_lines.append("  end;\n")
            out_lines.append("end;\n\n")
            
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
                out_lines.append("    var AResult: TScriptHostCommandResult)\n")
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
        
    for j in range(len(out_lines)):
        if "function TReportScriptHostAdapter.ExecuteSingleBeforeObject" in out_lines[j]:
            k = j
            while "begin" not in out_lines[k]:
                k += 1
            out_lines.insert(k, "  Handler: TScriptCommandHandler;\n")
            break

    with open("source/Vittix.Report.ScriptHost.Adapter.pas", "w", encoding="utf-8") as f:
        f.writelines(out_lines)

main()
print("Success")
