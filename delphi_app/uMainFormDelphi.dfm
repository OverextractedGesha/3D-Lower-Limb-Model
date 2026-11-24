object MainFormDelphi: TMainFormDelphi
  Left = 0
  Top = 0
  Caption = 'Knee Extension Demo - 3-Joint Lower Limb Model'
  ClientHeight = 760
  ClientWidth = 1280
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  TextHeight = 15
  object pnlLimb: TPanel
    Left = 6
    Top = 6
    Width = 430
    Height = 460
    BevelOuter = bvLowered
    Color = clBlack
    ParentBackground = False
    TabOrder = 0
    object pbLimb: TPaintBox
      Left = 1
      Top = 1
      Width = 428
      Height = 458
      Align = alClient
      OnPaint = pbLimbPaint
    end
  end
  object pnlControls: TPanel
    Left = 442
    Top = 6
    Width = 832
    Height = 68
    BevelOuter = bvNone
    TabOrder = 1
    object lblStimTitle: TLabel
      Left = 504
      Top = 12
      Width = 78
      Height = 15
      Caption = 'Stimulation s1:'
    end
    object lblStimVal: TLabel
      Left = 504
      Top = 44
      Width = 120
      Height = 15
      Caption = 's1 = 1.00  (u = 1.000)'
    end
    object btnFES: TButton
      Left = 4
      Top = 4
      Width = 132
      Height = 32
      Caption = 'FES Extension'
      TabOrder = 0
      OnClick = btnFESClick
    end
    object btnModel: TButton
      Left = 144
      Top = 4
      Width = 104
      Height = 32
      Caption = 'Model'
      TabOrder = 1
      OnClick = btnModelClick
    end
    object btnExtension: TButton
      Left = 256
      Top = 4
      Width = 120
      Height = 32
      Caption = 'Extension'
      TabOrder = 2
      OnClick = btnExtensionClick
    end
    object btnClose: TButton
      Left = 384
      Top = 4
      Width = 104
      Height = 32
      Caption = 'Close'
      TabOrder = 3
      OnClick = btnCloseClick
    end
    object tbStimS1: TTrackBar
      Left = 4
      Top = 40
      Width = 484
      Height = 28
      Max = 100
      Position = 100
      TickStyle = tsAuto
      TabOrder = 4
      OnChange = tbStimS1Change
    end
  end
  object chtAngle: TChart
    Left = 442
    Top = 80
    Width = 410
    Height = 190
    TabOrder = 2
  end
  object chtVel: TChart
    Left = 860
    Top = 80
    Width = 410
    Height = 190
    TabOrder = 3
  end
  object chtLength: TChart
    Left = 442
    Top = 276
    Width = 410
    Height = 190
    TabOrder = 4
  end
  object chtMusTorque: TChart
    Left = 860
    Top = 276
    Width = 410
    Height = 190
    TabOrder = 5
  end
  object chtFvsL: TChart
    Left = 6
    Top = 480
    Width = 310
    Height = 270
    TabOrder = 6
  end
  object chtFvsV: TChart
    Left = 324
    Top = 480
    Width = 310
    Height = 270
    TabOrder = 7
  end
  object chtGravTorque: TChart
    Left = 642
    Top = 480
    Width = 310
    Height = 270
    TabOrder = 8
  end
  object chtLvsV: TChart
    Left = 960
    Top = 480
    Width = 310
    Height = 270
    TabOrder = 9
  end
  object TimerSim: TTimer
    Enabled = False
    Interval = 20
    OnTimer = TimerSimTimer
    Left = 32
    Top = 32
  end
end
