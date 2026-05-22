unit DesignerPreferences;

interface

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  System.IniFiles,
  Vcl.Graphics,
  Vittix.Report.DesignerControl;

type
  TDesignerPreferences = record
    ShowGrid: Boolean;
    SnapToGrid: Boolean;
    ShowRulers: Boolean;
    ShowMargins: Boolean;
    PageColor: TColor;
    CanvasColor: TColor;
  end;

  TDesignerPreferencesService = class
  private
    FSettingsPath: string;
    function RecentFilesSectionName: string;
  public
    constructor Create(const ASettingsPath: string = '');

    function SettingsPath: string;

    procedure LoadDesignerPreferences(ADesigner: TVittixReportDesigner);
    procedure SaveDesignerPreferences(ADesigner: TVittixReportDesigner);

    procedure LoadRecentFiles(ARecentFiles: TList<string>);
    procedure SaveRecentFiles(ARecentFiles: TList<string>);
    procedure AddRecentFile(ARecentFiles: TList<string>; const AFileName: string;
      AMaxCount: Integer = 8);
    procedure ClearRecentFiles(ARecentFiles: TList<string>);
  end;

implementation

constructor TDesignerPreferencesService.Create(const ASettingsPath: string);
begin
  inherited Create;
  if ASettingsPath <> '' then
    FSettingsPath := ASettingsPath
  else
    FSettingsPath := TPath.Combine(TPath.GetHomePath, 'VittixDesigner.ini');
end;

function TDesignerPreferencesService.SettingsPath: string;
begin
  Result := FSettingsPath;
end;

function TDesignerPreferencesService.RecentFilesSectionName: string;
begin
  Result := 'RecentFiles';
end;

procedure TDesignerPreferencesService.LoadDesignerPreferences(
  ADesigner: TVittixReportDesigner);
var
  Ini: TIniFile;
begin
  if not Assigned(ADesigner) then
    Exit;

  Ini := TIniFile.Create(FSettingsPath);
  try
    ADesigner.ShowGrid    := Ini.ReadBool('Designer', 'ShowGrid', ADesigner.ShowGrid);
    ADesigner.SnapToGrid  := Ini.ReadBool('Designer', 'SnapToGrid', ADesigner.SnapToGrid);
    ADesigner.ShowRulers  := Ini.ReadBool('Designer', 'ShowRulers', ADesigner.ShowRulers);
    ADesigner.ShowMargins := Ini.ReadBool('Designer', 'ShowMargins', ADesigner.ShowMargins);
    ADesigner.PageColor   := TColor(Ini.ReadInteger('Designer', 'PageColor', Integer(ADesigner.PageColor)));
    ADesigner.CanvasColor := TColor(Ini.ReadInteger('Designer', 'CanvasColor', Integer(ADesigner.CanvasColor)));
  finally
    Ini.Free;
  end;
end;

procedure TDesignerPreferencesService.SaveDesignerPreferences(
  ADesigner: TVittixReportDesigner);
var
  Ini: TIniFile;
begin
  if not Assigned(ADesigner) then
    Exit;

  Ini := TIniFile.Create(FSettingsPath);
  try
    Ini.WriteBool('Designer', 'ShowGrid', ADesigner.ShowGrid);
    Ini.WriteBool('Designer', 'SnapToGrid', ADesigner.SnapToGrid);
    Ini.WriteBool('Designer', 'ShowRulers', ADesigner.ShowRulers);
    Ini.WriteBool('Designer', 'ShowMargins', ADesigner.ShowMargins);
    Ini.WriteInteger('Designer', 'PageColor', Integer(ADesigner.PageColor));
    Ini.WriteInteger('Designer', 'CanvasColor', Integer(ADesigner.CanvasColor));
  finally
    Ini.Free;
  end;
end;

procedure TDesignerPreferencesService.LoadRecentFiles(ARecentFiles: TList<string>);
var
  Ini: TIniFile;
  I, Count: Integer;
  S: string;
begin
  if not Assigned(ARecentFiles) then
    Exit;

  ARecentFiles.Clear;
  Ini := TIniFile.Create(FSettingsPath);
  try
    Count := Ini.ReadInteger(RecentFilesSectionName, 'Count', 0);
    for I := 0 to Count - 1 do
    begin
      S := Ini.ReadString(RecentFilesSectionName, 'File' + IntToStr(I), '');
      if S <> '' then
        ARecentFiles.Add(S);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TDesignerPreferencesService.SaveRecentFiles(ARecentFiles: TList<string>);
var
  Ini: TIniFile;
  I: Integer;
begin
  if not Assigned(ARecentFiles) then
    Exit;

  Ini := TIniFile.Create(FSettingsPath);
  try
    Ini.EraseSection(RecentFilesSectionName);
    Ini.WriteInteger(RecentFilesSectionName, 'Count', ARecentFiles.Count);
    for I := 0 to ARecentFiles.Count - 1 do
      Ini.WriteString(RecentFilesSectionName, 'File' + IntToStr(I), ARecentFiles[I]);
  finally
    Ini.Free;
  end;
end;

procedure TDesignerPreferencesService.AddRecentFile(
  ARecentFiles: TList<string>; const AFileName: string; AMaxCount: Integer);
var
  Idx: Integer;
  S: string;
begin
  if not Assigned(ARecentFiles) then
    Exit;

  S := Trim(AFileName);
  if S = '' then
    Exit;

  Idx := ARecentFiles.IndexOf(S);
  if Idx >= 0 then
    ARecentFiles.Delete(Idx);
  ARecentFiles.Insert(0, S);
  while ARecentFiles.Count > AMaxCount do
    ARecentFiles.Delete(ARecentFiles.Count - 1);
end;

procedure TDesignerPreferencesService.ClearRecentFiles(ARecentFiles: TList<string>);
begin
  if Assigned(ARecentFiles) then
    ARecentFiles.Clear;
end;

end.
