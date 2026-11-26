unit Test.Vittix.Designer.Preferences;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TDesignerPreferencesTests = class
  public
    [Test] procedure Test_BeginEndSession_BatchesIniWriteUntilEndSession;
    [Test] procedure Test_StandaloneSave_FlushesImmediately;
    [Test] procedure Test_AddRecentFile_DeduplicatesAndCapsMaxCount;
    [Test] procedure Test_MetadataCommand_ExecuteAndRollback;
    [Test] procedure Test_CollectReportProblems_DetectsZeroHeightBandAndMissingField;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.Types,
  System.Generics.Collections,
  Vcl.StdCtrls,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  DesignerPreferences,
  Frm.Main.Commands,
  Frm.Main.Problems;

procedure TDesignerPreferencesTests.Test_BeginEndSession_BatchesIniWriteUntilEndSession;
var
  IniPath: string;
  Svc, Reader: TDesignerPreferencesService;
  H1, H2, H3: Integer;
  C1, C2, C3, C4: Boolean;
  Files: TList<string>;
begin
  IniPath := TPath.Combine(TPath.GetTempPath,
    'vittix_pref_batch_' + TGUID.NewGuid.ToString + '.ini');
  Svc := TDesignerPreferencesService.Create(IniPath);
  Reader := TDesignerPreferencesService.Create(IniPath);
  Files := TList<string>.Create;
  try
    Svc.BeginSession;
    try
      Svc.SaveThemeName('Midnight');
      Svc.SaveSidebarSectionHeights(110, 120, 130);
      Svc.SaveSidebarCollapsed(True, False, True, False);
      Files.Add('a.vrt');
      Files.Add('b.vrt');
      Svc.SaveRecentFiles(Files);
      // File must not be written to disk until EndSession
      Assert.IsFalse(TFile.Exists(IniPath),
        'Batch session must defer INI flush until EndSession');
    finally
      Svc.EndSession;
    end;

    Assert.IsTrue(TFile.Exists(IniPath), 'EndSession must flush INI file');
    Assert.AreEqual('Midnight', Reader.LoadThemeName('Default'));
    H1 := 0; H2 := 0; H3 := 0;
    Reader.LoadSidebarSectionHeights(H1, H2, H3);
    Assert.AreEqual(110, H1);
    Assert.AreEqual(120, H2);
    Assert.AreEqual(130, H3);

    C1 := False; C2 := True; C3 := False; C4 := True;
    Reader.LoadSidebarCollapsed(C1, C2, C3, C4);
    Assert.IsTrue(C1);
    Assert.IsFalse(C2);
    Assert.IsTrue(C3);
    Assert.IsFalse(C4);

    Files.Clear;
    Reader.LoadRecentFiles(Files);
    Assert.AreEqual(2, Files.Count);
    Assert.AreEqual('a.vrt', Files[0]);
    Assert.AreEqual('b.vrt', Files[1]);
  finally
    Files.Free;
    Reader.Free;
    Svc.Free;
    if TFile.Exists(IniPath) then
      TFile.Delete(IniPath);
  end;
end;

procedure TDesignerPreferencesTests.Test_StandaloneSave_FlushesImmediately;
var
  IniPath: string;
  Svc: TDesignerPreferencesService;
begin
  IniPath := TPath.Combine(TPath.GetTempPath,
    'vittix_pref_single_' + TGUID.NewGuid.ToString + '.ini');
  Svc := TDesignerPreferencesService.Create(IniPath);
  try
    Svc.SaveThemeName('Slate');
    Assert.IsTrue(TFile.Exists(IniPath));
    Assert.AreEqual('Slate', Svc.LoadThemeName('Default'));
  finally
    Svc.Free;
    if TFile.Exists(IniPath) then
      TFile.Delete(IniPath);
  end;
end;

procedure TDesignerPreferencesTests.Test_AddRecentFile_DeduplicatesAndCapsMaxCount;
var
  Svc: TDesignerPreferencesService;
  Files: TList<string>;
begin
  Svc := TDesignerPreferencesService.Create('');
  Files := TList<string>.Create;
  try
    Svc.AddRecentFile(Files, 'one.vrt', 3);
    Svc.AddRecentFile(Files, 'two.vrt', 3);
    Svc.AddRecentFile(Files, 'three.vrt', 3);
    Svc.AddRecentFile(Files, 'one.vrt', 3); // moves to front
    Assert.AreEqual(3, Files.Count);
    Assert.AreEqual('one.vrt', Files[0]);
    Assert.AreEqual('three.vrt', Files[1]);
    Assert.AreEqual('two.vrt', Files[2]);

    Svc.AddRecentFile(Files, 'four.vrt', 3); // evicts oldest
    Assert.AreEqual(3, Files.Count);
    Assert.AreEqual('four.vrt', Files[0]);
    Assert.AreEqual('three.vrt', Files[2]);
  finally
    Files.Free;
    Svc.Free;
  end;
end;

procedure TDesignerPreferencesTests.Test_MetadataCommand_ExecuteAndRollback;
var
  Model: TReportModel;
  TitleEdit, AuthorEdit: TEdit;
  Cmd: TReportMetadataChangeCommand;
begin
  Model := TReportModel.Create;
  TitleEdit := TEdit.Create(nil);
  AuthorEdit := TEdit.Create(nil);
  try
    Model.Title := 'OldTitle';
    Model.Author := 'OldAuthor';
    Model.Description := 'OldDesc';
    Cmd := TReportMetadataChangeCommand.Create(
      Model, TitleEdit, AuthorEdit,
      'OldTitle', 'OldAuthor', 'OldDesc',
      'NewTitle', 'NewAuthor', 'NewDesc');
    try
      Cmd.Execute;
      Assert.AreEqual('NewTitle', Model.Title);
      Assert.AreEqual('NewAuthor', Model.Author);
      Assert.AreEqual('NewDesc', Model.Description);
      Assert.AreEqual('NewTitle', TitleEdit.Text);
      Assert.AreEqual('NewAuthor', AuthorEdit.Text);

      Cmd.Rollback;
      Assert.AreEqual('OldTitle', Model.Title);
      Assert.AreEqual('OldAuthor', Model.Author);
      Assert.AreEqual('OldDesc', Model.Description);
      Assert.AreEqual('OldTitle', TitleEdit.Text);
      Assert.AreEqual('OldAuthor', AuthorEdit.Text);
    finally
      Cmd.Free;
    end;
  finally
    AuthorEdit.Free;
    TitleEdit.Free;
    Model.Free;
  end;
end;

procedure TDesignerPreferencesTests.Test_CollectReportProblems_DetectsZeroHeightBandAndMissingField;
var
  Model: TReportModel;
  Band: TReportBand;
  Fld: TReportFieldObject;
  Problems: TObjectList<TDesignerProblem>;
  Diag: TStringList;
begin
  Model := TReportModel.Create;
  Problems := TObjectList<TDesignerProblem>.Create(True);
  Diag := TStringList.Create;
  try
    Diag.Add('Unknown object ignored');

    Band := TReportBand.Create;
    Band.Name := 'MasterBand1';
    Band.BandType := btMasterData;
    Band.Height := 0; // error
    Fld := TReportFieldObject.Create;
    Fld.Name := 'Field1';
    Fld.Bounds := Rect(4, 4, 100, 20);
    Fld.DataField := 'MissingCol'; // warning
    Band.Children.Add(Fld);
    Model.Objects.Add(Band);

    CollectReportProblems(Model, ['ID', 'Name'], Diag, Problems);

    Assert.AreEqual(3, Problems.Count);
    Assert.AreEqual(dpsWarning, Problems[0].Severity);
    Assert.AreEqual('Unknown object ignored', Problems[0].Text);
    Assert.AreEqual(dpsError, Problems[1].Severity);
    Assert.IsTrue(Pos('MasterBand1', Problems[1].Text) > 0);
    Assert.AreEqual(dpsWarning, Problems[2].Severity);
    Assert.IsTrue(Pos('MissingCol', Problems[2].Text) > 0);
  finally
    Diag.Free;
    Problems.Free;
    Model.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDesignerPreferencesTests);

end.
