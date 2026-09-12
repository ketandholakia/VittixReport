unit Vittix.Report.Objects.Unknown;

{
  Vittix.Report.Objects.Unknown
  ==============================
  TReportUnknownObject preserves raw JSON for object classes that are not
  registered in the current build.

  Forward Compatibility
  ---------------------
  When a .vrt file contains an object class that this version of VittixReport
  does not know about (e.g. from a newer version), the serializer creates a
  TReportUnknownObject that stores:

    ClassName   - the original class name from the JSON
    RawJSON     - the complete JSON fragment for that object

  On save, the raw JSON is written back verbatim, so unknown objects are
  never silently destroyed.  This is critical for forward compatibility.

  The object draws as a placeholder so the designer can show that something
  exists at that position.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  Winapi.Windows,
  Vcl.Graphics,
  Vittix.Report.Objects,
  Vittix.Report.Context;

type
  TReportUnknownObject = class(TReportObject)
  private
    FClassName: string;
    FRawJSON: string;
  public
    constructor Create; override;
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    class function DisplayName: string; override;

    // ClassName stores the original unknown class name (different from the
    // inherited ClassName which returns TReportUnknownObject)
    property OriginalClassName: string read FClassName write FClassName;
    property RawJSON: string read FRawJSON write FRawJSON;
  end;

implementation

uses
  System.JSON,
  Vittix.Report.Serializer;

{ TReportUnknownObject }

constructor TReportUnknownObject.Create;
begin
  inherited Create;
  FClassName := '';
  FRawJSON := '';
  Bounds := Rect(10, 10, 200, 50);
end;

procedure TReportUnknownObject.Draw(C: TCanvas; const Context: TExpressionContext);
var
  R: TRect;
  S: string;
begin
  R := Bounds;

  // Draw a hatched placeholder background
  C.Brush.Color := $00F0F0F0;
  C.Brush.Style := bsSolid;
  C.FillRect(R);

  // Draw a dashed border to indicate "unknown"
  C.Pen.Color := $00808080;
  C.Pen.Style := psDash;
  C.Brush.Style := bsClear;
  C.Rectangle(R);

  // Draw diagonal cross
  C.MoveTo(R.Left, R.Top);
  C.LineTo(R.Right, R.Bottom);
  C.MoveTo(R.Right, R.Top);
  C.LineTo(R.Left, R.Bottom);

  // Draw label
  C.Font.Color := $00808080;
  C.Font.Size := 8;
  C.Brush.Style := bsClear;
  if FClassName <> '' then
    S := Format('[Unknown: %s]', [FClassName])
  else
    S := '[Unknown Object]';

  var TextR := Rect(R.Left + 4, R.Top + 4, R.Right - 4, R.Bottom - 4);
  DrawText(C.Handle, PChar(S), Length(S), TextR,
    DT_LEFT or DT_TOP or DT_WORDBREAK or DT_END_ELLIPSIS);

  C.Pen.Style := psSolid;

  if Selected then
    DrawSelection(C);
end;

class function TReportUnknownObject.DisplayName: string;
begin
  Result := 'Unknown Object';
end;

initialization
  RegisterReportObject(TReportUnknownObject);

end.
