object SurfaceTools: TSurfaceTools
  AlignWithMargins = True
  Left = 0
  Top = 0
  BorderStyle = bsSizeToolWin
  Caption = 'SurfaceTools'
  ClientHeight = 287
  ClientWidth = 156
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 18
    Top = 17
    Width = 25
    Height = 13
    Caption = 'Scale'
  end
  object Label3: TLabel
    Left = 8
    Top = 106
    Width = 93
    Height = 13
    Caption = 'Move allong Normal'
  end
  object Info_Button: TButton
    Left = 21
    Top = 231
    Width = 99
    Height = 23
    Caption = 'Pan Surface Info'
    TabOrder = 0
    OnClick = Info_ButtonClick
  end
  object GroupBox1: TGroupBox
    Left = 405
    Top = 54
    Width = 119
    Height = 41
    TabOrder = 1
    object XCB: TCheckBox
      Left = 20
      Top = 15
      Width = 31
      Height = 17
      Caption = 'x'
      Checked = True
      State = cbChecked
      TabOrder = 0
    end
    object YCB: TCheckBox
      Left = 52
      Top = 15
      Width = 28
      Height = 17
      Caption = 'y'
      Checked = True
      State = cbChecked
      TabOrder = 1
    end
    object ZCB: TCheckBox
      Left = 84
      Top = 15
      Width = 31
      Height = 17
      Caption = 'z'
      Checked = True
      State = cbChecked
      TabOrder = 2
    end
  end
  object Edit3: TEdit
    Left = 411
    Top = 27
    Width = 41
    Height = 21
    TabOrder = 2
    Text = '.1'
  end
  object Edit1: TEdit
    Left = 411
    Top = -3
    Width = 41
    Height = 21
    TabOrder = 3
    Text = '1'
  end
  object Scale_UpDown: TUpDown
    Left = 113
    Top = 8
    Width = 20
    Height = 25
    Min = 1
    Max = 2000
    Position = 1000
    TabOrder = 4
    OnClick = Scale_UpDownClick
  end
  object Scale_ComboBox: TComboBox
    Left = 49
    Top = 8
    Width = 58
    Height = 21
    ItemHeight = 13
    ItemIndex = 10
    TabOrder = 5
    Text = '.1'
    Items.Strings = (
      '.9'
      '.8'
      '.7'
      '.6'
      '.5'
      '.4'
      '.3'
      '.250'
      '.2'
      '.125'
      '.1'
      '.09'
      '.08'
      '.07'
      '.06'
      '.05'
      '.04'
      '.03'
      '.02'
      '.01'
      '.005'
      '.001'
      '.0005')
  end
  object Move_UpDown: TUpDown
    Left = 111
    Top = 94
    Width = 20
    Height = 25
    Min = 1
    Max = 200
    Position = 100
    TabOrder = 6
    OnClick = Move_UpDownClick
  end
  object Inset_Button: TButton
    Left = 78
    Top = 138
    Width = 59
    Height = 25
    Caption = 'Inset'
    TabOrder = 7
    OnClick = Inset_ButtonClick
  end
  object Inset_ComboBox: TComboBox
    Left = 17
    Top = 140
    Width = 55
    Height = 21
    ItemHeight = 13
    ItemIndex = 4
    TabOrder = 8
    Text = '.5'
    Items.Strings = (
      '.9'
      '.8'
      '.7'
      '.6'
      '.5'
      '.4'
      '.3'
      '.250'
      '.2'
      '.125'
      '.1'
      '.09'
      '.08'
      '.07'
      '.06'
      '.05'
      '.04'
      '.03'
      '.02'
      '.01'
      '.005'
      '.001'
      '.0005')
  end
  object Extrude_Button: TButton
    Left = 78
    Top = 177
    Width = 59
    Height = 25
    Caption = 'Extrude'
    TabOrder = 9
    OnClick = Extrude_ButtonClick
  end
  object EDextrude: TEdit
    Left = 18
    Top = 179
    Width = 54
    Height = 21
    TabOrder = 10
    Text = '.5'
  end
  object Memo1: TMemo
    Left = 21
    Top = 355
    Width = 203
    Height = 78
    Lines.Strings = (
      'Memo1')
    ScrollBars = ssVertical
    TabOrder = 11
  end
  object Collapse_Button: TButton
    Left = 78
    Top = 52
    Width = 59
    Height = 25
    Caption = 'Collapse'
    TabOrder = 12
    OnClick = Collapse_ButtonClick
  end
end
