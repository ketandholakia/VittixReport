unit scratch;
interface
type
  IReportRenderHooks = interface;
  TExpressionContext = record
    Hooks: IReportRenderHooks;
  end;
  IReportRenderHooks = interface
  end;
implementation
end.
