unit Vittix.Report.LayoutBookmarks;

interface

uses
  Data.DB,
  Vittix.Report.Utils;

function CaptureDataSetBookmark(ADataSet: TDataSet; out ABookmark: TBookmark): Boolean;
procedure RestoreDataSetBookmark(ADataSet: TDataSet; ABookmark: TBookmark; AHasBookmark: Boolean);

implementation

function CaptureDataSetBookmark(ADataSet: TDataSet; out ABookmark: TBookmark): Boolean;
begin
  ABookmark := nil;
  Result := Assigned(ADataSet) and DataSetSupportsBookmarks(ADataSet);
  if Result then
    ABookmark := ADataSet.GetBookmark;
end;

procedure RestoreDataSetBookmark(ADataSet: TDataSet; ABookmark: TBookmark; AHasBookmark: Boolean);
begin
  if not AHasBookmark then
    Exit;
  if Assigned(ADataSet) and (ABookmark <> nil) and ADataSet.BookmarkValid(ABookmark) then
    ADataSet.GotoBookmark(ABookmark);
  if Assigned(ADataSet) and (ABookmark <> nil) then
    ADataSet.FreeBookmark(ABookmark);
end;

end.
