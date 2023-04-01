unit ogl_PRender;
  {
This is the OpenGL 3D Renderer
}
interface
uses Windows, dglOpenGL, Prender, Classes, J_Level, Forms,
     Messages, files, FileOperations, graph_files,
     lev_utils, sysUtils, misc_utils, GlobalVars, geometry,
     Math, Images,ExtCtrls;

type pCOlorTableExt=Procedure
(target:GLenum;internalformat:GLenum;width:GLsizei;
 format:GLenum;ttype:GLenum; const table);stdcall;

     pColorSubTableExt=Procedure
      (target:GLenum; start:GLsizei; count:GLsizei; format:GLenum;
       ttype:GLenum; const table);stdcall;


TOGLTexture=class(T3DPTexture)
 ObjIdx:TGLuint;
 Constructor CreateFromMat(const Mat:string;const Pal:TCMPPal;gamma:double);
 Procedure SetCurrent;{override;}
 Destructor Destroy;override;
end;


TOGLPRenderer=class(TNewPRenderer)
   hdc,hglc:LongWord;
   hpal:integer;

 Constructor Create(aForm:TForm);
 Constructor CreateFromPanel(aPanel:TPanel);
 Destructor Destroy;override;
 Procedure Initialize;override;
 Function LoadTexture(const name:string;const pal:TCMPPal;const cmp:TCMPTable):T3DPTexture;override;
 Procedure DrawMesh(m:T3DPMesh);override;
 Procedure GetWorldLine(X,Y:integer;var X1,Y1,Z1,X2,Y2,Z2:double);override;
 Procedure ClearTXList;override;
 Procedure SetViewToThing(th:TJKThing);override;
 Procedure Redraw;override;
Private
 Procedure SetMatrix;
 Function CreateOGLPalette(const pd:TPIXELFORMATDESCRIPTOR):integer;
end;


implementation

var ntex:integer=0;

{function wglGetProcAddress; stdcall;    external opengl32;
Procedure glGenTextures(n:GLsizei; var textures:GLuint); stdcall; external opengl32;
Procedure glDeleteTextures (n:GLsizei; var textures:GLuint); stdcall; external opengl32;}


//Const
// GL_COLOR_INDEX8_EXT = $80E5;
// GL_RGB8             = $8051;
// GL_RGB5             = $8050;

var
 pPalProc:pColorTableExt;

{    pfnColorTableEXT = (PFNGLCOLORTABLEEXTPROC)
        wglGetProcAddress("glColorTableEXT");
    if (pfnColorTableEXT == NULL)
        return FALSE;
    pfnColorSubTableEXT = (PFNGLCOLORSUBTABLEEXTPROC)
        wglGetProcAddress("glColorSubTableEXT");
    if (pfnColorSubTableEXT == NULL)
        return FALSE;

    glTexImage2D( GL_TEXTURE_2D, 0, GL_COLOR_INDEX8_EXT,
          sizeX, sizeY, 0,
          GL_COLOR_INDEX, GL_UNSIGNED_BYTE,
          _data );

    pfnColorTableEXT(GL_TEXTURE_2D, GL_RGB8, sizeof(YOUR_PALETTE),
	  GL_RGBA, GL_UNSIGNED_BYTE, YOUR_PALETTE );}

procedure DisableFPUExceptions ;
var
  FPUControlWord: WORD ;
asm
  FSTCW   FPUControlWord ;
  OR      FPUControlWord, $4 + $1 ; { Divide by zero + invalid operation }
  FLDCW   FPUControlWord ;
end ;



Constructor TOGLPRenderer.CreateFromPanel(aPanel:TPanel);
begin
 Whandle:=aPanel.handle;
 VWidth:=aPanel.Width;
 VHeight:=aPanel.Height;

 TxList:=TStringList.Create;
 TXList.Sorted:=true;
 CmpList:=TStringList.Create;
 CmpList.Sorted:=true;
 Sectors:=TSectors.Create;
 scList:=TMeshes.Create;
 thList:=TMeshes.Create;
 things:=TThings.Create;


end;

Constructor TOGLPRenderer.Create(aForm:TForm);
begin
 Inherited Create(aForm);
 WHandle:=aForm.Handle;
end;

Destructor TOGLPRenderer.Destroy;
begin
 if (hdc<>0) and (hglc<>0) then
 begin
  wglMakeCurrent(hdc,hglc);
  wglDeleteContext(hglc);
  DeleteDC(hdc);
end;

 if hpal<>0 then DeleteObject(hPal);
 inherited Destroy;
end;

Procedure TOGLPRenderer.Initialize;
var
    pfd : TPIXELFORMATDESCRIPTOR;
    pixelFormat:integer;
    hgl:integer;
begin
 if not InitOpenGL then Raise Exception.Create('Couldn''t initialize OpenGL');
 hdc:=GetDC(WHandle);
{ pfd.nsize :=  40;
 pfd.nVersion := 1;
pfd.dwFlags :=  PFD_DRAW_TO_WINDOW + PFD_SUPPORT_OPENGL+PFD_DOUBLEBUFFER;
 pfd.iPixelType := PFD_TYPE_RGBA;
 pfd.cColorBits := 8; pfd.cRedBits := 0; pfd.cRedShift := 0; pfd.cGreenBits := 0;
 pfd.cGreenShift := 0; pfd.cBlueBits := 0; pfd.cBlueShift := 0; pfd.cAlphaBits := 0;
 pfd.cAlphaShift := 0; pfd.cAccumBits := 0; pfd.cAccumRedBits := 0; pfd.cAccumGreenBits := 0;
 pfd.cAccumBlueBits := 0; pfd.cAccumAlphaBits := 0; pfd.cDepthBits := 32;
 pfd.cStencilBits := 0; pfd.cAuxBuffers := 0; pfd.iLayerType := PFD_MAIN_PLANE;
pfd.iLayerType := 0;
 pfd.bReserved := 0;
 pfd.dwLayerMask := 0;
 pfd.dwVisiblemask := 0;
 pfd.dwDamageMask := 0;
 pixelFormat := ChoosePixelFormat(HDC, @pfd);
 SetPixelFormat(Hdc, pixelFormat, @pfd);
 DescribePixelFormat(HDC, pixelFormat, sizeof(pfd), pfd);
 Hpal:=CreateOGLPalette(pfd);    }
 hglc:=CreateRenderingContext(hdc, [opDoubleBuffered],32,16,0,0,0,0);
 ActivateRenderingContext(hdc,hglc);
 hglc:= wglCreateContext(hdc);
 wglMakeCurrent(hdc,hglc);
 SwapBuffers(hdc);
 // glPolygonMode(GL_Front_AND_BACK,gl_Line);
 glEnable(GL_CULL_FACE);
 glCullFace(GL_BACK);
 glFrontFace(GL_CCW);

 glEnable(GL_TEXTURE_2D);

 glEnable(GL_DEPTH_TEST);

 glShadeModel(GL_SMOOTH);

 //@pPalProc:=wglGetProcAddress('glColorTableEXT');
  glEnable( GL_BLEND );
glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
 if (@pPalProc=nil) then
 begin
  //PanMessage(mt_info,'Your OpenGL implemetation doesn''t support palettized textures!');
 end;

 { glDepthRange(0,1000);
 glCullFace(GL_BACK);
 glEnable(GL_CULL_FACE);
 glFrontFace(GL_CCW);
 glClearColor(1,1,1,1);}

end;


Procedure TOGLPRenderer.SetViewToThing(th:TJKThing);
var
 bbox:TThingBox;
 tcen_x,tcen_y,tcen_z:double; {thing center}
 tdim_x,tdim_y,tdim_z:double; {thing dimension}
 trad:double; {radius}
 d:double;
begin
 if th.a3DO=nil then exit;
 th.a3DO.GetBBox(bbox);

 tcen_x:=bbox.x1+(bbox.x2-bbox.x1)/2;
 tcen_y:=bbox.y1+(bbox.y2-bbox.y1)/2;
 tcen_z:=bbox.z1+(bbox.z2-bbox.z1)/2;

 trad:=sqrt(sqr(tcen_x-bbox.x1)+sqr(tcen_y-bbox.y1)+sqr(tcen_z-bbox.z1));

 tdim_x:= bbox.x2-bbox.x1;
 tdim_y:= bbox.y2-bbox.y1;
 tdim_z:= bbox.z2-bbox.z1;

// glMatrixMode(GL_MODELVIEW);
// glLoadIdentity();
// gluLookAt(tcen_x + tdim_x, tcen_y + tdim_y, tcen_z + tdim_z,
//          tcen_x, tcen_y, tcen_z,
//          0.0, 1.0, 0.0);


CamX:=tcen_x;
CamY:=tcen_y-trad*1.5;
CamZ:=tcen_z;

end;


Function TOGLPRenderer.CreateOGLPalette(const pd:TPIXELFORMATDESCRIPTOR):integer;
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

Function Min(i1,i2:integer):integer;
begin
 if i1<i2 then result:=i1 else result:=i2;
end;

{Procedure TOGLPRenderer.SetViewPort(x,y,w,h:integer);
begin
end;}

Procedure TOGLPRenderer.DrawMesh(m:T3DPMesh);
var i,j:integer;
    surf:T3DPSurf;
    vxd:TVXdets;
begin
 if m=nil then exit;
 for i:=0 to m.surfs.count-1 do
 begin
 surf:=m.GetSurf(i);
  TOGLtexture(surf.tx).SetCurrent;
  glBegin(GL_POLYGON);
  for j:=0 to surf.vxds.count-1 do
  begin
   vxd:=surf.getVXD(j);
   glColor3ub(vxd.r,vxd.g,vxd.b);
   if surf.tx<>nil then glTexCoord2f(vxd.u,vxd.v);
   glVertex3f(vxd.x,vxd.y,vxd.z);
  end;
  glEnd;
 end;
end;

Procedure TOGLPRenderer.GetWorldLine(X,Y:integer;var X1,Y1,Z1,X2,Y2,Z2:double);
var
   // vp:TViewPortArray;
   vp:TVector4i;
   // pmx,mmx:TMatrixDblArray;
    pmx,mmx:TGLMatrixd4;
{    ax1,ay1,az1,
    ax2,ay2,az2:double;}
    d:double;
begin
 SetMatrix;

{ SetRenderMatrix;}
 glgetIntegerv(GL_VIEWPORT,@vp);
 glGetDoublev(GL_MODELVIEW_MATRIX,@mmx);
 glGetDoublev(GL_PROJECTION_MATRIX,@pmx);

 gluUnProject(X,vp[3]-Y,0,mmx,pmx,vp,@x1,@y1,@z1);
 gluUnProject(X,vp[3]-Y,1,mmx,pmx,vp,@x2,@y2,@z2);
end;

Procedure TOGLPRenderer.SetMatrix;
var a:double;
begin
 wglMakeCurrent(hdc,hglc);      //range check error
 glMatrixMode(GL_Projection);
 glLoadIdentity;
 a:=2*arctan(240/320)/pi*180;
 gluPerspective(a, 320/240 , 0.05, 5000.0);
 glRotated(-90,1,0,0);
 glRotated(pch,1,0,0);
 glRotated(yaw,0,0,1);
 glTranslated(-CamX,-CamY,-CamZ);
end;

Procedure TOGLPRenderer.Redraw;
var i:integer;
    v1,v2,v3:Tvector;
begin
 DisableFPUExceptions;
 SetMatrix;

 {glRotated(rol,0,0,1);}

 glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

 inherited Redraw;

 glFlush;
 SwapBuffers(wglGetCurrentDC);
 //SwapBuffers(hdc);
end;

Function TOGLPRenderer.LoadTexture(const name:string;const pal:TCMPPal;const cmp:TCMPTable):T3DPTexture;
var i:integer;
    Ttx:TOGLTexture;
    pnew:TCMPPal;
begin
 wglMakeCurrent(hdc,hglc);    //range check error

 Result:=nil;
 pnew:=pal;
 ApplyCMPTable(pnew,cmp);
 ttx:=TOGLTexture.CreateFromMat(name,pnew,gamma);
 Result:=ttx;
end;

Procedure TOGLPRenderer.ClearTXList;
var i:integer;
Idx:TGLuint;
begin
 wglMakeCurrent(hdc,hglc);     //range check error
 glBindTexture(GL_TEXTURE_2D,0);
 for i:=txlist.count-1 downto 0 do
 begin
   Idx:= TOGLTexture(txlist.Objects[i]).ObjIdx;
  glDeleteTextures(1,@TOGLTexture(txlist.Objects[i]).ObjIdx);
 end;
 inherited ClearTXList;
end;

Constructor TOGLTexture.CreateFromMat(const Mat:string;const Pal:TCMPPal;gamma:double);
type
  TRGBTripleArray = array[0..32767] of TRGBTriple;
  PRGBTripleArray = ^TRGBTripleArray;

  TRGBQuadArray = array[0..43680] of TRGBQuad;
  pRGBQuadArray = ^TRGBQuadArray;
var
    i,j:integer;
    pb:pANSIchar;    // njed 8/23/2022
    mf:TMat;
    f:TFile;
    pl,pline:pANSIchar;  // njed 8/23/2022
    n:integer;
    bits:PANSIchar;     // njed 8/23/2022
    c:ANSIchar;     // njed 8/23/2022
    pw:^word;
    inrow: PRGBTripleArray;
    inrow32: pRGBQuadArray;
    rgb:TRGBTriple;
    opal:array[0..255] of record r,g,b,a:byte; end;
    usepalette:boolean;

begin
 f:=OpenGameFile(mat);
 mf:=TMat.Create(f,0);

 //usepalette:=(mf.info.storedas<>bylines16) and (@pPalProc<>nil);
 usepalette:=false;   //doesnt work with nvidia


 width:=mf.info.width;
 height:=mf.info.Height;
 GetMem(pb,width*height*3);
 bits:=pb;

 GetMem(pl,width*2);

if usepalette then mf.LoadBits(pb^)
else
begin

 if mf.info.storedas=bylines16 then
 for i:=0 to height-1 do
 begin
  mf.getLine(pl^);
  pw:=pointer(pl);
  for j:=0 to width-1 do
  begin
    pb^:=ANSIchar(chr(Min(Round((pw^ shr 8 and $F8)*gamma),255)));     // njed 8/23/2022
    (pb+1)^:=ANSIchar(chr(Min(Round((pw^ shr 3 and $FC)*gamma),255)));  // njed 8/23/2022
    (pb+2)^:=ANSIchar(chr(Min(Round((pw^ shl 3 and $F8)*gamma),255)));   // njed 8/23/2022
   inc(pw);
   inc(pb,3);
  end;

 end;

 if mf.info.storedas=bylines24 then
   for i:=0 to height-1 do
 begin
  mf.getLine(pl^);
  //mf.getLine(inrow^);
  //pw:=pointer(pl);
  inrow:=pointer(pl);
  //move(chr(pl^),inrow^,width*3);
  for j:=0 to width-1 do
  begin
  rgb.rgbtRed:=  min( Round(inrow^[j].rgbtRed*gamma) ,255 );
  rgb.rgbtGreen:=min( Round(inrow^[j].rgbtGreen*gamma) ,255 );
  rgb.rgbtBlue:= min( Round(inrow^[j].rgbtBlue*gamma) ,255 );

  move(rgb.rgbtRed,pb^,sizeof(byte));
  move(rgb.rgbtGreen,(pb+1)^,sizeof(byte));
  move(rgb.rgbtBlue,(pb+2)^,sizeof(byte));

  inc(pb,3);
  end;
 end;

 if mf.info.storedas=bylines32 then
   for i:=0 to height-1 do
 begin
  mf.getLine(pl^);
  inrow32:=pointer(pl);

  for j:=0 to width-1 do
  begin
  rgb.rgbtRed:=  min( Round(inrow32^[j].rgbRed*gamma) ,255 );
  rgb.rgbtGreen:=min( Round(inrow32^[j].rgbGreen*gamma) ,255 );
  rgb.rgbtBlue:= min( Round(inrow32^[j].rgbBlue*gamma) ,255 );

  move(rgb.rgbtRed,pb^,sizeof(byte));
  move(rgb.rgbtGreen,(pb+1)^,sizeof(byte));
  move(rgb.rgbtBlue,(pb+2)^,sizeof(byte));

  inc(pb,3);
  end;
 end;

 if mf.info.storedas=bylines then
 for i:=0 to height-1 do
 begin
  mf.getLine(pl^);

  for j:=0 to width-1 do
  begin
   c:=ANSIchar((pl+j)^);  //njed 8/23/2022
   With pal[ord(c)] do
   begin
    pb^:=ANSIchar(chr(r));      // njed 8/23/2022
    (pb+1)^:=ANSIchar(chr(g));  // njed 8/23/2022
    (pb+2)^:=ANSIchar(chr(b));   // njed 8/23/2022
   end;
   inc(pb,3);
  end;

 end;
end;


 {for i:=0 to height-1 do
 begin
  mf.GetLine(pb^);
  inc(pb,width);
 end;}

{ for i:=0 to height-1 do
 begin
  pline:=pl;
  mf.GetLine(pline^);
  for j:=0 to width-1 do
  begin
   n:=ord(pline^);
   With Pal[n] do
   begin
    pb^:=chr(r);
    (pb+1)^:=chr(g);
    (pb+2)^:=chr(b);
   end;
   inc(pb,3);
   inc(pline);
  end;

 end;   }
 FreeMem(pl);
 mf.free;

glGenTextures(1,@ObjIdx);
 glBindTexture(GL_TEXTURE_2D,ObjIdx);

 glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
 glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
 glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
 glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
 glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_nearest);
 glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_nearest);
{ a:=GL_SPHERE_MAP;
 glTexGeniv(GL_S,GL_TEXTURE_GEN_MODE,@a);
 glTexGeniv(GL_T,GL_TEXTURE_GEN_MODE,@a);
 glTexGeniv(GL_R,GL_TEXTURE_GEN_MODE,@a);
 glTexGeniv(GL_Q,GL_TEXTURE_GEN_MODE,@a);}

 {glTexImage2D(GL_TEXTURE_2D, 0,3,width, height, 0,
   GL_RGB, GL_UNSIGNED_BYTE, bits^);}

 for i:=0 to 255 do
 begin
  opal[i].r:=pal[i].r;
  opal[i].g:=pal[i].g;
  opal[i].b:=pal[i].b;
  opal[i].a:=0;
 end;

 if usepalette then
 begin
  pPalProc(GL_TEXTURE_2D, GL_RGB8, 256,
	  GL_RGBA, GL_UNSIGNED_BYTE, opal );


  glTexImage2D( GL_TEXTURE_2D, 0, GL_COLOR_INDEX8_EXT,
          width, height, 0,
          GL_COLOR_INDEX, GL_UNSIGNED_BYTE,
          bits );
 end else
 begin

 

  glTexImage2D( GL_TEXTURE_2D, 0, GL_RGB8,
          width, height, 0,
          GL_RGB, GL_UNSIGNED_BYTE,
         bits );
 end;


{ pPalProc(GL_TEXTURE_2D, GL_RGB8, 256,
	  GL_RGBA, GL_UNSIGNED_BYTE, opal );


 glTexImage2D( GL_TEXTURE_2D, 0, GL_COLOR_INDEX8_EXT,
          width, height, 0,
          GL_COLOR_INDEX, GL_UNSIGNED_BYTE,
          bits^ );}



 i:=glGetError;
 if i<>0 then;

 glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST); {GL_NICEST);}
 {glBindTexture(GL_TEXTURE_2D,0);}

 FreeMem(bits);

end;


Procedure TOGLTexture.SetCurrent;
begin
 if self<>nil then
 begin
  glBindTexture(GL_TEXTURE_2D,ObjIdx);
 end else glBindTexture(GL_TEXTURE_2D,0);
end;

Destructor TOGLTexture.Destroy;
begin
 {glBindTexture(GL_TEXTURE_2D,0);
 glDeleteTextures(1,ObjIdx);}
end;

end.
