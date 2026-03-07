unit Vittix.Report.UserDataSet;

{
  Vittix.Report.UserDataSet
  =========================
  TVittixUserDataSet — a non-visual component that acts as the bridge between
  your application data and the VittixReport engine.

  This mirrors FastReport's TfrxUserDataSet pattern.  Instead of pointing the
  report directly at a TDataSet or TDataSource, you drop one or more
  TVittixUserDataSet components on your form, give each one a Name (which
  becomes the band's DataSetName in the designer), and handle three events:

    OnFirst     — move your data source to the first record
    OnNext      — advance to the next record
    OnEof       — return True when there are no more records
    OnGetValue  — return the value for a named field (as Variant)

  This lets you feed data from ANY source — TDataSet, arrays, JSON, REST APIs,
  in-memory lists — without the engine ever touching TDataSet directly.

  Typical usage (TDataSet backing)
  ---------------------------------
    procedure TForm1.FormCreate(Sender: TObject);
    begin
      VittixUserDataSet1.DataSet := qryOrders;   // convenience shortcut
      VittixReport1.RegisterUserDataSet(VittixUserDataSet1);
    end;

  Typical usage (custom / non-dataset data)
  ------------------------------------------
    procedure TForm1.UserDS1First(Sender: TObject);
    begin
      FIndex := 0;
    end;

    procedure TForm1.UserDS1Next(Sender: TObject);
    begin
      Inc(FIndex);
    end;

    procedure TForm1.UserDS1Eof(Sender: TObject; var AEof: Boolean);
    begin
      AEof := FIndex >= FList.Count;
    end;

    procedure TForm1.UserDS1GetValue(Sender: TObject;
      const AFieldName: string; var AValue: Variant);
    begin
      if SameText(AFieldName, 'Name') then AValue := FList[FIndex].Name
      else if SameText(AFieldName, 'Amount') then AValue := FList[FIndex].Amount;
    end;

  Registration
  ------------
    VittixReport1.RegisterUserDataSet(VittixUserDataSet1);

  The report engine resolves each band's DataSetName to a registered
  TVittixUserDataSet.  The primary (master) dataset is the one registered
  first, or the one whose Name matches the master band's DataSetName.

  Compatibility
  -------------
  When none of the three events are handled, the component transparently
  wraps its DataSet/DataSource property, giving full backwards-compatibility
  with existing code that used TVittixReport.DataSource directly.
}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Variants,
  Data.DB;

type
  // -------------------------------------------------------------------------
  //  Event signatures
  // -------------------------------------------------------------------------

  /// <summary>Called to move the data cursor to the first record.</summary>
  TVittixUserDataSetFirstEvent = procedure(Sender: TObject) of object;

  /// <summary>Called to advance the data cursor to the next record.</summary>
  TVittixUserDataSetNextEvent = procedure(Sender: TObject) of object;

  /// <summary>
  ///   Called to test whether the data cursor is past the last record.
  ///   Set AEof := True to signal end-of-data.
  /// </summary>
  TVittixUserDataSetEofEvent = procedure(Sender: TObject;
    var AEof: Boolean) of object;

  /// <summary>
  ///   Called to retrieve the current value for a field by name.
  ///   Set AValue to the field's value.  Leave unchanged for unknown fields.
  /// </summary>
  TVittixUserDataSetGetValueEvent = procedure(Sender: TObject;
    const AFieldName: string; var AValue: Variant) of object;

  // -------------------------------------------------------------------------
  //  TVittixUserDataSet
  // -------------------------------------------------------------------------

  TVittixUserDataSet = class(TComponent)
  private
    FDataSet   : TDataSet;
    FDataSource: TDataSource;

    FOnFirst   : TVittixUserDataSetFirstEvent;
    FOnNext    : TVittixUserDataSetNextEvent;
    FOnEof     : TVittixUserDataSetEofEvent;
    FOnGetValue: TVittixUserDataSetGetValueEvent;

    procedure SetDataSource(const V: TDataSource);
    procedure SetDataSet(const V: TDataSet);

  protected
    procedure Notification(AComponent: TComponent;
      Operation: TOperation); override;

  public
    // ----- Navigation (called by the engine) --------------------------------

    /// <summary>Move cursor to the first record.</summary>
    procedure First;

    /// <summary>Advance cursor to the next record.</summary>
    procedure Next;

    /// <summary>Returns True when there are no more records.</summary>
    function  Eof: Boolean;

    /// <summary>
    ///   Returns the current value of a field by name.
    ///   Returns Null for unknown fields.
    /// </summary>
    function  GetValue(const AFieldName: string): Variant;

    /// <summary>
    ///   Returns True when the dataset has data to iterate.
    ///   Checks the internal DataSet when no custom events are assigned.
    /// </summary>
    function  Active: Boolean;

    /// <summary>
    ///   Returns field names from the underlying DataSet (if set).
    ///   Used by the designer to populate the "Dataset Fields" panel.
    /// </summary>
    function  GetFieldNames: TArray<string>;

  published
    // ----- Convenience DataSet wiring ---------------------------------------

    /// <summary>
    ///   Optional: wire directly to a TDataSource for automatic DataSet
    ///   resolution.  Has no effect when all three navigation events are handled.
    /// </summary>
    property DataSource: TDataSource read FDataSource write SetDataSource;

    /// <summary>
    ///   Optional: direct TDataSet reference.  Used for navigation and
    ///   GetValue when no custom events are assigned.
    ///   Setting DataSource automatically keeps this in sync.
    /// </summary>
    property DataSet: TDataSet read FDataSet write SetDataSet;

    // ----- Custom data events -----------------------------------------------

    /// <summary>
    ///   Fired when the engine needs to start iterating from the first record.
    ///   When not assigned, calls DataSet.First.
    /// </summary>
    property OnFirst: TVittixUserDataSetFirstEvent
      read FOnFirst write FOnFirst;

    /// <summary>
    ///   Fired when the engine needs to advance to the next record.
    ///   When not assigned, calls DataSet.Next.
    /// </summary>
    property OnNext: TVittixUserDataSetNextEvent
      read FOnNext write FOnNext;

    /// <summary>
    ///   Fired when the engine needs to test for end-of-data.
    ///   When not assigned, returns DataSet.Eof.
    /// </summary>
    property OnEof: TVittixUserDataSetEofEvent
      read FOnEof write FOnEof;

    /// <summary>
    ///   Fired when the engine needs the value of a field by name.
    ///   When not assigned, reads from DataSet.FieldByName(AFieldName).
    /// </summary>
    property OnGetValue: TVittixUserDataSetGetValueEvent
      read FOnGetValue write FOnGetValue;
  end;

procedure Register;

implementation

// ---------------------------------------------------------------------------
//  TVittixUserDataSet
// ---------------------------------------------------------------------------

procedure TVittixUserDataSet.SetDataSource(const V: TDataSource);
begin
  if FDataSource = V then Exit;
  if Assigned(FDataSource) then
    FDataSource.RemoveFreeNotification(Self);
  FDataSource := V;
  if Assigned(FDataSource) then
  begin
    FDataSource.FreeNotification(Self);
    FDataSet := FDataSource.DataSet;   // keep in sync
  end
  else
    FDataSet := nil;
end;

procedure TVittixUserDataSet.SetDataSet(const V: TDataSet);
begin
  if FDataSet = V then Exit;
  if Assigned(FDataSet) then
    FDataSet.RemoveFreeNotification(Self);
  FDataSet := V;
  if Assigned(FDataSet) then
    FDataSet.FreeNotification(Self);
end;

procedure TVittixUserDataSet.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
  begin
    if AComponent = FDataSource then
    begin
      FDataSource := nil;
      FDataSet    := nil;
    end
    else if AComponent = FDataSet then
      FDataSet := nil;
  end;
end;

// ---------------------------------------------------------------------------
//  Navigation
// ---------------------------------------------------------------------------

procedure TVittixUserDataSet.First;
begin
  if Assigned(FOnFirst) then
    FOnFirst(Self)
  else if Assigned(FDataSet) and FDataSet.Active then
    FDataSet.First;
end;

procedure TVittixUserDataSet.Next;
begin
  if Assigned(FOnNext) then
    FOnNext(Self)
  else if Assigned(FDataSet) and FDataSet.Active then
    FDataSet.Next;
end;

function TVittixUserDataSet.Eof: Boolean;
var
  AEof: Boolean;
begin
  if Assigned(FOnEof) then
  begin
    AEof := True;
    FOnEof(Self, AEof);
    Result := AEof;
  end
  else if Assigned(FDataSet) and FDataSet.Active then
    Result := FDataSet.Eof
  else
    Result := True;
end;

function TVittixUserDataSet.GetValue(const AFieldName: string): Variant;
var
  F: TField;
begin
  Result := Null;
  if Assigned(FOnGetValue) then
  begin
    FOnGetValue(Self, AFieldName, Result);
    Exit;
  end;
  // Fall back to DataSet
  if Assigned(FDataSet) and FDataSet.Active then
  begin
    F := FDataSet.FindField(AFieldName);
    if Assigned(F) then
      Result := F.Value;
  end;
end;

function TVittixUserDataSet.Active: Boolean;
begin
  if Assigned(FOnEof) then
    Result := True   // custom source — assume active; Eof will gate the loop
  else
    Result := Assigned(FDataSet) and FDataSet.Active;
end;

function TVittixUserDataSet.GetFieldNames: TArray<string>;
var
  I: Integer;
begin
  Result := [];
  if not Assigned(FDataSet) then Exit;
  // Sync DataSet from DataSource in case it changed
  if Assigned(FDataSource) and (FDataSource.DataSet <> FDataSet) then
    FDataSet := FDataSource.DataSet;
  if not Assigned(FDataSet) or not FDataSet.Active then Exit;
  SetLength(Result, FDataSet.FieldCount);
  for I := 0 to FDataSet.FieldCount - 1 do
    Result[I] := FDataSet.Fields[I].FieldName;
end;

// ---------------------------------------------------------------------------
//  Registration
// ---------------------------------------------------------------------------

procedure Register;
begin
  RegisterComponents('Vittix Reporting', [TVittixUserDataSet]);
end;

end.