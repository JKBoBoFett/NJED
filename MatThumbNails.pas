unit MatThumbNails;
//NJED JAN-2023
interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs,GameImageList, Grids, StdCtrls,Math, ComCtrls,U_MatToBmpThread,graph_files;

type
  TfrmThumbNails = class(TForm)
    DrawGrid1: TDrawGrid;
    lbl_SelectedMat: TLabel;
    OKButton: TButton;
    PB_BuildThumbs: TProgressBar;
    procedure FormCreate(Sender: TObject);
    procedure DrawGrid1DrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure DrawGrid1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DrawGrid1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DrawGrid1SelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure FormHide(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  Procedure AddImage(aBitMap : TBitMap);
  Procedure ClearBmpList;
  Procedure UpdateCellCnt(ItemCnt:Integer);
  procedure CleanUp;
  end;

var
  frmThumbNails: TfrmThumbNails;
   bmpList:TBitMapList;
   MatList:Tstringlist;
   SelectedMatName:String;
   mouseD:integer;
   bmp:Tbitmap;
   drawgrid:boolean;
   gridUpdating:boolean;
   BmpThread:TMatToBmpThread;
   cmppal:TCMPPal;
implementation

{$R *.dfm}
Procedure TfrmThumbNails.AddImage(aBitMap : TBitMap);
begin
 bmpList.AddImage(aBitMap);
end;

 procedure TfrmThumbNails.CancelButtonClick(Sender: TObject);
begin
 ModalResult := mrCancel;
end;

Procedure TfrmThumbNails.ClearBmpList;
 begin
  bmpList.clear;
 end;

 Procedure TfrmThumbNails.UpdateCellCnt(ItemCnt:Integer);
 begin
 drawgrid1.RowCount:=Ceil(ItemCnt/3);
 //drawgrid1.Repaint;
 end;

procedure TfrmThumbNails.DrawGrid1DrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
   bmpRect: Trect;
   sc:double;
   index,dstW,dstH,cellSize: Integer;

begin
//exit;
//if drawgrid=false then exit;
// gridUpdating:=true;
 cellSize:=128;

index := ARow * DrawGrid1.ColCount + ACol;
if (bmpList <> nil) and (index <= bmpList.ImageCount-1)then
 bmpList.GetImage(index,bmp);

 if bmp.Empty = true then exit;

  if index > MatList.Count-1 then exit; 

 //sc:=drawgrid1.ScaleFactor;
 if bmp.Width > bmp.Height then
begin
dstW:= cellSize;
dstH:=trunc( (bmp.Height / bmp.Width)*cellSize);
end;

if bmp.Height > bmp.Width then
begin
dstW:=trunc( (bmp.Width / bmp.Height)*cellSize);
dstH:=cellSize;
end;

if bmp.Height = bmp.Width then
begin
dstW:= cellSize;
dstH:= cellSize;
end;

StretchBlt (DrawGrid1.Canvas.Handle,
                  Rect.TopLeft.X+4,                         {X coordinate on screen}
                  Rect.TopLeft.Y+4,                            {Y coordinate on screen}
                  trunc(dstW)-8,
                  trunc(dstH)-8,
                  BMP.Canvas.Handle,
                  0,
                  0,
                  BMP.Width,
                  BMP.Height,
                  SRCCOPY);
gridUpdating:=false;

if (gdFocused in State) then
  begin
  // lbl_SelectedMat.Caption:= 'Cell ' + InttoStr(index) + ' has the focus.';
    lbl_SelectedMat.Caption:=  MatList.Strings[index];
    SelectedMatName:=MatList.Strings[index];
  end;

end;

procedure TfrmThumbNails.DrawGrid1MouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
 mouseD:=1;
end;

procedure TfrmThumbNails.DrawGrid1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
   mouseD:=0;
end;

procedure TfrmThumbNails.DrawGrid1SelectCell(Sender: TObject; ACol,
  ARow: Integer; var CanSelect: Boolean);
begin
if mouseD = 0 then  CanSelect:= false;
if mouseD = 1 then  CanSelect:= true;
end;

procedure TfrmThumbNails.FormCreate(Sender: TObject);
begin
 bmp:=Tbitmap.Create;
 MatList:=Tstringlist.Create;
 drawgrid:=false;
 gridUpdating:=false;
 drawgrid1.DoubleBuffered:=true;
end;

procedure TfrmThumbNails.FormDestroy(Sender: TObject);
begin
 MatList.Free;
 bmp.Free;
end;

procedure TfrmThumbNails.CleanUp;
begin
 bmplist.FreeBMP;
 bmplist.Free;
end;

procedure TfrmThumbNails.FormHide(Sender: TObject);
begin
 BmpThread.Free;
 BmpThread:=nil;

 bmplist.FreeBMP;
 bmplist.Free;

 MatList.Clear;

 Drawgrid1.RowCount:=0;
end;

procedure TfrmThumbNails.FormShow(Sender: TObject);
begin
 bmpList:=TBitMapList.Create;
 BmpThread:=TMatToBmpThread.Create(MatList,CmpPal);
 Drawgrid1.ColCount:=3;
end;

end.
