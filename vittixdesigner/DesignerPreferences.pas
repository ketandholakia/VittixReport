unit DesignerPreferences;

interface

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  System.IniFiles,
  Vcl.Controls,
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
    BandGap: Integer;
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
    procedure LoadSidebarWidths(ALeftSidebar, ARightSidebar: TControl);
    procedure SaveSidebarWidths(ALeftSidebar, ARightSidebar: TControl);
    procedure LoadSidebarSectionHeights(AObjects, ADataSections, AFields: TControl);
    procedure SaveSidebarSectionHeights(AObjects, ADataSections, AFields: TControl);

    procedure LoadRecentFiles(ARecentFiles: TList<string>);
    procedure SaveRecentFiles(ARecentFiles: TList<string>);
    procedure AddRecentFile(ARecentFiles: TList<string>; const AFileName: string;
      AMaxCount: Integer = 8);
    procedure ClearRecentFiles(ARecentFiles: TList<string>);
  end;

implementation

const
  MinSidebarWidth = 100;
  MaxSidebarWidth = 600;
  MinSidebarSectionHeight = 50;
  MaxSidebarSectionHeight = 500;

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
    ADesigner.BandGap     := Ini.ReadInteger('Designer', 'BandGap', ADesigner.BandGap);
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
    Ini.WriteInteger('Designer', 'BandGap', ADesigner.BandGap);
  finally
    Ini.Free;
  end;
end;

procedure TDesignerPreferencesService.LoadSidebarWidths(ALeftSidebar,
  ARightSidebar: TControl);
var
  Ini: TIniFile;
  W: Integer;
begin
  if not Assigned(ALeftSidebar) or not Assigned(ARightSidebar) then
    Exit;

  Ini := TIniFile.Create(FSettingsPath);
  try
    W := Ini.ReadInteger('Designer', 'LeftSidebarWidth', ALeftSidebar.Width);
    if W < MinSidebarWidth then W := MinSidebarWidth;
    if W > MaxSidebarWidth then W := MaxSidebarWidth;
    ALeftSidebar.Width := W;

    W := Ini.ReadInteger('Designer', 'RightSidebarWidth', ARightSidebar.Width);
    if W < MinSidebarWidth then W := MinSidebarWidth;
    if W > MaxSidebarWidth then W := MaxSidebarWidth;
    ARightSidebar.Width := W;
  finally
    Ini.Free;
  end;
end;

procedure TDesignerPreferencesService.SaveSidebarWidths(ALeftSidebar,
  ARightSidebar: TControl);
var
  Ini: TIniFile;
begin
  if not Assigned(ALeftSidebar) or not Assigned(ARightSidebar) then
    Exit;

  Ini := TIniFile.Create(FSettingsPath);
  try
    Ini.WriteInteger('Designer', 'LeftSidebarWidth', ALeftSidebar.Width);
    Ini.WriteInteger('Designer', 'RightSidebarWidth', ARightSidebar.Width);
  finally
    Ini.Free;
  end;
end;

procedure TDesignerPreferencesService.LoadSidebarSectionHeights(AObjects,
  ADataSections, AFields: TControl);
var
  Ini: TIniFile;
  H: Integer;

  procedure LoadHeight(AControl: TControl; const AName: string);
  begin
    H := Ini.ReadInteger('Designer', AName, AControl.Height);
    if H < MinSidebarSectionHeight then H := MinSidebarSectionHeight;
    if H > MaxSidebarSectionHeight then H := MaxSidebarSectionHeight;
    AControl.Height := H;
  end;
begin
  if not Assigned(AObjects) or not Assigned(ADataSections) or
     not Assigned(AFields) then
    Exit;

  Ini := TIniFile.Create(FSettingsPath);
  try
    LoadHeight(AObjects, 'ObjectsPanelHeight');
    LoadHeight(ADataSections, 'DataSectionsPanelHeight');
    LoadHeight(AFields, 'FieldsPanelHeight');
  finally
    Ini.Free;
  end;
end;

procedure TDesignerPreferencesService.SaveSidebarSectionHeights(AObjects,
  ADataSections, AFields: TControl);
var
  Ini: TIniFile;
begin
  if not Assigned(AObjects) or not Assigned(ADataSections) or
     not Assigned(AFields) then
    Exit;

  Ini := TIniFile.Create(FSettingsPath);
  try
    Ini.WriteInteger('Designer', 'ObjectsPanelHeight', AObjects.Height);
    Ini.WriteInteger('Designer', 'DataSectionsPanelHeight', ADataSections.Height);
    Ini.WriteInteger('Designer', 'FieldsPanelHeight', AFields.Height);
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
