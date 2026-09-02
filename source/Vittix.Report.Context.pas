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
  System.SysUtils;

type
  IReportRenderHooks = interface;

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
  end;

implementation

end.
