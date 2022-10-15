object UVEdit: TUVEdit
  Left = 0
  Top = 0
  Caption = 'UVEdit'
  ClientHeight = 851
  ClientWidth = 1323
  Color = clBlack
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object PaintBox1: TPaintBox
    Left = 0
    Top = 0
    Width = 993
    Height = 833
    Align = alClient
    Color = clGray
    ParentColor = False
    OnMouseMove = PaintBox1MouseMove
    OnPaint = PaintBox1Paint
    ExplicitLeft = 160
    ExplicitWidth = 648
    ExplicitHeight = 556
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 833
    Width = 1323
    Height = 18
    Panels = <
      item
        Width = 60
      end
      item
        Width = 280
      end
      item
        Width = 50
      end>
    SizeGrip = False
  end
  object Panel1: TPanel
    Left = 993
    Top = 0
    Width = 330
    Height = 833
    Align = alRight
    TabOrder = 1
    object Label3: TLabel
      Left = 43
      Top = 350
      Width = 31
      Height = 13
      Caption = 'Label3'
    end
    object Label2: TLabel
      Left = 43
      Top = 331
      Width = 31
      Height = 13
      Caption = 'Label2'
    end
    object Label1: TLabel
      Left = 43
      Top = 312
      Width = 31
      Height = 13
      Caption = 'Label1'
    end
    object Memo1: TMemo
      Left = 19
      Top = 70
      Width = 287
      Height = 195
      TabStop = False
      TabOrder = 0
    end
    object UV_StringGrid: TStringGrid
      Left = 6
      Top = 408
      Width = 307
      Height = 257
      TabStop = False
      ColCount = 3
      DefaultColWidth = 50
      RowCount = 1
      FixedRows = 0
      Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goEditing]
      TabOrder = 1
      ColWidths = (
        50
        126
        125)
    end
    object SetUVButton: TButton
      Left = 128
      Top = 736
      Width = 75
      Height = 25
      Caption = 'Set UV'
      TabOrder = 2
      TabStop = False
      OnClick = SetUVButtonClick
    end
  end
end
