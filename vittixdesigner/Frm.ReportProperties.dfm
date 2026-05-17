object frmReportProperties: TfrmReportProperties
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Report Properties'
  ClientHeight = 289
  ClientWidth = 456
  Position = poMainFormCenter
  BorderIcons = [biSystemMenu]
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 15
  object lblTitle: TLabel
    Left = 16
    Top = 16
    Width = 26
    Height = 15
    Caption = 'Title'
  end
  object edtTitle: TEdit
    Left = 16
    Top = 36
    Width = 424
    Height = 23
    TabOrder = 0
  end
  object lblAuthor: TLabel
    Left = 16
    Top = 68
    Width = 38
    Height = 15
    Caption = 'Author'
  end
  object edtAuthor: TEdit
    Left = 16
    Top = 88
    Width = 424
    Height = 23
    TabOrder = 1
  end
  object lblDescription: TLabel
    Left = 16
    Top = 120
    Width = 60
    Height = 15
    Caption = 'Description'
  end
  object memDescription: TMemo
    Left = 16
    Top = 140
    Width = 424
    Height = 105
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object pnlButtons: TPanel
    Left = 0
    Top = 249
    Width = 456
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    object btnOK: TButton
      Left = 272
      Top = 8
      Width = 80
      Height = 25
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 360
      Top = 8
      Width = 80
      Height = 25
      Caption = 'Cancel'
      Cancel = True
      ModalResult = 2
      TabOrder = 1
    end
  end
end
