object ObjExport: TObjExport
  Left = 0
  Top = 0
  Caption = 'ObjExport'
  ClientHeight = 203
  ClientWidth = 244
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 16
    Top = 96
    Width = 75
    Height = 25
    Caption = 'Export'
    TabOrder = 0
    OnClick = Button1Click
  end
  object GroupBox1: TGroupBox
    Left = 8
    Top = 8
    Width = 97
    Height = 65
    Caption = 'Options'
    TabOrder = 1
    object CheckBox1: TCheckBox
      Left = 8
      Top = 16
      Width = 81
      Height = 17
      Caption = 'export UV'#39's'
      TabOrder = 0
    end
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = '.obj'
    Filter = 'obj|*.obj'
    Left = 128
    Top = 8
  end
end
