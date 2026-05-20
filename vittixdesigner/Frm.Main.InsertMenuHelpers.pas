unit Frm.Main.InsertMenuHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.Menus,
  Vittix.Report.Objects,
  Vittix.Report.Bands;

procedure BuildInsertMenu(
  AInsertMenu: TMenuItem;
  ASeparator: TMenuItem;
  AStructureTreeAddBandItem: TMenuItem;
  AStructureTreeAddObjectItem: TMenuItem;
  AInsertBandClick: TNotifyEvent;
  AInsertObjectClick: TNotifyEvent;
  AGetRegisteredReportObjects: TFunc<TArray<TReportObjectClass>>;
  ABandTypeName: TFunc<TReportBandType, string>);

implementation

procedure BuildInsertMenu(
  AInsertMenu: TMenuItem;
  ASeparator: TMenuItem;
  AStructureTreeAddBandItem: TMenuItem;
  AStructureTreeAddObjectItem: TMenuItem;
  AInsertBandClick: TNotifyEvent;
  AInsertObjectClick: TNotifyEvent;
  AGetRegisteredReportObjects: TFunc<TArray<TReportObjectClass>>;
  ABandTypeName: TFunc<TReportBandType, string>);
var
  C, ExistingClass: TReportObjectClass;
  MI, TreeMI: TMenuItem;
  I: Integer;
  BT: TReportBandType;
  Exists: Boolean;
  Registered: TArray<TReportObjectClass>;
begin
  if not Assigned(AInsertMenu) then
    Exit;

  for I := AInsertMenu.Count - 1 downto 0 do
    if SameText(AInsertMenu.Items[I].Hint, 'dynobj') or
       SameText(AInsertMenu.Items[I].Hint, 'dynband') then
      AInsertMenu.Delete(I);

  if Assigned(AStructureTreeAddBandItem) then
  begin
    AStructureTreeAddBandItem.Clear;
    for BT := Low(TReportBandType) to High(TReportBandType) do
    begin
      TreeMI := TMenuItem.Create(AStructureTreeAddBandItem);
      TreeMI.Caption := ABandTypeName(BT);
      TreeMI.Tag := Ord(BT);
      TreeMI.OnClick := AInsertBandClick;
      AStructureTreeAddBandItem.Add(TreeMI);
    end;
  end;

  for BT := Low(TReportBandType) to High(TReportBandType) do
  begin
    if BT in [btReportTitle, btPageHeader, btMasterData, btPageFooter, btReportSummary] then
      Continue;

    Exists := False;
    for I := 0 to AInsertMenu.Count - 1 do
      if SameText(AInsertMenu.Items[I].Caption, 'Band: ' + ABandTypeName(BT)) then
      begin
        Exists := True;
        Break;
      end;

    if not Exists then
    begin
      MI := TMenuItem.Create(AInsertMenu);
      MI.Caption := 'Band: ' + ABandTypeName(BT);
      MI.Tag := Ord(BT);
      MI.Hint := 'dynband';
      MI.OnClick := AInsertBandClick;
      if Assigned(ASeparator) then
        AInsertMenu.Insert(AInsertMenu.IndexOf(ASeparator), MI)
      else
        AInsertMenu.Add(MI);
    end;
  end;

  if Assigned(AStructureTreeAddObjectItem) then
    AStructureTreeAddObjectItem.Clear;

  Registered := [];
  if Assigned(AGetRegisteredReportObjects) then
    Registered := AGetRegisteredReportObjects();

  for C in Registered do
  begin
    if C.InheritsFrom(TReportBand) then
      Continue;

    Exists := False;
    for I := 0 to AInsertMenu.Count - 1 do
      if SameText(AInsertMenu.Items[I].Hint, 'dynobj') then
      begin
        ExistingClass := TReportObjectClass(AInsertMenu.Items[I].Tag);
        if Assigned(ExistingClass) and SameText(ExistingClass.DisplayName, C.DisplayName) then
        begin
          Exists := True;
          Break;
        end;
      end;
    if Exists then
      Continue;

    MI := TMenuItem.Create(AInsertMenu);
    MI.Caption := 'Insert ' + C.DisplayName;
    MI.Tag := NativeInt(C);
    MI.Hint := 'dynobj';
    MI.OnClick := AInsertObjectClick;
    AInsertMenu.Add(MI);

    if Assigned(AStructureTreeAddObjectItem) then
    begin
      TreeMI := TMenuItem.Create(AStructureTreeAddObjectItem);
      TreeMI.Caption := C.DisplayName;
      TreeMI.Tag := NativeInt(C);
      TreeMI.OnClick := AInsertObjectClick;
      AStructureTreeAddObjectItem.Add(TreeMI);
    end;
  end;
end;

end.
