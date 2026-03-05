object frmMain: TfrmMain
  Left = 0
  Top = 0
  ActiveControl = Toolbox
  Caption = 'Vittix Report Designer'
  ClientHeight = 720
  ClientWidth = 1280
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = mnuMain
  Position = poScreenCenter
  WindowState = wsMaximized
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object ToolBar1: TToolBar
    Left = 0
    Top = 0
    Width = 1280
    Height = 29
    ButtonHeight = 28
    ButtonWidth = 28
    EdgeBorders = [ebBottom]
    TabOrder = 0
    object btnNew: TToolButton
      Left = 0
      Top = 0
      Hint = 'New Report (Ctrl+N)'
      Caption = 'New'
      OnClick = mnuNewClick
    end
    object btnOpen: TToolButton
      Left = 28
      Top = 0
      Hint = 'Open Report (Ctrl+O)'
      Caption = 'Open'
      OnClick = mnuOpenClick
    end
    object btnSave: TToolButton
      Left = 56
      Top = 0
      Hint = 'Save Report (Ctrl+S)'
      Caption = 'Save'
      OnClick = mnuSaveClick
    end
    object tbSep1: TToolButton
      Left = 84
      Top = 0
      Width = 28
      Style = tbsSeparator
    end
    object btnUndo: TToolButton
      Left = 112
      Top = 0
      Hint = 'Undo (Ctrl+Z)'
      Caption = 'Undo'
      OnClick = mnuUndoClick
    end
    object btnRedo: TToolButton
      Left = 140
      Top = 0
      Hint = 'Redo (Ctrl+Y)'
      Caption = 'Redo'
      OnClick = mnuRedoClick
    end
    object tbSep2: TToolButton
      Left = 168
      Top = 0
      Width = 28
      Style = tbsSeparator
    end
    object btnDelete: TToolButton
      Left = 196
      Top = 0
      Hint = 'Delete selected'
      Caption = 'Del'
      OnClick = mnuDeleteClick
    end
    object btnCopy: TToolButton
      Left = 224
      Top = 0
      Hint = 'Copy (Ctrl+C)'
      Caption = 'Copy'
      OnClick = mnuCopyClick
    end
    object btnPaste: TToolButton
      Left = 252
      Top = 0
      Hint = 'Paste (Ctrl+V)'
      Caption = 'Paste'
      OnClick = mnuPasteClick
    end
    object tbSep3: TToolButton
      Left = 280
      Top = 0
      Width = 28
      Style = tbsSeparator
    end
    object btnAlignLeft: TToolButton
      Left = 308
      Top = 0
      Hint = 'Align Left'
      Caption = 'AL'
      OnClick = mnuAlignLeftClick
    end
    object btnAlignRight: TToolButton
      Left = 336
      Top = 0
      Hint = 'Align Right'
      Caption = 'AR'
      OnClick = mnuAlignRightClick
    end
    object btnAlignTop: TToolButton
      Left = 364
      Top = 0
      Hint = 'Align Top'
      Caption = 'AT'
      OnClick = mnuAlignTopClick
    end
    object btnAlignBottom: TToolButton
      Left = 392
      Top = 0
      Hint = 'Align Bottom'
      Caption = 'AB'
      OnClick = mnuAlignBottomClick
    end
    object tbSep4: TToolButton
      Left = 420
      Top = 0
      Width = 28
      Style = tbsSeparator
    end
    object btnSameW: TToolButton
      Left = 448
      Top = 0
      Hint = 'Same Width'
      Caption = 'SW'
      OnClick = mnuSameWidthClick
    end
    object btnSameH: TToolButton
      Left = 476
      Top = 0
      Hint = 'Same Height'
      Caption = 'SH'
      OnClick = mnuSameHeightClick
    end
    object tbSep5: TToolButton
      Left = 504
      Top = 0
      Width = 28
      Style = tbsSeparator
    end
    object btnCenterH: TToolButton
      Left = 532
      Top = 0
      Hint = 'Center Horizontal'
      Caption = 'CH'
      OnClick = mnuCenterHClick
    end
    object btnCenterV: TToolButton
      Left = 560
      Top = 0
      Hint = 'Center Vertical'
      Caption = 'CV'
      OnClick = mnuCenterVClick
    end
    object tbSep6: TToolButton
      Left = 588
      Top = 0
      Width = 28
      Style = tbsSeparator
    end
    object btnDistH: TToolButton
      Left = 616
      Top = 0
      Hint = 'Distribute Horizontal'
      Caption = 'DH'
      OnClick = mnuDistHClick
    end
    object btnDistV: TToolButton
      Left = 644
      Top = 0
      Hint = 'Distribute Vertical'
      Caption = 'DV'
      OnClick = mnuDistVClick
    end
    object tbSep7: TToolButton
      Left = 672
      Top = 0
      Width = 28
      Style = tbsSeparator
    end
    object btnFront: TToolButton
      Left = 700
      Top = 0
      Hint = 'Bring to Front'
      Caption = 'BTF'
      OnClick = mnuFrontClick
    end
    object btnBack: TToolButton
      Left = 728
      Top = 0
      Hint = 'Send to Back'
      Caption = 'STB'
      OnClick = mnuBackClick
    end
    object tbSep8: TToolButton
      Left = 756
      Top = 0
      Width = 28
      Style = tbsSeparator
    end
    object btnZoomIn: TToolButton
      Left = 784
      Top = 0
      Hint = 'Zoom In (Ctrl++)'
      Caption = 'Z+'
      OnClick = mnuZoomInClick
    end
    object btnZoomOut: TToolButton
      Left = 812
      Top = 0
      Hint = 'Zoom Out (Ctrl+-)'
      Caption = 'Z-'
      OnClick = mnuZoomOutClick
    end
    object tbSep9: TToolButton
      Left = 840
      Top = 0
      Width = 28
      Style = tbsSeparator
    end
    object btnPreview: TToolButton
      Left = 868
      Top = 0
      Hint = 'Preview Report (F5)'
      Caption = 'Preview'
      OnClick = mnuPreviewClick
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 701
    Width = 1280
    Height = 19
    Panels = <
      item
        Width = 480
      end
      item
        Width = 400
      end
      item
        Width = 200
      end>
  end
  object pnlOuter: TPanel
    Left = 0
    Top = 29
    Width = 1280
    Height = 672
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object splLeft: TSplitter
      Left = 0
      Top = 0
      Width = 4
      Height = 672
      Color = 13684944
      ParentColor = False
      ExplicitHeight = 100
    end
    object splRight: TSplitter
      Left = 1016
      Top = 0
      Width = 4
      Height = 672
      Align = alRight
      Color = 13684944
      ParentColor = False
      ExplicitLeft = 0
      ExplicitHeight = 100
    end
    object pnlToolbox: TPanel
      Left = 4
      Top = 0
      Width = 140
      Height = 672
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 0
      object lblToolbox: TLabel
        Left = 0
        Top = 0
        Width = 140
        Height = 15
        Align = alTop
        Caption = '  Objects'
        Color = 2894892
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWhite
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentColor = False
        ParentFont = False
        Transparent = False
        ExplicitWidth = 48
      end
      object Toolbox: TVittixReportToolbox
        Left = 0
        Top = 15
        Width = 140
        Height = 657
        Align = alClient
        ItemHeight = 15
        TabOrder = 0
        OnToolSelected = ToolboxToolSelected
      end
    end
    object pnlProperties: TPanel
      Left = 1020
      Top = 0
      Width = 260
      Height = 672
      Align = alRight
      BevelOuter = bvNone
      TabOrder = 1
      object lblProperties: TLabel
        Left = 0
        Top = 0
        Width = 260
        Height = 15
        Align = alTop
        Caption = '  Properties'
        Color = 2894892
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWhite
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentColor = False
        ParentFont = False
        Transparent = False
        ExplicitWidth = 64
      end
      object pnlReportInfo: TPanel
        Left = 0
        Top = 15
        Width = 260
        Height = 110
        Align = alTop
        BevelOuter = bvNone
        Padding.Left = 6
        Padding.Top = 4
        Padding.Right = 6
        Padding.Bottom = 4
        TabOrder = 0
        object lblReportTitle: TLabel
          Left = 6
          Top = 8
          Width = 64
          Height = 15
          Caption = 'Report Title:'
        end
        object lblReportAuthor: TLabel
          Left = 6
          Top = 52
          Width = 40
          Height = 15
          Caption = 'Author:'
        end
        object edtReportTitle: TEdit
          Left = 6
          Top = 24
          Width = 240
          Height = 23
          TabOrder = 0
          Text = 'New Report'
        end
        object edtReportAuthor: TEdit
          Left = 6
          Top = 68
          Width = 240
          Height = 23
          TabOrder = 1
        end
      end
      object pnlZoom: TPanel
        Left = 0
        Top = 125
        Width = 260
        Height = 34
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 1
        object lblZoom: TLabel
          Left = 6
          Top = 8
          Width = 48
          Height = 15
          Caption = 'Zoom %:'
        end
        object edtZoom: TEdit
          Left = 60
          Top = 5
          Width = 56
          Height = 23
          TabOrder = 0
          Text = '100'
          OnKeyDown = edtZoomKeyDown
        end
        object btnZoomApply: TButton
          Left = 120
          Top = 4
          Width = 50
          Height = 24
          Caption = 'Apply'
          TabOrder = 1
          OnClick = btnZoomApplyClick
        end
      end
      object PropEditor: TValueListEditor
        Left = 0
        Top = 159
        Width = 260
        Height = 485
        Align = alClient
        KeyOptions = [keyEdit, keyAdd, keyDelete, keyUnique]
        TabOrder = 2
        OnKeyDown = PropEditorKeyDown
        ColWidths = (
          120
          134)
      end
      object btnApplyProps: TButton
        Left = 0
        Top = 644
        Width = 260
        Height = 28
        Align = alBottom
        Caption = 'Apply Properties  [Enter]'
        TabOrder = 3
        OnClick = btnApplyPropsClick
      end
    end
    object pnlCanvas: TPanel
      Left = 144
      Top = 0
      Width = 872
      Height = 672
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 2
      object ScrollBox1: TScrollBox
        Left = 0
        Top = 0
        Width = 872
        Height = 672
        Align = alClient
        BorderStyle = bsNone
        Color = 15263976
        ParentColor = False
        TabOrder = 0
        object Designer: TVittixReportDesigner
          Left = 0
          Top = 0
          Width = 820
          Height = 1160
          OnSelectionChanged = DesignerSelectionChanged
          OnModified = DesignerModified
        end
      end
    end
  end
  object mnuMain: TMainMenu
    object mnuFile: TMenuItem
      Caption = '&File'
      object mnuNew: TMenuItem
        Caption = '&New Report'
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
      object mnuSep1: TMenuItem
        Caption = '-'
      end
      object mnuExportPDF: TMenuItem
        Caption = 'Export to &PDF...'
        OnClick = mnuExportPDFClick
      end
      object mnuSep2: TMenuItem
        Caption = '-'
      end
      object mnuExit: TMenuItem
        Caption = 'E&xit'
        ShortCut = 32883
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
      object mnuSep3: TMenuItem
        Caption = '-'
      end
      object mnuCut: TMenuItem
        Caption = 'Cu&t'
        ShortCut = 16472
        OnClick = mnuCutClick
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
        OnClick = mnuDeleteClick
      end
      object mnuSep4: TMenuItem
        Caption = '-'
      end
      object mnuSelectAll: TMenuItem
        Caption = 'Select &All'
        ShortCut = 16449
        OnClick = mnuSelectAllClick
      end
    end
    object mnuInsert: TMenuItem
      Caption = '&Insert'
      object mnuAddBandTitle: TMenuItem
        Caption = 'Band: Report &Title'
        OnClick = mnuAddBandTitleClick
      end
      object mnuAddBandHeader: TMenuItem
        Caption = 'Band: Page &Header'
        OnClick = mnuAddBandHeaderClick
      end
      object mnuAddBandData: TMenuItem
        Caption = 'Band: &Master Data'
        OnClick = mnuAddBandDataClick
      end
      object mnuAddBandFooter: TMenuItem
        Caption = 'Band: Page &Footer'
        OnClick = mnuAddBandFooterClick
      end
      object mnuAddBandSummary: TMenuItem
        Caption = 'Band: Report &Summary'
        OnClick = mnuAddBandSummaryClick
      end
      object mnuSep5: TMenuItem
        Caption = '-'
      end
    end
    object mnuAlign: TMenuItem
      Caption = '&Align'
      object mnuAlignLeft: TMenuItem
        Caption = 'Align &Left'
        OnClick = mnuAlignLeftClick
      end
      object mnuAlignRight: TMenuItem
        Caption = 'Align &Right'
        OnClick = mnuAlignRightClick
      end
      object mnuAlignTop: TMenuItem
        Caption = 'Align &Top'
        OnClick = mnuAlignTopClick
      end
      object mnuAlignBottom: TMenuItem
        Caption = 'Align &Bottom'
        OnClick = mnuAlignBottomClick
      end
      object mnuSep6: TMenuItem
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
      object mnuSep7: TMenuItem
        Caption = '-'
      end
      object mnuCenterH: TMenuItem
        Caption = 'Center &Horizontal'
        OnClick = mnuCenterHClick
      end
      object mnuCenterV: TMenuItem
        Caption = 'Center &Vertical'
        OnClick = mnuCenterVClick
      end
      object mnuSep8: TMenuItem
        Caption = '-'
      end
      object mnuDistH: TMenuItem
        Caption = 'Distribute &Horizontal'
        OnClick = mnuDistHClick
      end
      object mnuDistV: TMenuItem
        Caption = 'Distribute V&ertical'
        OnClick = mnuDistVClick
      end
      object mnuSep9: TMenuItem
        Caption = '-'
      end
      object mnuFront: TMenuItem
        Caption = 'Bring to &Front'
        OnClick = mnuFrontClick
      end
      object mnuBack: TMenuItem
        Caption = 'Send to &Back'
        OnClick = mnuBackClick
      end
    end
    object mnuView: TMenuItem
      Caption = '&View'
      object mnuZoomIn: TMenuItem
        Caption = 'Zoom &In'
        ShortCut = 16443
        OnClick = mnuZoomInClick
      end
      object mnuZoomOut: TMenuItem
        Caption = 'Zoom &Out'
        ShortCut = 16461
        OnClick = mnuZoomOutClick
      end
      object mnuZoomReset: TMenuItem
        Caption = '&Reset Zoom (100%)'
        ShortCut = 16464
        OnClick = mnuZoomResetClick
      end
      object mnuSep10: TMenuItem
        Caption = '-'
      end
      object mnuShowGrid: TMenuItem
        Caption = 'Show &Grid'
        Checked = True
        OnClick = mnuShowGridClick
      end
      object mnuSnapGrid: TMenuItem
        Caption = 'Snap to Grid'
        Checked = True
        OnClick = mnuSnapGridClick
      end
      object mnuShowRulers: TMenuItem
        Caption = 'Show &Rulers'
        Checked = True
        OnClick = mnuShowRulersClick
      end
      object mnuShowMargins: TMenuItem
        Caption = 'Show &Margins'
        Checked = True
        OnClick = mnuShowMarginsClick
      end
    end
    object mnuReport: TMenuItem
      Caption = '&Report'
      object mnuPreview: TMenuItem
        Caption = '&Preview...'
        ShortCut = 116
        OnClick = mnuPreviewClick
      end
      object mnuPageSetup: TMenuItem
        Caption = '&Page Setup...'
        OnClick = mnuPageSetupClick
      end
      object mnuBandMgr: TMenuItem
        Caption = '&Band Manager...'
        OnClick = mnuBandMgrClick
      end
      object mnuSep11: TMenuItem
        Caption = '-'
      end
      object mnuReportProps: TMenuItem
        Caption = 'Report &Properties'
        OnClick = mnuReportPropsClick
      end
    end
  end
  object dlgOpen: TOpenDialog
  end
  object dlgSave: TSaveDialog
  end
end
