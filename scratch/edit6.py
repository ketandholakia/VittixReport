import re

def main():
    file_path = "source/Vittix.Report.DesignerControl.pas"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Remove TDesignerMode declaration
    # Be careful not to remove too much. It might span a few lines.
    content = re.sub(
        r"  TDesignerMode = \(dmSelect, dmMove, dmResize, dmBandResize,\s*dmRubberBand, dmInsert\);\s*",
        "",
        content
    )
    # Also if it was single line:
    content = re.sub(
        r"  TDesignerMode = \(dmSelect, dmMove, dmResize, dmBandResize, dmRubberBand, dmInsert\);\s*",
        "",
        content
    )

    # 2. Fix casts: Integer(dmXYZ) -> dmXYZ
    content = re.sub(r"Integer\((dm[a-zA-Z]+)\)", r"\1", content)
    
    # 3. Fix casts: TDesignerMode(FInteractionState.Mode) -> FInteractionState.Mode
    content = content.replace("TDesignerMode(FInteractionState.Mode)", "FInteractionState.Mode")
    content = content.replace("TDesignerMode(FMode)", "FInteractionState.Mode") # just in case
    
    # Let's verify we replaced the enum def
    if "dmSelect, dmMove" in content:
        print("WARNING: Might not have removed TDesignerMode def.")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print("Success")

if __name__ == '__main__':
    main()
