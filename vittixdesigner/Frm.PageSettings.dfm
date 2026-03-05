object frmPageSettings: TfrmPageSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Page Setup'
  ClientHeight = 420
  ClientWidth = 460
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
    Align = alTop  Height = 36
    BevelOuter = bvNone  Color = $002C2C2C  Caption = ''
    object lblCaption: TLabel
      Left = 10  Top = 8
      Caption = 'Page Setup — Configure paper, orientation and margins'
      Font.Color = clWhite  Font.Style = [fsBold]  ParentFont = False
    end
  end

  object pnlBottom: TPanel
    Align = alBottom  Height = 44
    BevelOuter = bvNone  Caption = ''
    object btnOK: TButton
      Left = 244  Top = 8  Width = 80  Height = 28
      Caption = 'OK'  Default = True  TabOrder = 0  OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 332  Top = 8  Width = 80  Height = 28
      Caption = 'Cancel'  Cancel = True  ModalResult = 2  TabOrder = 1
    end
    object btnDefaults: TButton
      Left = 10   Top = 8  Width = 100  Height = 28
      Caption = 'Reset Defaults'  TabOrder = 2  OnClick = btnDefaultsClick
    end
  end

  object grpPaper: TGroupBox
    Left = 12  Top = 44  Width = 200  Height = 200
    Caption = ' Paper '

    object lblPaper: TLabel
      Left = 8  Top = 22  Caption = 'Size:'
    end
    object cboPaper: TComboBox
      Left = 8  Top = 38  Width = 178  Height = 23
      Style = csDropDownList  TabOrder = 0
      OnChange = cboPaperChange
    end

    object rdbPortrait: TRadioButton
      Left = 8  Top = 70  Width = 90  Height = 22
      Caption = 'Portrait'  Checked = True  TabOrder = 1
      OnClick = rdbOrientationClick
    end
    object rdbLandscape: TRadioButton
      Left = 8  Top = 94  Width = 100  Height = 22
      Caption = 'Landscape'  TabOrder = 2
      OnClick = rdbOrientationClick
    end

    object lblCustomW: TLabel
      Left = 8  Top = 126  Caption = 'Width (px):'
    end
    object edtCustomW: TEdit
      Left = 8  Top = 142  Width = 80  Height = 23  Text = '793'
      Enabled = False  TabOrder = 3  OnChange = edtChange
    end

    object lblCustomH: TLabel
      Left = 96  Top = 126  Caption = 'Height (px):'
    end
    object edtCustomH: TEdit
      Left = 96  Top = 142  Width = 80  Height = 23  Text = '1122'
      Enabled = False  TabOrder = 4  OnChange = edtChange
    end
  end

  object grpMargins: TGroupBox
    Left = 226  Top = 44  Width = 220  Height = 200
    Caption = ' Margins (pixels @ 96 DPI) '

    object lblLeft: TLabel
      Left = 8   Top = 22  Caption = 'Left:'
    end
    object edtLeft: TEdit
      Left = 8   Top = 38  Width = 80  Height = 23  Text = '40'
      TabOrder = 0  OnChange = edtChange
    end

    object lblTop: TLabel
      Left = 100  Top = 22  Caption = 'Top:'
    end
    object edtTop: TEdit
      Left = 100  Top = 38  Width = 80  Height = 23  Text = '40'
      TabOrder = 1  OnChange = edtChange
    end

    object lblRight: TLabel
      Left = 8   Top = 72  Caption = 'Right:'
    end
    object edtRight: TEdit
      Left = 8   Top = 88  Width = 80  Height = 23  Text = '40'
      TabOrder = 2  OnChange = edtChange
    end

    object lblBottom: TLabel
      Left = 100  Top = 72  Caption = 'Bottom:'
    end
    object edtBottom: TEdit
      Left = 100  Top = 88  Width = 80  Height = 23  Text = '40'
      TabOrder = 3  OnChange = edtChange
    end
  end

  object pnlPreview: TPanel
    Left = 12  Top = 254  Width = 434  Height = 52
    BevelOuter = bvLowered  Caption = ''
    Color = $00FAFAFA

    object lblPreview: TLabel
      Left = 8  Top = 6
      Caption = 'Preview:'  Font.Style = [fsBold]
    end
    object lblDimensions: TLabel
      Left = 8  Top = 24
      Caption = 'Page: 793 × 1122 px    Content: 713 × 1042 px    @96 DPI'
      Font.Color = clNavy
    end
  end
end
