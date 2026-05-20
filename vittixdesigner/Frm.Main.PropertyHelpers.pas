unit Frm.Main.PropertyHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vcl.StdCtrls;

function IsVisualGroupRow(const AKey: string): Boolean;
function IsFontDialogRowKey(const AKey: string): Boolean;
function IsColorPropertyKey(const AKey: string): Boolean;
function IsExpressionPropertyKey(const AKey: string): Boolean;
function IsBandEventScriptRowKey(const AKey: string): Boolean;
function ExpressionHelperBucketKey(const APropertyKey: string): string;
function ExpressionHelperRecentList(
  var AStore: TObjectDictionary<string, TStringList>;
  const APropertyKey: string; ACreate: Boolean): TStringList;
procedure ExpressionHelperAddRecent(
  var AStore: TObjectDictionary<string, TStringList>;
  const APropertyKey, AExpr: string);
function ExpressionHelperIsRecentHintItem(const AValue: string): Boolean;

implementation

function IsVisualGroupRow(const AKey: string): Boolean;
begin
  Result := (Length(AKey) >= 3) and (AKey[1] = '[') and (AKey[Length(AKey)] = ']');
end;

function IsFontDialogRowKey(const AKey: string): Boolean;
begin
  Result := SameText(AKey, 'Font') or SameText(AKey, 'FontName') or
    SameText(AKey, 'FontSize') or SameText(AKey, 'FontBold') or
    SameText(AKey, 'FontItalic') or SameText(AKey, 'FontColor');
end;

function IsColorPropertyKey(const AKey: string): Boolean;
begin
  Result := SameText(AKey, 'FontColor') or SameText(AKey, 'Background') or
    SameText(AKey, 'BorderColor') or SameText(AKey, 'BackColor') or
    SameText(AKey, 'BackgroundOnTrue') or SameText(AKey, 'BorderColorOnTrue') or
    SameText(AKey, 'FontColorOnTrue');
end;

function IsExpressionPropertyKey(const AKey: string): Boolean;
begin
  Result := SameText(AKey, 'Expression') or SameText(AKey, 'PrintWhen') or
    SameText(AKey, 'FontColorCondition') or SameText(AKey, 'BackgroundCondition') or
    SameText(AKey, 'BorderColorCondition');
end;

function IsBandEventScriptRowKey(const AKey: string): Boolean;
begin
  Result := SameText(AKey, 'OnBeforePrint') or SameText(AKey, 'OnAfterPrint');
end;

function ExpressionHelperBucketKey(const APropertyKey: string): string;
begin
  if SameText(APropertyKey, 'Expression') then Exit('expression');
  if SameText(APropertyKey, 'PrintWhen') then Exit('printwhen');
  if SameText(APropertyKey, 'BackgroundCondition') then Exit('backgroundcondition');
  if SameText(APropertyKey, 'FontColorCondition') then Exit('fontcolorcondition');
  if SameText(APropertyKey, 'BorderColorCondition') then Exit('bordercolorcondition');
  Result := '';
end;

function ExpressionHelperRecentList(
  var AStore: TObjectDictionary<string, TStringList>;
  const APropertyKey: string; ACreate: Boolean): TStringList;
var
  Key: string;
begin
  Result := nil;
  Key := ExpressionHelperBucketKey(APropertyKey);
  if Key = '' then Exit;
  if not Assigned(AStore) then
  begin
    if not ACreate then Exit;
    AStore := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  end;
  if not AStore.TryGetValue(Key, Result) and ACreate then
  begin
    Result := TStringList.Create;
    AStore.Add(Key, Result);
  end;
end;

procedure ExpressionHelperAddRecent(
  var AStore: TObjectDictionary<string, TStringList>;
  const APropertyKey, AExpr: string);
const
  CMaxRecentItems = 20;
var
  ExprText: string;
  Recent: TStringList;
  I: Integer;
begin
  ExprText := Trim(AExpr);
  if ExprText = '' then Exit;
  if ExpressionHelperIsRecentHintItem(ExprText) then Exit;
  Recent := ExpressionHelperRecentList(AStore, APropertyKey, True);
  if not Assigned(Recent) then Exit;
  for I := Recent.Count - 1 downto 0 do
    if SameText(Trim(Recent[I]), ExprText) then
      Recent.Delete(I);
  Recent.Insert(0, ExprText);
  while Recent.Count > CMaxRecentItems do
    Recent.Delete(Recent.Count - 1);
end;

function ExpressionHelperIsRecentHintItem(const AValue: string): Boolean;
begin
  Result := SameText(Trim(AValue), 'No recent expressions (session only)');
end;

end.
