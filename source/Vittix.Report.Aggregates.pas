unit Vittix.Report.Aggregates;

{
  Vittix.Report.Aggregates
  ========================
  Evaluates aggregate functions (SUM, COUNT, AVG, MIN, MAX) over a dataset
  range defined by the group bookmarks in TExpressionContext.

  Bug fixes in this revision
  --------------------------
  â€¢ BookmarkLeak: The while-loop previously called GetBookmark every row for
    the group-end boundary check but never freed the returned bookmark.
    Fix: capture in a local variable (RowBM) and free it after the comparison.
}

interface

uses
  System.SysUtils,
  System.Variants,
  Data.DB,
  Vittix.Report.Context;

type
  TReportAggregates = class
  public
    class function TryEvaluate(
      const Expr: string;
      const Context: TExpressionContext;
      out Value: Variant): Boolean;
  end;

implementation

uses
  Vittix.Report.Expressions;

class function TReportAggregates.TryEvaluate(
  const Expr: string;
  const Context: TExpressionContext;
  out Value: Variant): Boolean;
var
  Func, InnerExpr: string;
  P1, P2: Integer;
  SaveBM, RowBM: TBookmark;    // SaveBM = restore point; RowBM = per-row boundary check
  Count: Integer;
  Sum, ValFloat: Double;
  ValVar: Variant;
  FirstVal: Boolean;
  MinVal, MaxVal: Double;
  AtGroupEnd: Boolean;
begin
  Result := False;
  Value := Null;

  P1 := Pos('(', Expr);
  P2 := LastDelimiter(')', Expr);

  if (P1 <= 1) or (P2 <= P1) then Exit;

  Func      := UpperCase(Trim(Copy(Expr, 1, P1 - 1)));
  InnerExpr := Copy(Expr, P1 + 1, P2 - P1 - 1);

  if (Func <> 'SUM') and (Func <> 'COUNT') and (Func <> 'AVG') and
     (Func <> 'MIN') and (Func <> 'MAX') then Exit;

  if not Assigned(Context.DataSet) or not Context.DataSet.Active then Exit;

  SaveBM := Context.DataSet.GetBookmark;
  Context.DataSet.DisableControls;
  try
    if Context.GroupStart <> nil then
      Context.DataSet.GotoBookmark(Context.GroupStart)
    else
      Context.DataSet.First;

    Count    := 0;
    Sum      := 0.0;
    MinVal   := 0.0;
    MaxVal   := 0.0;
    FirstVal := True;

    while not Context.DataSet.Eof do
    begin
      // --- Group-end boundary check (fixed bookmark leak) ---
      AtGroupEnd := False;
      if Context.GroupEnd <> nil then
      begin
        RowBM := Context.DataSet.GetBookmark;  // allocate
        try
          AtGroupEnd :=
            (Context.DataSet.CompareBookmarks(RowBM, Context.GroupEnd) = 0);
        finally
          Context.DataSet.FreeBookmark(RowBM); // always free
        end;
      end;

      if AtGroupEnd then Break;
      // ------------------------------------------------------

      ValVar := TReportExpression.Evaluate(InnerExpr, Context);

      if not VarIsNull(ValVar) then
      begin
        if Func = 'COUNT' then
          Inc(Count)
        else
        begin
          try
            ValFloat := ValVar;

            if Func = 'SUM' then
              Sum := Sum + ValFloat
            else if Func = 'AVG' then
            begin
              Sum := Sum + ValFloat;
              Inc(Count);
            end
            else if Func = 'MIN' then
            begin
              if FirstVal or (ValFloat < MinVal) then MinVal := ValFloat;
            end
            else if Func = 'MAX' then
            begin
              if FirstVal or (ValFloat > MaxVal) then MaxVal := ValFloat;
            end;

            if Func <> 'COUNT' then FirstVal := False;
          except
            // Ignore non-numeric values for math aggregates
          end;
        end;
      end;

      Context.DataSet.Next;
    end;

    if Func = 'COUNT'     then Value := Count
    else if Func = 'SUM'  then Value := Sum
    else if Func = 'AVG'  then
    begin
      if Count > 0 then Value := Sum / Count else Value := 0;
    end
    else if Func = 'MIN'  then Value := MinVal
    else if Func = 'MAX'  then Value := MaxVal;

    Result := True;
  finally
    if Context.DataSet.Active and Context.DataSet.BookmarkValid(SaveBM) then
      Context.DataSet.GotoBookmark(SaveBM);
    Context.DataSet.FreeBookmark(SaveBM);
    Context.DataSet.EnableControls;
  end;
end;

end.
