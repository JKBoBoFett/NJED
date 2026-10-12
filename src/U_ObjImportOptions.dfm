object objImportOptions: TobjImportOptions
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'OBJ Import Options'
  ClientHeight = 198
  ClientWidth = 200
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object B_Done: TButton
    Left = 62
    Top = 165
    Width = 75
    Height = 25
    Caption = 'OK'
    TabOrder = 1
    OnClick = B_DoneClick
  end
  object GroupBox_TextureSize: TGroupBox
    Left = 8
    Top = 8
    Width = 177
    Height = 89
    Caption = 'Enter Texture Dimensions:'
    TabOrder = 0
    object Label1: TLabel
      Left = 16
      Top = 27
      Width = 32
      Height = 13
      Caption = 'Width:'
    end
    object Label2: TLabel
      Left = 13
      Top = 54
      Width = 35
      Height = 13
      Caption = 'Height:'
    end
    object Edit_Height: TEdit
      Left = 54
      Top = 46
      Width = 49
      Height = 21
      TabOrder = 1
      OnKeyPress = Edit_HeightKeyPress
    end
    object Edit_Width: TEdit
      Left = 54
      Top = 19
      Width = 49
      Height = 21
      TabOrder = 0
      OnKeyPress = Edit_WidthKeyPress
    end
  end
  object CheckBox_InvertU: TCheckBox
    Left = 8
    Top = 103
    Width = 97
    Height = 17
    Caption = 'Invert U'
    TabOrder = 2
  end
  object CheckBox_InvertV: TCheckBox
    Left = 8
    Top = 126
    Width = 97
    Height = 17
    Caption = 'Invert V'
    Checked = True
    State = cbChecked
    TabOrder = 3
  end
end
