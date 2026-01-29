unit Vittix.Report.Bands;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Graphics,
  System.Generics.Collections,
  Vittix.Report.Objects, // Keep here
  Data.DB,
  Vittix.Report.Context;

type
  TReportBandType = (
    btReportTitle,
    btPageHeader,
    btMasterData,
    btPageFooter,
    btReportSummary,
    btGroupHeader,
    btGroupFooter
  );

type
  TReportBand = class(TReportObject)
  private
    FBandType: TReportBandType;
    FHeight: Integer;
    FGroupLevel: Integer;
    FGroupField: string;
    FStartNewPage: Boolean;
    FChildren: TObjectList<TReportObject>; // NEW
  public
    constructor Create; override;
    destructor Destroy; override; // NEW

    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
    property Children: TObjectList<TReportObject> read FChildren; // NEW

  published
    property BandType: TReportBandType
      read FBandType write FBandType;

    property Height: Integer
      read FHeight write FHeight;

    property GroupField: string
      read FGroupField write FGroupField;

    property GroupLevel: Integer
      read FGroupLevel write FGroupLevel;

    property StartNewPage: Boolean
      read FStartNewPage write FStartNewPage;
  end;

implementation

constructor TReportBand.Create;
begin
  inherited Create;
  FHeight := 40;
  FChildren := TObjectList<TReportObject>.Create(True); // Owns objects
end;

destructor TReportBand.Destroy;
begin
  inherited;
  FChildren.Free;
end;

procedure TReportBand.Draw(C: TCanvas; const Context: TExpressionContext);
var
  Obj: TReportObject;
begin
  inherited Draw(C, Context); // Draw the band itself (e.g., background, border)

  // Draw child objects relative to the band's top-left corner
  for Obj in FChildren do
  begin
    // Adjust object's position to be relative to the band's origin for drawing
    // This might require a temporary translation of the canvas origin or
    // passing the band's top-left as an offset to the child's Draw method.
    // For simplicity, let's assume Draw handles relative positioning or
    // we'll adjust the canvas.
    // For now, we'll just call Draw, assuming child objects' Bounds are relative
    // to the band's top-left, or that the canvas origin is already translated.
    Obj.Draw(C, Context);
  end;
end;

end.
