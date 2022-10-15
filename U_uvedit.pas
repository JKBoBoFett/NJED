unit U_uvedit;
{
Notes:
JED creates negative TX coords, but the LEC levels all have positive values
  ArrangeTextureBy
 vertex order is counter clockwise
}



interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs,J_Level, StdCtrls,Jed_Main, FileOperations, graph_files,lev_utils,
  ExtCtrls,files, ComCtrls, Geometry,math,globalvars, Grids;

type
  TUVEdit = class(TForm)
    StatusBar1: TStatusBar;
    Memo1: TMemo;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    PaintBox1: TPaintBox;
    Panel1: TPanel;
    UV_StringGrid: TStringGrid;
    SetUVButton: TButton;

    procedure FormShow(Sender: TObject);
    Procedure SetPointSize(size:double);
     Procedure DrawVertex(X,Y:double);
    procedure Image1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PaintBox1Paint(Sender: TObject);
    procedure SetUVButtonClick(Sender: TObject);
    Procedure SetCanvasZoomAndRotation(ACanvas: TCanvas; Zoom: Double;
  Angle: Double; CenterpointX, CenterpointY: Double);
     procedure WMEraseBkgnd(var m: TWMEraseBkgnd);
      message WM_ERASEBKGND;
    procedure FormCreate(Sender: TObject);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
  private

    { Private declarations }
    halfpsize,psizeodd,YOffset,XOffset:integer;
    ZoomFactor:double;
    Dc:TCanvas;
     bm,bmp:TBitmap;
  public
    { Public declarations }
  end;

var
  UVEdit: TUVEdit;

implementation

{$R *.dfm}

procedure TUVEdit.WMEraseBkgnd(var m: TWMEraseBkgnd);
begin
  m.Result := LRESULT(False);
end;

procedure TUVEdit.FormCreate(Sender: TObject);
begin
  DoubleBuffered := True;
end;

procedure TUVEdit.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
case key of
    187,VK_ADD: begin
 ///  panel2.Height:=panel2.Height +10;
 //  panel2.Width:=panel2.Width +10;
 ZoomFactor:=ZoomFactor+0.1;
    end;
  189,VK_SUBTRACT: begin
 // panel2.Height:=panel2.Height-10;
 // panel2.Width:=panel2.Width-10;
 ZoomFactor:=ZoomFactor-0.1;
  end;

  Ord('N'): begin
     JedMain.SetCurSF(JedMain.Cur_SC,JedMain.Cur_SF+1);
     Formshow(self);
     repaint;
  end;

end;


 case key of
    VK_RIGHT: XOffset:=XOffset+5;
    VK_LEFT: XOffset:=XOffset-5;
    VK_UP: YOffset:=YOffset-5;
    VK_DOWN: YOffset:=YOffset+5;
   end;
   label3.Caption:=inttostr(YOffset);

   invalidate;
end;

procedure TUVEdit.FormShow(Sender: TObject);
var
 F:TFile;
 Fname:String;
   mat:TMAT;
   nMatCell,s,i:integer;
   bm,bmp:TBitmap;
   cmppal:TCMPPal;
    txv:TTXVertex;
    V:TJKVertex;
    row: integer;
begin
    YOffset:=0;XOffset:=0;
      ZoomFactor:=1;
  // edit1.Text:=inttostr( level.sectors.Count);



   //Bmp.Height := image1.Height;
   //Bmp.Width := image1.Width;
   //bmp.PixelFormat:=pf32bit;
     //image1.Picture.Bitmap.Assign(bmp);
     // bmp.Assign( image1.Picture.Bitmap);
   //   bmp.Width:= image1.Width;
  //    bmp.Height:= image1.Height;
  //   Bmp.Canvas.Brush.Color := clred;
  //   Bmp.Canvas.FillRect(Rect(0,0,image1.Width,image1.Height));
  //     Paintbox1.Canvas.Draw( 0,0,bmp);
     // bmp.FreeImage;
 //mage1.Picture.Bitmap:=bmp;
  // image1.Picture.Bitmap.Canvas.Draw( Bmp.Width div 2,Bmp.Height div 2,bm);

      memo1.Clear;

memo1.Lines.Add('TXVerts: '+inttostr(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count));

         UV_StringGrid.RowCount := 1;

     SetPointSize(3);
    for s:=0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count-1 do
           begin
              txv:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(s);
                 v:=   level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].GetVXs.GetItem(s);
//DrawVertex( (txv.u * (bm.Width div 2))  ,      (-(txv.v * (bm.Height div 2))) );
     //           DrawVertex( txv.u + Bmp.Width div 2,      ( -(txv.v ) )+Bmp.Height div 2 );
               memo1.Lines.Add('U:'+floattostr(txv.u)+',V:'+floattostr(txv.v)+',vertex:'+floattostr(v.x)+','+floattostr(v.y));

               row := UV_StringGrid.RowCount;
               UV_StringGrid.RowCount := row + 1;

               UV_StringGrid.Cells[1,0]:= 'U';
               UV_StringGrid.Cells[2,0]:= 'V';
               UV_StringGrid.Cells[0,s+1]:= inttostr(s);
               UV_StringGrid.Cells[2,s+1]:= floattostr(txv.v);
               UV_StringGrid.Cells[1,s+1]:= floattostr(txv.u);
               UV_StringGrid.Cells[2,s+1]:= floattostr(txv.v);
    {



                  image1.Picture.Bitmap.Canvas.Brush.Color := clred;
                 if s=0 then
                  begin
                   image1.Picture.Bitmap.Canvas.MoveTo(round(txv.u)+ Bmp.Width div 2,-(round(txv.v))+Bmp.Height div 2);
                   // x0:=vx; y0:=vy;
                   end
                 else image1.Picture.Bitmap.Canvas.LineTo(round(txv.u)+ Bmp.Width div 2,-(round(txv.v))+Bmp.Height div 2);

                 image1.Picture.Bitmap.Canvas.LineTo(round(txv.u)+ Bmp.Width div 2,-(round(txv.v))+Bmp.Height div 2);
               //  end;
               //  if p.Vertices.count>0 then LineTo(x0,y0);

     }

           end;

end;

procedure TUVEdit.Image1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
  var
  xActual:     integer;
  yActual:     integer;
begin
    xActual := X;
  yActual := Y;

   StatusBar1.Panels[0].Text :=
    '(' + IntToStr(xActual) + ', ' + IntToStr(yActual) + ')';
end;



procedure TUVEdit.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
  var
  xActual:     integer;
  yActual:     integer;
begin
    xActual := X;
  yActual := Y;

   StatusBar1.Panels[0].Text :=
    '(' + IntToStr(xActual) + ', ' + IntToStr(yActual) + ')';
end;

procedure TUVEdit.PaintBox1Paint(Sender: TObject);
var
  F:TFile;
 Fname:String;
   mat:TMAT;
   nMatCell,s,i,x0,y0,x01,y01,min,max,offset,Stotal,min_v,min_u:integer;
   bm,bmp:TBitmap;
   cmppal:TCMPPal;
    txv:TTXVertex;
    vx,ref:TJKVertex;
    u,v:single;
     x, y: integer;
     dx: double;
  iBMWid, iBMHeight: integer;
  normal:TVector;
  un,vn,dxu:Tvector;
  tv_u,tv_v:double;
  v1,v2,v3,v4:TJKVertex;
  minx,miny,maxx,maxy:double;
  xv,yv:Tvector;
begin


     offset:=0;
      min:=0;
      max:=0;
      min_v:=0;
      min_u:=0;
    Fname:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Material;
        GetLevelPal(Level,cmpPal);
  f:=OpenGameFile(Fname);
  if f=nil then begin  Raise Exception.Create(Fname+' not found'); end;


  mat:=TMat.Create(f,nMatCell);
  Mat.SetPal(cmpPal);
  bm:=MAT.LoadBitmap(mat.Info.width,mat.Info.height);
  //bm.PixelFormat:= pf32bit;

    dxu.dx:=1;
    dxu.dy:=0;
    dxu.dz:=0;
   ref:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.GetItem(0);

   //get min / max size
   for s:=0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count-1 do
           begin
           txv:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(s);
           normal:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].normal;
           vx:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.GetItem(s);


          // CalcSurfRect(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF],v1,v2,v3,v4,0.0);
          SysCalcSurfData(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF],xv,yv,minx,miny,maxx,maxy);
          // CalcUVNormals(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF],un,vn);

           NJEDCalcUVNormalsFrom(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF],0,un,vn);
        //   un:=VCross(un,dxu);
           //construct a u,v coordinate by projecting it onto each basis vector:
           tv_u:= DotProduct(vx.x-ref.x,vn.dx,vx.y-ref.y,vn.dy,vx.z-ref.z,vn.dz);
           tv_v:= abs(DotProduct(vx.x-ref.x,un.dx,vx.y-ref.y,un.dy,vx.z-ref.z,un.dz));

           if vx.z <>0 then  dx := vx.x / vx.z;


           x0:=round(txv.u);
           y0:=round(txv.v);
          //  x01:=round((txv.u/bm.Width)*PixelPerUnit*level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].uscale);
         //   y01:=round((txv.v/bm.Height)*PixelPerUnit*level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].vscale);


           if x0 < min then  min:=x0;
           if x0 < min_u then min_u:=x0;

           if y0 < min then  min:=y0;
           if y0 < min_v then  min_v:=y0;


           if x0 > max then  max:=x0;
           if y0 > max then  max:=y0;
           end;

           label1.Caption:=inttostr(min);
           label2.Caption:=inttostr(max);

  // if min<0 then offset:=max;
  if min <0 then
      begin
      min_v:=abs(min_v);
      min_u:=abs(min_u);
      end
       else
       begin
        min_v:=0;
        min_u:=0;
       end;

       Stotal:=abs(min)+abs(max);

   Bmp := TBitmap.Create;
   bmp.Width:= Stotal+3;
   bmp.Height:= Stotal+3;
   Bmp.Canvas.Pen.Mode:=pmCopy;
   Bmp.Canvas.Brush.Style:=bsSolid;
   Bmp.Canvas.Brush.Color := clblack;
   Bmp.Canvas.FillRect(Rect(0,0,Stotal+3,Stotal+3));
  // bm.Canvas.StretchDraw(rect(bm.Width-1,0,-1,bm.Height),bm);
  //   bm.Canvas.StretchDraw(rect(0,0,bm.Width,bm.Height),bm);
   // Bmp.Canvas.Draw(min_u,min_v,bm);






    iBMWid := bm.Width;
  iBMHeight := bm.Height;
  y := 0;
  while y < Bmp.Height do
  begin
    x := 0;
    while x < bmp.Width do
    begin
      bmp.Canvas.Draw(x, y, bm);
      x := x + iBMWid;
    end;
    y := y + iBMHeight;
  end;










    //  bmp.Canvas.Draw(0,0,bm);

          SetPointSize(3);
    for s:=0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count-1 do
           begin
              txv:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(s);

//DrawVertex( (txv.u * (bm.Width div 2))  ,      (-(txv.v * (bm.Height div 2))) );
           //     DrawVertex( txv.u + Bmp.Width div 2,      ( -(txv.v ) )+Bmp.Height div 2 );
           //    memo1.Lines.Add(floattostr(txv.u)+','+floattostr(txv.v));




            u:=(txv.u);
            v:=(txv.v);

           //  u:=(txv.u)*PixelPerUnit*level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].uscale;
           //  v:=(txv.v)*PixelPerUnit*level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].vscale;
           //  min_u:=0;
           //  min_v:=0;

                Bmp.Canvas.pen.Color:=clred;
                 if s=0 then
                  begin
                 //  Bmp.Canvas.MoveTo(round(u)+min_u,((round(v)))+min_v);
                      Bmp.Canvas.MoveTo(abs(round(u)),abs(round(v)));
                //   Bmp.Canvas.pen.Color:=clblue;
                 //  bmp.Canvas.Rectangle(round(u),round(v),round(u)+113,round(v)+113);
              //   Bmp.Canvas.Pixels[1,1]:=Bmp.Canvas.Pen.Color;
                //   Bmp.Canvas.pen.Color:=clred;


                    x0:=round(u)+min_u; y0:=(round(v)+min_v);
                   end
                 else
                    begin
                    if s=1 then Bmp.Canvas.pen.Color:=clblue;
                    // Bmp.Canvas.LineTo(round(u)+min_u,((round(v)))+min_v);
                    Bmp.Canvas.LineTo(abs(round(u)),abs(round(v)));
                    end;

                // Bmp.Canvas.LineTo(round(u)+min_u,(round(v))+min_v);

        end;
            if level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count>0 then  Bmp.Canvas.LineTo(x0,y0);

     // draw verts
       for s:=0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count-1 do
           begin
              txv:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(s);

                    Bmp.Canvas.pen.Color:=clblue;
                     if s=0 then Bmp.Canvas.pen.Color:=clyellow;
                 //  bmp.Canvas.Rectangle(round(u),round(v),round(u)+113,round(v)+113);
                 Bmp.Canvas.Pixels[round(txv.u),round(txv.v)]:=Bmp.Canvas.Pen.Color;
           end;


       SetCanvasZoomAndRotation(Paintbox1.Canvas, ZoomFactor, 0, 0, 0);

      Paintbox1.Canvas.Draw( XOffset,YOffset,bmp);
      bmp.Free;
      bm.Free;
end;


Procedure TUVEdit.SetCanvasZoomAndRotation(ACanvas: TCanvas; Zoom: Double;
  Angle: Double; CenterpointX, CenterpointY: Double);
var
  form: tagXFORM;
  rAngle: Double;
begin
  rAngle := DegToRad(Angle);
  SetGraphicsMode(ACanvas.Handle, GM_ADVANCED);
  SetMapMode(ACanvas.Handle, MM_ANISOTROPIC);
  form.eM11 := Zoom * Cos(rAngle);
  form.eM12 := Zoom * Sin(rAngle);
  form.eM21 := Zoom * (-Sin(rAngle));
  form.eM22 := Zoom * Cos(rAngle);
  form.eDx := CenterpointX;
  form.eDy := CenterpointY;
  SetWorldTransform(ACanvas.Handle, form);
end;




Procedure TUVEdit.SetPointSize(size:double);
begin
 halfpsize:=round(size/2);
 psizeodd:=round(size) mod 2;
end;


procedure TUVEdit.SetUVButtonClick(Sender: TObject);
var
  row,s:integer;
  txv:TTXVertex;
begin

  row := UV_StringGrid.RowCount;

  for s:=1 to row-1 do
  begin
     txv:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(s-1);
     txv.u:= strtofloat(UV_StringGrid.Cells[1,s]);
     txv.v:= strtofloat(UV_StringGrid.Cells[2,s]);
     level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.Items[s-1]:=txv;

  end;
 Windows.SetFocus(0);
end;

Procedure TUVEdit.DrawVertex(X,Y:double);
var vx,vy,vz:single;
    px,py:integer;
begin
 // vx:=cdx+x; vy:=cdy+y; vz:=cdz+z;
 // MultVM3s(mx,vx,vy,vz);
{  vx:=vx;
  vy:=vy;
  vz:=vz;}
  {Project}
  px:=round(x);
  py:=round(y);

{  if vz<1 then exit;
  px:=wcx+round(vx/vz);
  py:=wcy+Round(vy/vz);}

   Bmp.Canvas.Brush.Color := clblue;

//  if halfpsize=0 then Bmp.Canvas.Pixels[px,py]:=clred
 // else bmp.Canvas.Rectangle(px-halfpsize,py-halfpsize,px+halfpsize+psizeodd,py+halfpsize+psizeodd);
 bmp.Canvas.Rectangle(px,py,px,py);
end;



end.
