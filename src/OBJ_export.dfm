object ObjExport: TObjExport
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Export OBJ'
  ClientHeight = 290
  ClientWidth = 252
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
    Left = 80
    Top = 250
    Width = 75
    Height = 25
    Caption = 'Export'
    Default = True
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 161
    Top = 250
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Close'
    ModalResult = 2
    TabOrder = 2
  end
  object GroupBox1: TGroupBox
    Left = 8
    Top = 8
    Width = 236
    Height = 230
    Caption = 'Options'
    TabOrder = 0
    object CheckBox1: TCheckBox
      Left = 12
      Top = 20
      Width = 212
      Height = 17
      Caption = 'export UV'#39's'
      State = cbChecked
      TabOrder = 0
    end
    object CheckBoxMtl: TCheckBox
      Left = 12
      Top = 44
      Width = 212
      Height = 17
      Caption = 'write .mtl file (material names)'
      State = cbChecked
      TabOrder = 1
    end
    object CheckBoxSel: TCheckBox
      Left = 12
      Top = 68
      Width = 212
      Height = 17
      Caption = 'selected sectors only'
      State = cbUnchecked
      TabOrder = 2
    end
    object CheckBoxSkipAdj: TCheckBox
      Left = 12
      Top = 92
      Width = 212
      Height = 17
      Caption = 'skip adjoined surfaces'
      State = cbUnchecked
      TabOrder = 3
    end
    object CheckBoxYUp: TCheckBox
      Left = 12
      Top = 116
      Width = 212
      Height = 17
      Caption = 'Y-up (swap Y/Z)'
      State = cbUnchecked
      TabOrder = 4
    end
    object CheckBoxInvU: TCheckBox
      Left = 12
      Top = 140
      Width = 212
      Height = 17
      Caption = 'flip U'
      State = cbUnchecked
      TabOrder = 5
    end
    object CheckBoxInvV: TCheckBox
      Left = 12
      Top = 164
      Width = 212
      Height = 17
      Caption = 'flip V'
      State = cbUnchecked
      TabOrder = 6
    end
    object CheckBoxTri: TCheckBox
      Left = 12
      Top = 188
      Width = 212
      Height = 17
      Caption = 'triangulate faces (no quads/n-gons)'
      State = cbUnchecked
      TabOrder = 7
    end
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = 'obj'
    Filter = 'Wavefront OBJ|*.obj'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 8
    Top = 250
  end
end
