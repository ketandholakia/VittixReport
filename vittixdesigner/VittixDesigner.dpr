program VittixDesigner;

uses
  Vcl.Forms,
  Frm.Main in 'Frm.Main.pas' {frmMain},
  Frm.BandManager in 'Frm.BandManager.pas' {frmBandManager},
  Frm.PageSettings in 'Frm.PageSettings.pas' {frmPageSettings},
  Frm.Preview in 'Frm.Preview.pas' {frmPreview},
  Vittix.Report.Model in '..\Vittix.Report.Model.pas',
  Vittix.Report.Objects in '..\Vittix.Report.Objects.pas',
  Vittix.Report.Bands in '..\Vittix.Report.Bands.pas',
  Vittix.Report.Context in '..\Vittix.Report.Context.pas',
  Vittix.Report.Expressions in '..\Vittix.Report.Expressions.pas',
  Vittix.Report.Aggregates in '..\Vittix.Report.Aggregates.pas',
  Vittix.Report.PageSettings in '..\Vittix.Report.PageSettings.pas',
  Vittix.Report.Serializer in '..\Vittix.Report.Serializer.pas',
  Vittix.Report.Undo in '..\Vittix.Report.Undo.pas',
  Vittix.Report.DesignerControl in '..\Vittix.Report.DesignerControl.pas',
  Vittix.Report.Toolbox in '..\Vittix.Report.Toolbox.pas',
  Vittix.Report.PropertyBridge in '..\Vittix.Report.PropertyBridge.pas',
  Vittix.Report.Engine in '..\Vittix.Report.Engine.pas',
  Vittix.Report.Renderer in '..\Vittix.Report.Renderer.pas',
  Vittix.Report.Preview in '..\Vittix.Report.Preview.pas',
  Vittix.Report.Interfaces in '..\Vittix.Report.Interfaces.pas',
  Vittix.Report.Utils in '..\Vittix.Report.Utils.pas',
  Vittix.Report.Objects.Barcode in '..\Vittix.Report.Objects.Barcode.pas',
  Vittix.Report.Objects.Table in '..\Vittix.Report.Objects.Table.pas',
  Vittix.Report.Export.PDF in '..\Vittix.Report.Export.PDF.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Vittix Report Designer';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
