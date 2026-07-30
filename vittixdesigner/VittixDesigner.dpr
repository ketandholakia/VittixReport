program VittixDesigner;

{$IFDEF DEBUG}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
   madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
 Vcl.Forms,
  System.SysUtils,
  vcl.Dialogs,
  Winapi.Windows,
  Frm.Main in 'Frm.Main.pas' {frmMain},
  Frm.DesignerOptions in 'Frm.DesignerOptions.pas' {frmDesignerOptions},
  Frm.ScriptEditor in 'Frm.ScriptEditor.pas' {frmScriptEditor},
  Frm.BandManager in 'Frm.BandManager.pas' {frmBandManager},
  Frm.PageSettings in 'Frm.PageSettings.pas' {frmPageSettings},
  Frm.Preview in 'Frm.Preview.pas' {frmPreview},
  Vittix.Report.Model in '..\source\Vittix.Report.Model.pas',
  Vittix.Report.Objects in '..\source\Vittix.Report.Objects.pas',
  Vittix.Report.Bands in '..\source\Vittix.Report.Bands.pas',
  Vittix.Report.Context in '..\source\Vittix.Report.Context.pas',
  Vittix.Report.Expressions in '..\source\Vittix.Report.Expressions.pas',
  Vittix.Report.Aggregates in '..\source\Vittix.Report.Aggregates.pas',
  Vittix.Report.PageSettings in '..\source\Vittix.Report.PageSettings.pas',
  Vittix.Report.Serializer in '..\source\Vittix.Report.Serializer.pas',
  Vittix.Report.Undo in '..\source\Vittix.Report.Undo.pas',
  Vittix.Report.DesignerControl in '..\source\Vittix.Report.DesignerControl.pas',
  Vittix.Report.Toolbox in '..\source\Vittix.Report.Toolbox.pas',
  Vittix.Report.PropertyBridge in '..\source\Vittix.Report.PropertyBridge.pas',
  Vittix.Report.Engine in '..\source\Vittix.Report.Engine.pas',
  Vittix.Report.LayoutBookmarks in '..\source\Vittix.Report.LayoutBookmarks.pas',
  Vittix.Report.Renderer in '..\source\Vittix.Report.Renderer.pas',
  Vittix.Report.Preview in '..\source\Vittix.Report.Preview.pas',
  Vittix.Report.Interfaces in '..\source\Vittix.Report.Interfaces.pas',
  Vittix.Report.Utils in '..\source\Vittix.Report.Utils.pas',
  Vittix.Report.Objects.Barcode in '..\source\Vittix.Report.Objects.Barcode.pas',
  Vittix.Report.Objects.Table in '..\source\Vittix.Report.Objects.Table.pas',
  Vittix.Report.Objects.Chart in '..\source\Vittix.Report.Objects.Chart.pas',
  Vittix.Report.Objects.CrossTab in '..\source\Vittix.Report.Objects.CrossTab.pas',
  Vittix.Report.UserDataSet in '..\source\Vittix.Report.UserDataSet.pas',
  Vittix.Report.LayoutCache in '..\source\Vittix.Report.LayoutCache.pas',
  Vittix.Report.LayoutHelpers in '..\source\Vittix.Report.LayoutHelpers.pas',
  Vittix.Report.LayoutPagination in '..\source\Vittix.Report.LayoutPagination.pas',
  Vittix.Report.DesignerInteraction in '..\source\Vittix.Report.DesignerInteraction.pas',
  Vittix.Report.DesignerInteractionController in '..\source\Vittix.Report.DesignerInteractionController.pas',
  Vittix.Report.CommandDispatcher in '..\source\Vittix.Report.CommandDispatcher.pas',
  Vittix.Report.SelectionHelpers in '..\source\Vittix.Report.SelectionHelpers.pas',
  Vittix.Report.ScriptHost.Adapter in '..\source\Vittix.Report.ScriptHost.Adapter.pas',
  Vittix.Report.Scripting in '..\source\Vittix.Report.Scripting.pas',
  Vittix.Report.DataSources in '..\source\Vittix.Report.DataSources.pas',
  Vittix.Report.ObjectRegistry in '..\source\Vittix.Report.ObjectRegistry.pas',
  Vittix.Report.Engine.Engine in '..\source\Vittix.Report.Engine.Engine.pas',
  Vittix.Report.Engine.Renderer in '..\source\Vittix.Report.Engine.Renderer.pas',
  Vittix.Report.Export.Commands in '..\source\Vittix.Report.Export.Commands.pas',
  Vittix.Report.Export.VectorPDF in '..\source\Vittix.Report.Export.VectorPDF.pas',
  Vittix.Report.Export.VectorPDF.SVG in '..\source\Vittix.Report.Export.VectorPDF.SVG.pas',
  Vittix.Report.Export.VectorPDF.EMF in '..\source\Vittix.Report.Export.VectorPDF.EMF.pas',
  Vittix.Report.Export.PDF in '..\source\Vittix.Report.Export.PDF.pas',
  Vittix.Report.Export.Email in '..\source\Vittix.Report.Export.Email.pas',
  Vittix.Report.Export.Text in '..\source\Vittix.Report.Export.Text.pas';

{$R *.res}

procedure InitializeApplication;
begin
  { Enable high DPI awareness for better display on modern monitors }
  try
    if CheckWin32Version(6, 0) then
      SetProcessDPIAware;
  except
    // DPI awareness might not be available on older Windows versions
  end;
end;

begin
  try
    InitializeApplication;
    
    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.Title := 'Vittix Report Designer';
    Application.HelpFile := '';
    
    Application.CreateForm(TfrmMain, frmMain);
    
    Application.Run;
  except
    on E: Exception do
    begin
      ShowMessage('Fatal Error: ' + E.Message + sLineBreak + sLineBreak +
        'The application will now close.');
      ExitProcess(1);
    end;
  end;
end.
