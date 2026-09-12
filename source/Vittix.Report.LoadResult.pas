unit Vittix.Report.LoadResult;

{
  Vittix.Report.LoadResult
  ========================
  Explicit result type for report loading operations.

  Design
  ------
  A load result owns its TReportModel.  Callers access the model through the
  Model property and are responsible for freeing the result (which frees the
  model).  This makes ownership explicit and prevents leaks.

  Diagnostics are categorized by severity:

    rlsInfo     Notable but non-fatal (e.g. loaded v1 file without version key)
    rlsWarning  Recoverable issue (e.g. unknown object class skipped)
    rlsError    Failure that prevented successful load

  Transactional Contract
  ----------------------
  Success = True:
    Model is valid and fully loaded.
    Warnings may exist (e.g. unknown objects skipped in tolerant mode).
    Errors must be empty.

  Success = False:
    Model may be nil (complete failure) or partially populated (if the caller
    wants to inspect it).  Check Errors for the reason.
}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Vittix.Report.Model;

type
  TReportLoadSeverity = (rlsInfo, rlsWarning, rlsError);

  TReportLoadDiagnostic = class
  private
    FSeverity: TReportLoadSeverity;
    FCode: string;
    FMessage: string;
    FPath: string;
    FObjectClass: string;
  public
    constructor Create(
      ASeverity: TReportLoadSeverity;
      const AMessage: string;
      const APath: string = '';
      const AObjectClass: string = '';
      const ACode: string = '');

    property Severity: TReportLoadSeverity read FSeverity;
    property Code: string read FCode;
    property Message: string read FMessage;
    property Path: string read FPath;
    property ObjectClass: string read FObjectClass;

    function ToString: string; override;
  end;

  TReportLoadResult = class
  private
    FSuccess: Boolean;
    FModel: TReportModel;
    FDiagnostics: TObjectList<TReportLoadDiagnostic>;
    function GetWarningCount: Integer;
    function GetErrorCount: Integer;
    function GetHasWarnings: Boolean;
    function GetHasErrors: Boolean;
    function GetWarnings: TArray<string>;
    function GetErrors: TArray<string>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Add an informational diagnostic.</summary>
    procedure AddInfo(const AMessage: string; const APath: string = '';
      const AObjectClass: string = ''; const ACode: string = '');

    /// <summary>Add a warning diagnostic (recoverable issue).</summary>
    procedure AddWarning(const AMessage: string; const APath: string = '';
      const AObjectClass: string = ''; const ACode: string = '');

    /// <summary>Add an error diagnostic (load failure).</summary>
    procedure AddError(const AMessage: string; const APath: string = '';
      const AObjectClass: string = ''; const ACode: string = '');

    // Extracts ownership of the model from this result.
    // After this call, the result no longer owns the model and Success
    // is set to False (since the result no longer holds a valid model).
    // Use this when you want to transfer the model to another owner.
    function ExtractModel: TReportModel;

    property Success: Boolean read FSuccess write FSuccess;
    property Model: TReportModel read FModel write FModel;
    property Diagnostics: TObjectList<TReportLoadDiagnostic> read FDiagnostics;
    property WarningCount: Integer read GetWarningCount;
    property ErrorCount: Integer read GetErrorCount;
    property HasWarnings: Boolean read GetHasWarnings;
    property HasErrors: Boolean read GetHasErrors;
    property Warnings: TArray<string> read GetWarnings;
    property Errors: TArray<string> read GetErrors;
  end;

implementation

{ TReportLoadDiagnostic }

constructor TReportLoadDiagnostic.Create(
  ASeverity: TReportLoadSeverity;
  const AMessage: string;
  const APath: string;
  const AObjectClass: string;
  const ACode: string);
begin
  inherited Create;
  FSeverity := ASeverity;
  FMessage := AMessage;
  FPath := APath;
  FObjectClass := AObjectClass;
  FCode := ACode;
end;

function TReportLoadDiagnostic.ToString: string;
const
  SEVERITY_NAMES: array[TReportLoadSeverity] of string = ('INFO', 'WARNING', 'ERROR');
begin
  Result := Format('[%s] %s', [SEVERITY_NAMES[FSeverity], FMessage]);
  if FPath <> '' then
    Result := Result + Format(' (at %s)', [FPath]);
  if FObjectClass <> '' then
    Result := Result + Format(' [class: %s]', [FObjectClass]);
end;

{ TReportLoadResult }

constructor TReportLoadResult.Create;
begin
  inherited Create;
  FDiagnostics := TObjectList<TReportLoadDiagnostic>.Create(True);
  FSuccess := False;
  FModel := nil;
end;

destructor TReportLoadResult.Destroy;
begin
  FModel.Free;
  FDiagnostics.Free;
  inherited;
end;

procedure TReportLoadResult.AddInfo(const AMessage: string; const APath: string;
  const AObjectClass: string; const ACode: string);
begin
  FDiagnostics.Add(TReportLoadDiagnostic.Create(rlsInfo, AMessage, APath, AObjectClass, ACode));
end;

procedure TReportLoadResult.AddWarning(const AMessage: string; const APath: string;
  const AObjectClass: string; const ACode: string);
begin
  FDiagnostics.Add(TReportLoadDiagnostic.Create(rlsWarning, AMessage, APath, AObjectClass, ACode));
end;

procedure TReportLoadResult.AddError(const AMessage: string; const APath: string;
  const AObjectClass: string; const ACode: string);
begin
  FDiagnostics.Add(TReportLoadDiagnostic.Create(rlsError, AMessage, APath, AObjectClass, ACode));
end;

function TReportLoadResult.ExtractModel: TReportModel;
begin
  Result := FModel;
  FModel := nil;
  FSuccess := False;
end;

function TReportLoadResult.GetWarningCount: Integer;
var
  D: TReportLoadDiagnostic;
begin
  Result := 0;
  for D in FDiagnostics do
    if D.Severity = rlsWarning then
      Inc(Result);
end;

function TReportLoadResult.GetErrorCount: Integer;
var
  D: TReportLoadDiagnostic;
begin
  Result := 0;
  for D in FDiagnostics do
    if D.Severity = rlsError then
      Inc(Result);
end;

function TReportLoadResult.GetHasWarnings: Boolean;
begin
  Result := GetWarningCount > 0;
end;

function TReportLoadResult.GetHasErrors: Boolean;
begin
  Result := GetErrorCount > 0;
end;

function TReportLoadResult.GetWarnings: TArray<string>;
var
  D: TReportLoadDiagnostic;
begin
  SetLength(Result, 0);
  for D in FDiagnostics do
    if D.Severity = rlsWarning then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := D.ToString;
    end;
end;

function TReportLoadResult.GetErrors: TArray<string>;
var
  D: TReportLoadDiagnostic;
begin
  SetLength(Result, 0);
  for D in FDiagnostics do
    if D.Severity = rlsError then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := D.ToString;
    end;
end;

end.
