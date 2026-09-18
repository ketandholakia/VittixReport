object frmPreview: TfrmPreview
  Left = 0
  Top = 0
  Caption = 'Print Preview'
  ClientHeight = 800
  ClientWidth = 1280
  Color = clBtnFace
  Constraints.MinHeight = 480
  Constraints.MinWidth = 900
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poOwnerFormCenter
  WindowState = wsMaximized
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnResize = FormResize
  OnShow = FormShow
  TextHeight = 15
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 1280
    Height = 36
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblDocTitle: TLabel
      Left = 14
      Top = 9
      Width = 600
      Height = 17
      AutoSize = False
      Caption = 'Print Preview'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
    end
    object pnlHeaderLine: TPanel
      Left = 0
      Top = 35
      Width = 1280
      Height = 1
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 0
    end
  end
  object pnlToolbar: TPanel
    Left = 0
    Top = 36
    Width = 1280
    Height = 74
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object pnlToolbarLine: TPanel
      Left = 0
      Top = 73
      Width = 1280
      Height = 1
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 0
    end
    object btnFirst: TSpeedButton
      Left = 8
      Top = 5
      Width = 54
      Height = 54
      Hint = 'First page (Home)'
      Caption = 'First'
      Flat = True
      Layout = blGlyphTop
      Margin = 2
      Spacing = 4
      OnClick = btnFirstClick
    end
    object btnPrev: TSpeedButton
      Left = 62
      Top = 5
      Width = 54
      Height = 54
      Hint = 'Previous page (Page Up)'
      Caption = 'Prev'
      Flat = True
      Layout = blGlyphTop
      Margin = 2
      Spacing = 4
      OnClick = btnPrevClick
    end
    object btnNext: TSpeedButton
      Left = 116
      Top = 5
      Width = 54
      Height = 54
      Hint = 'Next page (Page Down)'
      Caption = 'Next'
      Flat = True
      Layout = blGlyphTop
      Margin = 2
      Spacing = 4
      OnClick = btnNextClick
    end
    object btnLast: TSpeedButton
      Left = 170
      Top = 5
      Width = 54
      Height = 54
      Hint = 'Last page (End)'
      Caption = 'Last'
      Flat = True
      Layout = blGlyphTop
      Margin = 2
      Spacing = 4
      OnClick = btnLastClick
    end
    object btnGoToPage: TSpeedButton
      Left = 224
      Top = 5
      Width = 62
      Height = 54
      Hint = 'Go to a page number'
      Caption = 'Go To...'
      Flat = True
      Layout = blGlyphTop
      Margin = 2
      Spacing = 4
      OnClick = btnGoToPageClick
    end
    object lblGrpNav: TLabel
      Left = 8
      Top = 61
      Width = 278
      Height = 12
      AutoSize = False
      Caption = 'Navigation'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Alignment = taCenter
    end
    object sepNav: TPanel
      Left = 292
      Top = 9
      Width = 1
      Height = 56
      BevelOuter = bvNone
      TabOrder = 1
    end
    object btnZoomIn: TSpeedButton
      Left = 302
      Top = 5
      Width = 54
      Height = 54
      Hint = 'Zoom in (Ctrl +)'
      Caption = 'Zoom In'
      Flat = True
      Layout = blGlyphTop
      Margin = 2
      Spacing = 4
      OnClick = btnZoomInClick
    end
    object btnZoomOut: TSpeedButton
      Left = 356
      Top = 5
      Width = 54
      Height = 54
      Hint = 'Zoom out (Ctrl -)'
      Caption = 'Zoom Out'
      Flat = True
      Layout = blGlyphTop
      Margin = 2
      Spacing = 4
      OnClick = btnZoomOutClick
    end
    object btnZoomStepOut: TButton
      Left = 416
      Top = 19
      Width = 22
      Height = 22
      Hint = 'Zoom out one step'
      Caption = '-'
      TabOrder = 2
      OnClick = btnZoomStepOutClick
    end
    object trkZoom: TTrackBar
      Left = 442
      Top = 12
      Width = 150
      Height = 30
      Hint = 'Zoom level'
      Max = 400
      Min = 10
      Frequency = 10
      Position = 100
      TabOrder = 3
      TickStyle = tsNone
      OnChange = trkZoomChange
    end
    object btnZoomStepIn: TButton
      Left = 596
      Top = 19
      Width = 22
      Height = 22
      Hint = 'Zoom in one step'
      Caption = '+'
      TabOrder = 4
      OnClick = btnZoomStepInClick
    end
    object lblZoom: TLabel
      Left = 626
      Top = 20
      Width = 46
      Height = 15
      AutoSize = False
      Caption = '100 %'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
    end
    object lblGrpZoom: TLabel
      Left = 302
      Top = 61
      Width = 372
      Height = 12
      AutoSize = False
      Caption = 'Zoom'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Alignment = taCenter
    end
    object sepZoom: TPanel
      Left = 682
      Top = 9
      Width = 1
      Height = 56
      BevelOuter = bvNone
      TabOrder = 5
    end
    object btnFitWidth: TSpeedButton
      Left = 692
      Top = 5
      Width = 54
      Height = 54
      Hint = 'Fit the page width to the window'
      Caption = 'Fit Width'
      Flat = True
      Layout = blGlyphTop
      Margin = 2
      Spacing = 4
      OnClick = btnFitWidthClick
    end
    object btnFitPage: TSpeedButton
      Left = 746
      Top = 5
      Width = 54
      Height = 54
      Hint = 'Fit the whole page in the window'
      Caption = 'Fit Page'
      Flat = True
      Layout = blGlyphTop
      Margin = 2
      Spacing = 4
      OnClick = btnFitPageClick
    end
    object lblGrpLayout: TLabel
      Left = 692
      Top = 61
      Width = 108
      Height = 12
      AutoSize = False
      Caption = 'Layout'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Alignment = taCenter
    end
    object sepLayout: TPanel
      Left = 808
      Top = 9
      Width = 1
      Height = 56
      BevelOuter = bvNone
      TabOrder = 6
    end
    object pnlMarginsSwitch: TPaintBox
      Left = 844
      Top = 17
      Width = 44
      Height = 22
      Hint = 'Show or hide the page margin guides'
      OnClick = pnlMarginsSwitchClick
      OnPaint = pnlMarginsSwitchPaint
    end
    object lblGrpTools: TLabel
      Left = 816
      Top = 61
      Width = 100
      Height = 12
      AutoSize = False
      Caption = 'Toggle Margins'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Alignment = taCenter
    end
    object sepTools: TPanel
      Left = 924
      Top = 9
      Width = 1
      Height = 56
      BevelOuter = bvNone
      TabOrder = 8
    end
    object pnlPrintBtn: TPanel
      Left = 932
      Top = 8
      Width = 58
      Height = 50
      BevelOuter = bvNone
      TabOrder = 9
      object btnPrint: TSpeedButton
        Left = 1
        Top = 1
        Width = 56
        Height = 48
        Hint = 'Print the report'
        Caption = 'Print'
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWhite
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        Layout = blGlyphTop
        Margin = 2
        Spacing = 4
        Transparent = True
        OnClick = btnPrintClick
      end
    end
    object btnSavePDF: TSpeedButton
      Left = 996
      Top = 5
      Width = 60
      Height = 54
      Hint = 'Export the report to PDF'
      Caption = 'Save as PDF'
      Flat = True
      Layout = blGlyphTop
      Margin = 2
      Spacing = 4
      OnClick = btnSavePDFClick
    end
    object lblGrpActions: TLabel
      Left = 932
      Top = 61
      Width = 124
      Height = 12
      AutoSize = False
      Caption = 'Actions'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Alignment = taCenter
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 772
    Width = 1280
    Height = 28
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object pnlStatusLine: TPanel
      Left = 0
      Top = 0
      Width = 1280
      Height = 1
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
    end
    object lblStatusText: TLabel
      Left = 12
      Top = 7
      Width = 280
      Height = 15
      AutoSize = False
      Caption = 'Status: Ready.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
    end
    object sepStatus1: TPanel
      Left = 300
      Top = 5
      Width = 1
      Height = 18
      BevelOuter = bvNone
      TabOrder = 1
    end
    object lblPageInfo: TLabel
      Left = 312
      Top = 7
      Width = 76
      Height = 15
      AutoSize = False
      Caption = 'Page 1 of 1'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
    end
    object sepStatus2: TPanel
      Left = 396
      Top = 5
      Width = 1
      Height = 18
      BevelOuter = bvNone
      TabOrder = 2
    end
    object lblZoomInfo: TLabel
      Left = 408
      Top = 7
      Width = 76
      Height = 15
      AutoSize = False
      Caption = 'Zoom: 100%'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
    end
    object sepStatus3: TPanel
      Left = 492
      Top = 5
      Width = 1
      Height = 18
      BevelOuter = bvNone
      TabOrder = 3
    end
    object btnClosePreview: TButton
      Left = 1140
      Top = 3
      Width = 128
      Height = 22
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Close Preview'
      TabOrder = 4
      OnClick = btnClosePreviewClick
    end
  end
  object ilIcons: TImageList
    ColorDepth = cd24Bit
    DrawingStyle = dsTransparent
    Height = 24
    Width = 24
    Left = 40
    Top = 8
  end
  object ilIconsLight: TImageList
    ColorDepth = cd24Bit
    DrawingStyle = dsTransparent
    Height = 24
    Width = 24
    Left = 88
    Top = 8
  end
  object Preview: TVittixReportPreview
    Left = 0
    Top = 110
    Width = 1280
    Height = 662
    Align = alClient
    Color = clGray
    PageIndex = 0
    OnPageChanged = PreviewPageChanged
  end
end
