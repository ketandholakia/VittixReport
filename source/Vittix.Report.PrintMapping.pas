unit Vittix.Report.PrintMapping;

{
  Vittix.Report.PrintMapping
  ==========================
  GAP-005 / P3 — the single destination-rectangle mapping for printer output.

  Before this unit, each printer path computed its destination rectangle
  independently, and the only aspect-preserving implementation was private to
  Vittix.Report.Export.PDF (with its "fit" mode unreachable dead code).

  `prsFullStretch` reproduces the previous behaviour EXACTLY
  (`Rect(0, 0, ADeviceWidth, ADeviceHeight)`), so adopting this unit changes no
  printed geometry. `prsFitPreserveAspectCentered` is available for an explicit,
  separately-approved behaviour change; it is not used by any default path.

  The function is pure: no globals, no device access, no side effects, so it can
  be verified without a printer.
}

interface

uses
  System.Types;

type
  TReportPrintScaleMode = (
    { Stretch the page to fill the device rectangle. Current default everywhere. }
    prsFullStretch,
    { Fit the page inside the device rectangle, preserving aspect, centred. }
    prsFitPreserveAspectCentered
  );

{ Destination rectangle for one page (APageWidth x APageHeight) on a device
  surface of ADeviceWidth x ADeviceHeight.

  Degenerate input never raises: a non-positive device size or (in fit mode) a
  non-positive page size falls back to the full device rectangle. }
function CalculatePrintDestRect(
  APageWidth, APageHeight, ADeviceWidth, ADeviceHeight: Integer;
  AMode: TReportPrintScaleMode = prsFullStretch): TRect;

{ True when a page and the destination device differ by more than ATolerance in
  either dimension.

  Extracted so the "output may be scaled" decision is a pure, testable function
  instead of living inline in a printer path. Callers REPORT the result; they
  must not block on it (see Vittix.Report.Export.PDF: the previous modal dialog
  was removed because it hung non-interactive export). }
function IsPrintSizeMismatch(
  APageWidth, APageHeight, ADeviceWidth, ADeviceHeight, ATolerance: Integer): Boolean;

implementation

uses
  System.Math;

function CalculatePrintDestRect(
  APageWidth, APageHeight, ADeviceWidth, ADeviceHeight: Integer;
  AMode: TReportPrintScaleMode): TRect;
var
  Scale: Double;
  W, H, X, Y: Integer;
begin
  case AMode of
    prsFitPreserveAspectCentered:
      begin
        if (APageWidth <= 0) or (APageHeight <= 0) or
           (ADeviceWidth <= 0) or (ADeviceHeight <= 0) then
        begin
          Result := Rect(0, 0, ADeviceWidth, ADeviceHeight);
          Exit;
        end;

        Scale := ADeviceWidth / APageWidth;
        if (ADeviceHeight / APageHeight) < Scale then
          Scale := ADeviceHeight / APageHeight;

        W := Round(APageWidth * Scale);
        H := Round(APageHeight * Scale);
        X := (ADeviceWidth - W) div 2;
        Y := (ADeviceHeight - H) div 2;
        Result := Rect(X, Y, X + W, Y + H);
      end;
  else
    // Current default: exact previous behaviour, page size is ignored.
    Result := Rect(0, 0, ADeviceWidth, ADeviceHeight);
  end;
end;

function IsPrintSizeMismatch(
  APageWidth, APageHeight, ADeviceWidth, ADeviceHeight, ATolerance: Integer): Boolean;
begin
  Result := (Abs(APageWidth - ADeviceWidth) > ATolerance) or
            (Abs(APageHeight - ADeviceHeight) > ATolerance);
end;

end.
