unit Vittix.Report.TraversalDiagnostics;

{
  Internal, opt-in diagnostics for Phase 2 characterization.

  Counters observe existing traversal only. They do not cache, short-circuit,
  or otherwise influence report execution. The VCL engine is currently invoked
  on its owning UI thread, so this lightweight process-local snapshot follows
  the same execution model.
}

interface

type
  TReportTraversalSnapshot = record
    DetailTraversals: Integer;
    DetailRowsVisited: Integer;
    SubReportParseAttempts: Integer;
    SubReportCacheHits: Integer;
    SubReportCacheMisses: Integer;
    SubReportTraversals: Integer;
    SubReportRowsVisited: Integer;
    AggregateEvaluations: Integer;
    AggregateCacheHits: Integer;
    AggregateCacheMisses: Integer;
    AggregateTraversals: Integer;
    AggregateRowsVisited: Integer;
    { DP-15: legacy bracket tokens carrying a dataset qualifier that names a
      KNOWN dataset other than the active one, e.g. [Orders.Company] read
      while the active dataset is Customers. The legacy evaluator resolves
      such tokens from the CURRENT dataset by frozen contract; the counter
      surfaces where that silent behavior may be reading unintended data. }
    LegacyQualifiedFieldTokens: Integer;
    { DP-36 / BUG-005: legacy aggregate prefixes (SUM/AVG/MIN/MAX/COUNT)
      that could not be evaluated because the context is user-dataset-backed
      (the aggregate engine reads TDataSet only; UDS-driven bands render
      with DataSet = nil).  The report falls back to printing the expression
      text - frozen semantics (the real fix is evaluator work deferred with
      Phase4I-20); the counter surfaces the silent fallback. }
    LegacyAggregatesOverUserDataSet: Integer;
    { DP-29: current entry count of the engine's aggregate cache, sampled by
      the engine after every store/eviction so tests can assert that
      row-scoped re-evaluations stay bounded. }
    AggregateCacheEntries: Integer;
    { Silent-failure observability (2026-10-25): four failure classes are
      swallowed by frozen fallback semantics - band PrintWhen exceptions
      (band skipped), object PrintWhen exceptions (object skipped),
      subreport JSON parse failures (object skipped) and aggregate value
      conversion errors (row skipped).  Counters only: no caching,
      short-circuit or output change.  A cached subreport parse failure is
      additionally counted once, not once per master row. }
    BandPrintWhenExceptions: Integer;
    ObjectPrintWhenExceptions: Integer;
    SubReportParseFailures: Integer;
    AggregateValueErrors: Integer;
  end;

  TReportTraversalDiagnostics = class
  private
    class var FSnapshot: TReportTraversalSnapshot;
  public
    class procedure Reset; static;
    class function Snapshot: TReportTraversalSnapshot; static;
    class procedure DetailTraversalStarted; static;
    class procedure DetailRowVisited; static;
    class procedure SubReportParseAttempted; static;
    class procedure SubReportCacheHit; static;
    class procedure SubReportCacheMiss; static;
    class procedure SubReportTraversalStarted; static;
    class procedure SubReportRowVisited; static;
    class procedure AggregateEvaluationStarted; static;
    class procedure AggregateCacheHit; static;
    class procedure AggregateCacheMiss; static;
    class procedure AggregateTraversalStarted; static;
    class procedure AggregateRowVisited; static;
    class procedure LegacyQualifiedFieldToken; static;
    class procedure LegacyAggregateOverUserDataSet; static;
    class procedure AggregateCacheSize(AValue: Integer); static;
    class procedure BandPrintWhenException; static;
    class procedure ObjectPrintWhenException; static;
    class procedure SubReportParseFailed; static;
    class procedure AggregateValueError; static;
  end;

implementation

class procedure TReportTraversalDiagnostics.Reset;
begin
  FSnapshot := Default(TReportTraversalSnapshot);
end;

class function TReportTraversalDiagnostics.Snapshot: TReportTraversalSnapshot;
begin
  Result := FSnapshot;
end;

class procedure TReportTraversalDiagnostics.DetailTraversalStarted;
begin
  Inc(FSnapshot.DetailTraversals);
end;

class procedure TReportTraversalDiagnostics.DetailRowVisited;
begin
  Inc(FSnapshot.DetailRowsVisited);
end;

class procedure TReportTraversalDiagnostics.SubReportParseAttempted;
begin
  Inc(FSnapshot.SubReportParseAttempts);
end;

class procedure TReportTraversalDiagnostics.SubReportCacheHit;
begin
  Inc(FSnapshot.SubReportCacheHits);
end;

class procedure TReportTraversalDiagnostics.SubReportCacheMiss;
begin
  Inc(FSnapshot.SubReportCacheMisses);
end;

class procedure TReportTraversalDiagnostics.SubReportTraversalStarted;
begin
  Inc(FSnapshot.SubReportTraversals);
end;

class procedure TReportTraversalDiagnostics.SubReportRowVisited;
begin
  Inc(FSnapshot.SubReportRowsVisited);
end;

class procedure TReportTraversalDiagnostics.AggregateEvaluationStarted;
begin
  Inc(FSnapshot.AggregateEvaluations);
end;

class procedure TReportTraversalDiagnostics.AggregateCacheHit;
begin
  Inc(FSnapshot.AggregateCacheHits);
end;

class procedure TReportTraversalDiagnostics.AggregateCacheMiss;
begin
  Inc(FSnapshot.AggregateCacheMisses);
end;

class procedure TReportTraversalDiagnostics.AggregateTraversalStarted;
begin
  Inc(FSnapshot.AggregateTraversals);
end;

class procedure TReportTraversalDiagnostics.AggregateRowVisited;
begin
  Inc(FSnapshot.AggregateRowsVisited);
end;

class procedure TReportTraversalDiagnostics.LegacyQualifiedFieldToken;
begin
  Inc(FSnapshot.LegacyQualifiedFieldTokens);
end;

class procedure TReportTraversalDiagnostics.LegacyAggregateOverUserDataSet;
begin
  Inc(FSnapshot.LegacyAggregatesOverUserDataSet);
end;

class procedure TReportTraversalDiagnostics.AggregateCacheSize(AValue: Integer);
begin
  FSnapshot.AggregateCacheEntries := AValue;
end;

class procedure TReportTraversalDiagnostics.BandPrintWhenException;
begin
  Inc(FSnapshot.BandPrintWhenExceptions);
end;

class procedure TReportTraversalDiagnostics.ObjectPrintWhenException;
begin
  Inc(FSnapshot.ObjectPrintWhenExceptions);
end;

class procedure TReportTraversalDiagnostics.SubReportParseFailed;
begin
  Inc(FSnapshot.SubReportParseFailures);
end;

class procedure TReportTraversalDiagnostics.AggregateValueError;
begin
  Inc(FSnapshot.AggregateValueErrors);
end;

end.
