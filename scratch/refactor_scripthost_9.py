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
            out_lines.append("""  TScriptCommandHandler = procedure(
    AObject: TReportObject;
    const Value, AScript: string;
    var Context: TExpressionContext;
    var ACanPrint: Boolean;
    var AResult: TScriptHostCommandResult
  ) of object;

""")
            out_lines.append(line)
            out_lines.append(lines[i+1]) # private
            out_lines.append("    FHandlers: TDictionary<string, TScriptCommandHandler>;\n")
            out_lines.append("    procedure InitHandlers;\n")
            i += 2
            continue
            
        if "    procedure EngineObjectBeforePrint" in line:
            for key, _ in handlers:
                out_lines.append(f"    procedure Cmd_{key.capitalize()}(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);\n")
            
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
                if lines[i].strip() == "Result.Handled := True;" and i+3 < len(lines) and "ScriptUnsupported[UnknownCommand]" in lines[i+3]:
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
                    nesting = 1 # We skipped the first begin
                    
                    while i < len(lines):
                        stripped = lines[i].strip()
                        if stripped in ("begin", "try") or stripped.startswith("case "):
                            nesting += 1
                        elif stripped.startswith("end;") or stripped == "end":
                            nesting -= 1
                            if nesting == 0:
                                break
                        block_lines.append(lines[i])
                        i += 1
                        
                    if block_lines and "Exit;" in block_lines[-1]:
                        block_lines.pop()
                                
                    handlers.append((key, block_lines))
                    i += 1 # skip the closing end;
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
                out_lines.append(f"    Handler := Cmd_{key.capitalize()};
  FHandlers.Add('{key}', Handler);\n")
            out_lines.append("end;\n\n")
            
            for key, block in handlers:
                out_lines.append(f"procedure TReportScriptHostAdapter.Cmd_{key.capitalize()}(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);\n")
                out_lines.append("var\n")
                out_lines.append("  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;\n")
                out_lines.append("begin\n")
                for bl in block:
                    out_lines.append(bl.replace("Result.", "AResult.").replace("Result :=", "AResult :="))
                out_lines.append("end;\n\n")
            continue
            
        out_lines.append(line)
        i += 1
        
    placeholder_idx = -1
    for j in range(len(out_lines)):
        if "    procedure EngineObjectBeforePrint" in out_lines[j]:
            placeholder_idx = j
            break
            
    if placeholder_idx != -1:
        for key, _ in reversed(handlers):
            out_lines.insert(placeholder_idx, f"    procedure Cmd_{key.capitalize()}(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);\n")

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
