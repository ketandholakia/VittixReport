object frmReportDesignerDemo: TfrmReportDesignerDemo
  Left = 0
  Top = 0
  Caption = 'Vittix Report Designer Demo'
  ClientHeight = 661
  ClientWidth = 1084
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnlLeft: TPanel
    Left = 0
    Top = 88
    Width = 225
    Height = 550
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object Splitter1: TSplitter
      Left = 0
      Top = 245
      Width = 225
      Height = 5
      Cursor = crVSplit
      Align = alTop
      ExplicitTop = 237
      ExplicitWidth = 193
    end
    object pnlToolbox: TPanel
      Left = 0
      Top = 0
      Width = 225
      Height = 245
      Align = alTop
      BevelOuter = bvNone
      Caption = 'pnlToolbox'
      ShowCaption = False
      TabOrder = 0
      object lblToolbox: TLabel
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 219
        Height = 13
        Align = alTop
        Caption = 'Toolbox - Select tool to insert:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
        ExplicitWidth = 170
      end
    end
    object pnlProperties: TPanel
      Left = 0
      Top = 250
      Width = 225
      Height = 300
      Align = alClient
      BevelOuter = bvNone
      Caption = 'pnlProperties'
      ShowCaption = False
      TabOrder = 1
      object lblProperties: TLabel
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 219
        Height = 13
        Align = alTop
        Caption = 'Properties:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
        ExplicitWidth = 62
      end
      object pnlPropertyGrid: TPanel
        Left = 0
        Top = 19
        Width = 225
        Height = 281
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 0
        object memoProperties: TMemo
          Left = 0
          Top = 0
          Width = 225
          Height = 281
          Align = alClient
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Courier New'
          Font.Style = []
          ParentFont = False
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 638
    Width = 1084
    Height = 23
    Panels = <
      item
        Width = 150
      end
      item
        Width = 200
      end
      item
        Width = 50
      end>
  end
  object pnlDesigner: TPanel
    Left = 225
    Top = 88
    Width = 859
    Height = 550
    Align = alClient
    BevelOuter = bvNone
    Caption = 'pnlDesigner'
    ShowCaption = False
    TabOrder = 2
  end
  object ToolBar1: TToolBar
    Left = 0
    Top = 41
    Width = 1084
    Height = 47
    ButtonHeight = 38
    ButtonWidth = 39
    Caption = 'ToolBar1'
    Images = ImageList1
    TabOrder = 3
    object btnNew: TToolButton
      Left = 0
      Top = 0
      Hint = 'New Report'
      Caption = 'New'
      ImageIndex = 0
      ParentShowHint = False
      ShowHint = True
      OnClick = mnuNewClick
    end
    object btnOpen: TToolButton
      Left = 39
      Top = 0
      Hint = 'Open Report'
      Caption = 'Open'
      ImageIndex = 1
      ParentShowHint = False
      ShowHint = True
      OnClick = mnuOpenClick
    end
    object btnSave: TToolButton
      Left = 78
      Top = 0
      Hint = 'Save Report'
      Caption = 'Save'
      ImageIndex = 2
      ParentShowHint = False
      ShowHint = True
      OnClick = mnuSaveClick
    end
    object ToolButton1: TToolButton
      Left = 117
      Top = 0
      Width = 8
      Caption = 'ToolButton1'
      ImageIndex = 3
      Style = tbsSeparator
    end
    object btnUndo: TToolButton
      Left = 125
      Top = 0
      Hint = 'Undo (Ctrl+Z)'
      Caption = 'Undo'
      ImageIndex = 3
      ParentShowHint = False
      ShowHint = True
      OnClick = mnuUndoClick
    end
    object btnRedo: TToolButton
      Left = 164
      Top = 0
      Hint = 'Redo (Ctrl+Y)'
      Caption = 'Redo'
      ImageIndex = 4
      ParentShowHint = False
      ShowHint = True
      OnClick = mnuRedoClick
    end
    object ToolButton2: TToolButton
      Left = 203
      Top = 0
      Width = 8
      Caption = 'ToolButton2'
      ImageIndex = 5
      Style = tbsSeparator
    end
    object btnCopy: TToolButton
      Left = 211
      Top = 0
      Hint = 'Copy (Ctrl+C)'
      Caption = 'Copy'
      ImageIndex = 5
      ParentShowHint = False
      ShowHint = True
      OnClick = mnuCopyClick
    end
    object btnPaste: TToolButton
      Left = 250
      Top = 0
      Hint = 'Paste (Ctrl+V)'
      Caption = 'Paste'
      ImageIndex = 6
      ParentShowHint = False
      ShowHint = True
      OnClick = mnuPasteClick
    end
    object ToolButton3: TToolButton
      Left = 289
      Top = 0
      Width = 8
      Caption = 'ToolButton3'
      ImageIndex = 7
      Style = tbsSeparator
    end
    object btnPreview: TToolButton
      Left = 297
      Top = 0
      Hint = 'Preview Report'
      Caption = 'Preview'
      ImageIndex = 7
      ParentShowHint = False
      ShowHint = True
      OnClick = mnuPreviewClick
    end
    object btnExportPDF: TToolButton
      Left = 336
      Top = 0
      Hint = 'Export to PDF'
      Caption = 'PDF'
      ImageIndex = 8
      ParentShowHint = False
      ShowHint = True
      OnClick = mnuExportPDFClick
    end
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1084
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 4
    object lblTitle: TLabel
      Left = 8
      Top = 8
      Width = 235
      Height = 19
      Caption = 'Vittix Report Designer Demo'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clNavy
      Font.Height = -16
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblDataSource: TLabel
      Left = 480
      Top = 12
      Width = 63
      Height = 13
      Caption = 'Data Source:'
    end
    object cbDataSource: TComboBox
      Left = 553
      Top = 9
      Width = 200
      Height = 21
      Style = csDropDownList
      TabOrder = 0
      OnChange = cbDataSourceChange
    end
    object btnRefreshData: TButton
      Left = 759
      Top = 7
      Width = 90
      Height = 25
      Caption = 'Refresh Data'
      TabOrder = 1
      OnClick = btnRefreshDataClick
    end
  end
  object MainMenu1: TMainMenu
    Left = 408
    Top = 200
    object mnuFile: TMenuItem
      Caption = '&File'
      object mnuNew: TMenuItem
        Caption = '&New'
        ShortCut = 16462
        OnClick = mnuNewClick
      end
      object mnuOpen: TMenuItem
        Caption = '&Open...'
        ShortCut = 16463
        OnClick = mnuOpenClick
      end
      object mnuSave: TMenuItem
        Caption = '&Save'
        ShortCut = 16467
        OnClick = mnuSaveClick
      end
      object mnuSaveAs: TMenuItem
        Caption = 'Save &As...'
        OnClick = mnuSaveAsClick
      end
      object N1: TMenuItem
        Caption = '-'
      end
      object mnuExit: TMenuItem
        Caption = 'E&xit'
        OnClick = mnuExitClick
      end
    end
    object mnuEdit: TMenuItem
      Caption = '&Edit'
      object mnuUndo: TMenuItem
        Caption = '&Undo'
        ShortCut = 16474
        OnClick = mnuUndoClick
      end
      object mnuRedo: TMenuItem
        Caption = '&Redo'
        ShortCut = 16473
        OnClick = mnuRedoClick
      end
      object N2: TMenuItem
        Caption = '-'
      end
      object mnuCut: TMenuItem
        Caption = 'Cu&t'
        ShortCut = 16472
      end
      object mnuCopy: TMenuItem
        Caption = '&Copy'
        ShortCut = 16451
        OnClick = mnuCopyClick
      end
      object mnuPaste: TMenuItem
        Caption = '&Paste'
        ShortCut = 16470
        OnClick = mnuPasteClick
      end
      object mnuDelete: TMenuItem
        Caption = '&Delete'
        ShortCut = 46
      end
    end
    object mnuAlign: TMenuItem
      Caption = '&Align'
      object mnuAlignLeft: TMenuItem
        Caption = 'Align &Left'
        ShortCut = 49228
        OnClick = mnuAlignLeftClick
      end
      object mnuAlignRight: TMenuItem
        Caption = 'Align &Right'
        ShortCut = 49234
        OnClick = mnuAlignRightClick
      end
      object mnuAlignTop: TMenuItem
        Caption = 'Align &Top'
        ShortCut = 49236
        OnClick = mnuAlignTopClick
      end
      object mnuAlignBottom: TMenuItem
        Caption = 'Align &Bottom'
        ShortCut = 49218
        OnClick = mnuAlignBottomClick
      end
      object N3: TMenuItem
        Caption = '-'
      end
      object mnuSameWidth: TMenuItem
        Caption = 'Same &Width'
        OnClick = mnuSameWidthClick
      end
      object mnuSameHeight: TMenuItem
        Caption = 'Same &Height'
        OnClick = mnuSameHeightClick
      end
      object N4: TMenuItem
        Caption = '-'
      end
      object mnuDistributeH: TMenuItem
        Caption = 'Distribute &Horizontally'
        OnClick = mnuDistributeHClick
      end
      object mnuDistributeV: TMenuItem
        Caption = 'Distribute &Vertically'
        OnClick = mnuDistributeVClick
      end
    end
    object mnuReport: TMenuItem
      Caption = '&Report'
      object mnuPreview: TMenuItem
        Caption = '&Preview'
        ShortCut = 116
        OnClick = mnuPreviewClick
      end
      object mnuExportPDF: TMenuItem
        Caption = '&Export to PDF...'
        OnClick = mnuExportPDFClick
      end
    end
  end
  object OpenDialog1: TOpenDialog
    DefaultExt = 'vrt'
    Filter = 'Vittix Report Files (*.vrt)|*.vrt|All Files (*.*)|*.*'
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Left = 328
    Top = 200
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = 'vrt'
    Filter = 'Vittix Report Files (*.vrt)|*.vrt|All Files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofPathMustExist, ofEnableSizing]
    Left = 328
    Top = 264
  end
  object SaveDialog2: TSaveDialog
    DefaultExt = 'pdf'
    Filter = 'PDF Files (*.pdf)|*.pdf|All Files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofPathMustExist, ofEnableSizing]
    Left = 408
    Top = 264
  end
  object ClientDataSet1: TClientDataSet
    Aggregates = <>
    Params = <>
    Left = 552
    Top = 200
  end
  object DataSource1: TDataSource
    DataSet = ClientDataSet1
    Left = 632
    Top = 200
  end
  object ImageList1: TImageList
    Left = 488
    Top = 200
  end
end
