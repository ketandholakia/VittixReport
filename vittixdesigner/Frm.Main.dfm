object frmMain: TfrmMain
  Left = 0
  Top = 0
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
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnCloseQuery = FormCloseQuery
  PixelsPerInch = 96
  TextHeight = 15
  object mnuMain: TMainMenu
    object mnuFile: TMenuItem
      Caption = '&File'
      object mnuNew:       TMenuItem Caption = '&New Report'        ShortCut = 16462  OnClick = mnuNewClick      end
      object mnuOpen:      TMenuItem Caption = '&Open...'           ShortCut = 16463  OnClick = mnuOpenClick     end
      object mnuSave:      TMenuItem Caption = '&Save'              ShortCut = 16467  OnClick = mnuSaveClick     end
      object mnuSaveAs:    TMenuItem Caption = 'Save &As...'                          OnClick = mnuSaveAsClick   end
      object mnuSep1:      TMenuItem Caption = '-' end
      object mnuExportPDF: TMenuItem Caption = 'Export to &PDF...'                    OnClick = mnuExportPDFClick end
      object mnuSep2:      TMenuItem Caption = '-' end
      object mnuExit:      TMenuItem Caption = 'E&xit'              ShortCut = 32883  OnClick = mnuExitClick     end
    end
    object mnuEdit: TMenuItem
      Caption = '&Edit'
      object mnuUndo:      TMenuItem Caption = '&Undo'    ShortCut = 16474  OnClick = mnuUndoClick      end
      object mnuRedo:      TMenuItem Caption = '&Redo'    ShortCut = 16473  OnClick = mnuRedoClick      end
      object mnuSep3:      TMenuItem Caption = '-' end
      object mnuCut:       TMenuItem Caption = 'Cu&t'     ShortCut = 16472  OnClick = mnuCutClick       end
      object mnuCopy:      TMenuItem Caption = '&Copy'    ShortCut = 16451  OnClick = mnuCopyClick      end
      object mnuPaste:     TMenuItem Caption = '&Paste'   ShortCut = 16470  OnClick = mnuPasteClick     end
      object mnuDelete:    TMenuItem Caption = '&Delete'  ShortCut = 46     OnClick = mnuDeleteClick    end
      object mnuSep4:      TMenuItem Caption = '-' end
      object mnuSelectAll: TMenuItem Caption = 'Select &All' ShortCut = 16449 OnClick = mnuSelectAllClick end
    end
    object mnuInsert: TMenuItem
      Caption = '&Insert'
      object mnuAddBandTitle:   TMenuItem Caption = 'Band: Report &Title'   OnClick = mnuAddBandTitleClick   end
      object mnuAddBandHeader:  TMenuItem Caption = 'Band: Page &Header'    OnClick = mnuAddBandHeaderClick  end
      object mnuAddBandData:    TMenuItem Caption = 'Band: &Master Data'    OnClick = mnuAddBandDataClick    end
      object mnuAddBandFooter:  TMenuItem Caption = 'Band: Page &Footer'    OnClick = mnuAddBandFooterClick  end
      object mnuAddBandSummary: TMenuItem Caption = 'Band: Report &Summary' OnClick = mnuAddBandSummaryClick end
      object mnuSep5:           TMenuItem Caption = '-' end
    end
    object mnuAlign: TMenuItem
      Caption = '&Align'
      object mnuAlignLeft:   TMenuItem Caption = 'Align &Left'         OnClick = mnuAlignLeftClick   end
      object mnuAlignRight:  TMenuItem Caption = 'Align &Right'        OnClick = mnuAlignRightClick  end
      object mnuAlignTop:    TMenuItem Caption = 'Align &Top'          OnClick = mnuAlignTopClick    end
      object mnuAlignBottom: TMenuItem Caption = 'Align &Bottom'       OnClick = mnuAlignBottomClick end
      object mnuSep6:        TMenuItem Caption = '-' end
      object mnuSameWidth:   TMenuItem Caption = 'Same &Width'         OnClick = mnuSameWidthClick   end
      object mnuSameHeight:  TMenuItem Caption = 'Same &Height'        OnClick = mnuSameHeightClick  end
      object mnuSep7:        TMenuItem Caption = '-' end
      object mnuCenterH:     TMenuItem Caption = 'Center &Horizontal'  OnClick = mnuCenterHClick     end
      object mnuCenterV:     TMenuItem Caption = 'Center &Vertical'    OnClick = mnuCenterVClick     end
      object mnuSep8:        TMenuItem Caption = '-' end
      object mnuDistH:       TMenuItem Caption = 'Distribute &Horizontal' OnClick = mnuDistHClick    end
      object mnuDistV:       TMenuItem Caption = 'Distribute V&ertical'   OnClick = mnuDistVClick    end
      object mnuSep9:        TMenuItem Caption = '-' end
      object mnuFront:       TMenuItem Caption = 'Bring to &Front'     OnClick = mnuFrontClick       end
      object mnuBack:        TMenuItem Caption = 'Send to &Back'       OnClick = mnuBackClick        end
    end
    object mnuView: TMenuItem
      Caption = '&View'
      object mnuZoomIn:      TMenuItem Caption = 'Zoom &In'           ShortCut = 16443  OnClick = mnuZoomInClick     end
      object mnuZoomOut:     TMenuItem Caption = 'Zoom &Out'          ShortCut = 16461  OnClick = mnuZoomOutClick    end
      object mnuZoomReset:   TMenuItem Caption = '&Reset Zoom (100%)' ShortCut = 16464  OnClick = mnuZoomResetClick  end
      object mnuSep10:       TMenuItem Caption = '-' end
      object mnuShowGrid:    TMenuItem Caption = 'Show &Grid'         Checked = True    OnClick = mnuShowGridClick    end
      object mnuSnapGrid:    TMenuItem Caption = 'Snap to Grid'       Checked = True    OnClick = mnuSnapGridClick    end
      object mnuShowRulers:  TMenuItem Caption = 'Show &Rulers'       Checked = True    OnClick = mnuShowRulersClick  end
      object mnuShowMargins: TMenuItem Caption = 'Show &Margins'      Checked = True    OnClick = mnuShowMarginsClick end
    end
    object mnuReport: TMenuItem
      Caption = '&Report'
      object mnuPreview:    TMenuItem Caption = '&Preview...'         ShortCut = 116    OnClick = mnuPreviewClick    end
      object mnuPageSetup:  TMenuItem Caption = '&Page Setup...'                        OnClick = mnuPageSetupClick  end
      object mnuBandMgr:    TMenuItem Caption = '&Band Manager...'                      OnClick = mnuBandMgrClick    end
      object mnuSep11:      TMenuItem Caption = '-' end
      object mnuReportProps:TMenuItem Caption = 'Report &Properties'                    OnClick = mnuReportPropsClick end
    end
  end
  object dlgOpen: TOpenDialog  end
  object dlgSave: TSaveDialog  end
  object ToolBar1: TToolBar
    Align = alTop
    ButtonHeight = 28
    ButtonWidth  = 28
    EdgeBorders  = [ebBottom]
    ShowCaptions = False
    object btnNew:    TToolButton Caption = 'New'     Hint = 'New Report (Ctrl+N)'     OnClick = mnuNewClick     end
    object btnOpen:   TToolButton Caption = 'Open'    Hint = 'Open Report (Ctrl+O)'    OnClick = mnuOpenClick    end
    object btnSave:   TToolButton Caption = 'Save'    Hint = 'Save Report (Ctrl+S)'    OnClick = mnuSaveClick    end
    object tbSep1:    TToolButton Style = tbsSeparator end
    object btnUndo:   TToolButton Caption = 'Undo'    Hint = 'Undo (Ctrl+Z)'           OnClick = mnuUndoClick    end
    object btnRedo:   TToolButton Caption = 'Redo'    Hint = 'Redo (Ctrl+Y)'           OnClick = mnuRedoClick    end
    object tbSep2:    TToolButton Style = tbsSeparator end
    object btnDelete: TToolButton Caption = 'Del'     Hint = 'Delete selected'         OnClick = mnuDeleteClick  end
    object btnCopy:   TToolButton Caption = 'Copy'    Hint = 'Copy (Ctrl+C)'           OnClick = mnuCopyClick    end
    object btnPaste:  TToolButton Caption = 'Paste'   Hint = 'Paste (Ctrl+V)'          OnClick = mnuPasteClick   end
    object tbSep3:    TToolButton Style = tbsSeparator end
    object btnAlignLeft:   TToolButton Caption = 'AL'  Hint = 'Align Left'       OnClick = mnuAlignLeftClick   end
    object btnAlignRight:  TToolButton Caption = 'AR'  Hint = 'Align Right'      OnClick = mnuAlignRightClick  end
    object btnAlignTop:    TToolButton Caption = 'AT'  Hint = 'Align Top'        OnClick = mnuAlignTopClick    end
    object btnAlignBottom: TToolButton Caption = 'AB'  Hint = 'Align Bottom'     OnClick = mnuAlignBottomClick end
    object tbSep4:    TToolButton Style = tbsSeparator end
    object btnSameW:  TToolButton Caption = 'SW'  Hint = 'Same Width'            OnClick = mnuSameWidthClick   end
    object btnSameH:  TToolButton Caption = 'SH'  Hint = 'Same Height'           OnClick = mnuSameHeightClick  end
    object tbSep5:    TToolButton Style = tbsSeparator end
    object btnCenterH:TToolButton Caption = 'CH'  Hint = 'Center Horizontal'     OnClick = mnuCenterHClick     end
    object btnCenterV:TToolButton Caption = 'CV'  Hint = 'Center Vertical'       OnClick = mnuCenterVClick     end
    object tbSep6:    TToolButton Style = tbsSeparator end
    object btnDistH:  TToolButton Caption = 'DH'  Hint = 'Distribute Horizontal' OnClick = mnuDistHClick       end
    object btnDistV:  TToolButton Caption = 'DV'  Hint = 'Distribute Vertical'   OnClick = mnuDistVClick       end
    object tbSep7:    TToolButton Style = tbsSeparator end
    object btnFront:  TToolButton Caption = 'BTF' Hint = 'Bring to Front'         OnClick = mnuFrontClick      end
    object btnBack:   TToolButton Caption = 'STB' Hint = 'Send to Back'           OnClick = mnuBackClick       end
    object tbSep8:    TToolButton Style = tbsSeparator end
    object btnZoomIn: TToolButton Caption = 'Z+'  Hint = 'Zoom In (Ctrl++)'       OnClick = mnuZoomInClick     end
    object btnZoomOut:TToolButton Caption = 'Z-'  Hint = 'Zoom Out (Ctrl+-)'      OnClick = mnuZoomOutClick    end
    object tbSep9:    TToolButton Style = tbsSeparator end
    object btnPreview:TToolButton Caption = 'Preview' Hint = 'Preview Report (F5)' OnClick = mnuPreviewClick   end
  end
  object StatusBar1: TStatusBar
    Align = alBottom
    Panels = <
      item Width = 480 end
      item Width = 400 end
      item Width = 200 end>
    SimplePanel = False
  end
  object pnlOuter: TPanel
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    object pnlToolbox: TPanel
      Align = alLeft
      Width = 140
      BevelOuter = bvNone
      Caption = ''
      object lblToolbox: TLabel
        Align = alTop
        Height = 22
        Caption = '  Objects'
        Font.Style = [fsBold]
        Color = $002C2C2C
        Font.Color = clWhite
        ParentColor = False
        ParentFont = False
        Transparent = False
      end
      object Toolbox: TVittixReportToolbox
        Align = alClient
        TabOrder = 0
        OnToolSelected = ToolboxToolSelected
      end
    end
    object splLeft: TSplitter
      Align = alLeft
      Width = 4
      Color = $00D0D0D0
      ParentColor = False
    end
    object pnlProperties: TPanel
      Align = alRight
      Width = 260
      BevelOuter = bvNone
      Caption = ''
      object lblProperties: TLabel
        Align = alTop
        Height = 22
        Caption = '  Properties'
        Font.Style = [fsBold]
        Color = $002C2C2C
        Font.Color = clWhite
        ParentColor = False
        ParentFont = False
        Transparent = False
      end
      object pnlReportInfo: TPanel
        Align = alTop
        Height = 110
        BevelOuter = bvNone
        Caption = ''
        Padding.Left = 6
        Padding.Right = 6
        Padding.Top = 4
        Padding.Bottom = 4
        object lblReportTitle: TLabel
          Top = 8
          Left = 6
          Caption = 'Report Title:'
        end
        object edtReportTitle: TEdit
          Top = 24
          Left = 6
          Width = 240
          Height = 22
          Text = 'New Report'
          TabOrder = 0
        end
        object lblReportAuthor: TLabel
          Top = 52
          Left = 6
          Caption = 'Author:'
        end
        object edtReportAuthor: TEdit
          Top = 68
          Left = 6
          Width = 240
          Height = 22
          Text = ''
          TabOrder = 1
        end
      end
      object pnlZoom: TPanel
        Align = alTop
        Height = 34
        BevelOuter = bvNone
        Caption = ''
        object lblZoom: TLabel
          Top = 8
          Left = 6
          Caption = 'Zoom %:'
        end
        object edtZoom: TEdit
          Top = 5
          Left = 60
          Width = 56
          Height = 22
          Text = '100'
          TabOrder = 0
          OnKeyDown = edtZoomKeyDown
        end
        object btnZoomApply: TButton
          Top = 4
          Left = 120
          Width = 50
          Height = 24
          Caption = 'Apply'
          TabOrder = 1
          OnClick = btnZoomApplyClick
        end
      end
      object PropEditor: TValueListEditor
        Align = alClient
        KeyOptions = [keyEdit, keyAdd, keyDelete, keyUnique]
        TabOrder = 2
        OnKeyDown = PropEditorKeyDown
        ColWidths = (120 120)
      end
      object btnApplyProps: TButton
        Align = alBottom
        Height = 28
        Caption = 'Apply Properties  [Enter]'
        TabOrder = 3
        OnClick = btnApplyPropsClick
      end
    end
    object splRight: TSplitter
      Align = alRight
      Width = 4
      Color = $00D0D0D0
      ParentColor = False
    end
    object pnlCanvas: TPanel
      Align = alClient
      BevelOuter = bvNone
      Caption = ''
      object ScrollBox1: TScrollBox
        Align = alClient
        BorderStyle = bsNone
        Color = $00E8E8E8
        ParentColor = False
        object Designer: TVittixReportDesigner
          Left = 0
          Top = 0
          Width = 820
          Height = 1160
          Color = $00E8E8E8
          ShowGrid    = True
          SnapToGrid  = True
          GridSize    = 8
          ShowRulers  = True
          ShowMargins = True
          Zoom        = 100
          TabOrder    = 0
          OnSelectionChanged = DesignerSelectionChanged
          OnModified         = DesignerModified
        end
      end
    end
  end
end