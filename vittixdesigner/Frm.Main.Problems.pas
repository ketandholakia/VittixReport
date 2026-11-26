unit Frm.Main.Problems;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects;

type
  TDesignerProblemSeverity = (dpsError, dpsWarning, dpsInfo);

  { One entry of the Problems panel. Target may be nil for report-wide issues
    (for example diagnostics produced while loading the file). }
  TDesignerProblem = class
  public
    Severity: TDesignerProblemSeverity;
    Text: string;
    Target: TReportObject;
    constructor Create(ASeverity: TDesignerProblemSeverity; const AText: string;
      ATarget: TReportObject = nil);
  end;

function SeverityText(ASeverity: TDesignerProblemSeverity): string;

procedure CollectReportProblems(
  AReport: TReportModel;
  const AFieldNames: TArray<string>;
  ALoadDiagnostics: TStrings;
  AProblems: TObjectList<TDesignerProblem>);

implementation

constructor TDesignerProblem.Create(ASeverity: TDesignerProblemSeverity;
  const AText: string; ATarget: TReportObject);
begin
  inherited Create;
  Severity := ASeverity;
  Text := AText;
  Target := ATarget;
end;

function SeverityText(ASeverity: TDesignerProblemSeverity): string;
begin
  case ASeverity of
    dpsError:   Result := 'Error';
    dpsWarning: Result := 'Warning';
  else
    Result := 'Info';
  end;
end;

procedure CollectReportProblems(
  AReport: TReportModel;
  const AFieldNames: TArray<string>;
  ALoadDiagnostics: TStrings;
  AProblems: TObjectList<TDesignerProblem>);
var
  Fields: TStringList;
  I: Integer;
  Obj: TReportObject;

  procedure Add(ASeverity: TDesignerProblemSeverity; const AText: string;
    ATarget: TReportObject);
  begin
    AProblems.Add(TDesignerProblem.Create(ASeverity, AText, ATarget));
  end;

  procedure CheckObject(AObj: TReportObject);
  var
    ImageObj: TReportImageObject;
    BoundField: string;
    ObjName: string;
  begin
    if not Assigned(AObj) then
      Exit;

    ObjName := Trim(AObj.Name);
    if ObjName = '' then
      ObjName := AObj.ClassName;

    if (AObj.Bounds.Width <= 0) or (AObj.Bounds.Height <= 0) then
      Add(dpsWarning, ObjName + ' has a zero width or height', AObj);

    if AObj is TReportImageObject then
    begin
      ImageObj := TReportImageObject(AObj);
      if (not Assigned(ImageObj.Picture.Graphic)) or
         ImageObj.Picture.Graphic.Empty then
        if Trim(ImageObj.DataField) = '' then
          Add(dpsInfo, ObjName + ' has no picture and no DataField', AObj);
    end;

    if AObj is TReportTextObject then
    begin
      BoundField := Trim(TReportTextObject(AObj).DataField);
      if BoundField = '' then
      begin
        // An empty DataField is only suspicious on a data-bound field object;
        // plain labels and memos legitimately bind nothing.
        if AObj is TReportFieldObject then
          Add(dpsWarning, ObjName + ' has no DataField bound', AObj);
      end
      else if Assigned(Fields) and (Fields.Count > 0) and
              (Fields.IndexOf(BoundField) < 0) then
        Add(dpsWarning, ObjName + ': DataField ''' + BoundField +
          ''' is not in the current dataset', AObj);
    end;
  end;

  procedure CheckBand(ABand: TReportBand);
  var
    J: Integer;
    BandName: string;
  begin
    if not Assigned(ABand) then
      Exit;

    BandName := Trim(ABand.Name);
    if BandName = '' then
      BandName := ABand.ClassName;

    if ABand.Height <= 0 then
      Add(dpsError, 'Band ' + BandName + ' has no height', ABand);

    for J := 0 to ABand.Children.Count - 1 do
      CheckObject(ABand.Children[J]);
  end;
begin
  if not Assigned(AProblems) then
    Exit;

  AProblems.Clear;

  // Diagnostics captured while loading the current file (unknown objects etc.).
  if Assigned(ALoadDiagnostics) then
    for I := 0 to ALoadDiagnostics.Count - 1 do
      AProblems.Add(TDesignerProblem.Create(dpsWarning, ALoadDiagnostics[I]));

  if not Assigned(AReport) then
    Exit;

  Fields := TStringList.Create;
  try
    Fields.CaseSensitive := False;
    for I := 0 to High(AFieldNames) do
      Fields.Add(AFieldNames[I]);

    for I := 0 to AReport.Objects.Count - 1 do
    begin
      Obj := AReport.Objects[I];
      if Obj is TReportBand then
        CheckBand(TReportBand(Obj))
      else
        CheckObject(Obj);
    end;
  finally
    Fields.Free;
  end;
end;

end.
