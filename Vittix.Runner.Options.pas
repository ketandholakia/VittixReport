unit Vittix.Runner.Options;

{
  Phase 3C-1: Configurable regression runner paths.

  CLI arguments -> parse -> validate (syntax) -> resolved TRunnerOptions.

  Free of process-global state (ParamCount/ParamStr) and filesystem access,
  so parsing is deterministic and unit-testable. The console runner builds
  the argument array from ParamStr and validates path existence afterwards.
}

interface

uses
  System.SysUtils;

type
  TRunnerOptions = record
    ReportsPath: string;
    BaselineFile: string;
    SampleDataFile: string;
    OutputPath: string;
    Filter: string;
    ScriptOnly: Boolean;
    ScriptTraceOnly: Boolean;
    KeepVectorPDF: Boolean;
    // "strict" is a reserved word in Delphi, so the escaped identifier
    // &Strict is used to expose the field as "Strict".
    &Strict: Boolean;
    Pause: Boolean;
    Help: Boolean;
    ErrorMessage: string;
  end;

function ParseOptions(const Args: TArray<string>;
  out AOptions: TRunnerOptions): Boolean;

function ParseOptionsFromCommandLine(out AOptions: TRunnerOptions): Boolean;

implementation

const
  SwitchHelp: array[0..1] of string = ('--help', '-h');
  SwitchScripts = '--scripts';
  SwitchScriptTrace = '--script-trace';
  SwitchKeepVectorPDF = '--keep-vector-pdf';
  SwitchStrict = '--strict';
  SwitchPause = '-pause';

  OptReports = '--reports';
  OptBaseline = '--baseline';
  OptSampleData = '--sample-data';
  OptOutput = '--output';
  OptFilter = '--filter';

type
  // Internal normalized token: either a switch, a value option with value,
  // or a positional argument.
  TOptKind = (okSwitch, okValue, okPositional);

function BooleanSwitchValue(const AArg: string; out AIsHelp: Boolean): Boolean;
begin
  Result := SameText(AArg, SwitchHelp[0]) or SameText(AArg, SwitchHelp[1]) or
    SameText(AArg, SwitchScripts) or SameText(AArg, SwitchScriptTrace) or
    SameText(AArg, SwitchKeepVectorPDF) or SameText(AArg, SwitchStrict) or
    SameText(AArg, SwitchPause);
  AIsHelp := SameText(AArg, SwitchHelp[0]) or SameText(AArg, SwitchHelp[1]);
end;

{ Classifies an argument. For okValue the value comes from "=" syntax
  (AInlineValue=True) or is taken from the next argument (AInlineValue=False). }
function ClassifyArg(const AArg: string; out AKind: TOptKind;
  out AName, AValue: string; out AInlineValue, AIsHelp: Boolean): Boolean;
var
  OptNames: array[0..4] of string;
  I, P: Integer;
begin
  OptNames[0] := OptReports;
  OptNames[1] := OptBaseline;
  OptNames[2] := OptSampleData;
  OptNames[3] := OptOutput;
  OptNames[4] := OptFilter;

  Result := True;
  AValue := '';
  AInlineValue := False;
  AIsHelp := False;

  if not AArg.StartsWith('-') then
  begin
    AKind := okPositional;
    AName := '';
    AValue := AArg;
    Exit;
  end;

  if BooleanSwitchValue(AArg, AIsHelp) then
  begin
    AKind := okSwitch;
    AName := AArg;
    Exit;
  end;

  // Value option via "--opt=value" syntax
  for I := Low(OptNames) to High(OptNames) do
  begin
    if SameText(Copy(AArg, 1, Length(OptNames[I]) + 1), OptNames[I] + '=') then
    begin
      P := Length(OptNames[I]) + 1;
      AKind := okValue;
      AName := OptNames[I];
      AValue := Copy(AArg, P + 1, Length(AArg));
      AInlineValue := True;
      Exit;
    end;
  end;

  // Value option via "--opt value" syntax
  for I := Low(OptNames) to High(OptNames) do
    if SameText(AArg, OptNames[I]) then
    begin
      AKind := okValue;
      AName := OptNames[I];
      Exit;
    end;

  Result := False;
  AKind := okSwitch;
  AName := '';
end;

function ParseOptions(const Args: TArray<string>;
  out AOptions: TRunnerOptions): Boolean;
var
  I: Integer;
  Arg, Name, Value: string;
  Kind: TOptKind;
  InlineValue, IsHelp, ParseOK: Boolean;
  function AssignValueOption(const AName, AValue: string): Boolean;
  begin
    Result := True;
    if AName = OptReports then
    begin
      if AOptions.ReportsPath <> '' then
        Exit(False);
      AOptions.ReportsPath := AValue;
    end
    else if AName = OptBaseline then
    begin
      if AOptions.BaselineFile <> '' then
        Exit(False);
      AOptions.BaselineFile := AValue;
    end
    else if AName = OptSampleData then
    begin
      if AOptions.SampleDataFile <> '' then
        Exit(False);
      AOptions.SampleDataFile := AValue;
    end
    else if AName = OptOutput then
    begin
      if AOptions.OutputPath <> '' then
        Exit(False);
      AOptions.OutputPath := AValue;
    end
    else if AName = OptFilter then
    begin
      if AOptions.Filter <> '' then
        Exit(False);
      AOptions.Filter := AValue;
    end;
  end;

begin
  // Safe initialization: TRunnerOptions contains managed string fields,
  // so FillChar must never be used. Default() initializes managed fields
  // correctly (empty strings, False booleans).
  AOptions := Default(TRunnerOptions);
  Result := True;

  I := 0;
  while (I <= High(Args)) and Result do
  begin
    Arg := Args[I];
    if Arg = '' then
    begin
      Inc(I);
      Continue;
    end;

    ParseOK := ClassifyArg(Arg, Kind, Name, Value, InlineValue, IsHelp);

    if not ParseOK then
    begin
      AOptions.ErrorMessage := 'Error: unknown option: ' + Arg;
      Exit(False);
    end;

    case Kind of
      okSwitch:
        begin
          if IsHelp then
            AOptions.Help := True
          else if SameText(Arg, SwitchScripts) then
            AOptions.ScriptOnly := True
          else if SameText(Arg, SwitchScriptTrace) then
            AOptions.ScriptTraceOnly := True
          else if SameText(Arg, SwitchKeepVectorPDF) then
            AOptions.KeepVectorPDF := True
          else if SameText(Arg, SwitchStrict) then
            AOptions.&Strict := True
          else if SameText(Arg, SwitchPause) then
            AOptions.Pause := True;
        end;

      okValue:
        begin
          if not InlineValue then
          begin
            if I + 1 > High(Args) then
            begin
              AOptions.ErrorMessage := 'Error: option ' + Name + ' requires a value.';
              Exit(False);
            end;
            Value := Args[I + 1];
            if Value.StartsWith('-') then
            begin
              AOptions.ErrorMessage := 'Error: option ' + Name + ' requires a value.';
              Exit(False);
            end;
            Inc(I);
          end;
          if Value = '' then
          begin
            AOptions.ErrorMessage := 'Error: option ' + Name + ' requires a value.';
            Exit(False);
          end;
          if not AssignValueOption(Name, Value) then
          begin
            if Name = OptFilter then
              AOptions.ErrorMessage :=
                'Error: duplicate report filter. Use either --filter or a positional report name, not both.'
            else
              AOptions.ErrorMessage := 'Error: duplicate option ' + Name + '.';
            Exit(False);
          end;
        end;

      okPositional:
        begin
          if AOptions.Filter <> '' then
          begin
            AOptions.ErrorMessage :=
              'Error: duplicate report filter. Use either --filter or a positional report name, not both.';
            Exit(False);
          end;
          AOptions.Filter := Value;
        end;
    end;

    Inc(I);
  end;
end;

function ParseOptionsFromCommandLine(out AOptions: TRunnerOptions): Boolean;
var
  I: Integer;
  Args: TArray<string>;
begin
  SetLength(Args, ParamCount);
  for I := 1 to ParamCount do
    Args[I - 1] := ParamStr(I);
  Result := ParseOptions(Args, AOptions);
end;

end.
