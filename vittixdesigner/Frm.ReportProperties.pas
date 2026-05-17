unit Frm.ReportProperties;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Forms;

type
  TfrmReportProperties = class(TForm)
    lblTitle: TLabel;
    edtTitle: TEdit;
    lblAuthor: TLabel;
    edtAuthor: TEdit;
    lblDescription: TLabel;
    memDescription: TMemo;
    pnlButtons: TPanel;
    btnOK: TButton;
    btnCancel: TButton;
  public
    procedure LoadValues(const ATitle, AAuthor, ADescription: string);
    function ReportTitle: string;
    function ReportAuthor: string;
    function ReportDescription: string;
  end;

implementation

{$R *.dfm}

procedure TfrmReportProperties.LoadValues(const ATitle, AAuthor,
  ADescription: string);
begin
  edtTitle.Text := ATitle;
  edtAuthor.Text := AAuthor;
  memDescription.Lines.Text := ADescription;
end;

function TfrmReportProperties.ReportTitle: string;
begin
  Result := edtTitle.Text;
end;

function TfrmReportProperties.ReportAuthor: string;
begin
  Result := edtAuthor.Text;
end;

function TfrmReportProperties.ReportDescription: string;
begin
  Result := memDescription.Lines.Text;
end;

end.
