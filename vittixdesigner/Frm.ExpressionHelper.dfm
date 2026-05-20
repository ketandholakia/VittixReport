object frmExpressionHelper: TfrmExpressionHelper
  Left = 0
  Top = 0
  Width = 920
  Height = 560
  Caption = 'Expression Helper'
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  object pnlLeft: TPanel
    Name = 'pnlLeft'
    Align = alLeft
    Width = 220
    BevelOuter = bvNone
    object lblFields: TLabel
      Name = 'lblFields'
      Align = alTop
      Alignment = taCenter
      Caption = 'Fields'
      Height = 20
    end
    object lstFields: TListBox
      Name = 'lstFields'
      Align = alClient
      OnDblClick = lstFieldsDblClick
    end
  end
  object pnlRight: TPanel
    Name = 'pnlRight'
    Align = alRight
    Width = 240
    BevelOuter = bvNone
    object pnlExamples: TPanel
      Name = 'pnlExamples'
      Align = alTop
      Height = 220
      BevelOuter = bvNone
      object lblExamples: TLabel
        Name = 'lblExamples'
        Align = alTop
        Alignment = taCenter
        Caption = 'Examples'
        Height = 20
      end
      object lstExamples: TListBox
        Name = 'lstExamples'
        Align = alClient
        OnDblClick = lstExamplesDblClick
      end
    end
    object pnlRecent: TPanel
      Name = 'pnlRecent'
      Align = alClient
      BevelOuter = bvNone
      object lblRecent: TLabel
        Name = 'lblRecent'
        Align = alTop
        Alignment = taCenter
        Caption = 'Recent'
        Height = 20
      end
      object lstRecent: TListBox
        Name = 'lstRecent'
        Align = alClient
        OnDblClick = lstRecentDblClick
      end
    end
  end
  object pnlCenter: TPanel
    Name = 'pnlCenter'
    Align = alClient
    BevelOuter = bvNone
    object pnlOperators: TPanel
      Name = 'pnlOperators'
      Align = alTop
      Height = 44
      BevelOuter = bvLowered
    end
    object memExpression: TMemo
      Name = 'memExpression'
      Align = alClient
      ScrollBars = ssBoth
      WordWrap = False
    end
    object pnlTemplates: TPanel
      Name = 'pnlTemplates'
      Align = alBottom
      Height = 60
      BevelOuter = bvLowered
    end
  end
  object pnlBottom: TPanel
    Name = 'pnlBottom'
    Align = alBottom
    Height = 40
    BevelOuter = bvNone
    object btnInsertField: TButton
      Name = 'btnInsertField'
      Left = 8
      Top = 8
      Width = 96
      Height = 26
      Caption = 'Insert Field'
      OnClick = btnInsertFieldClick
    end
    object btnCheck: TButton
      Name = 'btnCheck'
      Left = 112
      Top = 8
      Width = 80
      Height = 26
      Caption = 'Check'
      OnClick = btnCheckClick
    end
    object btnCancel: TButton
      Name = 'btnCancel'
      Left = 732
      Top = 8
      Width = 90
      Height = 26
      Caption = 'Cancel'
      Anchors = [akRight, akBottom]
    end
    object btnOK: TButton
      Name = 'btnOK'
      Left = 828
      Top = 8
      Width = 80
      Height = 26
      Caption = 'OK'
      Anchors = [akRight, akBottom]
    end
  end
end
