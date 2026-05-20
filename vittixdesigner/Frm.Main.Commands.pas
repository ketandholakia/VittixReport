unit Frm.Main.Commands;

interface

uses
  System.Classes,
  System.Rtti,
  Vcl.Graphics,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.DesignerControl,
  Vittix.Report.Objects,
  Vittix.Report.PageSettings,
  Vittix.Report.Renderer,
  Vittix.Report.Serializer,
  Vittix.Report.Undo;

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

implementation

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

end.
