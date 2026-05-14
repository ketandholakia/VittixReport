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
  PixelsPerInch = 96
  TextHeight = 15

  object pnlTop: TPanel
    Align = alTop  Height = 30
    BevelOuter = bvNone  Color = $002C2C2C  Caption = ''
    object lblPrevTitle: TLabel
      Left = 10  Top = 7
      Caption = 'Print Preview'
      Font.Color = clWhite  Font.Style = [fsBold]  ParentFont = False
    end
  end

  object StatusBar1: TStatusBar
    Align = alBottom
    SimplePanel = True
    SimpleText = 'Ready'
  end

  object ToolBar1: TToolBar
    Align = alTop
    ButtonHeight = 26
    ButtonWidth  = 26
    ShowCaptions = True

    object btnFirst:    TToolButton  Caption = 'First'    Hint = 'First Page'    OnClick = btnFirstClick    end
    object btnPrev:     TToolButton  Caption = 'Prev'     Hint = 'Previous Page' OnClick = btnPrevClick     end
    object btnNext:     TToolButton  Caption = 'Next'     Hint = 'Next Page'     OnClick = btnNextClick     end
    object btnLast:     TToolButton  Caption = 'Last'     Hint = 'Last Page'     OnClick = btnLastClick     end
    object tbSep1:      TToolButton  Style = tbsSeparator  end
    object btnZoomIn:   TToolButton  Caption = 'Zoom In'   Hint = 'Zoom In'       OnClick = btnZoomInClick   end
    object btnZoomOut:  TToolButton  Caption = 'Zoom Out'  Hint = 'Zoom Out'      OnClick = btnZoomOutClick  end
    object btnFitWidth: TToolButton  Caption = 'Fit'       Hint = 'Fit Width'     OnClick = btnFitWidthClick end
    object tbSep2:      TToolButton  Style = tbsSeparator  end
    object lblPageInfo: TLabel
      Caption = 'Page 1 / 1'
      Font.Style = [fsBold]
    end
    object tbSep3:      TToolButton  Style = tbsSeparator  end
    object btnPrint:    TToolButton  Caption = 'Print' Hint = 'Print Report' OnClick = btnPrintClick end
  end

  object btnClose: TButton
    Align = alBottom
    Height = 30
    Caption = 'Close Preview'
    Default = True
    Cancel  = True
    TabOrder = 1
    OnClick = btnCloseClick
  end

  object Preview: TVittixReportPreview
    Align = alClient
    Color = $00D0D0D0
    OnPageChanged = PreviewPageChanged
  end
end
