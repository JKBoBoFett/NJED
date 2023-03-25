object frmThumbNails: TfrmThumbNails
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'MAT Thumbnails'
  ClientHeight = 500
  ClientWidth = 450
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Scaled = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnHide = FormHide
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object lbl_SelectedMat: TLabel
    Left = 166
    Top = 430
    Width = 75
    Height = 13
    Caption = 'lbl_SelectedMat'
  end
  object DrawGrid1: TDrawGrid
    Left = 8
    Top = 8
    Width = 433
    Height = 393
    BorderStyle = bsNone
    ColCount = 3
    DefaultColWidth = 128
    DefaultRowHeight = 128
    FixedCols = 0
    RowCount = 1
    FixedRows = 0
    GridLineWidth = 4
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goDrawFocusSelected]
    ScrollBars = ssVertical
    TabOrder = 0
    OnDrawCell = DrawGrid1DrawCell
    OnMouseDown = DrawGrid1MouseDown
    OnMouseUp = DrawGrid1MouseUp
    OnSelectCell = DrawGrid1SelectCell
  end
  object OKButton: TButton
    Left = 166
    Top = 449
    Width = 75
    Height = 25
    Caption = 'OK'
    Enabled = False
    ModalResult = 1
    TabOrder = 1
  end
  object PB_BuildThumbs: TProgressBar
    Left = 8
    Top = 407
    Width = 432
    Height = 17
    TabOrder = 2
  end
end
