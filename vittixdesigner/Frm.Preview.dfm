object frmPreview: TfrmPreview
  Left = 0
  Top = 0
  Caption = 'Print Preview'
  ClientHeight = 760
  ClientWidth = 960
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  WindowState = wsMaximized
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 960
    Height = 30
    Align = alTop
    BevelOuter = bvNone
    Color = 2894892
    TabOrder = 0
    ExplicitWidth = 185
    object lblPrevTitle: TLabel
      Left = 10
      Top = 7
      Width = 76
      Height = 15
      Caption = 'Print Preview'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 711
    Width = 960
    Height = 19
    Panels = <>
    SimplePanel = True
    SimpleText = 'Ready'
    ExplicitTop = 0
    ExplicitWidth = 0
  end
  object ToolBar1: TToolBar
    Left = 0
    Top = 30
    Width = 960
    Height = 29
    ButtonHeight = 26
    ButtonWidth = 26
    ShowCaptions = True
    TabOrder = 3
    ExplicitTop = 0
    ExplicitWidth = 150
    object btnFirst: TToolButton
      Left = 0
      Top = 0
      Hint = 'First Page'
      Caption = 'First'
      OnClick = btnFirstClick
    end
    object btnPrev: TToolButton
      Left = 0
      Top = 0
      Hint = 'Previous Page'
      Caption = 'Prev'
      OnClick = btnPrevClick
    end
    object btnNext: TToolButton
      Left = 0
      Top = 0
      Hint = 'Next Page'
      Caption = 'Next'
      OnClick = btnNextClick
    end
    object btnLast: TToolButton
      Left = 0
      Top = 0
      Hint = 'Last Page'
      Caption = 'Last'
      OnClick = btnLastClick
    end
    object btnGoToPage: TToolButton
      Left = 0
      Top = 0
      Hint = 'Go To Page'
      Caption = 'Go To'
      OnClick = btnGoToPageClick
    end
    object tbSep1: TToolButton
      Left = 0
      Top = 0
      Width = 26
      Style = tbsSeparator
    end
    object btnZoomIn: TToolButton
      Left = 0
      Top = 0
      Hint = 'Zoom In (Ctrl +)'
      Caption = 'Zoom In'
      OnClick = btnZoomInClick
    end
    object btnZoomOut: TToolButton
      Left = 0
      Top = 0
      Hint = 'Zoom Out (Ctrl -)'
      Caption = 'Zoom Out'
      OnClick = btnZoomOutClick
    end
    object btnFitWidth: TToolButton
      Left = 0
      Top = 0
      Hint = 'Fit Width'
      Caption = 'Fit Width'
      OnClick = btnFitWidthClick
    end
    object btnFitPage: TToolButton
      Left = 0
      Top = 0
      Hint = 'Fit Whole Page'
      Caption = 'Fit Page'
      OnClick = btnFitPageClick
    end
    object tbSepZoom: TToolButton
      Left = 0
      Top = 0
      Width = 26
      Style = tbsSeparator
    end
    object trkZoom: TTrackBar
      Left = 0
      Top = 0
      Width = 130
      Height = 26
      Max = 400
      Min = 10
      Frequency = 10
      Position = 100
      TabOrder = 0
      OnChange = trkZoomChange
    end
    object lblZoom: TLabel
      Left = 0
      Top = 0
      Width = 34
      Height = 15
      Caption = '100 %'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
    end
    object tbSep2: TToolButton
      Left = 0
      Top = 0
      Width = 26
      Style = tbsSeparator
    end
    object lblPageInfo: TLabel
      Left = 0
      Top = 0
      Width = 55
      Height = 15
      Caption = 'Page 1 / 1'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object tbSep3: TToolButton
      Left = 0
      Top = 0
      Width = 26
      Style = tbsSeparator
    end
    object btnPrint: TToolButton
      Left = 0
      Top = 0
      Hint = 'Print Report'
      Caption = 'Print'
      OnClick = btnPrintClick
    end
  end
  object btnClose: TButton
    Left = 0
    Top = 730
    Width = 960
    Height = 30
    Align = alBottom
    Cancel = True
    Caption = 'Close Preview'
    Default = True
    TabOrder = 1
    OnClick = btnCloseClick
    ExplicitTop = 0
    ExplicitWidth = 75
  end
  object Preview: TVittixReportPreview
    Left = 0
    Top = 59
    Width = 960
    Height = 652
    Align = alClient
    Color = 13684944
    PageIndex = 0
    OnPageChanged = PreviewPageChanged
    ExplicitTop = 0
    ExplicitWidth = 0
    ExplicitHeight = 0
  end
end
