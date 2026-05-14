object frmDataConnection: TfrmDataConnection
  Left = 0
  Top = 0
  Caption = 'Live Data Connection (SQLite)'
  ClientHeight = 350
  ClientWidth = 500
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  DesignSize = (
    500
    350)
  TextHeight = 15
  object lblDatabase: TLabel
    Left = 16
    Top = 16
    Width = 83
    Height = 15
    Caption = 'Database Path:'
  end
  object lblSQL: TLabel
    Left = 16
    Top = 72
    Width = 60
    Height = 15
    Caption = 'SQL Query:'
  end
  object edtDatabase: TEdit
    Left = 16
    Top = 37
    Width = 385
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
  end
  object btnBrowse: TButton
    Left = 407
    Top = 36
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Browse...'
    TabOrder = 1
    OnClick = btnBrowseClick
  end
  object mmoSQL: TMemo
    Left = 16
    Top = 93
    Width = 466
    Height = 196
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    TabOrder = 2
  end
  object btnTest: TButton
    Left = 16
    Top = 305
    Width = 100
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Test Connection'
    TabOrder = 3
    OnClick = btnTestClick
  end
  object btnOK: TButton
    Left = 326
    Top = 305
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'OK'
    TabOrder = 4
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 407
    Top = 305
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 5
  end
  object dlgOpen: TOpenDialog
    Left = 344
    Top = 8
  end
  object FDConnection: TFDConnection
    Left = 216
    Top = 160
  end
  object FDQuery: TFDQuery
    Connection = FDConnection
    Left = 304
    Top = 160
  end
  object FDPhysSQLiteDriverLink: TFDPhysSQLiteDriverLink
    Left = 216
    Top = 216
  end
end