unit Frm.CommandPalette;

interface

uses
  System.Classes,
  Vcl.Forms,
  Vcl.Menus;

{ Shows a modal, filterable command palette built from the leaf items of
  AMainMenu. Type to filter, Up/Down to move, Enter to run, Esc to dismiss.
  Returns True when a command was executed.

  Note: the menu tree is the designer's command surface. TCommandDispatcher is
  about undoable model actions rather than UI commands, so it is not used here. }
function ShowCommandPalette(AOwner: TComponent; AMainMenu: TMainMenu): Boolean;

implementation

uses
  System.SysUtils,
  System.Types,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.StdCtrls;

type
  TCommandPaletteForm = class(TForm)
  private
    FEdit: TEdit;
    FList: TListBox;
    FAll: TStringList;
    FChosen: TMenuItem;
    procedure ApplyFilter;
    procedure ChooseSelected;
    procedure EditChanged(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ListDblClick(Sender: TObject);
  public
    constructor CreateNew(AOwner: TComponent; ADummy: Integer = 0); reintroduce;
    destructor Destroy; override;

    procedure BuildUI;
    property Chosen: TMenuItem read FChosen;
  end;

{ Fills ADest with "Menu > Item" entries; each entry's object is the menu item. }
procedure CollectMenuItems(AItem: TMenuItem; const APrefix: string;
  ADest: TStrings);
var
  I: Integer;
  Item: TMenuItem;
  Caption, Path: string;
begin
  if not Assigned(AItem) then
    Exit;

  for I := 0 to AItem.Count - 1 do
  begin
    Item := AItem.Items[I];
    Caption := StringReplace(Item.Caption, '&', '', [rfReplaceAll]);
    if (Caption = '') or (Caption = '-') then
      Continue;

    Path := APrefix + Caption;
    if Item.Count > 0 then
      CollectMenuItems(Item, Path + ' > ', ADest)
    else if Assigned(Item.OnClick) and Item.Enabled then
    begin
      if Item.ShortCut <> 0 then
        Path := Path + '    (' + ShortCutToText(Item.ShortCut) + ')';
      ADest.AddObject(Path, Item);
    end;
  end;
end;

{ TCommandPaletteForm }

constructor TCommandPaletteForm.CreateNew(AOwner: TComponent; ADummy: Integer);
begin
  inherited CreateNew(AOwner, ADummy);
  FAll := TStringList.Create;
end;

destructor TCommandPaletteForm.Destroy;
begin
  FAll.Free;
  inherited;
end;

procedure TCommandPaletteForm.BuildUI;
begin
  Caption := 'Command Palette';
  BorderStyle := bsSizeToolWin;
  Position := poOwnerFormCenter;
  ClientWidth := 560;
  ClientHeight := 400;
  KeyPreview := True;
  OnKeyDown := FormKeyDown;

  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.Align := alTop;
  FEdit.TextHint := 'Type a command, then press Enter';
  FEdit.OnChange := EditChanged;
  FEdit.OnKeyDown := EditKeyDown;

  FList := TListBox.Create(Self);
  FList.Parent := Self;
  FList.Align := alClient;
  FList.OnDblClick := ListDblClick;
end;

procedure TCommandPaletteForm.ApplyFilter;
var
  I: Integer;
  Needle: string;
begin
  Needle := UpperCase(Trim(FEdit.Text));
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    for I := 0 to FAll.Count - 1 do
      if (Needle = '') or (Pos(Needle, UpperCase(FAll[I])) > 0) then
        FList.Items.AddObject(FAll[I], FAll.Objects[I]);

    if FList.Items.Count > 0 then
      FList.ItemIndex := 0
    else
      FList.ItemIndex := -1;
  finally
    FList.Items.EndUpdate;
  end;
end;

procedure TCommandPaletteForm.ChooseSelected;
var
  Item: TMenuItem;
begin
  if (FList.ItemIndex < 0) or (FList.ItemIndex >= FList.Items.Count) then
    Exit;

  Item := TMenuItem(FList.Items.Objects[FList.ItemIndex]);
  if Assigned(Item) and Item.Enabled then
    FChosen := Item;

  ModalResult := mrOk;
end;

procedure TCommandPaletteForm.EditChanged(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TCommandPaletteForm.EditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  // Up/Down move the highlight while the caret stays in the edit box.
  case Key of
    VK_DOWN:
      begin
        if FList.ItemIndex < FList.Items.Count - 1 then
          FList.ItemIndex := FList.ItemIndex + 1;
        Key := 0;
      end;
    VK_UP:
      begin
        if FList.ItemIndex > 0 then
          FList.ItemIndex := FList.ItemIndex - 1;
        Key := 0;
      end;
  end;
end;

procedure TCommandPaletteForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_RETURN:
      begin
        ChooseSelected;
        Key := 0;
      end;
    VK_ESCAPE:
      begin
        FChosen := nil;
        ModalResult := mrCancel;
        Key := 0;
      end;
  end;
end;

procedure TCommandPaletteForm.ListDblClick(Sender: TObject);
begin
  ChooseSelected;
end;

function ShowCommandPalette(AOwner: TComponent; AMainMenu: TMainMenu): Boolean;
var
  Form: TCommandPaletteForm;
begin
  Result := False;
  if not Assigned(AMainMenu) then
    Exit;

  Form := TCommandPaletteForm.CreateNew(AOwner);
  try
    CollectMenuItems(AMainMenu.Items, '', Form.FAll);
    if Form.FAll.Count = 0 then
      Exit;

    Form.BuildUI;
    Form.ApplyFilter;
    // Focus the filter box once the form is active (SetFocus would fail here,
    // before the form is visible).
    Form.ActiveControl := Form.FEdit;

    Form.ShowModal;

    // Run the command after the palette is gone, so any dialog it opens nests
    // under the main window rather than under the palette.
    if Assigned(Form.Chosen) and Form.Chosen.Enabled then
    begin
      Form.Chosen.Click;
      Result := True;
    end;
  finally
    Form.Free;
  end;
end;

end.
