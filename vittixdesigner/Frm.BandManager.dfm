object frmBandManager: TfrmBandManager
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Band Manager'
  ClientHeight = 560
  ClientWidth = 540
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15

  object pnlTop: TPanel
    Align = alTop
    Height = 36
    BevelOuter = bvNone
    Color = $002C2C2C
    Caption = ''
    object lblTitle: TLabel
      Left = 10
      Top = 8
      Caption = 'Band Manager — Add, remove and configure report bands'
      Font.Color = clWhite
      Font.Style = [fsBold]
      ParentFont = False
    end
  end

  object pnlBottom: TPanel
    Align = alBottom
    Height = 40
    BevelOuter = bvNone
    Caption = ''
    object btnOK: TButton
      Left = 360
      Top = 8
      Width = 80
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 0
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 448
      Top = 8
      Width = 80
      Height = 26
      Caption = 'Cancel'
      Cancel = True
      ModalResult = 2
      TabOrder = 1
    end
  end

  object pnlList: TPanel
    Align = alLeft
    Width = 220
    BevelOuter = bvNone
    Caption = ''

    object lblBands: TLabel
      Align = alTop
      Height = 20
      Caption = '  Bands in Report'
      Font.Style = [fsBold]
    end

    object lstBands: TListBox
      Align = alClient
      TabOrder = 0
      OnClick = lstBandsClick
    end

    object pnlListBtns: TPanel
      Align = alBottom
      Height = 36
      BevelOuter = bvNone
      Caption = ''
      object btnAddBand: TButton
        Left = 2   Top = 5  Width = 50  Height = 26
        Caption = 'Add'
        TabOrder = 0  OnClick = btnAddBandClick
      end
      object btnDelBand: TButton
        Left = 54  Top = 5  Width = 50  Height = 26
        Caption = 'Delete'
        TabOrder = 1  OnClick = btnDelBandClick
      end
      object btnMoveUp: TButton
        Left = 106 Top = 5  Width = 50  Height = 26
        Caption = 'Up'
        TabOrder = 2  OnClick = btnMoveUpClick
      end
      object btnMoveDown: TButton
        Left = 158 Top = 5  Width = 50  Height = 26
        Caption = 'Down'
        TabOrder = 3  OnClick = btnMoveDownClick
      end
    end
  end

  object splH: TSplitter
    Align = alLeft
    Width = 4
    Color = $00D0D0D0
    ParentColor = False
  end

  object pnlEdit: TPanel
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Padding.Left = 10
    Padding.Right = 10
    Padding.Top = 6
    Padding.Bottom = 6

    object lblEditTitle: TLabel
      Left = 10  Top = 6
      Caption = 'Band Properties'
      Font.Style = [fsBold]
    end

    object lblBandType: TLabel
      Left = 10  Top = 32  Caption = 'Band Type:'
    end
    object cboBandType: TComboBox
      Left = 110  Top = 28  Width = 190  Height = 23
      Style = csDropDownList
      TabOrder = 0
    end

    object lblHeight: TLabel
      Left = 10  Top = 60  Caption = 'Height (px):'
    end
    object edtHeight: TEdit
      Left = 110  Top = 56  Width = 80  Height = 23  Text = '40'
      TabOrder = 1
    end

    object lblGroupField: TLabel
      Left = 10  Top = 92  Caption = 'Group Field:'
    end
    object edtGroupField: TEdit
      Left = 110  Top = 88  Width = 190  Height = 23  Text = ''
      TabOrder = 2
    end

    object lblGroupLevel: TLabel
      Left = 10  Top = 124  Caption = 'Group Level:'
    end
    object edtGroupLevel: TEdit
      Left = 110  Top = 120  Width = 60  Height = 23  Text = '0'
      TabOrder = 3
    end

    object chkCanGrow: TCheckBox
      Left = 10  Top = 154  Width = 140  Height = 22
      Caption = 'Can Grow'
      TabOrder = 4
    end
    object chkCanShrink: TCheckBox
      Left = 10  Top = 178  Width = 140  Height = 22
      Caption = 'Can Shrink'
      TabOrder = 5
    end
    object chkStartNewPage: TCheckBox
      Left = 10  Top = 202  Width = 180  Height = 22
      Caption = 'Start on New Page'
      TabOrder = 6
    end
    object chkTransparent: TCheckBox
      Left = 10  Top = 226  Width = 200  Height = 22
      Caption = 'Background Transparent'
      TabOrder = 7
    end

    object lblBackColor: TLabel
      Left = 10  Top = 258  Caption = 'Background Color:'
    end
    object pnlColorSwatch: TPanel
      Left = 140  Top = 254  Width = 50  Height = 22
      BevelOuter = bvSunken  Caption = ''
      Color = clWhite
    end
    object btnPickColor: TButton
      Left = 196  Top = 253  Width = 80  Height = 24
      Caption = 'Pick...'
      TabOrder = 8
      OnClick = btnPickColorClick
    end
  end

  object dlgColor: TColorDialog  end
end
