unit Vittix.Report.ComponentEditor;

{
  Vittix.Report.ComponentEditor
  ==============================
  Design-time component editor for TVittixReportDesigner.

  How it works (process-launch approach)
  ---------------------------------------
  The designer UI (Frm.Main, Frm.BandManager, etc.) lives in the
  standalone VittixDesigner.exe.  Embedding those forms directly in the
  design-time package caused AV crashes during package load because:
    • TfrmMain references RzPanel / RzButton (Raize) and ADODB — their
      BPLs must be fully initialised before the DFM can stream.
    • The IDE's package-load order does not guarantee this.

  Instead the component editor:
    1. Serialises the current TReportModel to a temporary .vrt file.
    2. Launches VittixDesigner.exe with that file as a command-line arg,
       also passing a second "return path" arg so the designer knows
       where to write the result.
    3. Waits for the process to exit (pumping messages so the IDE stays
       responsive).
    4. If the return file exists, reads it back and stores the JSON in
       the component's ReportJSON property, marking the IDE project dirty.

  VittixDesigner.exe protocol
  ---------------------------
  Command line:   VittixDesigner.exe "<input.vrt>" "<output.vrt>"
  • On open  : designer loads <input.vrt> (may be empty/nonexistent for
               a new report).
  • On "Save & Close" (or normal close after editing): designer saves
    the report to <output.vrt> then exits with code 0.
  • On Cancel / no changes: designer exits without writing <output.vrt>
    (or exits with code 1).

  Finding the EXE
  ---------------
  The editor looks for VittixDesigner.exe in:
    1. The same folder as the design-time BPL.
    2. The same folder as the currently open Delphi project.
    3. A path stored in the registry key
         HKCU\Software\VittixReport\DesignerPath
  Update FindDesignerExe below if your deployment differs.
}

interface

procedure Register;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Winapi.Windows,
  Winapi.ShellAPI,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  ToolsAPI,
  DesignIntf,
  DesignEditors,
  Vittix.Report.DesignerControl,
  Vittix.Report.Model,
  Vittix.Report.Serializer;

{ --------------------------------------------------------------------------- }
{  Helper: locate VittixDesigner.exe                                           }
{ --------------------------------------------------------------------------- }

function FindDesignerExe: string;
var
  BplPath   : array[0..MAX_PATH] of Char;
  BplDir    : string;
  ModServices: IOTAModuleServices;
  ModFile   : string;
  i         : Integer;
begin
  Result := '';

  // 1. Same folder as this BPL
  GetModuleFileName(HInstance, BplPath, MAX_PATH);
  BplDir := ExtractFilePath(BplPath);
  Result := TPath.Combine(BplDir, 'VittixDesigner.exe');
  if TFile.Exists(Result) then Exit;

  // 2. Active/open project directory from IDE module services
  try
    if Supports(BorlandIDEServices, IOTAModuleServices, ModServices) then
    begin
      for i := 0 to ModServices.ModuleCount - 1 do
      begin
        ModFile := ModServices.Modules[i].FileName;
        if (ModFile = '') then
          Continue;

        if SameText(ExtractFileExt(ModFile), '.dproj') or
           SameText(ExtractFileExt(ModFile), '.dpr') or
           SameText(ExtractFileExt(ModFile), '.dpk') then
        begin
          Result := TPath.Combine(ExtractFilePath(ModFile), 'VittixDesigner.exe');
          if TFile.Exists(Result) then Exit;

          // Also try ..\vittixdesigner\ relative to the project/package file
          Result := TPath.Combine(ExtractFilePath(ModFile),
                      '..\vittixdesigner\VittixDesigner.exe');
          Result := TPath.GetFullPath(Result);
          if TFile.Exists(Result) then Exit;
        end;
      end;
    end;
  except
    // IDE service lookup is best-effort
  end;

  Result := ''; // not found
end;

{ --------------------------------------------------------------------------- }
{  Helper: launch process and wait, pumping messages                           }
{ --------------------------------------------------------------------------- }

function LaunchAndWait(const ACmdLine: string): Boolean;
var
  SI  : TStartupInfo;
  PI  : TProcessInformation;
  Cmd : string;
begin
  Result := False;
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_SHOWNORMAL;

  Cmd := ACmdLine; // CreateProcess needs a mutable buffer
  UniqueString(Cmd);

  if not CreateProcess(nil, PChar(Cmd), nil, nil, False,
                       0, nil, nil, SI, PI) then
    Exit;

  try
    // Pump messages while the child process runs so the IDE stays alive
    while WaitForSingleObject(PI.hProcess, 50) = WAIT_TIMEOUT do
      Application.ProcessMessages;
    Result := True;
  finally
    CloseHandle(PI.hProcess);
    CloseHandle(PI.hThread);
  end;
end;

{ --------------------------------------------------------------------------- }
{  Component editor                                                             }
{ --------------------------------------------------------------------------- }

type
  TVittixReportComponentEditor = class(TComponentEditor)
  public
    function  GetVerbCount: Integer; override;
    function  GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
  end;

function TVittixReportComponentEditor.GetVerbCount: Integer;
begin
  Result := 2;
end;

function TVittixReportComponentEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := 'Design Report...';
    1: Result := 'Clear Report';
  else
    Result := '';
  end;
end;

procedure TVittixReportComponentEditor.ExecuteVerb(Index: Integer);
var
  Comp      : TVittixReportDesigner;
  ExePath   : string;
  InFile    : string;
  OutFile   : string;
  CmdLine   : string;
  JsonIn    : string;
  JsonOut   : string;
begin
  Comp := Component as TVittixReportDesigner;

  case Index of

    { ---- 0: Open the visual designer ---- }
    0:
    begin
      ExePath := FindDesignerExe;
      if ExePath = '' then
      begin
        ShowMessage(
          'VittixDesigner.exe not found.' + sLineBreak +
          'Please place VittixDesigner.exe in the same folder as the ' +
          'design-time package BPL, or next to your Delphi project.');
        Exit;
      end;

      // Write current report JSON to a temp input file
      InFile  := TPath.Combine(TPath.GetTempPath, 'VittixReport_edit_in.vrt');
      OutFile := TPath.Combine(TPath.GetTempPath, 'VittixReport_edit_out.vrt');

      // Remove stale output file so we can detect a fresh save
      if TFile.Exists(OutFile) then
        TFile.Delete(OutFile);

      // Write the current report (may be empty JSON for a new report)
      JsonIn := Comp.ReportJSON;
      if JsonIn = '' then
        JsonIn := TReportSerializer.SaveToJSON(TReportModel.Create)  // blank
      else
        JsonIn := JsonIn;  // already have it

      TFile.WriteAllText(InFile, JsonIn, TEncoding.UTF8);

      // Build command line:  VittixDesigner.exe "input.vrt" "output.vrt"
      CmdLine := Format('"%s" "%s" "%s"', [ExePath, InFile, OutFile]);

      LaunchAndWait(CmdLine);

      // Read result back if the designer saved it
      if TFile.Exists(OutFile) then
      begin
        JsonOut := TFile.ReadAllText(OutFile, TEncoding.UTF8);
        if (JsonOut <> '') and (JsonOut <> JsonIn) then
        begin
          Comp.ReportJSON := JsonOut;
          Designer.Modified;
        end;
        TFile.Delete(OutFile);
      end;

      if TFile.Exists(InFile) then
        TFile.Delete(InFile);
    end;

    { ---- 1: Clear the stored report ---- }
    1:
    begin
      if MessageDlg('Clear the report design? This cannot be undone.',
                    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      begin
        Comp.ReportJSON := '';
        Comp.NewReport;
        Designer.Modified;
      end;
    end;

  end;
end;

{ --------------------------------------------------------------------------- }
{  Register                                                                     }
{ --------------------------------------------------------------------------- }

procedure Register;
begin
  RegisterComponentEditor(TVittixReportDesigner,
                          TVittixReportComponentEditor);
end;

end.