unit Frm.Main.TemplateMenu;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Menus;

{ Resolves the folder the report templates are loaded from. Probes the same
  locations the sample/regression reports use, so a deployed build and a source
  checkout both work. Returns '' when no folder with .vrt files is found. }
function ResolveTemplateFolder: string;

{ Builds (or rebuilds) a "New from &Template" submenu on AMainMenu, inserted
  before AAnchorMenu. Each item carries the full path in its Hint and reports
  clicks through AOpenTemplate. }
procedure BuildTemplateMenu(
  AMainMenu, AAnchorMenu: TMenuItem;
  AOpenTemplate: TNotifyEvent);

implementation

uses
  System.IOUtils;

const
  MAX_TEMPLATES = 40;

function FolderHasTemplates(const AFolder: string): Boolean;
begin
  Result := False;
  if (AFolder = '') or not TDirectory.Exists(AFolder) then
    Exit;
  Result := Length(TDirectory.GetFiles(AFolder, '*.vrt')) > 0;
end;

function ResolveTemplateFolder: string;
var
  ExeDir, Cwd: string;
  Candidates: TArray<string>;
  I: Integer;
begin
  ExeDir := ExtractFilePath(ParamStr(0));
  Cwd := GetCurrentDir;

  Candidates := TArray<string>.Create(
    TPath.Combine(ExeDir, 'templates'),
    TPath.GetFullPath(TPath.Combine(ExeDir, '..\templates')),
    TPath.Combine(ExeDir, 'reports'),
    TPath.GetFullPath(TPath.Combine(ExeDir, '..\reports')),
    TPath.GetFullPath(TPath.Combine(ExeDir, '..\demo\vrt')),
    TPath.Combine(Cwd, 'reports'),
    TPath.GetFullPath(TPath.Combine(Cwd, '..\demo\vrt')));

  for I := 0 to High(Candidates) do
    if FolderHasTemplates(Candidates[I]) then
      Exit(Candidates[I]);

  Result := '';
end;

procedure BuildTemplateMenu(
  AMainMenu, AAnchorMenu: TMenuItem;
  AOpenTemplate: TNotifyEvent);
var
  Folder: string;
  Files: TArray<string>;
  Sub, Sep, MI: TMenuItem;
  I: Integer;

  function FindTemplateMenu: TMenuItem;
  var
    J: Integer;
  begin
    Result := nil;
    if not Assigned(AMainMenu) then
      Exit;
    for J := 0 to AMainMenu.Count - 1 do
      if SameText(AMainMenu.Items[J].Caption, 'New from &Template') then
        Exit(AMainMenu.Items[J]);
  end;

begin
  if not Assigned(AMainMenu) or not Assigned(AAnchorMenu) then
    Exit;

  Sub := FindTemplateMenu;
  if not Assigned(Sub) then
  begin
    Sub := TMenuItem.Create(AMainMenu);
    Sub.Caption := 'New from &Template';
    Sep := TMenuItem.Create(AMainMenu);
    Sep.Caption := '-';
    AMainMenu.Insert(AMainMenu.IndexOf(AAnchorMenu), Sub);
    AMainMenu.Insert(AMainMenu.IndexOf(Sub) + 1, Sep);
  end;

  while Sub.Count > 0 do
    Sub.Delete(0);

  Folder := ResolveTemplateFolder;
  if Folder = '' then
  begin
    MI := TMenuItem.Create(Sub);
    MI.Caption := '(No template folder found)';
    MI.Enabled := False;
    Sub.Add(MI);
    Exit;
  end;

  Files := TDirectory.GetFiles(Folder, '*.vrt');
  TArray.Sort<string>(Files);

  for I := 0 to High(Files) do
  begin
    if I >= MAX_TEMPLATES then
      Break;
    MI := TMenuItem.Create(Sub);
    MI.Caption := TPath.GetFileNameWithoutExtension(Files[I]);
    MI.Hint := Files[I];
    MI.OnClick := AOpenTemplate;
    Sub.Add(MI);
  end;

  if Sub.Count = 0 then
  begin
    MI := TMenuItem.Create(Sub);
    MI.Caption := '(No templates)';
    MI.Enabled := False;
    Sub.Add(MI);
  end;
end;

end.
