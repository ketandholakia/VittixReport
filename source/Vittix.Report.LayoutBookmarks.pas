unit Vittix.Report.LayoutBookmarks;

interface

uses
  Data.DB,
  System.SysUtils,
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
var
  PrimaryException: Exception;
  CleanupException: Exception;
begin
  if not AHasBookmark then
    Exit;
  if not Assigned(ADataSet) or (ABookmark = nil) then
    Exit;

  { FreeBookmark must run even when the restore raises; if both fail, the
    original (primary) restore exception wins and the cleanup exception is
    freed with it. }
  PrimaryException := nil;
  CleanupException := nil;
  try
    try
      if ADataSet.BookmarkValid(ABookmark) then
        ADataSet.GotoBookmark(ABookmark);
    except
      PrimaryException := Exception(AcquireExceptionObject);
    end;
  finally
    try
      ADataSet.FreeBookmark(ABookmark);
    except
      CleanupException := Exception(AcquireExceptionObject);
    end;
  end;

  if Assigned(PrimaryException) then
  begin
    if Assigned(CleanupException) then
      CleanupException.Free;
    raise PrimaryException;
  end;
  if Assigned(CleanupException) then
    raise CleanupException;
end;

end.
