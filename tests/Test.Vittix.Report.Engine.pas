unit Test.Vittix.Report.Engine;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects;

type
  [TestFixture]
  TTestReportEngine = class
  private
    FReport: TReportModel;
    FDataSet: TClientDataSet;
    FEngine: TReportEngine;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_H01_DatasetStatePreservation;

    [Test]
    procedure Test_C01_FooterPageBreakRecursion;
  end;

implementation

{ TTestReportEngine }

procedure TTestReportEngine.Setup;
begin
  FReport := TReportModel.Create;
  FDataSet := TClientDataSet.Create(nil);
  FDataSet.FieldDefs.Add('ID', ftInteger, 0, False);
  FDataSet.FieldDefs.Add('Name', ftString, 50, False);
  FDataSet.CreateDataSet;
  
  // Add some sample data
  FDataSet.AppendRecord([1, 'First']);
  FDataSet.AppendRecord([2, 'Second']);
  FDataSet.AppendRecord([3, 'Third']);
  
  FEngine := TReportEngine.Create(FReport, FDataSet);
end;

procedure TTestReportEngine.TearDown;
begin
  FEngine.Free;
  FDataSet.Free;
  FReport.Free;
end;

procedure TTestReportEngine.Test_H01_DatasetStatePreservation;
var
  ExpectedID: Integer;
begin
  // Set dataset to a specific position
  FDataSet.First;
  FDataSet.Next; // Now at ID = 2
  ExpectedID := FDataSet.FieldByName('ID').AsInteger;
  
  // Add a master band so the engine actually traverses the dataset
  var LMasterBand := TReportBand.Create;
  LMasterBand.BandType := btMasterData;
  LMasterBand.Height := 20;
  FReport.Objects.Add(LMasterBand);

  // Run the report
  FEngine.Prepare;

  // Verify the dataset is NOT at EOF and is at the same record
  Assert.IsFalse(FDataSet.Eof, 'Dataset should not be at EOF after Prepare');
  Assert.AreEqual(ExpectedID, FDataSet.FieldByName('ID').AsInteger, 'Dataset position should be restored');
end;

procedure TTestReportEngine.Test_C01_FooterPageBreakRecursion;
var
  LFooterBand: TReportBand;
  LChildObj: TReportTextObject;
begin
  // Set up a simple master band to force at least one page
  var LMasterBand := TReportBand.Create;
  LMasterBand.BandType := btMasterData;
  LMasterBand.Height := 20;
  FReport.Objects.Add(LMasterBand);

  // Set up a footer band with an object that requests a page break
  LFooterBand := TReportBand.Create;
  LFooterBand.BandType := btPageFooter;
  LFooterBand.Height := 50;
  
  LChildObj := TReportTextObject.Create;
  LChildObj.PageBreakBefore := True; // This is the malicious property causing C-01
  LFooterBand.Children.Add(LChildObj);
  FReport.Objects.Add(LFooterBand);

  // If C-01 is present, this will cause a Stack Overflow
  // If guarded properly, Prepare will complete successfully
  FEngine.Prepare;
  
  // If we reach here without a stack overflow, the test passes
  Assert.Pass('No infinite recursion triggered by footer page break');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestReportEngine);

end.
