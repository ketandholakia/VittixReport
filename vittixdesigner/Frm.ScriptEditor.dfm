object frmScriptEditor: TfrmScriptEditor
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Script Editor'
  ClientHeight = 460
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  OnKeyDown = FormKeyDown
  TextHeight = 15
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 760
    Height = 176
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 185
    DesignSize = (
      760
      176)
    object lblTip: TLabel
      Left = 12
      Top = 76
      Width = 117
      Height = 15
      Caption = 'Tip: Ctrl+Enter to save'
    end
    object lblNoValidation: TLabel
      Left = 12
      Top = 96
      Width = 604
      Height = 15
      Caption = 
        'No syntax validation is performed in the designer. Script meanin' +
        'g is defined by your host callback implementation.'
    end
    object lblTarget: TLabel
      Left = 12
      Top = 112
      Width = 143
      Height = 15
      Caption = 'Selected target: none'
    end
    object lblSnippets: TLabel
      Left = 12
      Top = 128
      Width = 212
      Height = 15
      Caption = 'Host-script example snippets (text only):'
    end
    object memInfo: TMemo
      Left = 0
      Top = 0
      Width = 760
      Height = 72
      TabStop = False
      Align = alTop
      BorderStyle = bsNone
      Lines.Strings = (
        'Info')
      ParentColor = True
      ReadOnly = True
      TabOrder = 2
    end
    object cboSnippets: TComboBox
      Left = 12
      Top = 146
      Width = 642
      Height = 23
      Style = csDropDownList
      TabOrder = 0
    end
    object btnInsert: TButton
      Left = 662
      Top = 145
      Width = 86
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Insert'
      TabOrder = 1
      OnClick = btnInsertClick
    end
  end
  object memScript: TMemo
    Left = 0
    Top = 176
    Width = 760
    Height = 240
    Align = alClient
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssBoth
    TabOrder = 1
    WordWrap = False
    OnChange = memScriptChange
    ExplicitTop = 0
    ExplicitWidth = 185
    ExplicitHeight = 89
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 416
    Width = 760
    Height = 44
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    ExplicitTop = 0
    ExplicitWidth = 185
    DesignSize = (
      760
      44)
    object lblStats: TLabel
      Left = 12
      Top = 14
      Width = 90
      Height = 15
      Caption = 'Lines: 0 | Chars: 0'
    end
    object btnOK: TButton
      Left = 580
      Top = 8
      Width = 80
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = 'OK'
      Default = True
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 668
      Top = 8
      Width = 80
      Height = 25
      Anchors = [akRight, akBottom]
      Cancel = True
      Caption = 'Cancel'
      TabOrder = 1
    end
  end
end
