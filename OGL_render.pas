unit OGL_render;

interface

{This unit contains an OpenGL implementation
 of TRenderer class}

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  dglOpenGL, GlobalVars, Geometry, Render, StdCtrls, misc_utils,math;

type
  TOGL_config = class(TForm)
    GroupBox1: TGroupBox;
    RBPerspective: TRadioButton;
    RBParallel: TRadioButton;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  OGL_config: TOGL_config;

Type
TOGLRenderer=class(TRenderer)
 //hdc,hglc:Integer;
 hdc:HDC;
 hglc:HGLRC;
 glx1,glx2,glz1,glz2:double;

 Perspective:boolean;
{ mode:TRenderStyle;}
 selectBuf:array[1..2048] of GLInt;
 {R_style:TRenderStyle;}

 ccenterx,ccentery,crad:integer;
 ccolor:TCOLORREF;

 OGR,OGB,OGG:integer;

 Procedure Initialize;override;
 Procedure BeginScene;override;
 Procedure SetViewPort(x,y,w,h:integer);override;
 {Procedure SetRenderStyle(rstyle:TRenderStyle);override;}
 Procedure EndScene;override;

 Procedure SetColor(what,r,g,b:byte);override;
 Procedure SetCulling(how:integer);override;

 Procedure DrawPolygon(p:TPolygon);override;
 Procedure DrawPolygons(ps:TPolygons);override;
 Procedure DrawPolygonsAt(ps:TPolygons;dx,dy,dz,pch,yaw,rol:double);override;
 Procedure DrawLine(v1,v2:TVertex);override;
 Procedure DrawVertex(X,Y,Z:double);override;
 Procedure DrawCircle(cx,cy,cz,rad:double);override;
 Procedure DrawVertices(vxs:TVertices);override;
 Procedure Configure;override; {Setup dialog}
 Destructor Destroy; override;

 Procedure BeginPick(x,y:integer);override;
 Procedure EndPick;override;
 Procedure PickPolygon(p:TPolygon;id:integer);override;
 Procedure PickPolygons(ps:TPolygons;id:integer);override;
 Procedure PickLine(v1,v2:TVertex;id:integer);override;
 Procedure PickVertex(X,Y,Z:double;id:integer);override;
 Function GetXYZonPlaneAt(scX,scY:integer;pnormal:TVector; pX,pY,pZ:double; var X,Y,Z:double):Boolean;override;
 Function GetGridAt(scX,scY:integer;var X,Y,Z:double):boolean;override;
 Procedure SetPointSize(size:double);override;
 Procedure ProjectPoint(x,y,z:double; Var WinX,WinY:integer);override;
 Procedure UnProjectPoint(WinX,WinY:integer; WinZ:double; var x,y,z:double);override;
 Function HandleWMQueryPal:integer;override;
 Function HandleWMChangePal:integer;override;
Private
 Procedure SetCamera;
 Procedure SetRenderMatrix;
 Procedure SetPickMatrix(x,y:integer);
 Procedure RenderPoly(p:TPolygon);
 Procedure RenderLine(v1,v2:TVertex);
 Function CreateOGLPalette(const pd:TPIXELFORMATDESCRIPTOR):integer;
 Procedure GLDrawCircle(cx,cy,r:double;num_segments:integer);
end;

implementation

uses Jed_Main, Lev_utils;

{$R *.DFM}

procedure DisableFPUExceptions ;
var
  FPUControlWord: WORD ;
asm
  FSTCW   FPUControlWord ;
  OR      FPUControlWord, $4 + $1 ; { Divide by zero + invalid operation }
  FLDCW   FPUControlWord ;
end ;

Procedure TOGLRenderer.BeginScene;
begin
 DisableFPUExceptions;
 SetRenderMatrix;
 crad:=0;
 With bgnd_clr do glClearColor(r/255,g/255,b/255,0);
 glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

end;

{Procedure TOGLRenderer.SetRenderStyle;
begin
 Case rstyle of
  DRAW_WIREFRAME: begin
                   glPolygonMode(GL_Front_AND_BACK,gl_Line);
                  end;
  DRAW_FLAT_POLYS: GlPolygonMode(GL_FRONT_AND_BACK,gl_fill);
  DRAW_TEXTURED: GlPolygonMode(GL_FRONT_AND_BACK,gl_fill);
  DRAW_VERTICES: GlPolygonMode(GL_Front_AND_BACK,gl_Points);
 end;
 R_Style:=rstyle;
end;}

Procedure TOGLRenderer.EndScene;
var oldpen,pen:Hpen;
begin
 glFlush;
 SwapBuffers(hdc);
 if crad<>0 then
 begin
 // SelectObject(hdc,GetStockObject(NULL_BRUSH));
//  pen:=CreatePen(PS_SOLID,1,ccolor);
 // oldpen:=SelectObject(hdc,pen);
//  Ellipse(hdc,ccenterx-crad,ccentery-crad,ccenterx+crad,ccentery+crad);
 // SelectObject(hdc,oldpen);
 // DeleteObject(pen);
 end;
end;

Procedure TOGLRenderer.SetCamera;
begin
 glMatrixMode(gl_Modelview);
 glLoadIdentity;
  gluLookAt(0,0,0,
           -zv.dx,-zv.dy,-zv.dz,
           yv.dx,yv.dy,yv.dz);

 glTranslated(CamX,CamY,CamZ);
end;

Procedure TOGLRenderer.SetRenderMatrix;
var dpx,dpy:double;
begin
 wglMakeCurrent(hdc,hglc);
 glMatrixMode(GL_Projection);
 glLoadIdentity;

 dpx:=vpw/ppunit*scale;
 dpy:=vph/vpw*dpx;

 GlOrtho(-dpx/2,dpx/2,-dpy/2,dpy/2,-ZRange/2,Zrange/2);

 SetCamera;

end;

Procedure TOGLRenderer.SetPickMatrix(x,y:integer);
var dpx,dpy:double;
     a:TVector4i;
begin
{
 wglMakeCurrent(hdc,hglc);
 glGetIntegerV(GL_VIEWPORT,@a);
 glMatrixMode (GL_PROJECTION);
 glLoadIdentity ();
 gluPickMatrix(X,a[3]-Y,4,4,a);


 dpx:=vpw/ppunit*scale;
 dpy:=vph/vpw*dpx;

 GlOrtho(-dpx/2,dpx/2,-dpy/2,dpy/2,-ZRange/2,Zrange/2);

 SetCamera;

 glMatrixMode(GL_ModelView);
 glLoadIdentity;
 }
end;

Function TOGLRenderer.CreateOGLPalette(const pd:TPIXELFORMATDESCRIPTOR):integer;
var ncolors:integer;
    lp:PLogPalette;
    i:integer;
    rrange,grange,brange:byte;
begin
 Result:=0;
 if pd.dwFlags and PFD_NEED_PALETTE = 0 then exit;
 ncolors:=1 shl pd.cColorBits;
 GetMem(lp,sizeof(TLOGPALETTE)+ncolors*sizeof(TPALETTEENTRY));
 lp.palVersion:=$300;
 lp.palNumEntries:=ncolors;

  RRange:=(1 shl pd.cRedBits)-1;
  GRange:=(1 shl pd.cGreenBits)-1;
  BRange:=(1 shl pd.cBlueBits)-1;

  for i:=0 to nColors-1 do
{$R-}
  With lp.palPalEntry[i] do
{$R+}
  begin
   // Fill in the 8-bit equivalents for each component
   peRed:=(i shr pd.cRedShift) and RRange;
   peRed:=Round(peRed * 255.0 / RRange);
   peGreen:=(i shr pd.cGreenShift) and GRange;
   peGreen:=Round(peGreen * 255.0 / GRange);

   peBlue:=(i shr pd.cBlueShift) and BRange;
   peBlue:=Round(peBlue* 255.0 / BRange);

   peFlags:=0;
   end;
 Result:=CreatePalette(lp^);
 SelectPalette(hDC,Result,FALSE);
 RealizePalette(hDC);
 FreeMem(lp);
end;

Procedure TOGLRenderer.Initialize;
var
    pfd : TPIXELFORMATDESCRIPTOR;
    pixelFormat:integer;
begin

 if not InitOpenGL then Raise Exception.Create('Couldn''t initialize OpenGL');
 // GdiFlush;
 hdc:=GetDC(hViewer);
 // hglc:= wglCreateContext(hdc);
  hglc:=CreateRenderingContext(hdc, [opDoubleBuffered],32,16,0,0,0,0);
 //hglc:=CreateRenderingContext(hdc, [opDoubleBuffered],32,24,8,0,0,0);
 ActivateRenderingContext(hdc,hglc);

 glEnable(GL_DEPTH_TEST);
 glDepthFunc(GL_LEQUAL);
 glClearDepth(1.0);
 glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);

 glPolygonMode(GL_Front_AND_BACK,gl_Line);

 glEnable(GL_DEPTH_TEST);
 glDepthRange(0,1000);

 glEnable(GL_CULL_FACE);
 glCullFace(GL_BACK);
 glFrontFace(GL_CCW);

 SwapBuffers(hdc);
end;

Procedure TOGLRenderer.SetViewPort(x,y,w,h:integer);
begin
 Inherited SetViewPort(x,y,w,h);
 glViewPort(x,y,w,h);
end;

Procedure TOGLRenderer.DrawPolygon(p:TPolygon);
begin
   RenderPoly(p);
end;

Procedure TOGLRenderer.DrawPolygonsAt(ps:TPolygons;dx,dy,dz,pch,yaw,rol:double);
var i,j,n:integer;
    mx:TMat3x3;
    ax,ay,az:double;
begin
 CreateRotMatrix(mx,pch,yaw,rol);
try
 for i:=0 to ps.count-1 do
 with ps[i] do
 begin
  n:=vertices.count;
  case n of
   3: glBegin(GL_triangles);
   4: glBegin(GL_Quads);
  else glBegin(GL_Polygon);
  end;
  for j:=0 to vertices.count-1 do
  with vertices[j] do
  begin
   ax:=x; ay:=y; az:=z;
   MultVM3(mx,ax,ay,az);
   glVertex3d(ax+dx,ay+dy,az+dz);
  end;
 glEnd;
end;

 finally

 end;
end;


Procedure TOGLRenderer.DrawPolygons(ps:TPolygons);
var i:integer;
begin
 for i:=0 to ps.count-1
 do RenderPoly(ps[i]);
 end;

Procedure TOGLRenderer.RenderPoly(p:TPolygon);
var i,n:integer;
begin
 n:=p.vertices.count;
 case n of
  3: glBegin(GL_triangles);
  4: glBegin(GL_Quads);
 else glBegin(GL_Polygon);
 end;

 for i:=0 to p.vertices.count-1 do
 with p.vertices[i] do
 begin
  glVertex3d(x,y,z);
 end;
 glEnd;
 
end;

Procedure TOGLRenderer.DrawVertex(X,Y,Z:double);
begin
 glBegin(gl_points);
 glVertex3d(x,y,z);
 glend;
end;

Procedure TOGLRenderer.DrawCircle(cx,cy,cz,rad:double);
var px,py,px1,py1,i:integer;
    x,y:double;
    vp:TVector4i;
begin
   glgetIntegerv(GL_VIEWPORT,@vp);

   ProjectPoint(cx,cy,cz,px,py);
   ProjectPoint(cx+xv.dx*rad,cy+xv.dy*rad,cz+xv.dz*rad,px1,py1);

   crad:=px1-px;

   glgetIntegerv(GL_VIEWPORT,@vp);

   glPushMatrix();
   glMatrixMode(GL_PROJECTION);

   glLoadIdentity();
   gluOrtho2D(0.0, vp[2], 0.0, vp[3]);

   glMatrixMode(GL_MODELVIEW);
   glLoadIdentity();

   glColor4f(1.0, 0.0, 0.0, 0.5);

   GLDrawCircle(px,vp[3]-py,crad,50);

   glPopMatrix();
end;


//http://slabode.exofire.net/circle_draw.shtml
 Procedure TOGLRenderer.GLDrawCircle(cx,cy,r:double;num_segments:integer);
 var
    theta,tangetial_factor, radial_factor,x,y,tx,ty:double;
    ii:integer;
 begin
     theta := 2 * 3.1415926 / num_segments;
     tangetial_factor := Tan(theta);//calculate the tangential factor
     radial_factor := cos(theta);  //calculate the radial factor

     x := r;//we start at angle = 0
     y := 0;

     ii:=0;

     glBegin(GL_LINE_LOOP);
     while ii < num_segments do
     begin
     glVertex2f(x + cx, y + cy);//output vertex

     //calculate the tangential vector
		//remember, the radial vector is (x, y)
		//to get the tangential vector we flip those coordinates and negate one of them

     tx := -y;
     ty := x;

     x :=x + tx * tangetial_factor;
		 y :=y+ ty * tangetial_factor;

     //correct using the radial factor
     x := x * radial_factor;
		 y := y * radial_factor;

     inc(ii);
     end;
   glEnd();

 end;


Procedure TOGLRenderer.DrawVertices(vxs:TVertices);
var i:integer;
begin
 glBegin(gl_points);
  for i:=0 to vxs.count-1 do
 With Vxs[i] do
  glVertex3d(x,y,z);
 glend;
end;

Procedure TOGLRenderer.Configure; {Setup dialog}
begin
 with OGL_config do
 begin
  RBPerspective.checked:=Perspective;
 end;

if OGL_config.ShowModal=idOk then
with OGL_config do
begin
 Perspective:=RBPerspective.Checked;
end;

end;

Procedure TOGLRenderer.RenderLine(v1,v2:TVertex);
begin
 glBegin(gl_lines);
  With v1 do glVertex3d(x,y,z);
  With v2 do glVertex3d(x,y,z);
 glEnd;
end;

Procedure TOGLRenderer.DrawLine(v1,v2:TVertex);
begin
  RenderLine(v1,v2);
end;

Destructor TOGLRenderer.Destroy;
begin
 wglDeleteContext(hglc);
 DeleteDC(hdc);
 if hpal<>0 then DeleteObject(hPal);
 inherited Destroy;
end;

Procedure TOGLRenderer.BeginPick(x,y:integer);
var
dpx,dpy:double;
    a:TVector4i;

begin
 selected.Clear;
 FillChar(selectBuf,SizeOf(selectBuf),0);

 // Select buffer parameters
 glGetIntegerV(GL_VIEWPORT,@a);
 glSelectBuffer(sizeof(SelectBuf), @selectBuf);


 // Enter to selection mode
 glMatrixMode (GL_PROJECTION);
 glPushMatrix();
 glRenderMode (GL_SELECT);

 glEnable(GL_CULL_FACE);

 // Clear Select Buffer;
 glInitNames();
 glPushName(0);
 glLoadIdentity ();

 gluPickMatrix(X,a[3]-Y,4,4,a);

 dpx:=vpw/ppunit*scale;
 dpy:=vph/vpw*dpx;

 GlOrtho(-dpx/2,dpx/2,-dpy/2,dpy/2,-ZRange/2,Zrange/2);
 glMatrixMode(GL_ModelView);

end;

Procedure TOGLRenderer.EndPick;
var i,j,hits,names:integer;pi:^Integer;
    z:integer;
    zs:TIntList;

Procedure AddID(id,z:integer);
var i,n:integer;
begin
 n:=Selected.Count;
 for i:=0 to n-1 do
 begin
  if z<zs[i] then begin n:=i; break; end;
 end;
 Selected.Insert(n,ID);
 zs.Insert(n,z);
end;

begin
 glFlush;
 hits:=glRenderMode(GL_RENDER);
 Selected.Clear;
 zs:=TIntList.Create;
 pi:=@SelectBuf;
 for i:=0 to hits-1 do
 begin
  names:=pi^; inc(pi);
  z:=pi^;
  inc(pi);inc(pi);
  for j:=0 to names-1 do
  begin
   AddID(pi^,z);
   inc(pi);
  end;
 end;
 zs.free;
 glDisable(GL_CULL_FACE);
end;

Procedure TOGLRenderer.PickPolygon(p:TPolygon;id:integer);
begin
 glLoadName(id);

 RenderPoly(p);

end;

Procedure TOGLRenderer.PickPolygons(ps:TPolygons;id:integer);
var i:integer;
begin
 glLoadName(id);
  for i:=0 to ps.count-1
  do RenderPoly(ps[i]);
end;

Procedure TOGLRenderer.PickLine(v1,v2:TVertex;id:integer);
begin
 glLoadName(id);
 RenderLine(v1,v2);
end;

Procedure TOGLRenderer.PickVertex(X,Y,Z:double;id:integer);
begin
 glLoadName(id);
 DrawVertex(X,Y,Z);
end;

Function TOGLRenderer.GetXYZonPlaneAt(scX,scY:integer;pnormal:TVector; pX,pY,pZ:double; var X,Y,Z:double):Boolean;
var
    vp:TVector4i;
   pmx,mmx:TGLMatrixd4;
    ax1,ay1,az1,
    ax2,ay2,az2:double;
    d:double;
begin
 SetRenderMatrix;
 glgetIntegerv(GL_VIEWPORT,@vp);
 glGetDoublev(GL_MODELVIEW_MATRIX,@mmx);
 glGetDoublev(GL_PROJECTION_MATRIX,@pmx);

 gluUnProject(scX,vp[3]-scY,0,mmx,pmx,vp,@ax1,@ay1,@az1);
 gluUnProject(scX,vp[3]-scY,1,mmx,pmx,vp,@ax2,@ay2,@az2);

 With pnormal do d:=dx*pX+dy*pY+dz*pZ;

 result:=PlaneLineXn(pnormal,D,ax1,ay1,az1,ax2,ay2,az2,x,y,z);
 Result:=Result and (abs(x)<xrange) and (abs(y)<Yrange) and (abs(Z)<ZRange);
 if not result then exit;
 x:=JKRound(x); y:=JKRound(y); z:=JKRound(z);
end;

Function TOGLRenderer.GetGridAt(scX,scY:integer;var X,Y,Z:double):boolean;
begin
 Result:=GetXYZonPlaneAt(scX,ScY,gnormal,GridX,GridY,GridZ,x,y,z);
 if result then begin x:=JKRound(x); y:=JKRound(y); z:=JKRound(z); end;
end;



Procedure TOGLRenderer.UnProjectPoint(WinX,WinY:integer; WinZ:double; var x,y,z:double);
var
   vp:TVector4i;
   pmx,mmx:TGLMatrixd4;
   pixel:Integer;
   Win_Z:integer;
begin


 //SetRenderMatrix;
glgetIntegerv(GL_VIEWPORT,@vp);
glGetDoublev(GL_MODELVIEW_MATRIX,@mmx);
 glGetDoublev(GL_PROJECTION_MATRIX,@pmx);

 //glReadPixels( WinX, vp[3]-WinY, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, @win_Z );
// gluUnProject(WinX,vp[3]-WinY,Win_Z,mmx,pmx,vp,@X,@y,@z);   //converts Windows screen coordinates to OpenGL coordinates
 gluUnProject(WinX,vp[3]-WinY,WinZ,mmx,pmx,vp,@X,@y,@z);   //converts Windows screen coordinates to OpenGL coordinates


 //njed

//glReadPixels(round(X), round(Y), 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, @pixel);
//z:=pixel;
end;

Procedure TOGLRenderer.ProjectPoint(x,y,z:double; Var WinX,WinY:integer);
var
   vp:TVector4i;
   pmx,mmx:TGLMatrixd4;
    WX,WY,WZ:double;
begin
 SetRenderMatrix;
 glgetIntegerv(GL_VIEWPORT,@vp);
 glGetDoublev(GL_MODELVIEW_MATRIX,@mmx);
 glGetDoublev(GL_PROJECTION_MATRIX,@pmx);
 gluProject(x,y,z,mmx,pmx,vp,@wX,@wY,@wZ);
 WinX:=Round(WX);
 WinY:=vp[3]-Round(WY);
end;

Procedure TOGLRenderer.SetPointSize(size:double);
begin
 glPointSize(size);
end;

Function TOGLRenderer.HandleWMQueryPal:integer;
begin
 //Result:=0;
 //if hpal=0 then exit;
 //SelectPalette(hDC, hPal, FALSE);
 //Result:=RealizePalette(hDC);

 //InvalidateRect(hViewer,nil,false);
// Viewer.Invalidate;
end;

Function TOGLRenderer.HandleWMChangePal:integer;
begin
// Result:=0;
/// if hpal=0 then exit;
// SelectPalette(hDC,hPal,FALSE);
// RealizePalette(hDC);
// UpdateColors(hDC);
end;

Procedure TOGLRenderer.SetColor(what,r,g,b:byte);
begin
 case what of
  CL_BackGround:
   begin
   bgnd_clr.r:=r; bgnd_clr.g:=g; bgnd_clr.b:=b;
   end;
 else begin
  glColor3ub(r,g,b);
  Front_clr.r:=r;
   Front_clr.g:=g;
    Front_clr.b:=b;

     end;
 end;
  //PanMessage(mt_info,'Your OpenGL implemetation doesn''t support palettized textures!');

end;

Procedure TOGLRenderer.SetCulling(how:integer);
begin
 case how of
  r_CULLNONE: begin
               glDisable(GL_CULL_FACE);
              end;
  r_CULLBACK: begin
               glEnable(GL_CULL_FACE);
               glCullFace(gl_back);
              end;
  r_CULLFRONT: begin
               glEnable(GL_CULL_FACE);
               glCullFace(gl_front);
              end;
 end;
end;


end.

