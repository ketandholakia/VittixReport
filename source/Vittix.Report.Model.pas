unit Vittix.Report.Model;

{
  Vittix.Report.Model
  ===================
  TReportModel is the central value object of the VittixReport framework.
  It owns:
    • A flat list of TReportObject instances (bands + top-level layout objects).
      TReportBand items in this list each own their children separately.
    • A TReportPageSettings describing paper size, margins, orientation.
    • A Title string shown by the engine as report header metadata.

  Design constraints
  ------------------
  • This unit must NOT reference Engine, Renderer, Designer, or Serializer so
    it stays at the bottom of the dependency graph.
  • Clear resets all objects but preserves PageSettings.
  • Assign performs a shallow structural copy; for a deep clone use
    TReportSerializer.CloneReport (serialise → deserialise round-trip).
}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vittix.Report.Objects,
  Vittix.Report.PageSettings;

type
  TReportModel = class(TPersistent)
  private
    FObjects:      TObjectList<TReportObject>;
    FPageSettings: TReportPageSettings;
    FTitle:        string;
    FAuthor:       string;
    FDescription:  string;
  public
    constructor Create;
    destructor  Destroy; override;

    /// <summary>
    ///   Removes all objects from the list.
    ///   PageSettings and metadata (Title/Author/Description) are preserved.
    /// </summary>
    procedure Clear;

    /// <summary>
    ///   Flat list of top-level report objects (primarily TReportBand items).
    ///   The list owns its elements — do not free items manually.
    /// </summary>
    property Objects: TObjectList<TReportObject> read FObjects;

    /// <summary>
    ///   Page geometry: paper size, orientation, margins.
    ///   Created in the constructor; never nil.
    /// </summary>
    property PageSettings: TReportPageSettings read FPageSettings;

  published
    { Metadata — persisted to/from the .vrt JSON file }
    property Title:       string read FTitle       write FTitle;
    property Author:      string read FAuthor      write FAuthor;
    property Description: string read FDescription write FDescription;
  end;

implementation

{ ================= Constructor / Destructor ================= }

constructor TReportModel.Create;
begin
  inherited;
  FObjects      := TObjectList<TReportObject>.Create(True); // owns items
  FPageSettings := TReportPageSettings.Create;
  FTitle        := 'New Report';
end;

destructor TReportModel.Destroy;
begin
  FObjects.Free;
  FPageSettings.Free;
  inherited;
end;

{ ================= Clear ================= }

procedure TReportModel.Clear;
begin
  FObjects.Clear;
  // PageSettings and metadata are intentionally kept
end;

end.
