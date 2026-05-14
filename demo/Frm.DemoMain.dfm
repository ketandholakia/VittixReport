object frmDemoMain: TfrmDemoMain
  Left = 0
  Top = 0
  Caption = 'Vittix Report Demo'
  ClientHeight = 720
  ClientWidth = 1180
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object Splitter1: TSplitter
    Left = 320
    Top = 0
    Width = 6
    Height = 701
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 0
    Width = 320
    Height = 701
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object tvSamples: TTreeView
      Left = 0
      Top = 0
      Width = 320
      Height = 701
      Align = alClient
      Indent = 19
      ReadOnly = True
      TabOrder = 0
      OnChange = tvSamplesChange
    end
  end
  object pnlRight: TPanel
    Left = 326
    Top = 0
    Width = 854
    Height = 701
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object lblTitle: TLabel
      Left = 16
      Top = 12
      Width = 213
      Height = 28
      Caption = 'Select a report sample'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -20
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblReportFileCaption: TLabel
      Left = 16
      Top = 52
      Width = 57
      Height = 15
      Caption = 'Report file:'
    end
    object lblReportFile: TLabel
      Left = 16
      Top = 72
      Width = 5
      Height = 15
      Caption = '-'
    end
    object mmoDescription: TMemo
      Left = 16
      Top = 100
      Width = 822
      Height = 540
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
    end
    object pnlButtons: TPanel
      Left = 0
      Top = 653
      Width = 854
      Height = 48
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 1
      object btnOpenFolder: TButton
        Left = 16
        Top = 10
        Width = 120
        Height = 28
        Caption = 'Open VRT Folder'
        Enabled = False
        TabOrder = 0
        OnClick = btnOpenFolderClick
      end
      object btnDesign: TButton
        Left = 620
        Top = 10
        Width = 100
        Height = 28
        Caption = 'Design'
        Enabled = False
        TabOrder = 1
        OnClick = btnDesignClick
      end
      object btnPreview: TButton
        Left = 732
        Top = 10
        Width = 100
        Height = 28
        Caption = 'Preview'
        Enabled = False
        TabOrder = 2
        OnClick = btnPreviewClick
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 701
    Width = 1180
    Height = 19
    Panels = <>
    SimplePanel = True
  end
end
