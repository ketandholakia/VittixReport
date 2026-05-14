object frmBandManager: TfrmBandManager
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Band Manager'
  ClientHeight = 560
  ClientWidth = 540
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object splH: TSplitter
    Left = 0
    Top = 36
    Width = 4
    Height = 484
    Color = 13684944
    ParentColor = False
    ExplicitTop = 0
    ExplicitHeight = 100
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 540
    Height = 36
    Align = alTop
    BevelOuter = bvNone
    Color = 2894892
    TabOrder = 0
    object lblTitle: TLabel
      Left = 10
      Top = 8
      Width = 331
      Height = 15
      Caption = 'Band Manager '#226#8364#8221' Add, remove and configure report bands'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 520
    Width = 540
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnOK: TButton
      Left = 360
      Top = 8
      Width = 80
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 448
      Top = 8
      Width = 80
      Height = 26
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
  object pnlList: TPanel
    Left = 4
    Top = 36
    Width = 220
    Height = 484
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 2
    object lblBands: TLabel
      Left = 0
      Top = 0
      Width = 220
      Height = 15
      Align = alTop
      Caption = '  Bands in Report'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      ExplicitWidth = 94
    end
    object lstBands: TListBox
      Left = 0
      Top = 15
      Width = 220
      Height = 433
      Align = alClient
      ItemHeight = 15
      TabOrder = 0
      OnClick = lstBandsClick
    end
    object pnlListBtns: TPanel
      Left = 0
      Top = 448
      Width = 220
      Height = 36
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 1
      object btnAddBand: TButton
        Left = 2
        Top = 5
        Width = 50
        Height = 26
        Caption = 'Add'
        TabOrder = 0
        OnClick = btnAddBandClick
      end
      object btnDelBand: TButton
        Left = 54
        Top = 5
        Width = 50
        Height = 26
        Caption = 'Delete'
        TabOrder = 1
        OnClick = btnDelBandClick
      end
      object btnMoveUp: TButton
        Left = 106
        Top = 5
        Width = 50
        Height = 26
        Caption = 'Up'
        TabOrder = 2
        OnClick = btnMoveUpClick
      end
      object btnMoveDown: TButton
        Left = 158
        Top = 5
        Width = 50
        Height = 26
        Caption = 'Down'
        TabOrder = 3
        OnClick = btnMoveDownClick
      end
    end
  end
  object pnlEdit: TPanel
    Left = 224
    Top = 36
    Width = 316
    Height = 484
    Align = alClient
    BevelOuter = bvNone
    Padding.Left = 10
    Padding.Top = 6
    Padding.Right = 10
    Padding.Bottom = 6
    TabOrder = 3
    object lblEditTitle: TLabel
      Left = 10
      Top = 6
      Width = 89
      Height = 15
      Caption = 'Band Properties'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblBandType: TLabel
      Left = 10
      Top = 32
      Width = 58
      Height = 15
      Caption = 'Band Type:'
    end
    object lblHeight: TLabel
      Left = 10
      Top = 60
      Width = 62
      Height = 15
      Caption = 'Height (px):'
    end
    object lblDataSetName: TLabel
      Left = 10
      Top = 92
      Width = 79
      Height = 15
      Caption = 'DataSet Name:'
    end
    object lblGroupField: TLabel
      Left = 10
      Top = 124
      Width = 64
      Height = 15
      Caption = 'Group Field:'
    end
    object lblGroupLevel: TLabel
      Left = 10
      Top = 156
      Width = 66
      Height = 15
      Caption = 'Group Level:'
    end
    object lblBackColor: TLabel
      Left = 10
      Top = 290
      Width = 99
      Height = 15
      Caption = 'Background Color:'
    end
    object cboBandType: TComboBox
      Left = 110
      Top = 28
      Width = 190
      Height = 23
      Style = csDropDownList
      TabOrder = 0
    end
    object edtHeight: TEdit
      Left = 110
      Top = 56
      Width = 80
      Height = 23
      TabOrder = 1
      Text = '40'
    end
    object cboDataSetName: TComboBox
      Left = 110
      Top = 88
      Width = 190
      Height = 23
      Style = csDropDown
      TabOrder = 2
    end
    object edtGroupField: TEdit
      Left = 110
      Top = 120
      Width = 190
      Height = 23
      TabOrder = 3
    end
    object edtGroupLevel: TEdit
      Left = 110
      Top = 152
      Width = 60
      Height = 23
      TabOrder = 4
      Text = '0'
    end
    object chkCanGrow: TCheckBox
      Left = 10
      Top = 186
      Width = 140
      Height = 22
      Caption = 'Can Grow'
      TabOrder = 5
    end
    object chkCanShrink: TCheckBox
      Left = 10
      Top = 210
      Width = 140
      Height = 22
      Caption = 'Can Shrink'
      TabOrder = 6
    end
    object chkStartNewPage: TCheckBox
      Left = 10
      Top = 234
      Width = 180
      Height = 22
      Caption = 'Start on New Page'
      TabOrder = 7
    end
    object chkTransparent: TCheckBox
      Left = 10
      Top = 258
      Width = 200
      Height = 22
      Caption = 'Background Transparent'
      TabOrder = 8
    end
    object pnlColorSwatch: TPanel
      Left = 140
      Top = 318
      Width = 50
      Height = 22
      Color = clWhite
      TabOrder = 10
    end
    object btnPickColor: TButton
      Left = 196
      Top = 317
      Width = 80
      Height = 24
      Caption = 'Pick...'
      TabOrder = 9
      OnClick = btnPickColorClick
    end
  end
  object dlgColor: TColorDialog
  end
end
