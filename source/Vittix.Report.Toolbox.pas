unit Vittix.Report.Toolbox;

interface

uses
  System.Classes,
  Vcl.StdCtrls,
  Vittix.Report.Objects;

type
  TVittixReportToolbox = class(TListBox)
  private
    FOnToolSelected: TNotifyEvent;
    FSelectedClass: TReportObjectClass;

    procedure ReloadTools;
    procedure UpdateSelection;

  protected
    procedure Click; override;

  public
    constructor Create(AOwner: TComponent); override;

    procedure RefreshToolList;

    property SelectedObjectClass: TReportObjectClass
      read FSelectedClass;
  published
    property OnToolSelected: TNotifyEvent
      read FOnToolSelected write FOnToolSelected;
  end;

procedure Register;

implementation

{ ================= Constructor ================= }

constructor TVittixReportToolbox.Create(AOwner: TComponent);
begin
  inherited;

  Style := lbStandard;
  Sorted := False;
end;

{ ================= Load Tools ================= }

procedure TVittixReportToolbox.ReloadTools;
var
  C: TReportObjectClass;
begin
  Items.BeginUpdate;
  try
    Items.Clear;

    for C in GetRegisteredReportObjects do
      Items.AddObject(C.ClassName, TObject(C));

  finally
    Items.EndUpdate;
  end;

  if Items.Count > 0 then
    ItemIndex := 0;

  UpdateSelection;
end;

procedure TVittixReportToolbox.RefreshToolList;
begin
  ReloadTools;
end;

{ ================= Selection ================= }

procedure TVittixReportToolbox.UpdateSelection;
begin
  if ItemIndex >= 0 then
    FSelectedClass :=
      TReportObjectClass(Items.Objects[ItemIndex])
  else
    FSelectedClass := nil;
end;

procedure TVittixReportToolbox.Click;
begin
  inherited;
  UpdateSelection;
  
  if Assigned(FOnToolSelected) then
    FOnToolSelected(Self);
end;

{ ================= Register ================= }

procedure Register;
begin
  RegisterComponents('Vittix Reporting', [TVittixReportToolbox]);
end;

end.
