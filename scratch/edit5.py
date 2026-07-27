import re

def main():
    comp_path = "source/Vittix.Report.Component.pas"
    with open(comp_path, "r", encoding="utf-8") as f:
        comp_content = f.read()

    # We need to replace in TVittixReport.Execute
    # Let's use regex to replace both instances

    old_pattern = r"""      Renderer := TReportRenderer\.Create;
      try
        Renderer\.Parameters\.Assign\(FParameters\);
        Renderer\.TwoPassRendering := FTwoPassRendering;
        if Assigned\(PrimaryUDS\) then
          Renderer\.Render\(Model, PrimaryUDS, NamedUDS\)
        else
          Renderer\.Render\(Model, Primary, NamedDS\);"""

    new_pattern = """      Renderer := TReportRenderer.Create;
      try
        Renderer.Parameters.Assign(FParameters);
        Renderer.TwoPassRendering := FTwoPassRendering;
        var Engine: TReportEngine;
        if Assigned(PrimaryUDS) then
          Engine := TReportEngine.Create(Model, PrimaryUDS, NamedUDS, nil)
        else
          Engine := TReportEngine.Create(Model, Primary, NamedDS, nil);
        try
          Renderer.Render(Engine, Model.PageSettings.PageWidth, Model.PageSettings.PageHeight);
        finally
          Engine.Free;
        end;"""

    comp_content = re.sub(old_pattern, new_pattern, comp_content)

    with open(comp_path, "w", encoding="utf-8") as f:
        f.write(comp_content)
    
    print("Success Component")

if __name__ == '__main__':
    main()
