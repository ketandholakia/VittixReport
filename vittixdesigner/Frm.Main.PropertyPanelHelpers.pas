unit Frm.Main.PropertyPanelHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  Vcl.ValEdit,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.Objects.Barcode,
  Vittix.Report.DesignerControl,
  Frm.Main.PropertyHelpers;

function PropertyHintText(AObj: TReportObject; const AKey: string): string;
procedure PromoteImportantProperties(APropEditor: TValueListEditor; AObj: TReportObject);
procedure InsertVisualGroupRows(APropEditor: TValueListEditor; AObj: TReportObject);
procedure UpdatePropertyPanelHintForRow(APropEditor: TValueListEditor; AStatusBar: TStatusBar; ARow: Integer; AObj: TReportObject);
procedure UpdatePropertyPanelHeader(ADesigner: TVittixReportDesigner; ALabel: TLabel; AObj: TReportObject);

implementation

function PropertyHintText(AObj: TReportObject; const AKey: string): string;
begin
  if SameText(AKey, 'Name') then
    Exit('Object name used by expressions and references')
  else if SameText(AKey, 'Left') or SameText(AKey, 'Top') or
          SameText(AKey, 'Width') or SameText(AKey, 'Height') then
    Exit('Object bounds in pixels on the designer')
  else if SameText(AKey, 'DataField') then
    Exit('Dataset field to bind this object to')
  else if SameText(AKey, 'Expression') then
    Exit('Expression evaluated at runtime for value/output')
  else if SameText(AKey, 'DisplayFormat') then
    Exit('Formatting pattern for field values')
  else if SameText(AKey, 'EditMask') then
    Exit('Input/output mask for field values')
  else if SameText(AKey, 'PrintWhen') then
    Exit('Condition that controls whether object/band prints')
  else if SameText(AKey, 'PageBreakBefore') then
    Exit('Start a new page before the owning band is printed')
  else if SameText(AKey, 'PageBreakAfter') then
    Exit('Start a new page after the owning band is printed')
  else if SameText(AKey, 'FontColor') then
    Exit('Text color')
  else if SameText(AKey, 'BackgroundColor') then
    Exit('Background fill color')
  else if SameText(AKey, 'BorderColor') then
    Exit('Border line color')
  else if SameText(AKey, 'CanGrow') then
    Exit('Allow control height to increase for long content')
  else if SameText(AKey, 'CanShrink') then
    Exit('Allow control height to shrink when content is empty')
  else if SameText(AKey, 'GroupField') then
    Exit('Field used for grouping band sections')
  else if SameText(AKey, 'OnBeforePrint') then
  begin
    if Assigned(AObj) and not (AObj is TReportBand) then
      Exit('Persisted object script text stored with this object and passed to the host script callback.');
    Exit('Persisted band script hook executed before the band prints. Different from runtime Delphi callbacks.');
  end
  else if SameText(AKey, 'OnAfterPrint') then
  begin
    if Assigned(AObj) and not (AObj is TReportBand) then
      Exit('Persisted object script text stored with this object and passed to the host script callback.');
    Exit('Persisted band script hook executed after the band prints. Different from runtime Delphi callbacks.');
  end;
  Result := '';
end;

procedure UpdatePropertyPanelHintForRow(APropEditor: TValueListEditor; AStatusBar: TStatusBar; ARow: Integer; AObj: TReportObject);
var
  KeyName: string;
  HintText: string;
begin
  if (ARow <= 0) or (ARow >= APropEditor.RowCount) then
  begin
    if Assigned(AStatusBar) and (AStatusBar.Panels.Count > 1) then
      AStatusBar.Panels[1].Text := '';
    Exit;
  end;

  KeyName := Trim(APropEditor.Keys[ARow]);
  if (Length(KeyName) >= 3) and (KeyName[1] = '[') and (KeyName[Length(KeyName)] = ']') then
    HintText := ''
  else
    HintText := PropertyHintText(AObj, KeyName);

  if (HintText = '') and (KeyName <> '') and not ((Length(KeyName) >= 3) and (KeyName[1] = '[') and (KeyName[Length(KeyName)] = ']')) then
    HintText := KeyName;

  if Assigned(AStatusBar) and (AStatusBar.Panels.Count > 1) then
    AStatusBar.Panels[1].Text := HintText;
end;

procedure PromoteImportantProperties(APropEditor: TValueListEditor; AObj: TReportObject);
const
  BandKeys: array[0..14] of string = (
    'BandType', 'Height', 'DataSetName', 'GroupField', 'GroupLevel',
    'CanGrow', 'CanShrink', 'StartNewPage', 'Visible', 'PrintWhen',
    'BackColor', 'BackColorTransparent', 'BackColorCondition',
    'OnBeforePrint', 'OnAfterPrint'
  );
  TextKeys: array[0..24] of string = (
    'Text', 'DataField', 'Expression', 'DisplayFormat', 'EditMask',
    'Bounds', 'Left', 'Top', 'Width', 'Height',
    'FontName', 'FontSize', 'FontBold', 'FontItalic', 'FontColor',
    'WordWrap', 'AutoSize', 'Transparent', 'Background',
    'BorderVisible', 'BorderColor', 'BorderWidth', 'PrintWhen',
    'PageBreakBefore', 'PageBreakAfter'
  );
  ImageKeys: array[0..16] of string = (
    'DataField', 'ImagePath', 'Picture', 'Stretch', 'Proportional', 'Center',
    'Bounds', 'Left', 'Top', 'Width', 'Height',
    'BorderVisible', 'BorderColor', 'Visible', 'PrintWhen',
    'PageBreakBefore', 'PageBreakAfter'
  );
  BarcodeKeys: array[0..14] of string = (
    'Value', 'DataField', 'Symbology', 'BarcodeType', 'ShowText',
    'Bounds', 'Left', 'Top', 'Width', 'Height', 'Visible', 'PrintWhen',
    'PageBreakBefore', 'PageBreakAfter', 'BarColor'
  );
var
  Keys: TArray<string>;
  I, Idx: Integer;
  K, Val: string;
  procedure AddKeys(const AKeys: array of string);
  var
    J: Integer;
  begin
    for J := Low(AKeys) to High(AKeys) do
    begin
      SetLength(Keys, Length(Keys) + 1);
      Keys[High(Keys)] := AKeys[J];
    end;
  end;
begin
  if (not Assigned(APropEditor)) or (APropEditor.RowCount <= 1) then Exit;
  Keys := nil;
  if AObj is TReportBand then
    AddKeys(BandKeys)
  else if (AObj is TReportTextObject) or (AObj is TReportFieldObject) or (AObj is TReportMemoObject) then
    AddKeys(TextKeys)
  else if AObj is TReportImageObject then
    AddKeys(ImageKeys)
  else if AObj is TReportBarcodeObject then
    AddKeys(BarcodeKeys)
  else
    AddKeys(['Bounds', 'Left', 'Top', 'Width', 'Height', 'Visible', 'PrintWhen']);

  for I := High(Keys) downto Low(Keys) do
  begin
    K := Keys[I];
    Idx := APropEditor.Strings.IndexOfName(K);
    if Idx > 0 then
    begin
      Val := APropEditor.Values[K];
      APropEditor.Strings.Delete(Idx);
      APropEditor.Strings.Insert(1, K + '=' + Val);
    end;
  end;
end;

procedure InsertVisualGroupRows(APropEditor: TValueListEditor; AObj: TReportObject);
var
  I: Integer;
  procedure InsertGroupAt(const GroupName: string; AIndex: Integer);
  var
    GroupKey: string;
  begin
    GroupKey := '[' + GroupName + ']';
    if APropEditor.Strings.IndexOfName(GroupKey) >= 0 then
      Exit;
    if AIndex < 1 then
      AIndex := 1;
    if AIndex > APropEditor.RowCount then
      AIndex := APropEditor.RowCount;
    APropEditor.Strings.Insert(AIndex, GroupKey + '=');
  end;

  function FindFirstExistingIndex(const KeyNames: array of string): Integer;
  var
    J, Idx: Integer;
  begin
    Result := -1;
    for J := Low(KeyNames) to High(KeyNames) do
    begin
      Idx := APropEditor.Strings.IndexOfName(KeyNames[J]);
      if Idx > 0 then
      begin
        Result := Idx;
        Exit;
      end;
    end;
  end;
begin
  if not Assigned(APropEditor) then
    Exit;

  if not Assigned(AObj) then
    Exit;

  for I := APropEditor.RowCount - 1 downto 0 do
    if IsVisualGroupRow(APropEditor.Keys[I]) then
      APropEditor.Strings.Delete(I);

  InsertGroupAt('Common', FindFirstExistingIndex(['Visible', 'Name', 'PrintWhen', 'Bounds']));
  InsertGroupAt('Layout', FindFirstExistingIndex(['Bounds', 'Left', 'Top', 'Width', 'Height']));
  InsertGroupAt('Data', FindFirstExistingIndex(['DataField', 'DataSetName', 'Expression', 'Value']));
  InsertGroupAt('Appearance', FindFirstExistingIndex(['Transparent', 'Background', 'BackColor', 'BrushColor']));
  InsertGroupAt('Font', FindFirstExistingIndex(['FontName', 'FontSize', 'FontBold', 'Font']));
  InsertGroupAt('Border', FindFirstExistingIndex(['BorderVisible', 'BorderColor', 'BorderWidth', 'PenColor']));
  InsertGroupAt('Behavior', FindFirstExistingIndex(['PrintWhen', 'CanGrow', 'CanShrink', 'StartNewPage']));
  if FindFirstExistingIndex(['OnBeforePrint', 'OnAfterPrint']) > 0 then
    InsertGroupAt('Events', FindFirstExistingIndex(['OnBeforePrint', 'OnAfterPrint']));

  if AObj is TReportBand then
  begin
    if APropEditor.Strings.IndexOfName('[Data]') < 0 then
      InsertGroupAt('Data', FindFirstExistingIndex(['DataSetName', 'GroupField', 'GroupLevel']));
    if APropEditor.Strings.IndexOfName('[Behavior]') < 0 then
      InsertGroupAt('Behavior', FindFirstExistingIndex(['CanGrow', 'CanShrink', 'StartNewPage']));
  end;
end;

function BandTypeName(ABandType: TReportBandType): string;
begin
  case ABandType of
    btReportTitle:   Result := 'Report Title';
    btPageHeader:    Result := 'Page Header';
    btMasterData:    Result := 'Master Data';
    btPageFooter:    Result := 'Page Footer';
    btReportSummary: Result := 'Summary';
    btGroupHeader:   Result := 'Group Header';
    btGroupFooter:   Result := 'Group Footer';
    btColumnHeader:  Result := 'Column Header';
    btDetail:        Result := 'Detail';
    btOverlay:       Result := 'Overlay';
  else
    Result := 'Band';
  end;
end;

procedure UpdatePropertyPanelHeader(ADesigner: TVittixReportDesigner; ALabel: TLabel; AObj: TReportObject);
var
  SelCount: Integer;
  Band: TReportBand;
  ObjName: string;
begin
  if not Assigned(ALabel) then
    Exit;

  SelCount := 0;
  if Assigned(ADesigner) then
    SelCount := ADesigner.SelectedCount;

  if SelCount > 1 then
    ALabel.Caption := Format('Selected: %d Objects', [SelCount])
  else if Assigned(AObj) and (AObj is TReportBand) then
  begin
    Band := TReportBand(AObj);
    if Trim(Band.Name) <> '' then
      ALabel.Caption := 'Selected: ' + BandTypeName(Band.BandType) + ' Band (' + Band.Name + ')'
    else
      ALabel.Caption := 'Selected: ' + BandTypeName(Band.BandType) + ' Band';
  end
  else if Assigned(AObj) then
  begin
    ObjName := Trim(AObj.Name);
    if ObjName <> '' then
      ALabel.Caption := 'Selected: ' + AObj.ClassName + ' (' + ObjName + ')'
    else
      ALabel.Caption := 'Selected: ' + AObj.ClassName;
  end
  else
    ALabel.Caption := 'Selected: None';
end;

end.
