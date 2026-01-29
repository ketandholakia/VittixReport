unit Vittix.Report.Aggregates;

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
  BM: TBookmark;
  Count: Integer;
  Sum, ValFloat: Double;
  ValVar: Variant;
  FirstVal: Boolean;
  MinVal, MaxVal: Double;
begin
  Result := False;
  Value := Null;

  P1 := Pos('(', Expr);
  P2 := LastDelimiter(')', Expr);

  if (P1 <= 1) or (P2 <= P1) then Exit;

  Func := UpperCase(Trim(Copy(Expr, 1, P1 - 1)));
  InnerExpr := Copy(Expr, P1 + 1, P2 - P1 - 1);

  if (Func <> 'SUM') and (Func <> 'COUNT') and (Func <> 'AVG') and
     (Func <> 'MIN') and (Func <> 'MAX') then Exit;

  if not Assigned(Context.DataSet) or not Context.DataSet.Active then Exit;

  BM := Context.DataSet.GetBookmark;
  Context.DataSet.DisableControls;
  try
    if Context.GroupStart <> nil then
      Context.DataSet.GotoBookmark(Context.GroupStart)
    else
      Context.DataSet.First;

    Count := 0;
    Sum := 0.0;
    MinVal := 0.0;
    MaxVal := 0.0;
    FirstVal := True;

    while not Context.DataSet.Eof do
    begin
      if (Context.GroupEnd <> nil) and
         (Context.DataSet.CompareBookmarks(Context.DataSet.GetBookmark, Context.GroupEnd) = 0) then
        Break;

      ValVar := TReportExpression.Evaluate(InnerExpr, Context);

      if not VarIsNull(ValVar) then
      begin
        if Func = 'COUNT' then
          Inc(Count)
        else
        begin
          try
            ValFloat := ValVar; // Implicit variant conversion
            
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

    if Func = 'COUNT' then Value := Count
    else if Func = 'SUM' then Value := Sum
    else if Func = 'AVG' then
    begin
      if Count > 0 then Value := Sum / Count else Value := 0;
    end
    else if Func = 'MIN' then Value := MinVal
    else if Func = 'MAX' then Value := MaxVal;

    Result := True;
  finally
    if Context.DataSet.Active and Context.DataSet.BookmarkValid(BM) then
      Context.DataSet.GotoBookmark(BM);
    Context.DataSet.FreeBookmark(BM);
    Context.DataSet.EnableControls;
  end;
end;

end.