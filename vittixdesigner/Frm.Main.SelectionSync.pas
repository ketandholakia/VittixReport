unit Frm.Main.SelectionSync;

interface

uses
  System.Classes,
  System.Types,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.Forms,
  Vittix.Report.DesignerControl,
  Vittix.Report.Objects;

procedure SyncReportStructureSelection(
  ATree: TTreeView;
  ATarget: TReportObject;
  var AUpdatingStructureSelection: Boolean);

procedure StructureTreeChange(
  ATree: TTreeView;
  ADesigner: TVittixReportDesigner;
  AUpdatingStructureSelection: Boolean;
  Sender: TObject;
  Node: TTreeNode);

procedure StructureTreeDblClick(
  ATree: TTreeView;
  ADesigner: TVittixReportDesigner);

{ Scrolls the scroll box hosting ADesigner so that AObj is inside the viewport. }
procedure ScrollObjectIntoView(
  ADesigner: TVittixReportDesigner;
  AObj: TReportObject);

procedure StructureTreeMouseDown(
  ATree: TTreeView;
  Button: TMouseButton;
  X, Y: Integer);

implementation

uses
  System.SysUtils;

function FindNodeByData(ATree: TTreeView; AData: Pointer): TTreeNode;
var
  Node: TTreeNode;
begin
  Result := nil;
  if not Assigned(ATree) then
    Exit;

  Node := ATree.Items.GetFirstNode;
  while Assigned(Node) do
  begin
    if Node.Data = AData then
      Exit(Node);
    Node := Node.GetNext;
  end;
end;

procedure SyncReportStructureSelection(
  ATree: TTreeView;
  ATarget: TReportObject;
  var AUpdatingStructureSelection: Boolean);
var
  Node: TTreeNode;
begin
  if not Assigned(ATree) or (ATree.Items.Count = 0) then
    Exit;

  if Assigned(ATarget) then
    Node := FindNodeByData(ATree, ATarget)
  else
    Node := ATree.Items.GetFirstNode;

  if Assigned(Node) then
  begin
    AUpdatingStructureSelection := True;
    try
      ATree.Selected := Node;
      Node.MakeVisible;
    finally
      AUpdatingStructureSelection := False;
    end;
  end;
end;

procedure StructureTreeChange(
  ATree: TTreeView;
  ADesigner: TVittixReportDesigner;
  AUpdatingStructureSelection: Boolean;
  Sender: TObject;
  Node: TTreeNode);
begin
  if AUpdatingStructureSelection or not Assigned(ADesigner) then
    Exit;

  if not Assigned(Node) or not Assigned(Node.Data) then
    ADesigner.SelectObject(nil)
  else
    ADesigner.SelectObject(TReportObject(Node.Data));
end;

procedure StructureTreeDblClick(
  ATree: TTreeView;
  ADesigner: TVittixReportDesigner);
var
  Node: TTreeNode;
  Target: TReportObject;
begin
  if not Assigned(ATree) or not Assigned(ADesigner) then
    Exit;

  Node := ATree.Selected;
  if not Assigned(Node) then
    Exit;

  Target := nil;
  if Assigned(Node.Data) then
    Target := TReportObject(Node.Data);

  if Assigned(Target) then
    ADesigner.SelectObject(Target);

  if Assigned(ADesigner.Parent) and ADesigner.Parent.CanFocus then
    ADesigner.Parent.SetFocus
  else if ADesigner.CanFocus then
    ADesigner.SetFocus;

  ScrollObjectIntoView(ADesigner, Target);
  ADesigner.Invalidate;
end;

procedure ScrollObjectIntoView(
  ADesigner: TVittixReportDesigner;
  AObj: TReportObject);
const
  MARGIN = 24;
var
  SB: TScrollBox;
  R: TRect;
  VisibleL, VisibleT, VisibleR, VisibleB, DX, DY: Integer;
begin
  if not Assigned(ADesigner) or not Assigned(AObj) then
    Exit;
  if not (ADesigner.Parent is TScrollBox) then
    Exit;

  R := ADesigner.ObjectClientRect(AObj);
  if IsRectEmpty(R) then
    Exit;

  SB := TScrollBox(ADesigner.Parent);
  VisibleL := SB.HorzScrollBar.Position;
  VisibleT := SB.VertScrollBar.Position;
  VisibleR := VisibleL + SB.ClientWidth;
  VisibleB := VisibleT + SB.ClientHeight;

  DX := 0;
  DY := 0;
  if R.Left < VisibleL + MARGIN then
    DX := R.Left - MARGIN - VisibleL
  else if R.Right > VisibleR - MARGIN then
    DX := R.Right + MARGIN - VisibleR;

  if R.Top < VisibleT + MARGIN then
    DY := R.Top - MARGIN - VisibleT
  else if R.Bottom > VisibleB - MARGIN then
    DY := R.Bottom + MARGIN - VisibleB;

  if DX <> 0 then
    SB.HorzScrollBar.Position := SB.HorzScrollBar.Position + DX;
  if DY <> 0 then
    SB.VertScrollBar.Position := SB.VertScrollBar.Position + DY;
end;

procedure StructureTreeMouseDown(
  ATree: TTreeView;
  Button: TMouseButton;
  X, Y: Integer);
var
  Node: TTreeNode;
begin
  if (Button <> mbRight) or not Assigned(ATree) then
    Exit;

  Node := ATree.GetNodeAt(X, Y);
  if Assigned(Node) then
    ATree.Selected := Node
  else
    ATree.Selected := nil;
end;

end.
