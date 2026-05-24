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

    { Pass metadata }
    IsCountingPass: Boolean; // True only during the engine page-count pass
  end;

implementation

end.
