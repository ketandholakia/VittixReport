unit Vittix.Report.Context;

{
  Vittix.Report.Context
  =====================
  TExpressionContext is the immutable snapshot passed to every Draw call and
  to the expression evaluator.  It carries all the runtime information an
  object or band needs to resolve field tokens, aggregate functions, and
  built-in system variables.

  Built-in expression tokens (resolved by TReportExpression)
  -----------------------------------------------------------
    [PageNo]        Current page number (1-based)
    [TotalPages]    Total page count after engine Prepare
    [RowNumber]     Current master row number (1-based)
    [Param.Name]    Runtime report parameter value
    [ReportTitle]   TReportModel.Title
    [ReportDate]    Date the report was generated (formatted by engine)
    [FieldName]     Value of a dataset field
    SUM([F]), COUNT([F]), AVG([F]), MIN([F]), MAX([F])  — aggregate functions

  Phase 4G-1: PrecheckedObjectForPrintWhen is a per-render reentrancy guard.
  It is set by DrawReportObjectWithHooks (Vittix.Report.Objects.pas) just
  before AObject.Draw and cleared in the matching finally. ShouldPrintObject
  reads it to short-circuit re-evaluation of Self.PrintWhen while Self is
  being drawn. Replaces the previous unit-level global of the same name.
  Typed as TObject to avoid a unit cycle (TExpressionContext is a leaf
  unit that must not import any other VittixReport unit); the only writer
  always assigns a real TReportObject, so the cast at the read site is safe.

  Dependency
  ----------
  This unit must NOT reference any other VittixReport unit
  so all units can freely import it without cycles.
}

interface

uses
  Data.DB,
  System.Classes,
  System.SysUtils,
  Vittix.Report.Expression.Mode;

type
  IReportRenderHooks = interface;
  // Phase B/C: engine-implemented subreport row-streaming session.
  // Fully declared after TExpressionContext. It stays forward-declared here so
  // the record below can carry the accessor; the band parameter is typed
  // TObject (not TReportBand) to keep this unit leaf-clean.
  IReportSubReportRowStream = interface;
  // Phase C: one stream's session token (per subreport Draw invocation).
  IReportNestedRowStream = interface;

  TExpressionContext = record
    { Dataset access }
    DataSet:    TDataSet;
    UserDataSet: TObject;   // optional TVittixUserDataSet, kept as TObject to avoid unit cycles
    // Borrowed bookmarks owned by the report engine. Do not store context
    // copies beyond the current Draw/PrintBand call.
    GroupStart: TBookmark;  // nil = full dataset
    GroupEnd:   TBookmark;  // nil = end of dataset

    { Page metadata — filled by the engine before each PrintBand call }
    PageNumber:  Integer;   // 1-based current page number
    TotalPages:  Integer;   // 0 until the engine finishes (two-pass becomes possible later)
    RowNumber:   Integer;   // 1-based master row number; 0 outside data rows
    PageBottom:   Integer;   // printable page bottom in the current canvas coordinate space

    { Report metadata }
    ReportTitle: string;
    ReportDate:  TDateTime; // set once when Prepare begins
    Parameters:  TStrings;  // borrowed runtime parameter name/value pairs
    Variables:   TStrings;  // borrowed design-time model variables (name=value)

    { Pass metadata }
    IsCountingPass: Boolean; // True only during the engine page-count pass

    { Phase B/C: subreport row streaming. RowStreaming is a measurement
      marker set by the engine on contexts used with MeasuredBottom: in that
      state TReportSubReportObject reports only its natural reserve (bounds
      bottom) instead of stacking all subreport rows. RowStream is the
      render-time accessor into the engine's row-stream stack; nil in any
      context that must keep legacy behavior (designer canvases, direct
      callers, bands printed from a continuation flush). Both fields default
      to False/nil via Default(TExpressionContext). }
    RowStreaming: Boolean;
    RowStream: IReportSubReportRowStream;

    { Expression language mode (Phase 4B-2B) }
    // Default(TExpressionContext) yields emLegacy, which is the first enum
    // value, so every existing caller keeps legacy semantics.  The engine
    // sets this from TReportModel.ExpressionLanguageVersion when rendering a
    // report that explicitly opted into ExpressionLanguageVersion = 1.
    ExpressionMode: TExpressionMode;
    
    { Hooks and Context State }
    Hooks: IReportRenderHooks;

    { Phase 4G-1: per-render reentrancy guard. Set by
      DrawReportObjectWithHooks (Vittix.Report.Objects.pas) immediately
      before AObject.Draw; cleared in the matching finally. Read by
      ShouldPrintObject to short-circuit Self.PrintWhen re-evaluation
      while Self is being drawn. nil for any context that was not
      produced by the render path (preserves the pre-R1 behavior in
      tests and direct callers that build a context by hand). }
    PrecheckedObjectForPrintWhen: TObject;
  end;

  IReportRenderHooks = interface
    ['{F8D69A64-D72E-4D3B-A162-42DF6ED26226}']
    procedure InvokeBeforeObjectPrint(Sender: TObject; const Context: TExpressionContext; var CanPrint: Boolean);
    procedure InvokeAfterObjectPrint(Sender: TObject; const Context: TExpressionContext);
    function GetNamedDataSet(const AName: string): TDataSet;
    function TryGetAggregateCache(const AExpression: string;
      const AContext: TExpressionContext; out AValue: Variant): Boolean;
    procedure StoreAggregateCache(const AExpression: string;
      const AContext: TExpressionContext; const AValue: Variant);
    function GetSubReportModel(AObject: TObject; const AJSON: string): TObject;
  end;

  { Phase B: subreport row-streaming accessor, implemented by the report
    engine (not reference counted on the engine side). BeginRowStream opens a
    stream for one subreport instance under AMasterBand and returns that
    stream's session token; nil means streaming is unavailable for this call
    (depth cap, unusable band/dataset) and the caller must keep the legacy
    clipped loop. Each session is an independent entry on the engine's stream
    stack, which is what allows Phase C nested continuation: a subreport
    drawn inside another stream's row pushes its own session and the engine
    flushes the stack depth-first at the band boundary. }
  IReportSubReportRowStream = interface
    ['{3D9B8A41-6C2E-4F17-9A55-8E21D0F4B7C3}']
    function BeginRowStream(const AContext: TExpressionContext;
      AMasterBand: TObject; ADS: TDataSet; AMasterField, ADetailField: string;
      AAnchorX, AEntryCursorY, ABoundsLeft, ABoundsTop, ABoundsHeight,
      ABoundsRight, ARowHeight: Integer): IReportNestedRowStream;
  end;

  { Phase C: session token for exactly one stream (one subreport Draw
    invocation). PrepareRow is the planner-owned atomic-row fit decision:
    True = the engine approved the row for immediate draw on the current page;
    False = the row stays pending and is re-emitted at atomic row boundaries by
    the engine's depth-first flush (a False caused by a deeper pending stream
    defers this stream's next row without painting it). RowTop is the
    page-space Y where the row approved by the last PrepareRow call must be
    painted. EndStream restores the logical-stream dataset position and marks
    the session finished; the engine keeps pending rows for the flush and
    releases the state when the band returns. }
  IReportNestedRowStream = interface
    ['{7C1D2E55-4A1B-4C8E-9D63-2F0A8B5E91D1}']
    function PrepareRow(ARowHeight: Integer): Boolean;
    function RowTop: Integer;
    procedure EndStream;
  end;

implementation

end.
