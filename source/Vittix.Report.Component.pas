unit Vittix.Report.Component;

{
  Vittix.Report.Component
  ========================
  TVittixReport — the non-visual report component.

  Drop this on a form exactly like TfrxReport in FastReport.
  It shows as a small icon in the non-visual component tray — no visible
  surface at design-time.

  UserDataSet usage (preferred — FastReport style)
  -------------------------------------------------
    // Drop TVittixUserDataSet on the form, set its DataSet/DataSource,
    // then register it with the report before Execute:

    procedure TForm1.FormCreate(Sender: TObject);
    begin
      VittixReport1.RegisterUserDataSet(dsOrders);   // dsOrders is TVittixUserDataSet
    end;

    procedure TForm1.btnPreviewClick(Sender: TObject);
    begin
      VittixReport1.LoadFromFile('invoice.vrt');
      VittixReport1.Execute;
    end;

  Legacy DataSource usage (still supported)
  ------------------------------------------
    VittixReport1.DataSource := DataSource1;
    VittixReport1.Execute;

  The engine resolution order:
    1. Registered TVittixUserDataSet whose Name matches the band's DataSetName
    2. Primary TVittixUserDataSet (first registered, or only one registered)
    3. Legacy FDataSource.DataSet  (backwards-compatible fallback)
}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Serializer,
  Vittix.Report.Engine,
  Vittix.Report.Renderer,
  Vittix.Report.Export.PDF,
  Vittix.Report.Export.Text,
  Vittix.Report.Interfaces,
  Vittix.Report.UserDataSet;

type
  TVittixReport = class(TComponent)
  private
    FDataSource   : TDataSource;
    FReportJSON   : string;
    FParameters   : TStrings;
    FTwoPassRendering: Boolean;
    // Ordered list — first entry is the primary dataset
    FUserDataSets : TList<TVittixUserDataSet>;

    function  GetReportJSON: string;
    procedure SetReportJSON(const V: string);
    procedure SetDataSource(const V: TDataSource);
    procedure SetParameters(const V: TStrings);

    // Build the TDataSet / named-dataset map consumed by the engine
    function  ResolvePrimaryDataSet: TDataSet;
    procedure BuildNamedDataSets(
      out APrimary: TDataSet;
      out ANamedDS: TDictionary<string, TDataSet>);
    procedure BuildNamedUserDataSets(
      out APrimary: TVittixUserDataSet;
      out ANamedDS: TDictionary<string, TVittixUserDataSet>);

  protected
    procedure Notification(AComponent: TComponent;
                           Operation: TOperation); override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    // ----- Report file I/O --------------------------------------------------
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);

    // ----- UserDataSet registration -----------------------------------------

    /// <summary>
    ///   Register a TVittixUserDataSet with this report.
    ///   The first registered dataset is treated as the primary (master) source.
    ///   Additional datasets are looked up by their component Name when the
    ///   engine resolves a band's DataSetName property.
    ///
    ///   Call this once per dataset, e.g. in FormCreate.
    ///   Safe to call multiple times — duplicates are silently ignored.
    /// </summary>
    procedure RegisterUserDataSet(ADataSet: TVittixUserDataSet);

    /// <summary>Remove a previously registered TVittixUserDataSet.</summary>
    procedure UnregisterUserDataSet(ADataSet: TVittixUserDataSet);

    /// <summary>Remove all registered TVittixUserDataSet instances.</summary>
    procedure ClearUserDataSets;

    // ----- Execution --------------------------------------------------------
    procedure Execute;
    procedure Print;
    procedure ExportToPDF(const AFileName: string);
    procedure ExportToText(const AFileName: string);
    procedure ExportWith(const AExporter: IReportExporter; const AFileName: string);

    { Returns a freshly deserialised model — caller must free }
    function  GetModel: TReportModel;

  published
    // Legacy single-datasource wiring — still works; UserDataSet takes priority
    property DataSource: TDataSource
      read FDataSource write SetDataSource;

    property ReportJSON: string
      read GetReportJSON write SetReportJSON;

    property Parameters: TStrings
      read FParameters write SetParameters;

    property TwoPassRendering: Boolean
      read FTwoPassRendering write FTwoPassRendering default True;
  end;

// procedure Register;  // registration moved to Vittix.Report.Reg

implementation

uses
  Vcl.Forms,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vittix.Report.Preview;

// ---------------------------------------------------------------------------
//  Constructor / Destructor
// ---------------------------------------------------------------------------

constructor TVittixReport.Create(AOwner: TComponent);
begin
  inherited;
  FParameters := TStringList.Create;
  FUserDataSets := TList<TVittixUserDataSet>.Create;
  FTwoPassRendering := True;
end;

destructor TVittixReport.Destroy;
begin
  FUserDataSets.Free;
  FParameters.Free;
  inherited;
end;

// ---------------------------------------------------------------------------
//  Notification — clean up dangling references
// ---------------------------------------------------------------------------

procedure TVittixReport.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
  begin
    if AComponent = FDataSource then
      FDataSource := nil;
    if AComponent is TVittixUserDataSet then
      FUserDataSets.Remove(TVittixUserDataSet(AComponent));
  end;
end;

// ---------------------------------------------------------------------------
//  Property accessors
// ---------------------------------------------------------------------------

procedure TVittixReport.SetDataSource(const V: TDataSource);
begin
  if FDataSource = V then Exit;
  if Assigned(FDataSource) then
    FDataSource.RemoveFreeNotification(Self);
  FDataSource := V;
  if Assigned(FDataSource) then
    FDataSource.FreeNotification(Self);
end;

function TVittixReport.GetReportJSON: string;
begin
  Result := FReportJSON;
end;

procedure TVittixReport.SetReportJSON(const V: string);
begin
  FReportJSON := V;
end;

procedure TVittixReport.SetParameters(const V: TStrings);
begin
  FParameters.Clear;
  if Assigned(V) then
    FParameters.Assign(V);
end;

// ---------------------------------------------------------------------------
//  UserDataSet registration
// ---------------------------------------------------------------------------

procedure TVittixReport.RegisterUserDataSet(ADataSet: TVittixUserDataSet);
begin
  if not Assigned(ADataSet) then Exit;
  if FUserDataSets.IndexOf(ADataSet) < 0 then
  begin
    FUserDataSets.Add(ADataSet);
    ADataSet.FreeNotification(Self);
  end;
end;

procedure TVittixReport.UnregisterUserDataSet(ADataSet: TVittixUserDataSet);
begin
  if Assigned(ADataSet) then
    FUserDataSets.Remove(ADataSet);
end;

procedure TVittixReport.ClearUserDataSets;
begin
  FUserDataSets.Clear;
end;

// ---------------------------------------------------------------------------
//  Dataset resolution
//
//  Priority:
//    1. RegisterUserDataSet entries (first = primary, others by .Name)
//    2. Legacy FDataSource.DataSet
// ---------------------------------------------------------------------------

function TVittixReport.ResolvePrimaryDataSet: TDataSet;
begin
  if FUserDataSets.Count > 0 then
    Result := FUserDataSets[0].DataSet
  else if Assigned(FDataSource) then
    Result := FDataSource.DataSet
  else
    Result := nil;
end;

procedure TVittixReport.BuildNamedDataSets(
  out APrimary: TDataSet;
  out ANamedDS: TDictionary<string, TDataSet>);
var
  UDS: TVittixUserDataSet;
  I  : Integer;
begin
  ANamedDS := TDictionary<string, TDataSet>.Create;

  if FUserDataSets.Count > 0 then
  begin
    // First registered = primary
    APrimary := FUserDataSets[0].DataSet;

    // All registered datasets indexed by component Name for band lookup
    for I := 0 to FUserDataSets.Count - 1 do
    begin
      UDS := FUserDataSets[I];
      if (UDS.Name <> '') and Assigned(UDS.DataSet) then
        ANamedDS.AddOrSetValue(UDS.Name, UDS.DataSet);
    end;
  end
  else
  begin
    // Legacy fallback
    APrimary := nil;
    if Assigned(FDataSource) then
      APrimary := FDataSource.DataSet;
  end;
end;

procedure TVittixReport.BuildNamedUserDataSets(
  out APrimary: TVittixUserDataSet;
  out ANamedDS: TDictionary<string, TVittixUserDataSet>);
var
  I: Integer;
  UDS: TVittixUserDataSet;
begin
  APrimary := nil;
  ANamedDS := TDictionary<string, TVittixUserDataSet>.Create;

  if FUserDataSets.Count = 0 then
    Exit;

  APrimary := FUserDataSets[0];
  for I := 0 to FUserDataSets.Count - 1 do
  begin
    UDS := FUserDataSets[I];
    if UDS.Name <> '' then
      ANamedDS.AddOrSetValue(UDS.Name, UDS);
  end;
end;

// ---------------------------------------------------------------------------
//  Report file I/O
// ---------------------------------------------------------------------------

procedure TVittixReport.LoadFromFile(const AFileName: string);
var
  Model: TReportModel;
begin
  Model := TReportSerializer.LoadFromFile(AFileName);
  try
    FReportJSON := TReportSerializer.SaveToJSON(Model);
  finally
    Model.Free;
  end;
end;

procedure TVittixReport.SaveToFile(const AFileName: string);
var
  Model: TReportModel;
begin
  if FReportJSON = '' then Exit;
  Model := TReportSerializer.LoadFromJSON(FReportJSON);
  try
    TReportSerializer.SaveToFile(Model, AFileName);
  finally
    Model.Free;
  end;
end;

function TVittixReport.GetModel: TReportModel;
begin
  if FReportJSON = '' then
    Result := TReportModel.Create
  else
    Result := TReportSerializer.LoadFromJSON(FReportJSON);
end;

// ---------------------------------------------------------------------------
//  Preview helper
// ---------------------------------------------------------------------------

type
  TPreviewAction = procedure of object;

  TPreviewNavHelper = class
    Preview: TVittixReportPreview;
    procedure PrevClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure ZoomInClick(Sender: TObject);
    procedure ZoomOutClick(Sender: TObject);
    procedure FitWidthClick(Sender: TObject);
    procedure FitPageClick(Sender: TObject);
    procedure ZoomResetClick(Sender: TObject);
  end;

procedure InvokePreviewAction(APreview: TObject; const AMethodName: string);
var
  M: TMethod;
  Action: TPreviewAction;
begin
  if not Assigned(APreview) then Exit;
  M.Code := APreview.MethodAddress(AMethodName);
  if not Assigned(M.Code) then Exit;
  M.Data := APreview;
  Action := TPreviewAction(M);
  Action;
end;

procedure TPreviewNavHelper.PrevClick(Sender: TObject);     begin Preview.GoPrev;          end;
procedure TPreviewNavHelper.NextClick(Sender: TObject);     begin Preview.GoNext;          end;
procedure TPreviewNavHelper.ZoomInClick(Sender: TObject);   begin Preview.ZoomIn;          end;
procedure TPreviewNavHelper.ZoomOutClick(Sender: TObject);  begin Preview.ZoomOut;         end;
procedure TPreviewNavHelper.FitWidthClick(Sender: TObject); begin Preview.FitWidth;        end;
procedure TPreviewNavHelper.FitPageClick(Sender: TObject);  begin InvokePreviewAction(Preview, 'FitPage'); end;
procedure TPreviewNavHelper.ZoomResetClick(Sender: TObject); begin Preview.ZoomPercent := 100; end;

// ---------------------------------------------------------------------------
//  Execute — modal preview
// ---------------------------------------------------------------------------

procedure TVittixReport.Execute;
var
  Model    : TReportModel;
  Primary  : TDataSet;
  NamedDS  : TDictionary<string, TDataSet>;
  PrimaryUDS: TVittixUserDataSet;
  NamedUDS : TDictionary<string, TVittixUserDataSet>;
  Renderer : TReportRenderer;
  Frm      : TForm;
  Preview  : TVittixReportPreview;
  Toolbar  : TPanel;
  BtnClose, BtnPrev, BtnNext       : TButton;
  BtnZoomIn, BtnZoomOut, BtnZoom100: TButton;
  BtnFitPage, BtnFitWidth          : TButton;
  NavHelp  : TPreviewNavHelper;
begin
  if FReportJSON = '' then
    raise Exception.Create(
      'No report design loaded. Call LoadFromFile first.');

  Model := TReportSerializer.LoadFromJSON(FReportJSON);
  BuildNamedDataSets(Primary, NamedDS);
  BuildNamedUserDataSets(PrimaryUDS, NamedUDS);
  try
    Renderer := TReportRenderer.Create;
    try
      Renderer.Parameters.Assign(FParameters);
      Renderer.TwoPassRendering := FTwoPassRendering;
      if Assigned(PrimaryUDS) then
        Renderer.Render(Model, PrimaryUDS, NamedUDS)
      else
        Renderer.Render(Model, Primary, NamedDS);

      NavHelp := TPreviewNavHelper.Create;
      try
        Frm := TForm.Create(nil);
        try
          Frm.Caption  := Model.Title + ' — Preview';
          Frm.Width    := 900;
          Frm.Height   := 700;
          Frm.Position := poScreenCenter;

          Toolbar            := TPanel.Create(Frm);
          Toolbar.Parent     := Frm;
          Toolbar.Align      := alTop;
          Toolbar.Height     := 40;
          Toolbar.BevelOuter := bvNone;

          BtnClose             := TButton.Create(Frm);
          BtnClose.Parent      := Toolbar;
          BtnClose.Caption     := 'Close';
          BtnClose.Left        := 8;   BtnClose.Top := 4;
          BtnClose.Width       := 72;
          BtnClose.ModalResult := mrCancel;

          BtnPrev         := TButton.Create(Frm);
          BtnPrev.Parent  := Toolbar;
          BtnPrev.Caption := '< Prev';
          BtnPrev.Left    := 92;   BtnPrev.Top := 4;  BtnPrev.Width := 72;

          BtnNext         := TButton.Create(Frm);
          BtnNext.Parent  := Toolbar;
          BtnNext.Caption := 'Next >';
          BtnNext.Left    := 172;  BtnNext.Top := 4;  BtnNext.Width := 72;

          BtnZoomOut         := TButton.Create(Frm);
          BtnZoomOut.Parent  := Toolbar;
          BtnZoomOut.Caption := 'Zoom -';
          BtnZoomOut.Left    := 262; BtnZoomOut.Top := 4; BtnZoomOut.Width := 72;

          BtnZoomIn         := TButton.Create(Frm);
          BtnZoomIn.Parent  := Toolbar;
          BtnZoomIn.Caption := 'Zoom +';
          BtnZoomIn.Left    := 342; BtnZoomIn.Top := 4;  BtnZoomIn.Width := 72;

          BtnZoom100         := TButton.Create(Frm);
          BtnZoom100.Parent  := Toolbar;
          BtnZoom100.Caption := '100%';
          BtnZoom100.Left    := 422; BtnZoom100.Top := 4; BtnZoom100.Width := 60;

          BtnFitPage         := TButton.Create(Frm);
          BtnFitPage.Parent  := Toolbar;
          BtnFitPage.Caption := 'Fit Page';
          BtnFitPage.Left    := 490; BtnFitPage.Top := 4; BtnFitPage.Width := 72;

          BtnFitWidth         := TButton.Create(Frm);
          BtnFitWidth.Parent  := Toolbar;
          BtnFitWidth.Caption := 'Fit Width';
          BtnFitWidth.Left    := 570; BtnFitWidth.Top := 4; BtnFitWidth.Width := 72;

          Preview        := TVittixReportPreview.Create(Frm);
          Preview.Parent := Frm;
          Preview.Align  := alClient;
          Preview.LoadFromRenderer(Renderer);

          NavHelp.Preview      := Preview;
          BtnPrev.OnClick      := NavHelp.PrevClick;
          BtnNext.OnClick      := NavHelp.NextClick;
          BtnZoomIn.OnClick    := NavHelp.ZoomInClick;
          BtnZoomOut.OnClick   := NavHelp.ZoomOutClick;
          BtnFitWidth.OnClick  := NavHelp.FitWidthClick;
          BtnFitPage.OnClick   := NavHelp.FitPageClick;
          BtnZoom100.OnClick   := NavHelp.ZoomResetClick;

          Frm.ShowModal;
        finally
          Frm.Free;
        end;
      finally
        NavHelp.Free;
      end;
    finally
      Renderer.Free;
    end;
  finally
    NamedUDS.Free;
    NamedDS.Free;
    Model.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  Print
// ---------------------------------------------------------------------------

procedure TVittixReport.Print;
var
  Model  : TReportModel;
  Primary: TDataSet;
  NamedDS: TDictionary<string, TDataSet>;
  PrimaryUDS: TVittixUserDataSet;
  NamedUDS: TDictionary<string, TVittixUserDataSet>;
  Renderer: TReportRenderer;
begin
  if FReportJSON = '' then
    raise Exception.Create('No report design loaded.');

  Model := TReportSerializer.LoadFromJSON(FReportJSON);
  BuildNamedDataSets(Primary, NamedDS);
  BuildNamedUserDataSets(PrimaryUDS, NamedUDS);
  try
    Renderer := TReportRenderer.Create;
    try
      Renderer.Parameters.Assign(FParameters);
      Renderer.TwoPassRendering := FTwoPassRendering;
      if Assigned(PrimaryUDS) then
        Renderer.Render(Model, PrimaryUDS, NamedUDS)
      else
        Renderer.Render(Model, Primary, NamedDS);
      Renderer.Print;
  finally
    Renderer.Free;
  end;
  finally
    NamedUDS.Free;
    NamedDS.Free;
    Model.Free;
  end;
end;

// ---------------------------------------------------------------------------
//  ExportToPDF
// ---------------------------------------------------------------------------

procedure TVittixReport.ExportToPDF(const AFileName: string);
var
  Model  : TReportModel;
  Primary: TDataSet;
  NamedDS: TDictionary<string, TDataSet>;
  PrimaryUDS: TVittixUserDataSet;
  NamedUDS: TDictionary<string, TVittixUserDataSet>;
  Engine : TReportEngine;
begin
  if FReportJSON = '' then
    raise Exception.Create('No report design loaded.');

  Model := TReportSerializer.LoadFromJSON(FReportJSON);
  BuildNamedDataSets(Primary, NamedDS);
  BuildNamedUserDataSets(PrimaryUDS, NamedUDS);
  try
    if Assigned(PrimaryUDS) then
      Engine := TReportEngine.Create(Model, PrimaryUDS, NamedUDS, nil)
    else
      Engine := TReportEngine.Create(Model, Primary, NamedDS, nil);
    try
      Engine.Parameters.Assign(FParameters);
      Engine.TwoPassRendering := FTwoPassRendering;
      Engine.Prepare;
      TReportPDFExporter.ExportToFile(Engine.Pages, AFileName);
    finally
      Engine.Free;
    end;
  finally
    NamedUDS.Free;
    NamedDS.Free;
    Model.Free;
  end;
end;

procedure TVittixReport.ExportToText(const AFileName: string);
var
  Model  : TReportModel;
  Primary: TDataSet;
  NamedDS: TDictionary<string, TDataSet>;
begin
  if FReportJSON = '' then
    raise Exception.Create('No report design loaded.');

  Model := TReportSerializer.LoadFromJSON(FReportJSON);
  BuildNamedDataSets(Primary, NamedDS);
  try
    TReportTextExporter.ExportToFile(Model, Primary, NamedDS, FParameters, AFileName);
  finally
    NamedDS.Free;
    Model.Free;
  end;
end;

procedure TVittixReport.ExportWith(const AExporter: IReportExporter;
  const AFileName: string);
var
  Model  : TReportModel;
  Primary: TDataSet;
  NamedDS: TDictionary<string, TDataSet>;
  PrimaryUDS: TVittixUserDataSet;
  NamedUDS: TDictionary<string, TVittixUserDataSet>;
  Engine : TReportEngine;
begin
  if not Assigned(AExporter) then
    raise Exception.Create('Report exporter is not assigned.');

  if FReportJSON = '' then
    raise Exception.Create('No report design loaded.');

  Model := TReportSerializer.LoadFromJSON(FReportJSON);
  BuildNamedDataSets(Primary, NamedDS);
  BuildNamedUserDataSets(PrimaryUDS, NamedUDS);
  try
    if Assigned(PrimaryUDS) then
      Engine := TReportEngine.Create(Model, PrimaryUDS, NamedUDS, nil)
    else
      Engine := TReportEngine.Create(Model, Primary, NamedDS, nil);
    try
      Engine.Parameters.Assign(FParameters);
      Engine.TwoPassRendering := FTwoPassRendering;
      Engine.Prepare;
      AExporter.ExportPages(Engine.Pages, AFileName);
    finally
      Engine.Free;
    end;
  finally
    NamedUDS.Free;
    NamedDS.Free;
    Model.Free;
  end;
end;

end.
