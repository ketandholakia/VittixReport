unit Vittix.Report.LayoutPagination;

interface

function BandFitsOnPage(
  ACurrentY, ARequiredHeight, APageHeight, ABottomMargin, AFooterHeight: Integer): Boolean;

implementation

function BandFitsOnPage(
  ACurrentY, ARequiredHeight, APageHeight, ABottomMargin, AFooterHeight: Integer): Boolean;
begin
  if ARequiredHeight <= 0 then
    ARequiredHeight := 1;
  Result :=
    (ACurrentY + ARequiredHeight) <=
    (APageHeight - ABottomMargin - AFooterHeight);
end;

end.
