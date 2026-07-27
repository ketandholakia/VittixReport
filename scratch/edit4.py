import re

def main():
    file_path = "source/Vittix.Report.Renderer.pas"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Update interface
    old_interface = """    procedure Render(AReport: TReportModel; ADataSet: TDataSet); overload;
    procedure Render(
      AReport: TReportModel;
      ADataSet: TDataSet;
      ANamedDataSets: TDictionary<string, TDataSet>); overload;
    procedure Render(
      AReport: TReportModel;
      AUserDataSet: TVittixUserDataSet;
      ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>); overload;"""
    new_interface = """    procedure Render(AEngine: TReportEngine; APageWidth, APageHeight: Integer);"""
    content = content.replace(old_interface, new_interface)

    # 2. Update implementation
    old_impl1 = """procedure TReportRenderer.Render(
  AReport: TReportModel;
  ADataSet: TDataSet);
begin
  Render(AReport, ADataSet, nil);
end;

procedure TReportRenderer.Render(
  AReport: TReportModel;
  ADataSet: TDataSet;
  ANamedDataSets: TDictionary<string, TDataSet>);
var
  Engine: TReportEngine;
  i:      Integer;
  Page:   TRenderPage;
  R:      TRect;
  PW, PH: Integer;
begin
  FPages.Clear;

  if not Assigned(AReport) then Exit;

  // Read page dimensions from the model's PageSettings
  PW := AReport.PageSettings.PageWidth;
  PH := AReport.PageSettings.PageHeight;

  Engine := TReportEngine.Create(AReport, ADataSet, ANamedDataSets, nil);
  try
    Engine.Parameters.Assign(FParameters);
    Engine.TwoPassRendering := FTwoPassRendering;
    Engine.Prepare;

    for i := 0 to Engine.Pages.Count - 1 do
    begin
      Page := TRenderPage.Create(PW, PH);
      try
        R  := Rect(0, 0, PW, PH);

        Page.Metafile.Assign(Engine.Pages[i]);
        Page.Bitmap.Canvas.StretchDraw(R, Engine.Pages[i]);

        FPages.Add(Page);
        Page := nil; // owned by FPages after Add
      finally
        Page.Free;
      end;
    end;
  finally
    Engine.Free;
  end;
end;

procedure TReportRenderer.Render(
  AReport: TReportModel;
  AUserDataSet: TVittixUserDataSet;
  ANamedUserDataSets: TDictionary<string, TVittixUserDataSet>);
var
  Engine: TReportEngine;
  i:      Integer;
  Page:   TRenderPage;
  R:      TRect;
  PW, PH: Integer;
begin
  FPages.Clear;

  if not Assigned(AReport) then Exit;

  PW := AReport.PageSettings.PageWidth;
  PH := AReport.PageSettings.PageHeight;

  Engine := TReportEngine.Create(AReport, AUserDataSet, ANamedUserDataSets, nil);
  try
    Engine.Parameters.Assign(FParameters);
    Engine.TwoPassRendering := FTwoPassRendering;
    Engine.Prepare;

    for i := 0 to Engine.Pages.Count - 1 do
    begin
      Page := TRenderPage.Create(PW, PH);
      try
        R  := Rect(0, 0, PW, PH);

        Page.Metafile.Assign(Engine.Pages[i]);
        Page.Bitmap.Canvas.StretchDraw(R, Engine.Pages[i]);

        FPages.Add(Page);
        Page := nil;
      finally
        Page.Free;
      end;
    end;
  finally
    Engine.Free;
  end;
end;"""
    new_impl = """procedure TReportRenderer.Render(AEngine: TReportEngine; APageWidth, APageHeight: Integer);
var
  i:      Integer;
  Page:   TRenderPage;
  R:      TRect;
begin
  FPages.Clear;
  if not Assigned(AEngine) then Exit;

  AEngine.Parameters.Assign(FParameters);
  AEngine.TwoPassRendering := FTwoPassRendering;
  AEngine.Prepare;

  for i := 0 to AEngine.Pages.Count - 1 do
  begin
    Page := TRenderPage.Create(APageWidth, APageHeight);
    try
      R  := Rect(0, 0, APageWidth, APageHeight);
      Page.Metafile.Assign(AEngine.Pages[i]);
      Page.Bitmap.Canvas.StretchDraw(R, AEngine.Pages[i]);
      FPages.Add(Page);
      Page := nil; // owned by FPages after Add
    finally
      Page.Free;
    end;
  end;
end;"""
    content = content.replace(old_impl1, new_impl)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print("Success Renderer")


    # Now update Component.pas
    comp_path = "source/Vittix.Report.Component.pas"
    with open(comp_path, "r", encoding="utf-8") as f:
        comp_content = f.read()

    old_comp_exec = """    try
      Renderer := TReportRenderer.Create;
      try
        Renderer.Parameters.Assign(FParameters);
        Renderer.TwoPassRendering := FTwoPassRendering;
        if Assigned(PrimaryUDS) then
          Renderer.Render(Model, PrimaryUDS, NamedUDS)
        else
          Renderer.Render(Model, Primary, NamedDS);

        if Renderer.Pages.Count = 0 then
        begin
          ShowMessage('The report generated no pages.');
          Exit;
        end;"""
    
    new_comp_exec = """    try
      Renderer := TReportRenderer.Create;
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
        end;

        if Renderer.Pages.Count = 0 then
        begin
          ShowMessage('The report generated no pages.');
          Exit;
        end;"""
    comp_content = comp_content.replace(old_comp_exec, new_comp_exec)

    with open(comp_path, "w", encoding="utf-8") as f:
        f.write(comp_content)

    print("Success Component")

if __name__ == '__main__':
    main()
