object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'VittixReport Full-Featured Demo'
  ClientHeight = 800
  ClientWidth = 1280
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  Menu = FMainMenu
  object FToolBar: TToolBar
    Left = 0
    Top = 0
    Width = 1280
    Height = 32
    ButtonHeight = 24
    ButtonWidth = 60
    Caption = 'FToolBar'
    Flat = True
    ShowCaptions = True
    TabOrder = 0
    object FBtnNew: TToolButton
      Left = 0
      Top = 0
      Caption = 'New'
      OnClick = MnuNewClick
    end
    object FBtnOpen: TToolButton
      Left = 60
      Top = 0
      Caption = 'Open'
      OnClick = MnuOpenClick
    end
    object FBtnSave: TToolButton
      Left = 120
      Top = 0
      Caption = 'Save'
      OnClick = MnuSaveClick
    end
    object ToolButtonSep1: TToolButton
      Left = 180
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object FBtnUndo: TToolButton
      Left = 188
      Top = 0
      Caption = 'Undo'
      OnClick = MnuUndoClick
    end
    object FBtnRedo: TToolButton
      Left = 248
      Top = 0
      Caption = 'Redo'
      OnClick = MnuRedoClick
    end
    object ToolButtonSep2: TToolButton
      Left = 308
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object FBtnDelete: TToolButton
      Left = 316
      Top = 0
      Caption = 'Delete'
      OnClick = MnuDeleteClick
    end
    object FBtnSelectAll: TToolButton
      Left = 376
      Top = 0
      Caption = 'Select All'
      OnClick = MnuSelectAllClick
    end
    object FBtnInsert: TToolButton
      Left = 436
      Top = 0
      Caption = 'Insert Tool'
      OnClick = ToolboxToolSelected
    end
    object ToolButtonSep3: TToolButton
      Left = 496
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object FBtnBringFront: TToolButton
      Left = 504
      Top = 0
      Caption = 'Front'
      OnClick = MnuBringFrontClick
    end
    object FBtnSendBack: TToolButton
      Left = 564
      Top = 0
      Caption = 'Back'
      OnClick = MnuSendBackClick
    end
    object ToolButtonSep4: TToolButton
      Left = 624
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object FBtnAlignLeft: TToolButton
      Left = 632
      Top = 0
      Caption = 'L'
      OnClick = MnuAlignLeftClick
    end
    object FBtnAlignRight: TToolButton
      Left = 692
      Top = 0
      Caption = 'R'
      OnClick = MnuAlignRightClick
    end
    object FBtnAlignTop: TToolButton
      Left = 752
      Top = 0
      Caption = 'T'
      OnClick = MnuAlignTopClick
    end
    object FBtnAlignBottom: TToolButton
      Left = 812
      Top = 0
      Caption = 'Bot'
      OnClick = MnuAlignBottomClick
    end
    object FBtnCenterH: TToolButton
      Left = 872
      Top = 0
      Caption = 'CX'
      OnClick = MnuCenterHClick
    end
    object FBtnCenterV: TToolButton
      Left = 932
      Top = 0
      Caption = 'CY'
      OnClick = MnuCenterVClick
    end
    object ToolButtonSep5: TToolButton
      Left = 992
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object FBtnZoomOut: TToolButton
      Left = 1000
      Top = 0
      Caption = '-'
      OnClick = MnuZoomOutClick
    end
    object FBtnZoom100: TToolButton
      Left = 1060
      Top = 0
      Caption = '100%'
      OnClick = MnuZoomResetClick
    end
    object FZoomCombo: TComboBox
      Left = 1120
      Top = 0
      Width = 70
      Height = 21
      Style = csDropDownList
      ItemIndex = 3
      TabOrder = 0
      Text = '100%'
      OnChange = ZoomComboChange
      Items.Strings = (
        '25%'
        '50%'
        '75%'
        '100%'
        '125%'
        '150%'
        '200%'
        '300%'
        '400%')
    end
    object FBtnZoomIn: TToolButton
      Left = 1190
      Top = 0
      Caption = '+'
      OnClick = MnuZoomInClick
    end
    object ToolButtonSep6: TToolButton
      Left = 1250
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object FBtnBuild: TToolButton
      Left = 1258
      Top = 0
      Caption = 'Build Preview (F5)'
      OnClick = MnuBuildClick
    end
  end
  object FStatusBar: TStatusBar
    Left = 0
    Top = 781
    Width = 1280
    Height = 19
    Panels = <
      item
        Width = 300
      end
      item
        Width = 150
      end
      item
        Width = 200
      end>
  end
  object FPnlLeft: TPanel
    Left = 0
    Top = 32
    Width = 160
    Height = 749
    Align = alLeft
    BevelOuter = bvNone
    Caption = ''
    TabOrder = 2
    object LblTools: TLabel
      Left = 0
      Top = 0
      Width = 160
      Height = 22
      Align = alTop
      Alignment = taCenter
      Caption = 'Object Toolbox'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      ExplicitWidth = 80
    end
    object FToolboxHost: TPanel
      Left = 0
      Top = 22
      Width = 160
      Height = 200
      Align = alTop
      BevelOuter = bvNone
      Caption = ''
      TabOrder = 0
    end
    object LblProps: TLabel
      Left = 0
      Top = 227
      Width = 160
      Height = 22
      Align = alTop
      Alignment = taCenter
      Caption = 'Properties'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      ExplicitWidth = 55
    end
    object FPropGrid: TStringGrid
      Left = 0
      Top = 249
      Width = 160
      Height = 500
      Align = alClient
      ColCount = 2
      DefaultColWidth = 70
      FixedCols = 0
      RowCount = 2
      Options = [goFixedVertLine,goFixedHorzLine,goVertLine,goHorzLine,goRangeSelect,goEditing]
      ScrollBars = ssVertical
      TabOrder = 1
      OnSetEditText = PropGridSetEditText
      ColWidths = (
        70
        82)
      RowHeights = (
        24
        24)
    end
  end
  object FSplLeft: TSplitter
    Left = 160
    Top = 32
    Width = 5
    Height = 749
    Align = alLeft
    ExplicitLeft = 162
    ExplicitTop = 116
    ExplicitHeight = 100
  end
  object FPnlRight: TPanel
    Left = 980
    Top = 32
    Width = 300
    Height = 749
    Align = alRight
    BevelOuter = bvNone
    Caption = ''
    TabOrder = 3
    object LblPrev: TLabel
      Left = 0
      Top = 0
      Width = 300
      Height = 22
      Align = alTop
      Alignment = taCenter
      Caption = 'Print Preview'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      ExplicitWidth = 62
    end
    object FPreviewHost: TPanel
      Left = 0
      Top = 22
      Width = 300
      Height = 727
      Align = alClient
      BevelOuter = bvNone
      Caption = ''
      TabOrder = 0
    end
  end
  object FSplRight: TSplitter
    Left = 975
    Top = 32
    Width = 5
    Height = 749
    Align = alRight
    ExplicitLeft = 830
    ExplicitTop = 116
    ExplicitHeight = 100
  end
  object FPnlCenter: TPanel
    Left = 165
    Top = 32
    Width = 810
    Height = 749
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    TabOrder = 1
    object FPnlGrid: TPanel
      Left = 0
      Top = 549
      Width = 810
      Height = 200
      Align = alBottom
      BevelOuter = bvNone
      Caption = ''
      TabOrder = 1
      object LblGrid: TLabel
        Left = 0
        Top = 0
        Width = 810
        Height = 22
        Align = alTop
        Alignment = taCenter
        Caption = 'Data Source  (TClientDataSet  Orders)'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        ExplicitWidth = 161
      end
      object FGrid: TDBGrid
        Left = 0
        Top = 22
        Width = 810
        Height = 178
        Align = alClient
        DataSource = FDS
        Options = [dgEditing,dgTitles,dgIndicator,dgColumnResize,dgColLines,dgRowLines,dgTabs,dgConfirmDelete,dgCancelOnExit,dgTitleClick,dgTitleHotTrack]
        TabOrder = 0
      end
    end
    object FSplH: TSplitter
      Left = 0
      Top = 544
      Width = 810
      Height = 5
      Cursor = crVSplit
      Align = alBottom
      ExplicitTop = 525
      ExplicitWidth = 702
    end
    object FPnlDesigner: TPanel
      Left = 0
      Top = 0
      Width = 810
      Height = 544
      Align = alClient
      BevelOuter = bvNone
      Caption = ''
      TabOrder = 0
      object LblDes: TLabel
        Left = 0
        Top = 0
        Width = 810
        Height = 20
        Align = alTop
        Alignment = taCenter
        Caption = 'Report Designer  click a toolbox item then click here to insert | Drag to move | Handles to resize'
        ExplicitWidth = 491
      end
      object FDesignerHost: TPanel
        Left = 0
        Top = 20
        Width = 810
        Height = 524
        Align = alClient
        BevelOuter = bvNone
        Caption = ''
        TabOrder = 0
      end
    end
  end
  object FMainMenu: TMainMenu
    Left = 136
    Top = 96
    object MnuFile: TMenuItem
      Caption = '&File'
      object MnuFileNew: TMenuItem
        Caption = '&New'
        OnClick = MnuNewClick
      end
      object MnuFileOpen: TMenuItem
        Caption = '&Open...'
        OnClick = MnuOpenClick
      end
      object NFileSep1: TMenuItem
        Caption = '-'
      end
      object MnuFileSave: TMenuItem
        Caption = '&Save'
        OnClick = MnuSaveClick
      end
      object MnuFileSaveAs: TMenuItem
        Caption = 'Save &As...'
        OnClick = MnuSaveAsClick
      end
      object NFileSep2: TMenuItem
        Caption = '-'
      end
      object MnuFileExportPDF: TMenuItem
        Caption = 'Export &PDF...'
        OnClick = MnuExportPDFClick
      end
      object NFileSep3: TMenuItem
        Caption = '-'
      end
      object MnuFileExit: TMenuItem
        Caption = 'E&xit'
        OnClick = MnuExitClick
      end
    end
    object MnuEdit: TMenuItem
      Caption = '&Edit'
      object FMnuUndo: TMenuItem
        Caption = '&Undo'
        OnClick = MnuUndoClick
      end
      object FMnuRedo: TMenuItem
        Caption = '&Redo'
        OnClick = MnuRedoClick
      end
      object NEditSep1: TMenuItem
        Caption = '-'
      end
      object MnuEditCopy: TMenuItem
        Caption = '&Copy'
        OnClick = MnuCopyClick
      end
      object MnuEditPaste: TMenuItem
        Caption = '&Paste'
        OnClick = MnuPasteClick
      end
      object NEditSep2: TMenuItem
        Caption = '-'
      end
      object MnuEditDelete: TMenuItem
        Caption = '&Delete'
        OnClick = MnuDeleteClick
      end
      object MnuEditSelectAll: TMenuItem
        Caption = 'Select &All'
        OnClick = MnuSelectAllClick
      end
    end
    object MnuBand: TMenuItem
      Caption = '&Band'
      object MnuBandReportTitle: TMenuItem
        Tag = 0
        Caption = 'Add Report &Title'
        OnClick = MnuAddBandClick
      end
      object MnuBandPageHeader: TMenuItem
        Tag = 1
        Caption = 'Add Page &Header'
        OnClick = MnuAddBandClick
      end
      object MnuBandColumnHeader: TMenuItem
        Tag = 2
        Caption = 'Add &Column Header'
        OnClick = MnuAddBandClick
      end
      object MnuBandMasterData: TMenuItem
        Tag = 3
        Caption = 'Add &Master Data'
        OnClick = MnuAddBandClick
      end
      object MnuBandDetail: TMenuItem
        Tag = 4
        Caption = 'Add &Detail'
        OnClick = MnuAddBandClick
      end
      object MnuBandPageFooter: TMenuItem
        Tag = 5
        Caption = 'Add Page &Footer'
        OnClick = MnuAddBandClick
      end
      object MnuBandReportSummary: TMenuItem
        Tag = 6
        Caption = 'Add Report &Summary'
        OnClick = MnuAddBandClick
      end
      object MnuBandGroupHeader: TMenuItem
        Tag = 7
        Caption = 'Add Group H&eader'
        OnClick = MnuAddBandClick
      end
      object MnuBandGroupFooter: TMenuItem
        Tag = 8
        Caption = 'Add Group F&ooter'
        OnClick = MnuAddBandClick
      end
      object NBandSep1: TMenuItem
        Caption = '-'
      end
      object MnuBandOverlay: TMenuItem
        Tag = 9
        Caption = 'Add &Overlay'
        OnClick = MnuAddBandClick
      end
    end
    object MnuFormat: TMenuItem
      Caption = 'F&ormat'
      object MnuFormatAlign: TMenuItem
        Caption = '&Align'
        object MnuAlignLeft: TMenuItem
          Caption = 'Align &Left'
          OnClick = MnuAlignLeftClick
        end
        object MnuAlignRight: TMenuItem
          Caption = 'Align &Right'
          OnClick = MnuAlignRightClick
        end
        object MnuAlignTop: TMenuItem
          Caption = 'Align &Top'
          OnClick = MnuAlignTopClick
        end
        object MnuAlignBottom: TMenuItem
          Caption = 'Align &Bottom'
          OnClick = MnuAlignBottomClick
        end
      end
      object MnuFormatCenter: TMenuItem
        Caption = '&Center'
        object MnuCenterH: TMenuItem
          Caption = 'Center &Horizontally'
          OnClick = MnuCenterHClick
        end
        object MnuCenterV: TMenuItem
          Caption = 'Center &Vertically'
          OnClick = MnuCenterVClick
        end
      end
      object MnuFormatDistribute: TMenuItem
        Caption = '&Distribute'
        object MnuDistH: TMenuItem
          Caption = 'Distribute &Horizontally'
          OnClick = MnuDistHClick
        end
        object MnuDistV: TMenuItem
          Caption = 'Distribute &Vertically'
          OnClick = MnuDistVClick
        end
      end
      object MnuFormatSameSize: TMenuItem
        Caption = 'Make &Same Size'
        object MnuSameWidth: TMenuItem
          Caption = 'Same &Width'
          OnClick = MnuSameWidthClick
        end
        object MnuSameHeight: TMenuItem
          Caption = 'Same &Height'
          OnClick = MnuSameHeightClick
        end
      end
      object NFormatSep1: TMenuItem
        Caption = '-'
      end
      object MnuBringFront: TMenuItem
        Caption = 'Bring to &Front'
        OnClick = MnuBringFrontClick
      end
      object MnuSendBack: TMenuItem
        Caption = 'Send to &Back'
        OnClick = MnuSendBackClick
      end
    end
    object MnuView: TMenuItem
      Caption = '&View'
      object FMnuShowRulers: TMenuItem
        Caption = 'Show &Rulers'
        OnClick = MnuShowRulersClick
      end
      object FMnuShowGrid: TMenuItem
        Caption = 'Show &Grid'
        OnClick = MnuShowGridClick
      end
      object FMnuShowMargins: TMenuItem
        Caption = 'Show &Margins'
        OnClick = MnuShowMarginsClick
      end
      object NViewSep1: TMenuItem
        Caption = '-'
      end
      object MnuViewZoomIn: TMenuItem
        Caption = 'Zoom &In'
        OnClick = MnuZoomInClick
      end
      object MnuViewZoomOut: TMenuItem
        Caption = 'Zoom &Out'
        OnClick = MnuZoomOutClick
      end
      object MnuViewZoom100: TMenuItem
        Caption = '&100%'
        OnClick = MnuZoomResetClick
      end
      object NViewSep2: TMenuItem
        Caption = '-'
      end
      object FMnuPreviewPane: TMenuItem
        Caption = 'Preview &Pane'
        OnClick = MnuPreviewPaneClick
      end
      object FMnuDataPane: TMenuItem
        Caption = '&Data Pane'
        OnClick = MnuDataPaneClick
      end
    end
    object MnuReport: TMenuItem
      Caption = '&Report'
      object MnuReportBuild: TMenuItem
        Caption = '&Build Preview'
        OnClick = MnuBuildClick
      end
    end
    object MnuHelp: TMenuItem
      Caption = '&Help'
      object MnuAbout: TMenuItem
        Caption = '&About...'
        OnClick = MnuAboutClick
      end
    end
  end
  object FCDS: TClientDataSet
    Aggregates = <>
    Params = <>
    Left = 56
    Top = 96
  end
  object FDS: TDataSource
    DataSet = FCDS
    Left = 56
    Top = 144
  end
  object FDlgOpen: TOpenDialog
    DefaultExt = 'vrt'
    Filter = 'VittixReport files (*.vrt)|*.vrt|All files|*.*'
    Title = 'Open Report'
    Left = 56
    Top = 192
  end
  object FDlgSave: TSaveDialog
    DefaultExt = 'vrt'
    Filter = 'VittixReport files (*.vrt)|*.vrt|All files|*.*'
    Title = 'Save Report'
    Left = 56
    Top = 240
  end
end
