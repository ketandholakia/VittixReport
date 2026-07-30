unit Test.Vittix.Report.Serializer;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  Vittix.Report.Model,
  Vittix.Report.Serializer,
  Vittix.Report.Objects,
  Vittix.Report.Bands;

type
  [TestFixture]
  TTestReportSerializer = class
  public
    [Test]
    procedure Test_RoundTrip_EmptyModel;
    [Test]
    procedure Test_RoundTrip_ModelWithProperties;
    [Test]
    procedure Test_CloneReport;
    [Test]
    procedure Test_CloneObject;
    [Test]
    procedure Test_Clipboard_SerializeDeserialize;
  end;

implementation

{ TTestReportSerializer }

procedure TTestReportSerializer.Test_RoundTrip_EmptyModel;
var
  M1, M2: TReportModel;
  JSON: string;
begin
  M1 := TReportModel.Create;
  try
    JSON := TReportSerializer.SaveToJSON(M1);
    M2 := TReportSerializer.LoadFromJSON(JSON);
    try
      Assert.IsNotNull(M2);
      Assert.AreEqual(0, M2.Objects.Count);
    finally
      M2.Free;
    end;
  finally
    M1.Free;
  end;
end;

procedure TTestReportSerializer.Test_RoundTrip_ModelWithProperties;
var
  M1, M2: TReportModel;
  JSON: string;
  B: TReportBand;
  L: TReportTextObject;
begin
  M1 := TReportModel.Create;
  try
    M1.Title := 'Test Title';
    M1.Author := 'Test Author';
    M1.Description := 'Test Description';
    M1.FieldNames.Add('ID');
    M1.FieldNames.Add('Name');
    
    B := TReportBand.Create;
    B.Name := 'HeaderBand';
    B.BandType := btPageHeader;
    
    L := TReportTextObject.Create;
    L.Name := 'TitleLabel';
    L.Text := 'My Report';
    B.Children.Add(L);
    
    M1.Objects.Add(B);

    JSON := TReportSerializer.SaveToJSON(M1);
    M2 := TReportSerializer.LoadFromJSON(JSON);
    try
      Assert.AreEqual('Test Title', M2.Title);
      Assert.AreEqual('Test Author', M2.Author);
      Assert.AreEqual('Test Description', M2.Description);
      Assert.AreEqual(2, M2.FieldNames.Count);
      Assert.AreEqual('ID', M2.FieldNames[0]);
      Assert.AreEqual(1, M2.Objects.Count);
      Assert.InheritsFrom(M2.Objects[0].ClassType, TReportBand);
      Assert.AreEqual('HeaderBand', M2.Objects[0].Name);
      
      var B2 := TReportBand(M2.Objects[0]);
      Assert.AreEqual(btPageHeader, B2.BandType);
      Assert.AreEqual(1, B2.Children.Count);
      Assert.AreEqual('TitleLabel', B2.Children[0].Name);
    finally
      M2.Free;
    end;
  finally
    M1.Free;
  end;
end;

procedure TTestReportSerializer.Test_CloneReport;
var
  M1, M2: TReportModel;
begin
  M1 := TReportModel.Create;
  try
    M1.Title := 'Title';
    M2 := TReportSerializer.CloneReport(M1);
    try
      Assert.IsNotNull(M2);
      Assert.AreEqual('Title', M2.Title);
    finally
      M2.Free;
    end;
  finally
    M1.Free;
  end;
end;

procedure TTestReportSerializer.Test_CloneObject;
var
  O1, O2: TReportTextObject;
begin
  O1 := TReportTextObject.Create;
  try
    O1.Name := 'Obj1';
    O1.Text := 'Text1';
    O2 := TReportSerializer.CloneObject(O1) as TReportTextObject;
    try
      Assert.IsNotNull(O2);
      Assert.AreEqual('Obj1', O2.Name);
      Assert.AreEqual('Text1', O2.Text);
    finally
      O2.Free;
    end;
  finally
    O1.Free;
  end;
end;

procedure TTestReportSerializer.Test_Clipboard_SerializeDeserialize;
var
  O1: TReportTextObject;
  O2: TReportShapeObject;
  Arr: TArray<TReportObject>;
  Arr2: TArray<TReportObject>;
  JSON: string;
begin
  O1 := TReportTextObject.Create;
  O1.Name := 'O1';
  O1.Text := 'T1';
  
  O2 := TReportShapeObject.Create;
  O2.Name := 'O2';
  
  SetLength(Arr, 2);
  Arr[0] := O1;
  Arr[1] := O2;
  
  try
    JSON := TReportSerializer.SerializeObjectListToJSON(Arr);
    Assert.IsNotEmpty(JSON);
    
    Arr2 := TReportSerializer.DeserializeObjectListFromJSON(JSON);
    try
      Assert.AreEqual(2, Length(Arr2));
      Assert.AreEqual('O1', Arr2[0].Name);
      Assert.AreEqual('O2', Arr2[1].Name);
      Assert.InheritsFrom(Arr2[0].ClassType, TReportTextObject);
      Assert.InheritsFrom(Arr2[1].ClassType, TReportShapeObject);
    finally
      for var O in Arr2 do O.Free;
    end;
  finally
    O1.Free;
    O2.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestReportSerializer);

end.
