unit Vittix.Report.Toolbox;

interface

uses
  System.Classes, System.Types, System.UITypes,
  Vcl.Controls,
  Vcl.Graphics, Vcl.ImgList,
  Vcl.StdCtrls,
  Vittix.Report.Objects;

type
  TVittixReportToolbox = class(TListBox)
  private
    FOnToolSelected: TNotifyEvent;
    FSelectedClass: TReportObjectClass;
    FToolImages: TCustomImageList;

    procedure ReloadTools;
    procedure UpdateSelection;
    function ToolImageNameForClass(AClass: TReportObjectClass): string;
    function ToolImageIndexForClass(AClass: TReportObjectClass): Integer;

  protected
    procedure Click; override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;

  public
    constructor Create(AOwner: TComponent); override;

    procedure RefreshToolList;

    property SelectedObjectClass: TReportObjectClass
      read FSelectedClass;
  published
    property TabOrder;
    property ToolImages: TCustomImageList
      read FToolImages write FToolImages;
    property OnToolSelected: TNotifyEvent
      read FOnToolSelected write FOnToolSelected;
  end;

procedure Register;

implementation

uses
  Vittix.Report.Objects.Barcode,
  Vittix.Report.Objects.Table;

{ ================= Constructor ================= }

constructor TVittixReportToolbox.Create(AOwner: TComponent);
begin
  inherited;

  Style := lbOwnerDrawFixed;
  ItemHeight := 24;
  Sorted := False;
end;

{ ================= Load Tools ================= }

procedure TVittixReportToolbox.ReloadTools;
var
  C: TReportObjectClass;
begin
  Items.BeginUpdate;
  try
    Items.Clear;

    for C in GetRegisteredReportObjects do
      Items.AddObject(C.DisplayName, TObject(C));

  finally
    Items.EndUpdate;
  end;

  if Items.Count > 0 then
    ItemIndex := 0;

  UpdateSelection;
end;

procedure TVittixReportToolbox.RefreshToolList;
begin
  ReloadTools;
end;

{ ================= Selection ================= }

procedure TVittixReportToolbox.UpdateSelection;
begin
  if ItemIndex >= 0 then
    FSelectedClass :=
      TReportObjectClass(Items.Objects[ItemIndex])
  else
    FSelectedClass := nil;
end;

procedure TVittixReportToolbox.Click;
begin
  inherited;
  UpdateSelection;
  
  if Assigned(FOnToolSelected) then
    FOnToolSelected(Self);
end;

function TVittixReportToolbox.ToolImageNameForClass(AClass: TReportObjectClass): string;
begin
  if not Assigned(AClass) then
    Exit('description');

  if AClass.InheritsFrom(TReportLabelObject) then
    Exit('label_object');
  if AClass.InheritsFrom(TReportFieldObject) then
    Exit('datafield_object');
  if AClass.InheritsFrom(TReportMemoObject) then
    Exit('memo_object');
  if AClass.InheritsFrom(TReportImageObject) then
    Exit('image_object');
  if AClass.InheritsFrom(TReportBarcodeObject) then
    Exit('barcode_object');
  if AClass.InheritsFrom(TReportShapeObject) then
    Exit('shapes_object');
  if AClass.InheritsFrom(TReportLineObject) then
    Exit('line_object');
  if AClass.InheritsFrom(TReportSubReportObject) then
    Exit('subreport_object');
  if AClass.InheritsFrom(TReportTableObject) then
    Exit('table_object');
  if AClass.InheritsFrom(TReportTextObject) then
    Exit('text_object');

  Result := 'description';
end;

function TVittixReportToolbox.ToolImageIndexForClass(AClass: TReportObjectClass): Integer;
begin
  Result := -1;
  if not Assigned(FToolImages) then
    Exit;

  Result := FToolImages.GetIndexByName(ToolImageNameForClass(AClass));
end;

procedure TVittixReportToolbox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
const
  ICON_MARGIN = 4;
  TEXT_MARGIN = 6;
var
  ToolClass: TReportObjectClass;
  IconIndex: Integer;
  IconSize: Integer;
  TextRect: TRect;
begin
  Canvas.FillRect(Rect);

  if (Index < 0) or (Index >= Items.Count) then
    Exit;

  if Index = ItemIndex then
  begin
    Canvas.Brush.Color := clHighlight;
    Canvas.Font.Color := clHighlightText;
    Canvas.FillRect(Rect);
  end
  else
  begin
    Canvas.Brush.Color := Color;
    Canvas.Font.Color := Font.Color;
    Canvas.FillRect(Rect);
  end;

  ToolClass := TReportObjectClass(Items.Objects[Index]);
  IconIndex := ToolImageIndexForClass(ToolClass);
  TextRect := Rect;

  if Assigned(FToolImages) and (IconIndex >= 0) then
  begin
    IconSize := FToolImages.Height;
    FToolImages.Draw(Canvas,
      Rect.Left + ICON_MARGIN,
      Rect.Top + ((Rect.Height - IconSize) div 2),
      IconIndex, Enabled);
    Inc(TextRect.Left, ICON_MARGIN + FToolImages.Width + TEXT_MARGIN);
  end
  else
    Inc(TextRect.Left, ICON_MARGIN);

  Canvas.TextRect(TextRect,
    TextRect.Left,
    TextRect.Top + ((TextRect.Height - Canvas.TextHeight(Items[Index])) div 2),
    Items[Index]);

  if Focused and (Index = ItemIndex) then
    Canvas.DrawFocusRect(Rect);
end;

{ ================= Register ================= }

procedure Register;
begin
  RegisterComponents('Vittix Reporting', [TVittixReportToolbox]);
end;

end.
