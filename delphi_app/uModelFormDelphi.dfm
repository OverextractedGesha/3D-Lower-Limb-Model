object ModelFormDelphi: TModelFormDelphi
  Left = 0
  Top = 0
  Caption = '3-Joint Lower Limb Model Parameters'
  ClientHeight = 560
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 760
    Height = 52
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblBW: TLabel
      Left = 16
      Top = 18
      Width = 97
      Height = 15
      Caption = 'Body Weight (kg):'
    end
    object lblBH: TLabel
      Left = 236
      Top = 18
      Width = 99
      Height = 15
      Caption = 'Body Height (cm):'
    end
    object edtBW: TEdit
      Left = 132
      Top = 14
      Width = 84
      Height = 23
      TabOrder = 0
      Text = '70'
    end
    object edtBH: TEdit
      Left = 352
      Top = 14
      Width = 84
      Height = 23
      TabOrder = 1
      Text = '175'
    end
    object btnApply: TButton
      Left = 464
      Top = 12
      Width = 116
      Height = 28
      Caption = 'Apply & Compute'
      TabOrder = 2
      OnClick = btnApplyClick
    end
    object btnClose: TButton
      Left = 592
      Top = 12
      Width = 96
      Height = 28
      Caption = 'Close'
      TabOrder = 3
      OnClick = btnCloseClick
    end
  end
  object memoModel: TMemo
    Left = 0
    Top = 52
    Width = 760
    Height = 508
    Align = alClient
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 1
    WordWrap = False
  end
end
