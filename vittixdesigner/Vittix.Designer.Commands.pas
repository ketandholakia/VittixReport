unit Vittix.Designer.Commands;

interface

uses
  System.SysUtils, System.Classes, System.Rtti, Vcl.Graphics, Vcl.StdCtrls,
  Vittix.Report.Undo,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.PageSettings,
  Vittix.Report.DesignerControl;

type
  TPropertyBatchChangeCommand = class(TUndoableAction)
  private
    FObj: TObject;
    FPropNames: TArray<string>;
    FOldValues: TArray<TValue>;
    FNewValues: TArray<TValue>;
    procedure ApplyValues(const AValues: TArray<TValue>);
  public
    constructor Create(AObj: TObject; const APropNames: TArray<string>;
      const AOldValues, ANewValues: TArray<TValue>);
    procedure Execute; override;
    procedure Rollback; override;
  end;

  TTextFontChangeCommand = class(TUndoableAction)
  private
    FObj: TReportTextObject;
    FOldFont: TFont;
    FNewFont: TFont;
  public
    constructor Create(AObj: TReportTextObject; const AOldFont, ANewFont: TFont);
    destructor Destroy; override;
    procedure Execute; override;
    procedure Rollback; override;
  end;

  TReportSnapshotCommand = class(TUndoableAction)
  private
    FDesigner: TVittixReportDesigner;
    FBeforeJSON: string;
    FAfterJSON: string;
    procedure ApplyJSON(const AJSON: string);
  public
    constructor Create(ADesigner: TVittixReportDesigner;
      const ABeforeJSON, AAfterJSON: string);
    procedure Execute; override;
    procedure Rollback; override;
  end;

  TPageSettingsChangeCommand = class(TUndoableAction)
  private
    FDesigner: TVittixReportDesigner;
    FOldSettings: TReportPageSettings;
    FNewSettings: TReportPageSettings;
    procedure ApplySettings(ASource: TReportPageSettings);
  public
    constructor Create(ADesigner: TVittixReportDesigner;
      AOldSettings, ANewSettings: TReportPageSettings);
    destructor Destroy; override;
    procedure Execute; override;
    procedure Rollback; override;
  end;

  TReportMetadataChangeCommand = class(TUndoableAction)
  private
    FReport: TReportModel;
    FTitleEdit: TEdit;
    FAuthorEdit: TEdit;
    FOldTitle: string;
    FOldAuthor: string;
    FOldDescription: string;
    FNewTitle: string;
    FNewAuthor: string;
    FNewDescription: string;
    procedure ApplyValues(const ATitle, AAuthor, ADescription: string);
  public
    constructor Create(AReport: TReportModel;
      ATitleEdit, AAuthorEdit: TEdit;
      const AOldTitle, AOldAuthor, AOldDescription,
      ANewTitle, ANewAuthor, ANewDescription: string);
    procedure Execute; override;
    procedure Rollback; override;
  end;

implementation

uses
  Vittix.Report.Serializer;

{ TPropertyBatchChangeCommand }

constructor TPropertyBatchChangeCommand.Create(AObj: TObject;
  const APropNames: TArray<string>; const AOldValues, ANewValues: TArray<TValue>);
begin
  inherited Create;
  ActionName := 'Property Change';
  FObj := AObj;
  FPropNames := APropNames;
  FOldValues := AOldValues;
  FNewValues := ANewValues;
end;

procedure TPropertyBatchChangeCommand.ApplyValues(const AValues: TArray<TValue>);
var
  Ctx: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
  I: Integer;
begin
  if not Assigned(FObj) then
    Exit;

  Ctx := TRttiContext.Create;
  try
    RttiType := Ctx.GetType(FObj.ClassType);
    if not Assigned(RttiType) then
      Exit;

    for I := 0 to High(FPropNames) do
    begin
      if I > High(AValues) then
        Break;
      Prop := RttiType.GetProperty(FPropNames[I]);
      if Assigned(Prop) and Prop.IsWritable then
        Prop.SetValue(FObj, AValues[I]);
    end;
  finally
    Ctx.Free;
  end;
end;

procedure TPropertyBatchChangeCommand.Execute;
begin
  ApplyValues(FNewValues);
end;

procedure TPropertyBatchChangeCommand.Rollback;
begin
  ApplyValues(FOldValues);
end;

{ TTextFontChangeCommand }

constructor TTextFontChangeCommand.Create(AObj: TReportTextObject;
  const AOldFont, ANewFont: TFont);
begin
  inherited Create;
  ActionName := 'Font Change';
  FObj := AObj;
  FOldFont := TFont.Create;
  FNewFont := TFont.Create;
  FOldFont.Assign(AOldFont);
  FNewFont.Assign(ANewFont);
end;

destructor TTextFontChangeCommand.Destroy;
begin
  FOldFont.Free;
  FNewFont.Free;
  inherited;
end;

procedure TTextFontChangeCommand.Execute;
begin
  if Assigned(FObj) then
    FObj.Font.Assign(FNewFont);
end;

procedure TTextFontChangeCommand.Rollback;
begin
  if Assigned(FObj) then
    FObj.Font.Assign(FOldFont);
end;

{ TReportSnapshotCommand }

constructor TReportSnapshotCommand.Create(ADesigner: TVittixReportDesigner;
  const ABeforeJSON, AAfterJSON: string);
begin
  inherited Create;
  ActionName := 'Band Manager Changes';
  FDesigner := ADesigner;
  FBeforeJSON := ABeforeJSON;
  FAfterJSON := AAfterJSON;
end;

procedure TReportSnapshotCommand.ApplyJSON(const AJSON: string);
var
  Model: TReportModel;
begin
  if not Assigned(FDesigner) then
    Exit;
  Model := TReportSerializer.LoadFromJSON(AJSON);
  try
    FDesigner.LoadReport(Model, True, False);
  except
    Model.Free;
    raise;
  end;
end;

procedure TReportSnapshotCommand.Execute;
begin
  ApplyJSON(FAfterJSON);
end;

procedure TReportSnapshotCommand.Rollback;
begin
  ApplyJSON(FBeforeJSON);
end;

{ TPageSettingsChangeCommand }

constructor TPageSettingsChangeCommand.Create(ADesigner: TVittixReportDesigner;
  AOldSettings, ANewSettings: TReportPageSettings);
begin
  inherited Create;
  ActionName := 'Page Setup Change';
  FDesigner := ADesigner;
  FOldSettings := TReportPageSettings.Create;
  FNewSettings := TReportPageSettings.Create;
  if Assigned(AOldSettings) then
    AOldSettings.AssignTo(FOldSettings);
  if Assigned(ANewSettings) then
    ANewSettings.AssignTo(FNewSettings);
end;

destructor TPageSettingsChangeCommand.Destroy;
begin
  FOldSettings.Free;
  FNewSettings.Free;
  inherited;
end;

procedure TPageSettingsChangeCommand.ApplySettings(ASource: TReportPageSettings);
begin
  if not Assigned(FDesigner) or not Assigned(FDesigner.Report) or
     not Assigned(FDesigner.Report.PageSettings) or not Assigned(ASource) then
    Exit;
  ASource.AssignTo(FDesigner.Report.PageSettings);
end;

procedure TPageSettingsChangeCommand.Execute;
begin
  ApplySettings(FNewSettings);
end;

procedure TPageSettingsChangeCommand.Rollback;
begin
  ApplySettings(FOldSettings);
end;

{ TReportMetadataChangeCommand }

constructor TReportMetadataChangeCommand.Create(AReport: TReportModel;
  ATitleEdit, AAuthorEdit: TEdit;
  const AOldTitle, AOldAuthor, AOldDescription,
  ANewTitle, ANewAuthor, ANewDescription: string);
begin
  inherited Create;
  ActionName := 'Report Properties Change';
  FReport := AReport;
  FTitleEdit := ATitleEdit;
  FAuthorEdit := AAuthorEdit;
  FOldTitle := AOldTitle;
  FOldAuthor := AOldAuthor;
  FOldDescription := AOldDescription;
  FNewTitle := ANewTitle;
  FNewAuthor := ANewAuthor;
  FNewDescription := ANewDescription;
end;

procedure TReportMetadataChangeCommand.ApplyValues(const ATitle, AAuthor,
  ADescription: string);
begin
  if Assigned(FReport) then
  begin
    FReport.Title := ATitle;
    FReport.Author := AAuthor;
    FReport.Description := ADescription;
  end;

  if Assigned(FTitleEdit) then
    FTitleEdit.Text := ATitle;
  if Assigned(FAuthorEdit) then
    FAuthorEdit.Text := AAuthor;
end;

procedure TReportMetadataChangeCommand.Execute;
begin
  ApplyValues(FNewTitle, FNewAuthor, FNewDescription);
end;

procedure TReportMetadataChangeCommand.Rollback;
begin
  ApplyValues(FOldTitle, FOldAuthor, FOldDescription);
end;

end.
