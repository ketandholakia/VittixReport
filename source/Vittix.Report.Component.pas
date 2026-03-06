unit Vittix.Report.Component;

{
  Vittix.Report.Component
  ========================
  TVittixReport — the non-visual report component.

  Drop this on a form exactly like TfrxReport in FastReport.
  It shows as a small icon in the non-visual component tray — no visible
  surface at design-time.

  Runtime usage
  -------------
    VittixReport1.DataSource := DataSource1;
    VittixReport1.Execute;               // show preview
    VittixReport1.Print;                 // direct print
    VittixReport1.ExportToPDF('out.pdf');
}

interface

uses
  System.Classes,
  System.SysUtils,
  Data.DB,
  Vittix.Report.Model,
  Vittix.Report.Serializer,
  Vittix.Report.Engine,
  Vittix.Report.Renderer,
  Vittix.Report.Export.PDF;

type
  TVittixReport = class(TComponent)
  private
    FDataSource: TDataSource;
    FReportJSON: string;

    function  GetReportJSON: string;
    procedure SetReportJSON(const V: string);
    procedure SetDataSource(const V: TDataSource);

  protected
    procedure Notification(AComponent: TComponent;
                           Operation: TOperation); override;

  public
    destructor Destroy; override;

    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);

    procedure Execute;
    procedure Print;
    procedure ExportToPDF(const AFileName: string);

    { Returns a freshly deserialised model — caller must free }
    function GetModel: TReportModel;

  published
    property ReportJSON: string
      read GetReportJSON write SetReportJSON;
    property DataSource: TDataSource
      read FDataSource write SetDataSource;
  end;

procedure Register;

implementation

uses
  Vcl.Forms,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vittix.Report.Preview;  // TVittixReportPreview

{ --------------------------------------------------------------------------- }

destructor TVittixReport.Destroy;
begin
  inherited;
end;

procedure TVittixReport.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDataSource) then
    FDataSource := nil;
end;

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

{ --------------------------------------------------------------------------- }

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

{ --------------------------------------------------------------------------- }
{  Preview nav button handlers                                                  }
{  TNotifyEvent requires 'of object' so we use a tiny helper class.           }
{ --------------------------------------------------------------------------- }

type
  TPreviewNavHelper = class
    Preview: TVittixReportPreview;
    procedure PrevClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
  end;

procedure TPreviewNavHelper.PrevClick(Sender: TObject);
begin
  Preview.GoPrev;
end;

procedure TPreviewNavHelper.NextClick(Sender: TObject);
begin
  Preview.GoNext;
end;

{ --------------------------------------------------------------------------- }
{  Execute — modal preview window built from TVittixReportPreview              }
{ --------------------------------------------------------------------------- }

procedure TVittixReport.Execute;
var
  Model   : TReportModel;
  DS      : TDataSet;
  Renderer: TReportRenderer;
  Frm     : TForm;
  Preview : TVittixReportPreview;
  Toolbar : TPanel;
  BtnClose: TButton;
  BtnPrev : TButton;
  BtnNext : TButton;
  NavHelp : TPreviewNavHelper;
begin
  if FReportJSON = '' then
    raise Exception.Create(
      'No report design loaded. Double-click the component at design-time.');

  Model := TReportSerializer.LoadFromJSON(FReportJSON);
  try
    DS := nil;
    if Assigned(FDataSource) then
      DS := FDataSource.DataSet;

    Renderer := TReportRenderer.Create;
    try
      Renderer.Render(Model, DS);

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
          Toolbar.Height     := 36;
          Toolbar.BevelOuter := bvNone;

          BtnClose             := TButton.Create(Frm);
          BtnClose.Parent      := Toolbar;
          BtnClose.Caption     := 'Close';
          BtnClose.Left        := 8;
          BtnClose.Top         := 4;
          BtnClose.Width       := 72;
          BtnClose.ModalResult := mrCancel;

          BtnPrev         := TButton.Create(Frm);
          BtnPrev.Parent  := Toolbar;
          BtnPrev.Caption := '< Prev';
          BtnPrev.Left    := 92;
          BtnPrev.Top     := 4;
          BtnPrev.Width   := 72;

          BtnNext         := TButton.Create(Frm);
          BtnNext.Parent  := Toolbar;
          BtnNext.Caption := 'Next >';
          BtnNext.Left    := 172;
          BtnNext.Top     := 4;
          BtnNext.Width   := 72;

          Preview        := TVittixReportPreview.Create(Frm);
          Preview.Parent := Frm;
          Preview.Align  := alClient;
          Preview.LoadFromRenderer(Renderer);

          NavHelp.Preview  := Preview;
          BtnPrev.OnClick  := NavHelp.PrevClick;
          BtnNext.OnClick  := NavHelp.NextClick;

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
    Model.Free;
  end;
end;

{ --------------------------------------------------------------------------- }
{  Print — renders then sends to printer via TVittixReportPreview.Print        }
{ --------------------------------------------------------------------------- }

procedure TVittixReport.Print;
var
  Model   : TReportModel;
  DS      : TDataSet;
  Renderer: TReportRenderer;
begin
  if FReportJSON = '' then
    raise Exception.Create('No report design loaded.');

  Model := TReportSerializer.LoadFromJSON(FReportJSON);
  try
    DS := nil;
    if Assigned(FDataSource) then
      DS := FDataSource.DataSet;

    Renderer := TReportRenderer.Create;
    try
      Renderer.Render(Model, DS);
      Renderer.Print;
    finally
      Renderer.Free;
    end;
  finally
    Model.Free;
  end;
end;

{ --------------------------------------------------------------------------- }
{  ExportToPDF — uses TReportEngine directly (PDF exporter needs TMetafile)   }
{ --------------------------------------------------------------------------- }

procedure TVittixReport.ExportToPDF(const AFileName: string);
var
  Model : TReportModel;
  DS    : TDataSet;
  Engine: TReportEngine;
begin
  if FReportJSON = '' then
    raise Exception.Create('No report design loaded.');

  Model := TReportSerializer.LoadFromJSON(FReportJSON);
  try
    DS := nil;
    if Assigned(FDataSource) then
      DS := FDataSource.DataSet;

    Engine := TReportEngine.Create(Model, DS);
    try
      Engine.Prepare;
      TReportPDFExporter.ExportToFile(Engine.Pages, AFileName);
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
  end;
end;

{ --------------------------------------------------------------------------- }

procedure Register;
begin
  RegisterComponents('Vittix Reporting', [TVittixReport]);
end;

end.
