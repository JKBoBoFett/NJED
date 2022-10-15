object VertexLight: TVertexLight
  Left = 0
  Top = 0
  BorderStyle = bsSizeToolWin
  Caption = 'VertexLight'
  ClientHeight = 516
  ClientWidth = 289
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 454
    Width = 289
    Height = 62
    Align = alBottom
    TabOrder = 0
    ExplicitTop = 376
    ExplicitWidth = 245
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
  object SGValues: TStringGrid
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 283
    Height = 448
    Align = alClient
    ColCount = 2
    DefaultColWidth = 105
    DefaultRowHeight = 20
    RowCount = 1
    FixedRows = 0
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goEditing, goAlwaysShowEditor]
    TabOrder = 1
    OnSelectCell = SGValuesSelectCell
    ExplicitWidth = 854
    ExplicitHeight = 756
    RowHeights = (
      20)
  end
end
