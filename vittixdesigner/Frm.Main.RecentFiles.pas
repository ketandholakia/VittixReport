unit Frm.Main.RecentFiles;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Menus;

procedure BuildRecentFilesMenu(
  AMainMenu, AOpenMenu, ASaveMenu: TMenuItem;
  ARecentFiles: TList<string>;
  AOpenRecentFile: TNotifyEvent;
  AClearRecentFiles: TNotifyEvent);

implementation

procedure BuildRecentFilesMenu(
  AMainMenu, AOpenMenu, ASaveMenu: TMenuItem;
  ARecentFiles: TList<string>;
  AOpenRecentFile: TNotifyEvent;
  AClearRecentFiles: TNotifyEvent);
var
  RecentMI, ClearMI, Sep, MI: TMenuItem;
  I: Integer;

  function FindRecentMenu: TMenuItem;
  var
    J: Integer;
  begin
    Result := nil;
    if not Assigned(AMainMenu) then
      Exit;
    for J := 0 to AMainMenu.Count - 1 do
      if SameText(AMainMenu.Items[J].Caption, 'Recent &Files') then
        Exit(AMainMenu.Items[J]);
  end;

begin
  if not Assigned(AMainMenu) or not Assigned(AOpenMenu) or not Assigned(ASaveMenu) then
    Exit;

  RecentMI := FindRecentMenu;
  if not Assigned(RecentMI) then
  begin
    RecentMI := TMenuItem.Create(AMainMenu);
    RecentMI.Caption := 'Recent &Files';
    Sep := TMenuItem.Create(AMainMenu);
    Sep.Caption := '-';
    AMainMenu.Insert(AMainMenu.IndexOf(ASaveMenu), Sep);
    AMainMenu.Insert(AMainMenu.IndexOf(Sep), RecentMI);
  end;

  while RecentMI.Count > 0 do
    RecentMI.Delete(0);

  if Assigned(ARecentFiles) and (ARecentFiles.Count > 0) then
  begin
    for I := 0 to ARecentFiles.Count - 1 do
    begin
      MI := TMenuItem.Create(RecentMI);
      MI.Caption := Format('&%d %s', [I + 1, ExtractFileName(ARecentFiles[I])]);
      MI.Hint := ARecentFiles[I];
      MI.Tag := I;
      MI.OnClick := AOpenRecentFile;
      RecentMI.Add(MI);
    end;
  end
  else
  begin
    MI := TMenuItem.Create(RecentMI);
    MI.Caption := '(Empty)';
    MI.Enabled := False;
    RecentMI.Add(MI);
  end;

  ClearMI := TMenuItem.Create(RecentMI);
  ClearMI.Caption := 'Clear Recent Files';
  ClearMI.OnClick := AClearRecentFiles;
  RecentMI.Add(ClearMI);
end;

end.
