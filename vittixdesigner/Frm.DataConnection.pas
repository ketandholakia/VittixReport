unit Frm.DataConnection;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet;

type
  TfrmDataConnection = class(TForm)
    lblDatabase: TLabel;
    edtDatabase: TEdit;
    btnBrowse: TButton;
    lblSQL: TLabel;
    mmoSQL: TMemo;
    btnTest: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    dlgOpen: TOpenDialog;
    FDConnection: TFDConnection;
    FDQuery: TFDQuery;
    FDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink;
    procedure btnBrowseClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    function GetActiveDataSet: TDataSet;
  end;

var
  frmDataConnection: TfrmDataConnection;

implementation

{$R *.dfm}

procedure TfrmDataConnection.btnBrowseClick(Sender: TObject);
begin
  dlgOpen.Filter := 'SQLite Databases (*.db;*.sqlite)|*.db;*.sqlite|All Files (*.*)|*.*';
  if dlgOpen.Execute then
    edtDatabase.Text := dlgOpen.FileName;
end;

procedure TfrmDataConnection.btnTestClick(Sender: TObject);
begin
  try
    FDConnection.Close;
    FDConnection.Params.Clear;
    FDConnection.Params.Add('DriverID=SQLite');
    FDConnection.Params.Add('Database=' + edtDatabase.Text);
    FDConnection.LoginPrompt := False;
    
    FDQuery.Close;
    FDQuery.SQL.Text := mmoSQL.Text;
    
    FDConnection.Open;
    FDQuery.Open;

    ShowMessage('Connection successful!' + sLineBreak +
                'Rows returned: ' + IntToStr(FDQuery.RecordCount));
  except
    on E: Exception do
      ShowMessage('Error: ' + E.Message);
  end;
end;

procedure TfrmDataConnection.btnOKClick(Sender: TObject);
begin
  // Validate by attempting a silent connection test
  btnTestClick(nil);
  if FDQuery.Active then
    ModalResult := mrOk;
end;

function TfrmDataConnection.GetActiveDataSet: TDataSet;
begin
  if FDQuery.Active then
    Result := FDQuery
  else
    Result := nil;
end;

end.