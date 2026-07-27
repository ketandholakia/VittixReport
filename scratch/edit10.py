def update_dpk(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        c = f.read()
    c = c.replace("  Vittix.Report.Core.Model      in '..\\source\\Vittix.Report.Core.Model.pas',\n", "")
    c = c.replace("  Vittix.Report.Core.Objects    in '..\\source\\Vittix.Report.Core.Objects.pas',\n", "")
    c = c.replace("  Vittix.Report.Core.Bands      in '..\\source\\Vittix.Report.Core.Bands.pas',\n", "  Vittix.Report.Core            in '..\\source\\Vittix.Report.Core.pas',\n")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(c)

def update_dproj(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        c = f.read()
    c = c.replace("        <DCCReference Include=\"..\\source\\Vittix.Report.Core.Model.pas\"/>\n", "")
    c = c.replace("        <DCCReference Include=\"..\\source\\Vittix.Report.Core.Objects.pas\"/>\n", "")
    c = c.replace("        <DCCReference Include=\"..\\source\\Vittix.Report.Core.Bands.pas\"/>\n", "        <DCCReference Include=\"..\\source\\Vittix.Report.Core.pas\"/>\n")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(c)

update_dpk("packages/VittixReportRuntime.dpk")
update_dproj("packages/VittixReportRuntime.dproj")
print("Done")
