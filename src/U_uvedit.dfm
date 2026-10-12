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
  KeyPreview = True
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnDeactivate = FormDeactivate
  OnHide = FormHide
  OnKeyDown = FormKeyDown
  OnPaint = FormPaint
  OnResize = FormResize
  OnShow = FormShow
  TextHeight = 13
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
      ScrollBars = ssHorizontal
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
  object Panel2: TPanel
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 987
    Height = 827
    Align = alClient
    Caption = 'Panel2'
    TabOrder = 2
    OnMouseDown = Panel2MouseDown
    OnMouseMove = Panel2MouseMove
    OnMouseUp = Panel2MouseUp
    OnResize = Panel2Resize
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 250
    OnTimer = Timer1Timer
    Left = 1201
    Top = 800
  end
end
