unit Vittix.Report.Serializer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Types,
  Vittix.Report.Model,
  Vittix.Report.Objects;

type
  TReportSerializer = class
  public
    class procedure SaveToFile(R: TReportModel; const FN: string);
    class function LoadFromFile(const FN: string): TReportModel;
    class function CloneObject(Obj: TReportObject): TReportObject;
  end;

function ObjectToJSON(Obj: TReportObject): TJSONObject;
function JSONToObject(O: TJSONObject): TReportObject;

implementation

{ ================= Helpers ================= }

function RectToJSON(const R: TRect): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('L', TJSONNumber.Create(R.Left));
  Result.AddPair('T', TJSONNumber.Create(R.Top));
  Result.AddPair('R', TJSONNumber.Create(R.Right));
  Result.AddPair('B', TJSONNumber.Create(R.Bottom));
end;

function JSONToRect(O: TJSONObject): TRect;
begin
  Result := Rect(
    O.GetValue<Integer>('L'),
    O.GetValue<Integer>('T'),
    O.GetValue<Integer>('R'),
    O.GetValue<Integer>('B')
  );
end;

function FindObjectClass(const ClassName: string): TReportObjectClass;
var
  C: TReportObjectClass;
begin
  Result := nil;
  for C in GetRegisteredReportObjects do
    if SameText(C.ClassName, ClassName) then
      Exit(C);
end;

{ ================= Object → JSON ================= }

function ObjectToJSON(Obj: TReportObject): TJSONObject;
var
  T: TReportTextObject;
begin
  Result := TJSONObject.Create;

  Result.AddPair('Class', Obj.ClassName);
  Result.AddPair('Name', Obj.Name);
  Result.AddPair('Bounds', RectToJSON(Obj.Bounds));

  if Obj is TReportTextObject then
  begin
    T := TReportTextObject(Obj);
    Result.AddPair('Text', T.Text);
    Result.AddPair('DataField', T.DataField);
    Result.AddPair('Expression', T.Expression);
    Result.AddPair('FontName', T.Font.Name);
    Result.AddPair('FontSize', TJSONNumber.Create(T.Font.Size));
  end;
end;

{ ================= JSON → Object ================= }

function JSONToObject(O: TJSONObject): TReportObject;
var
  Cls: TReportObjectClass;
  Obj: TReportObject;
  T: TReportTextObject;
begin
  Cls := FindObjectClass(O.GetValue<string>('Class'));
  if not Assigned(Cls) then
    raise Exception.Create('Unknown report object class: ' +
      O.GetValue<string>('Class'));

  Obj := Cls.Create;
  Obj.Name := O.GetValue<string>('Name', '');
  Obj.Bounds := JSONToRect(O.GetValue<TJSONObject>('Bounds'));

  if Obj is TReportTextObject then
  begin
    T := TReportTextObject(Obj);
    T.Text := O.GetValue<string>('Text', '');
    T.DataField := O.GetValue<string>('DataField', '');
    T.Expression := O.GetValue<string>('Expression', '');
    T.Font.Name := O.GetValue<string>('FontName', 'Tahoma');
    T.Font.Size := O.GetValue<Integer>('FontSize', 10);
  end;

  Result := Obj;
end;

{ ================= Clone ================= }

class function TReportSerializer.CloneObject(
  Obj: TReportObject): TReportObject;
var
  J: TJSONObject;
begin
  J := ObjectToJSON(Obj);
  try
    Result := JSONToObject(J);
  finally
    J.Free;
  end;
end;

{ ================= Save ================= }

class procedure TReportSerializer.SaveToFile(
  R: TReportModel; const FN: string);
var
  Root: TJSONObject;
  Arr: TJSONArray;
  Obj: TReportObject;
  SL: TStringList;
begin
  Root := TJSONObject.Create;
  try
    Arr := TJSONArray.Create;

    for Obj in R.Objects do
      Arr.AddElement(ObjectToJSON(Obj));

    Root.AddPair('Objects', Arr);

    SL := TStringList.Create;
    try
      SL.Text := Root.Format(2);
      SL.SaveToFile(FN);
    finally
      SL.Free;
    end;

  finally
    Root.Free;
  end;
end;

{ ================= Load ================= }

class function TReportSerializer.LoadFromFile(
  const FN: string): TReportModel;
var
  Root: TJSONObject;
  Arr: TJSONArray;
  SL: TStringList;
  i: Integer;
begin
  if not FileExists(FN) then
    raise Exception.Create('Report file not found: ' + FN);

  SL := TStringList.Create;
  Root := nil;
  try
    SL.LoadFromFile(FN);
    Root := TJSONObject.ParseJSONValue(SL.Text) as TJSONObject;

    if not Assigned(Root) then
      raise Exception.Create('Invalid JSON format in report file');

    Result := TReportModel.Create;

    try
      Arr := Root.GetValue<TJSONArray>('Objects');
      if Assigned(Arr) then
        for i := 0 to Arr.Count - 1 do
          Result.Objects.Add(
            JSONToObject(Arr.Items[i] as TJSONObject)
          );
    except
      Result.Free;
      raise;
    end;

  finally
    Root.Free;
    SL.Free;
  end;
end;

end.

