unit Vittix.Report.Context;

interface

uses
  Data.DB;

type
  TExpressionContext = record
    DataSet: TDataSet;
    GroupStart: TBookmark;
    GroupEnd: TBookmark;
  end;

implementation

end.