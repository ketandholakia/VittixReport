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
    [ReportTitle]   TReportModel.Title
    [ReportDate]    Date the report was generated (formatted by engine)
    [FieldName]     Value of a dataset field
    SUM([F]), COUNT([F]), AVG([F]), MIN([F]), MAX([F])  — aggregate functions

  Dependency
  ----------
  This unit must NOT reference any other VittixReport unit
  so all units can freely import it without cycles.
}

interface

uses
  Data.DB,
  System.SysUtils;

type
  TExpressionContext = record
    { Dataset access }
    DataSet:    TDataSet;
    GroupStart: TBookmark;  // nil = full dataset
    GroupEnd:   TBookmark;  // nil = end of dataset

    { Page metadata — filled by the engine before each PrintBand call }
    PageNumber:  Integer;   // 1-based current page number
    TotalPages:  Integer;   // 0 until the engine finishes (two-pass becomes possible later)

    { Report metadata }
    ReportTitle: string;
    ReportDate:  TDateTime; // set once when Prepare begins

    { Pass metadata }
    IsCountingPass: Boolean; // True only during the engine page-count pass
  end;

implementation

end.
