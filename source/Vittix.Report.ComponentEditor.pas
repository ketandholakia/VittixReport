unit Vittix.Report.ComponentEditor;

{
  Vittix.Report.ComponentEditor
  ==============================
  Design-time component editor for TVittixReport (non-visual component).
  Double-clicking the component icon in the IDE launches VittixDesigner.exe,
  exactly like FastReport's double-click behaviour.

  Protocol with VittixDesigner.exe
  ----------------------------------
  Command line:  VittixDesigner.exe "<input.vrt>" "<output.vrt>"
  • On open  : designer loads <input.vrt>
  • On close : designer writes result to <output.vrt> then exits
  • On cancel: designer exits without writing <output.vrt>

  No VCL forms are referenced here — this keeps the design package
  free of DFM streaming and third-party component dependencies,
  which was the cause of the previous AV on package install.
}

interface

procedure Register;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  DesignIntf,
  DesignEditors,
  Vittix.Report.Component,   // TVittixReport
  Vittix.Report.Model,
  Vittix.Report.Serializer;

{ --------------------------------------------------------------------------- }
{  Helper: find VittixDesigner.exe                                             }
{ --------------------------------------------------------------------------- }

function FindDesignerExe: string;
var
  Buf: array[0..MAX_PATH] of Char;
begin
  // 1. Same folder as this design BPL
  GetModuleFileName(HInstance, Buf, MAX_PATH);
  Result := TPath.Combine(ExtractFilePath(Buf), 'VittixDesigner.exe');
  if TFile.Exists(Result) then Exit;

  // 2. Sibling vittixdesigner\ folder relative to BPL
  Result := TPath.GetFullPath(
    TPath.Combine(ExtractFilePath(Buf), '..\vittixdesigner\VittixDesigner.exe'));
  if TFile.Exists(Result) then Exit;

  Result := '';
end;

{ --------------------------------------------------------------------------- }
{  Helper: launch process and wait, pumping IDE messages                       }
{ --------------------------------------------------------------------------- }

function LaunchAndWait(const ACmdLine: string): Boolean;
var
  SI : TStartupInfo;
  PI : TProcessInformation;
  Cmd: string;
begin
  Result := False;
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_SHOWNORMAL;
  Cmd := ACmdLine;
  UniqueString(Cmd);
  if not CreateProcess(nil, PChar(Cmd), nil, nil, False, 0, nil, nil, SI, PI) then
    Exit;
  try
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
  Comp   : TVittixReport;
  ExePath: string;
  InFile : string;
  OutFile: string;
  JsonIn : string;
  JsonOut: string;
  Blank  : TReportModel;
  G      : TGUID;
  Token  : string;
  Utf8NoBom: TUTF8Encoding;
begin
  Comp := Component as TVittixReport;

  case Index of

    0: // Design Report...
    begin
      ExePath := FindDesignerExe;
      if ExePath = '' then
      begin
        ShowMessage(
          'VittixDesigner.exe not found.' + sLineBreak +
          'Place VittixDesigner.exe in the same folder as VittixReportDesign.bpl,' +
          ' or in the vittixdesigner\ sibling folder.');
        Exit;
      end;

      CreateGUID(G);
      Token  := StringReplace(GUIDToString(G), '{', '', [rfReplaceAll]);
      Token  := StringReplace(Token, '}', '', [rfReplaceAll]);
      InFile  := TPath.Combine(TPath.GetTempPath, 'VittixRpt_in_'  + Token + '.vrt');
      OutFile := TPath.Combine(TPath.GetTempPath, 'VittixRpt_out_' + Token + '.vrt');

      if TFile.Exists(OutFile) then TFile.Delete(OutFile);

      // Write current JSON (or blank model) to temp input file
      JsonIn := Comp.ReportJSON;
      if JsonIn = '' then
      begin
        Blank := TReportModel.Create;
        try
          JsonIn := TReportSerializer.SaveToJSON(Blank);
        finally
          Blank.Free;
        end;
      end;
      Utf8NoBom := TUTF8Encoding.Create(False);
      try
        TFile.WriteAllText(InFile, JsonIn, Utf8NoBom);
      finally
        Utf8NoBom.Free;
      end;

      LaunchAndWait(Format('"%s" "%s" "%s"', [ExePath, InFile, OutFile]));

      // Read result back if the designer saved it
      if TFile.Exists(OutFile) then
      begin
        JsonOut := TFile.ReadAllText(OutFile, TEncoding.UTF8);
        if (JsonOut <> '') and (JsonOut[1] = #$FEFF) then
          Delete(JsonOut, 1, 1);
        if (Length(JsonOut) >= 3) and
           (JsonOut[1] = #$00EF) and (JsonOut[2] = #$00BB) and (JsonOut[3] = #$00BF) then
          Delete(JsonOut, 1, 3);
        if (JsonOut <> '') and (JsonOut <> JsonIn) then
        begin
          Comp.ReportJSON := JsonOut;
          Designer.Modified;
        end;
        TFile.Delete(OutFile);
      end;

      if TFile.Exists(InFile) then TFile.Delete(InFile);
    end;

    1: // Clear Report
    begin
      if MessageDlg('Clear the report design? This cannot be undone.',
                    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      begin
        Comp.ReportJSON := '';
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
  RegisterComponentEditor(TVittixReport, TVittixReportComponentEditor);
end;

end.
