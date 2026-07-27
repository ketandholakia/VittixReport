import re, glob

def update_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # DPK replacements
    content = re.sub(r"^\s*Vittix\.Report\.Core\.Model\s+in '.*Vittix\.Report\.Core\.Model\.pas',\s*?\n", "", content, flags=re.MULTILINE)
    content = re.sub(r"^\s*Vittix\.Report\.Core\.Objects\s+in '.*Vittix\.Report\.Core\.Objects\.pas',\s*?\n", "", content, flags=re.MULTILINE)
    content = re.sub(r"^\s*Vittix\.Report\.Core\.Bands\s+in '.*Vittix\.Report\.Core\.Bands\.pas',\s*?\n", "  Vittix.Report.Core in '..\\source\\Vittix.Report.Core.pas',\n", content, flags=re.MULTILINE)

    # DPROJ replacements
    content = re.sub(r"^\s*<DCCReference Include=\"\.\.\\source\\Vittix\.Report\.Core\.Model\.pas\"/>\s*?\n", "", content, flags=re.MULTILINE)
    content = re.sub(r"^\s*<DCCReference Include=\"\.\.\\source\\Vittix\.Report\.Core\.Objects\.pas\"/>\s*?\n", "", content, flags=re.MULTILINE)
    content = re.sub(r"^\s*<DCCReference Include=\"\.\.\\source\\Vittix\.Report\.Core\.Bands\.pas\"/>\s*?\n", "        <DCCReference Include=\"..\\source\\Vittix.Report.Core.pas\"/>\n", content, flags=re.MULTILINE)

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

for f in ["packages/VittixReportRuntime.dpk", "packages/VittixReportRuntime.dproj"]:
    update_file(f)

print("Done")
