unit Vittix.Designer.ComponentEditorSave;

interface

uses Vittix.Report.Model;

{ False vetoes close; AError is shown by the designer's existing error dialog. }
function TrySaveComponentEditorOutput(AReport: TReportModel;
  const APath: string; var AModified: Boolean; out AError: string): Boolean;

implementation

uses System.SysUtils, Vittix.Report.FileSave;

function TrySaveComponentEditorOutput(AReport: TReportModel;
  const APath: string; var AModified: Boolean; out AError: string): Boolean;
begin
  AError := '';
  try
    TReportFileSaver.SaveToPath(AReport, APath);
    Result := True;
  except
    on E: Exception do
    begin
      AModified := True;
      AError := E.Message;
      Result := False;
    end;
  end;
end;

end.
