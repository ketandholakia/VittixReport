unit Frm.Main.SelectionSync;

interface

uses
  System.Classes,
  Vcl.ComCtrls,
  Vcl.Controls,
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
begin
  if not Assigned(ATree) or not Assigned(ADesigner) then
    Exit;

  Node := ATree.Selected;
  if not Assigned(Node) then
    Exit;

  if Assigned(Node.Data) then
    ADesigner.SelectObject(TReportObject(Node.Data));

  if Assigned(ADesigner.Parent) and ADesigner.Parent.CanFocus then
    ADesigner.Parent.SetFocus
  else if ADesigner.CanFocus then
    ADesigner.SetFocus;

  ADesigner.Invalidate;
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
