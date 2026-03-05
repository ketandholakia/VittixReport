unit Vittix.Report.ObjectRegistry;

interface

uses
  System.SysUtils,
  Vittix.Report.Objects;

procedure RegisterObject(AClass: TReportObjectClass);
function RegisteredObjects: TArray<TReportObjectClass>;
function FindRegisteredObjectClass(const AClassName: string): TReportObjectClass;

implementation

procedure RegisterObject(AClass: TReportObjectClass);
begin
  RegisterReportObject(AClass);
end;

function RegisteredObjects: TArray<TReportObjectClass>;
begin
  Result := GetRegisteredReportObjects;
end;

function FindRegisteredObjectClass(const AClassName: string): TReportObjectClass;
var
  ObjClass: TReportObjectClass;
begin
  Result := nil;
  for ObjClass in GetRegisteredReportObjects do
    if SameText(ObjClass.ClassName, AClassName) then
      Exit(ObjClass);
end;

end.
