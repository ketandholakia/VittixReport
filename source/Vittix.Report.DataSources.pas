unit Vittix.Report.DataSources;

interface

uses
  System.SysUtils,
  Data.DB;

type
  EReportDataSourceError = class(Exception);

  IReportDataSource = interface
    ['{C9CDB1B8-0A09-4E53-98A9-3B8AA850BEA5}']
    procedure First;
    procedure Next;
    function EOF: Boolean;
    function Active: Boolean;
    function FieldExists(const AFieldName: string): Boolean;
    function FieldAsString(const AFieldName: string): string;
    function RecordCount: Integer;
  end;

  TCustomReportDataSource = class(TInterfacedObject, IReportDataSource)
  public
    procedure First; virtual; abstract;
    procedure Next; virtual; abstract;
    function EOF: Boolean; virtual; abstract;
    function Active: Boolean; virtual; abstract;
    function FieldExists(const AFieldName: string): Boolean; virtual; abstract;
    function FieldAsString(const AFieldName: string): string; virtual; abstract;
    function RecordCount: Integer; virtual; abstract;
  end;

  TDataSetReportDataSource = class(TCustomReportDataSource)
  private
    FDataSet: TDataSet;
  public
    constructor Create(ADataSet: TDataSet);
    procedure First; override;
    procedure Next; override;
    function EOF: Boolean; override;
    function Active: Boolean; override;
    function FieldExists(const AFieldName: string): Boolean; override;
    function FieldAsString(const AFieldName: string): string; override;
    function RecordCount: Integer; override;

    property DataSet: TDataSet read FDataSet;
  end;

  TJsonReportDataSource = class(TCustomReportDataSource)
  public
    procedure First; override;
    procedure Next; override;
    function EOF: Boolean; override;
    function Active: Boolean; override;
    function FieldExists(const AFieldName: string): Boolean; override;
    function FieldAsString(const AFieldName: string): string; override;
    function RecordCount: Integer; override;
  end;

  TCsvReportDataSource = class(TCustomReportDataSource)
  public
    procedure First; override;
    procedure Next; override;
    function EOF: Boolean; override;
    function Active: Boolean; override;
    function FieldExists(const AFieldName: string): Boolean; override;
    function FieldAsString(const AFieldName: string): string; override;
    function RecordCount: Integer; override;
  end;

  TRestReportDataSource = class(TCustomReportDataSource)
  public
    procedure First; override;
    procedure Next; override;
    function EOF: Boolean; override;
    function Active: Boolean; override;
    function FieldExists(const AFieldName: string): Boolean; override;
    function FieldAsString(const AFieldName: string): string; override;
    function RecordCount: Integer; override;
  end;

implementation

procedure NotImplemented(const ASourceName: string);
begin
  raise EReportDataSourceError.CreateFmt('%s is a scaffold. Add concrete provider logic.', [ASourceName]);
end;

constructor TDataSetReportDataSource.Create(ADataSet: TDataSet);
begin
  inherited Create;
  FDataSet := ADataSet;
end;

procedure TDataSetReportDataSource.First;
begin
  if Assigned(FDataSet) and FDataSet.Active then
    FDataSet.First;
end;

procedure TDataSetReportDataSource.Next;
begin
  if Assigned(FDataSet) and FDataSet.Active then
    FDataSet.Next;
end;

function TDataSetReportDataSource.EOF: Boolean;
begin
  Result := not Assigned(FDataSet) or not FDataSet.Active or FDataSet.Eof;
end;

function TDataSetReportDataSource.Active: Boolean;
begin
  Result := Assigned(FDataSet) and FDataSet.Active;
end;

function TDataSetReportDataSource.FieldExists(const AFieldName: string): Boolean;
begin
  Result := Assigned(FDataSet) and Assigned(FDataSet.FindField(AFieldName));
end;

function TDataSetReportDataSource.FieldAsString(const AFieldName: string): string;
var
  Field: TField;
begin
  Result := '';
  if not Assigned(FDataSet) or not FDataSet.Active then
    Exit;

  Field := FDataSet.FindField(AFieldName);
  if Assigned(Field) then
    Result := Field.AsString;
end;

function TDataSetReportDataSource.RecordCount: Integer;
begin
  if not Assigned(FDataSet) or not FDataSet.Active then
    Exit(0);
  try
    Result := FDataSet.RecordCount;
  except
    Result := 0;
  end;
end;

procedure TJsonReportDataSource.First;
begin
  NotImplemented('JSON data source');
end;

procedure TJsonReportDataSource.Next;
begin
  NotImplemented('JSON data source');
end;

function TJsonReportDataSource.EOF: Boolean;
begin
  NotImplemented('JSON data source');
  Result := True;
end;

function TJsonReportDataSource.Active: Boolean;
begin
  NotImplemented('JSON data source');
  Result := False;
end;

function TJsonReportDataSource.FieldExists(const AFieldName: string): Boolean;
begin
  NotImplemented('JSON data source');
  Result := False;
end;

function TJsonReportDataSource.FieldAsString(const AFieldName: string): string;
begin
  NotImplemented('JSON data source');
  Result := '';
end;

function TJsonReportDataSource.RecordCount: Integer;
begin
  NotImplemented('JSON data source');
  Result := 0;
end;

procedure TCsvReportDataSource.First;
begin
  NotImplemented('CSV data source');
end;

procedure TCsvReportDataSource.Next;
begin
  NotImplemented('CSV data source');
end;

function TCsvReportDataSource.EOF: Boolean;
begin
  NotImplemented('CSV data source');
  Result := True;
end;

function TCsvReportDataSource.Active: Boolean;
begin
  NotImplemented('CSV data source');
  Result := False;
end;

function TCsvReportDataSource.FieldExists(const AFieldName: string): Boolean;
begin
  NotImplemented('CSV data source');
  Result := False;
end;

function TCsvReportDataSource.FieldAsString(const AFieldName: string): string;
begin
  NotImplemented('CSV data source');
  Result := '';
end;

function TCsvReportDataSource.RecordCount: Integer;
begin
  NotImplemented('CSV data source');
  Result := 0;
end;

procedure TRestReportDataSource.First;
begin
  NotImplemented('REST data source');
end;

procedure TRestReportDataSource.Next;
begin
  NotImplemented('REST data source');
end;

function TRestReportDataSource.EOF: Boolean;
begin
  NotImplemented('REST data source');
  Result := True;
end;

function TRestReportDataSource.Active: Boolean;
begin
  NotImplemented('REST data source');
  Result := False;
end;

function TRestReportDataSource.FieldExists(const AFieldName: string): Boolean;
begin
  NotImplemented('REST data source');
  Result := False;
end;

function TRestReportDataSource.FieldAsString(const AFieldName: string): string;
begin
  NotImplemented('REST data source');
  Result := '';
end;

function TRestReportDataSource.RecordCount: Integer;
begin
  NotImplemented('REST data source');
  Result := 0;
end;

end.
