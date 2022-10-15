object SurfaceTools: TSurfaceTools
  Left = 0
  Top = 0
  BorderStyle = bsSizeToolWin
  Caption = 'SurfaceTools'
  ClientHeight = 593
  ClientWidth = 301
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 15
    Top = 79
    Width = 25
    Height = 13
    Caption = 'Scale'
  end
  object Label3: TLabel
    Left = 16
    Top = 118
    Width = 26
    Height = 13
    Caption = 'Move'
  end
  object Memo1: TMemo
    Left = 6
    Top = 358
    Width = 203
    Height = 78
    Lines.Strings = (
      'Memo1')
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object Info_Button: TButton
    Left = 8
    Top = 335
    Width = 75
    Height = 17
    Caption = 'Surface Info'
    TabOrder = 1
    OnClick = Info_ButtonClick
  end
  object GroupBox1: TGroupBox
    Left = 8
    Top = 24
    Width = 153
    Height = 41
    TabOrder = 2
    object CheckBox1: TCheckBox
      Left = 20
      Top = 15
      Width = 31
      Height = 17
      Caption = 'x'
      Checked = True
      State = cbChecked
      TabOrder = 0
    end
    object CheckBox2: TCheckBox
      Left = 52
      Top = 15
      Width = 28
      Height = 17
      Caption = 'y'
      Checked = True
      State = cbChecked
      TabOrder = 1
    end
    object CheckBox3: TCheckBox
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
    Left = 416
    Top = 41
    Width = 41
    Height = 21
    TabOrder = 3
    Text = '.1'
  end
  object Edit1: TEdit
    Left = 416
    Top = 11
    Width = 41
    Height = 21
    TabOrder = 4
    Text = '1'
  end
  object Scale_UpDown: TUpDown
    Left = 119
    Top = 68
    Width = 20
    Height = 25
    Min = 1
    Max = 2000
    Position = 1000
    TabOrder = 5
    OnClick = Scale_UpDownClick
  end
  object Scale_ComboBox: TComboBox
    Left = 56
    Top = 71
    Width = 58
    Height = 21
    ItemHeight = 13
    ItemIndex = 10
    TabOrder = 6
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
    Left = 56
    Top = 110
    Width = 20
    Height = 25
    Min = 1
    Max = 200
    Position = 100
    TabOrder = 7
    OnClick = Move_UpDownClick
  end
  object Collapse_Button: TButton
    Left = 17
    Top = 160
    Width = 59
    Height = 25
    Caption = 'Collapse'
    TabOrder = 8
    OnClick = Collapse_ButtonClick
  end
  object Inset_Button: TButton
    Left = 75
    Top = 201
    Width = 48
    Height = 25
    Caption = 'Inset'
    TabOrder = 9
    OnClick = Inset_ButtonClick
  end
  object Inset_ComboBox: TComboBox
    Left = 14
    Top = 202
    Width = 55
    Height = 21
    ItemHeight = 13
    ItemIndex = 4
    TabOrder = 10
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
    Left = 73
    Top = 240
    Width = 50
    Height = 25
    Caption = 'Extrude'
    TabOrder = 11
    OnClick = Extrude_ButtonClick
  end
  object EDextrude: TEdit
    Left = 12
    Top = 241
    Width = 60
    Height = 21
    TabOrder = 12
    Text = '.5'
  end
end
