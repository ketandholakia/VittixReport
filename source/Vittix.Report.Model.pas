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
    • A FieldNames TStringList — dataset column names embedded in the .vrt
      file so the standalone designer can populate its "Dataset Fields" panel
      without a live database connection.

  Design constraints
  ------------------
  • This unit must NOT reference Engine, Renderer, Designer, or Serializer so
    it stays at the bottom of the dependency graph.
  • Clear resets all objects but preserves PageSettings and FieldNames.
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
    FFieldNames:   TStringList;              // <-- ADDED
    FTitle:        string;
    FAuthor:       string;
    FDescription:  string;
  public
    constructor Create;
    destructor  Destroy; override;

    /// <summary>
    ///   Removes all objects from the list.
    ///   PageSettings, FieldNames and metadata (Title/Author/Description)
    ///   are intentionally preserved.
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

    /// <summary>
    ///   Dataset column names persisted inside the .vrt JSON file.
    ///   Populated by the demo app before launching the designer so the
    ///   standalone designer EXE can show fields without a live connection.
    /// </summary>
    property FieldNames: TStringList read FFieldNames;  // <-- ADDED

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
  FFieldNames   := TStringList.Create;      // <-- ADDED
  FTitle        := 'New Report';
end;

destructor TReportModel.Destroy;
begin
  FObjects.Free;
  FPageSettings.Free;
  FFieldNames.Free;                          // <-- ADDED
  inherited;
end;

{ ================= Clear ================= }

procedure TReportModel.Clear;
begin
  FObjects.Clear;
  // PageSettings, FieldNames and metadata are intentionally kept
end;

end.