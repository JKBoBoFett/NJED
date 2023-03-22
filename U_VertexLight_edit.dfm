object VertexLight: TVertexLight
  Left = 0
  Top = 0
  BorderStyle = bsSizeToolWin
  Caption = 'Vertex Light intensities'
  ClientHeight = 438
  ClientWidth = 245
  Color = clWindow
  Ctl3D = False
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  Position = poMainFormCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 120
  TextHeight = 16
  object SGValues: TStringGrid
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 239
    Height = 370
    Align = alClient
    ColCount = 2
    DefaultColWidth = 105
    DefaultRowHeight = 20
    RowCount = 1
    FixedRows = 0
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goEditing, goAlwaysShowEditor]
    TabOrder = 0
    OnSelectCell = SGValuesSelectCell
    RowHeights = (
      20)
  end
  object Panel1: TPanel
    Left = 0
    Top = 376
    Width = 245
    Height = 62
    Align = alBottom
    TabOrder = 1
    object BNSet: TButton
      Left = 80
      Top = 24
      Width = 89
      Height = 25
      Caption = 'Set Intensities'
      TabOrder = 0
      OnClick = BNSetClick
    end
    object CBVertex0_Master: TCheckBox
      Left = 11
      Top = 3
      Width = 190
      Height = 17
      Caption = 'Set all the same as Vertex 0'
      TabOrder = 1
    end
  end
end
