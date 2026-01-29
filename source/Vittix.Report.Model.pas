unit Vittix.Report.Model;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vittix.Report.Objects;

type
  TReportModel = class(TPersistent)
  private
    FObjects: TObjectList<TReportObject>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    property Objects: TObjectList<TReportObject>
      read FObjects;
  end;

implementation

{ ================= Constructor ================= }

constructor TReportModel.Create;
begin
  inherited;
  FObjects := TObjectList<TReportObject>.Create(True); // owns objects
end;

destructor TReportModel.Destroy;
begin
  FObjects.Free;
  inherited;
end;

{ ================= Clear ================= }

procedure TReportModel.Clear;
begin
  FObjects.Clear;
end;

end.
