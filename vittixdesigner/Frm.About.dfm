object frmAbout: TfrmAbout
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'About Vittix Report Designer'
  ClientHeight = 340
  ClientWidth = 470
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object imgLogo: TImage
    Left = 20
    Top = 20
    Width = 132
    Height = 74
    Proportional = True
    Stretch = True
  end
  object lblProduct: TLabel
    Left = 166
    Top = 26
    Width = 200
    Height = 24
    Caption = 'Vittix Report Designer'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblVersion: TLabel
    Left = 168
    Top = 54
    Width = 200
    Height = 15
    Caption = 'Version 1.0.0.0'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 8421504
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object lblTagline: TLabel
    Left = 20
    Top = 106
    Width = 430
    Height = 32
    AutoSize = False
    Caption = 'Tagline'
    WordWrap = True
  end
  object bevSep: TBevel
    Left = 20
    Top = 146
    Width = 430
    Height = 2
    Shape = bsTopLine
  end
  object lblKeyEngine: TLabel
    Left = 20
    Top = 160
    Width = 92
    Height = 15
    Caption = 'Engine'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 8421504
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object lblValEngine: TLabel
    Left = 118
    Top = 160
    Width = 332
    Height = 15
    AutoSize = False
    Caption = 'Engine'
  end
  object lblKeyCompiler: TLabel
    Left = 20
    Top = 180
    Width = 92
    Height = 15
    Caption = 'Compiler'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 8421504
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object lblValCompiler: TLabel
    Left = 118
    Top = 180
    Width = 332
    Height = 15
    AutoSize = False
    Caption = 'Compiler'
  end
  object lblKeyPlatform: TLabel
    Left = 20
    Top = 200
    Width = 92
    Height = 15
    Caption = 'Platform'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 8421504
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object lblValPlatform: TLabel
    Left = 118
    Top = 200
    Width = 332
    Height = 15
    AutoSize = False
    Caption = 'Platform'
  end
  object lblKeyExecutable: TLabel
    Left = 20
    Top = 220
    Width = 92
    Height = 15
    Caption = 'Executable'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 8421504
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object lblValExecutable: TLabel
    Left = 118
    Top = 220
    Width = 332
    Height = 15
    AutoSize = False
    Caption = 'Executable'
    EllipsisPosition = epEndEllipsis
    ParentShowHint = False
    ShowHint = True
  end
  object lblCopyright: TLabel
    Left = 20
    Top = 250
    Width = 430
    Height = 16
    AutoSize = False
    Caption = 'Copyright'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 8421504
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object pnlButtons: TPanel
    Left = 0
    Top = 294
    Width = 470
    Height = 46
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object btnCopyDetails: TButton
      Left = 246
      Top = 10
      Width = 126
      Height = 26
      Caption = 'Copy Details'
      TabOrder = 1
      OnClick = btnCopyDetailsClick
    end
    object btnClose: TButton
      Left = 380
      Top = 10
      Width = 72
      Height = 26
      Cancel = True
      Caption = 'Close'
      Default = True
      ModalResult = 2
      TabOrder = 0
    end
  end
end
