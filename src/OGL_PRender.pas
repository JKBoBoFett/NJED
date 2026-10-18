unit ogl_PRender;
  {
This is the OpenGL 3D Renderer
}
interface
uses Windows, dglOpenGL, Prender, Classes, J_Level, Forms,
     Messages, files, FileOperations, graph_files,
     lev_utils, sysUtils, misc_utils, GlobalVars, geometry,
     Math, Images,ExtCtrls,Jed_Main, MatPixels;

type pCOlorTableExt=Procedure
(target:GLenum;internalformat:GLenum;width:GLsizei;
 format:GLenum;ttype:GLenum; const table);stdcall;

     pColorSubTableExt=Procedure
      (target:GLenum; start:GLsizei; count:GLsizei; format:GLenum;
       ttype:GLenum; const table);stdcall;


TOGLTexture=class(T3DPTexture)
 ObjIdx:TGLuint;
 EmissIdx:TGLuint;     // glow only copy of the texture (0 = none)
 Constructor CreateFromMat(const Mat:string;const Pal,GlowPal:TCMPPal;const Dark:TCMPTable;gamma:double);
 Procedure SetCurrent;{override;}
 Destructor Destroy;override;
end;


TOGLPRenderer=class(TNewPRenderer)
   hdc,hglc:LongWord;
   hpal:integer;
   AlphaList:TList;      // surfaces with 4 bit alpha, drawn last (far to near) with blending
   GlowList:TList;       // surfaces with an emissive texture, glow added after the normal pass

 Constructor Create(aForm:TForm);
 Constructor CreateFromPanel(aPanel:TPanel);
 Destructor Destroy;override;
 Procedure Initialize;override;
 Function LoadTexture(const name:string;const pal:TCMPPal;const cmp,dark:TCMPTable):T3DPTexture;override;
 Procedure DrawMesh(m:T3DPMesh);override;
 Procedure GetWorldLine(X,Y:integer;var X1,Y1,Z1,X2,Y2,Z2:double);override;
 Procedure ClearTXList;override;
 Procedure SetViewToThing(th:TJKThing);override;
 Procedure Redraw;override;
 Procedure LookAtThing(const bbox:TThingBox;tpch,tyaw:double;zoom:double); override;
 Procedure SetPCHYAW(pch,yaw:double);override;
 Procedure RenderSelectedSurf;override;
 Function ProjectToScreen(x,y,z:double;var sx,sy:double):boolean;override;
Private
 Procedure DrawMarquee;
 Procedure DrawSurf(surf:T3DPSurf);
 Procedure DrawAlphaSurfs;
 Procedure DrawGlowSurfs;
 Procedure SetMatrix;
 Function CreateOGLPalette(const pd:TPIXELFORMATDESCRIPTOR):integer;
end;

implementation

var ntex:integer=0;
 pPalProc:pColorTableExt;

procedure DisableFPUExceptions;
var
  FPUControlWord: WORD;
asm
  FSTCW   FPUControlWord;
  OR      FPUControlWord, $4 + $1; { Divide by zero + invalid operation }
  FLDCW   FPUControlWord;
end;

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
 AlphaList.Free;
 GlowList.Free;
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
 //hglc:=CreateRenderingContext(hdc, [opDoubleBuffered],32,24,0,0,0,0);
 hglc := CreateRenderingContext(hdc, [opDoubleBuffered], 24, 24, 8, 0, 0, 0);
 ActivateRenderingContext(hdc,hglc);
 hglc:= wglCreateContext(hdc);
 wglMakeCurrent(hdc,hglc);
 //SwapBuffers(hdc);
 // glPolygonMode(GL_Front_AND_BACK,gl_Line);
 glEnable(GL_CULL_FACE);
 glCullFace(GL_BACK);
 glFrontFace(GL_CCW);

 glShadeModel(GL_SMOOTH);

 glEnable(GL_DEPTH_TEST);

 glEnable(GL_TEXTURE_2D);
 glPolygonmode(GL_FRONT, GL_FILL);
end;


Procedure TOGLPRenderer.SetViewToThing(th:TJKThing);
var
 bbox:TThingBox;
 tcen_x,tcen_y,tcen_z:double; {thing center}
 tdim_x,tdim_y,tdim_z:double; {thing dimension}
 trad:double; {radius}
 d,nd:double;
  vec:TVector;
begin
// if th.a3DO=nil then exit;
// th.a3DO.GetBBox(bbox);
//
//
// tcen_x:=bbox.x1+(bbox.x2-bbox.x1)/2;
// tcen_y:=bbox.y1+(bbox.y2-bbox.y1)/2;
// tcen_z:=bbox.z1+(bbox.z2-bbox.z1)/2;
//
// trad:=sqrt(sqr(tcen_x-bbox.x1)+sqr(tcen_y-bbox.y1)+sqr(tcen_z-bbox.z1));
// d:=FrontPlane+Trad;
//
// d:=FrontPlane+Trad;
// nd:=trad/sin(320*pi/180);
// if nd>d then d:=nd;
// nd:=trad/sin(240*pi/180);
// if nd>d then d:=nd;
//
//
// CamX:=tcen_x;
// CamY:=tcen_y-10;
// CamZ:=tcen_z;

end;


//from pjedi source
Procedure TOGLPRenderer.LookAtThing(const bbox:TThingBox;tpch,tyaw:double;zoom:double);
var tcen_x,tcen_y,tcen_z:double; {thing center}
    trad:double; {radius}
    nd,d:double;
    vec:TVector;
begin
 tcen_x:=bbox.x1+(bbox.x2-bbox.x1)/2;
 tcen_y:=bbox.y1+(bbox.y2-bbox.y1)/2;
 tcen_z:=bbox.z1+(bbox.z2-bbox.z1)/2;
 trad:=sqrt(sqr(tcen_x-bbox.x1)+sqr(tcen_y-bbox.y1)+sqr(tcen_z-bbox.z1));
 d:=FrontPlane+Trad;
 nd:=trad/sin(320*pi/180);
 if nd>d then d:=nd;
 nd:=trad/sin(240*pi/180);
 if nd>d then d:=nd;
 d:=d*zoom;

 SetVec(vec,0,d,0);
 RotateVector(vec,tpch,0,0);
 RotateVector(vec,0,tyaw,0);

 yaw:=180-tyaw;
 pch:=tpch;

 CamX:=tcen_x+vec.dx;
 CamY:=tcen_y+vec.dy;
 CamZ:=tcen_z+vec.dz;

end;

Procedure TOGLPRenderer.SetPCHYAW(pch,yaw:double);

begin
//if things.count=0 then exit;
//
//th:=Things[0];
// if th.a3DO=nil then exit;
//
//th.a3DO.GetBBox(bbox);
// LookAtThing(bbox,pch,yaw,1.1);
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

Function CompareAlphaSurfs(a,b:Pointer):integer;
begin
 // far to near
 if T3DPSurf(a).sortdist>T3DPSurf(b).sortdist then Result:=-1
 else if T3DPSurf(a).sortdist<T3DPSurf(b).sortdist then Result:=1
 else Result:=0;
end;

// draws one surface; 1 bit alpha textures are alpha tested
Procedure TOGLPRenderer.DrawSurf(surf:T3DPSurf);
var j:integer;
    vxd:TVXdets;
    cutout,solid,untex:boolean;
    a:byte;
begin
 // geo mode 3 (or the preview's force geo mode 3 option): the mat's colour instead of its texture
 solid:=((surf.geo=3) or PreviewForceGeo3) and (surf.tx<>nil);
 // preview option: no textures, just the lighting
 untex:=PreviewUntextured and (not solid);
 cutout:=(surf.tx<>nil) and (surf.tx.AlphaMode=1) and (not solid) and (not untex);
 if surf.translucent then a:=128 else a:=255;   // face flag translucent: ~50% blend
 if cutout then
 begin
  glEnable(GL_ALPHA_TEST);
  glAlphaFunc(GL_GREATER,0.5);
 end;
 if solid or untex then glBindTexture(GL_TEXTURE_2D,0)
 else TOGLtexture(surf.tx).SetCurrent;
 glBegin(GL_POLYGON);
 for j:=0 to surf.vxds.count-1 do
 begin
  vxd:=surf.getVXD(j);
  if solid then
   // same vertex lighting as a textured surface: light * solid colour (what the texture modulate does)
   glColor4ub((vxd.r*surf.tx.SolidR) div 255,(vxd.g*surf.tx.SolidG) div 255,(vxd.b*surf.tx.SolidB) div 255,a)
  else glColor4ub(vxd.r,vxd.g,vxd.b,a);
  if (surf.tx<>nil) and (not solid) and (not untex) then glTexCoord2f(vxd.u,vxd.v);
  glVertex3f(vxd.x,vxd.y,vxd.z);
 end;
 glEnd;
 if cutout then glDisable(GL_ALPHA_TEST);
end;

// emissive textures: the glow-only copy of the texture is added on top of the already drawn surface.
// 8 bit: the glow colours are added as they are (the game adds them to the lit colour).
// 16 bit flag 2: glow is mask * colour * (1 - light), so a fully lit surface gets nothing extra,
// the same as in OpenJKDF2.
Procedure TOGLPRenderer.DrawGlowSurfs;
var i,j:integer;
    surf:T3DPSurf;
    vxd:TVXdets;
    tx:TOGLTexture;
    cutout:boolean;
begin
 if (GlowList=nil) or (GlowList.Count=0) then exit;
 glEnable(GL_BLEND);
 glBlendFunc(GL_ONE,GL_ONE);
 glDepthMask(False);
 glDepthFunc(GL_LEQUAL);
 glEnable(GL_POLYGON_OFFSET_FILL);
 glPolygonOffset(-1.0,-1.0);
 for i:=0 to GlowList.Count-1 do
 begin
  surf:=T3DPSurf(GlowList[i]);
  tx:=TOGLTexture(surf.tx);
  cutout:=tx.AlphaMode=1;
  if cutout then
  begin
   glEnable(GL_ALPHA_TEST);
   glAlphaFunc(GL_GREATER,0.5);
  end;
  glBindTexture(GL_TEXTURE_2D,tx.EmissIdx);
  glBegin(GL_POLYGON);
  for j:=0 to surf.vxds.count-1 do
  begin
   vxd:=surf.getVXD(j);
   if tx.GlowMode=2 then glColor3ub(255-vxd.r,255-vxd.g,255-vxd.b)
   else glColor3ub(255,255,255);
   glTexCoord2f(vxd.u,vxd.v);
   glVertex3f(vxd.x,vxd.y,vxd.z);
  end;
  glEnd;
  if cutout then glDisable(GL_ALPHA_TEST);
 end;
 glDisable(GL_POLYGON_OFFSET_FILL);
 glDepthFunc(GL_LESS);
 glDepthMask(True);
 glDisable(GL_BLEND);
 GlowList.Clear;
end;

// surfaces with 4 bit alpha: sorted far to near, alpha blended, no depth writes
Procedure TOGLPRenderer.DrawAlphaSurfs;
var i,j:integer;
    surf:T3DPSurf;
    vxd:TVXdets;
    cx,cy,cz:double;
begin
 if (AlphaList=nil) or (AlphaList.Count=0) then exit;
 for i:=0 to AlphaList.Count-1 do
 begin
  surf:=T3DPSurf(AlphaList[i]);
  cx:=0; cy:=0; cz:=0;
  for j:=0 to surf.vxds.count-1 do
  begin
   vxd:=surf.getVXD(j);
   cx:=cx+vxd.x; cy:=cy+vxd.y; cz:=cz+vxd.z;
  end;
  if surf.vxds.count>0 then
  begin
   cx:=cx/surf.vxds.count; cy:=cy/surf.vxds.count; cz:=cz/surf.vxds.count;
  end;
  surf.sortdist:=sqr(cx-CamX)+sqr(cy-CamY)+sqr(cz-CamZ);
 end;
 AlphaList.Sort(CompareAlphaSurfs);

 glEnable(GL_BLEND);
 glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
 glDepthMask(False);
 for i:=0 to AlphaList.Count-1 do DrawSurf(T3DPSurf(AlphaList[i]));
 glDepthMask(True);
 glDisable(GL_BLEND);
 AlphaList.Clear;
end;

Procedure TOGLPRenderer.DrawMesh(m:T3DPMesh);
var i,j:integer;
    surf:T3DPSurf;
    vxd:TVXdets;
    vx:TJKVertex;
 s:integer;
    plain:boolean;
begin
 if m=nil then exit;
 for i:=0 to m.surfs.count-1 do
 begin
  surf:=m.GetSurf(i);
  plain:=(surf.geo=3) or PreviewForceGeo3 or PreviewUntextured;   // drawn without the texture: no alpha, no glow
  if surf.translucent or ((surf.tx<>nil) and (surf.tx.AlphaMode=2) and (not plain)) then
  begin
   if AlphaList=nil then AlphaList:=TList.Create;
   AlphaList.Add(surf);        // drawn by DrawAlphaSurfs after everything else
  end
  else DrawSurf(surf);
  if PreviewGlow and (not plain) and (surf.tx<>nil) and (surf.tx.GlowMode<>0) and (TOGLTexture(surf.tx).EmissIdx<>0) then
  begin
   if GlowList=nil then GlowList:=TList.Create;
   GlowList.Add(surf);         // glow is added by DrawGlowSurfs
  end;
 end;

 //NJED 5/19/2025
 if m.selected then
   begin
     if m=nil then exit;
     glEnable(GL_POLYGON_OFFSET_LINE);
     glPolygonOffset(-1.0, -1.0);

     glDisable(GL_TEXTURE_2D);

     glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
     glColor3f(1.0, 1.0, 0.0); // Yellow
   for i:=0 to m.surfs.count-1 do
     begin
       surf:=m.GetSurf(i);
       glBegin(GL_POLYGON);
     for j:=0 to surf.vxds.count-1 do
     begin
       vxd:=surf.getVXD(j);
       glVertex3f(vxd.x,vxd.y,vxd.z);
     end;
       glEnd;

     end;

    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    glEnable(GL_TEXTURE_2D);

    glDisable(GL_POLYGON_OFFSET_LINE);
   end;

end;

 Procedure TOGLPRenderer.RenderSelectedSurf;
 var
 vx:TJKVertex;
 s:integer;
 k,msc,msf:integer;

 // 3DO sectors are rendered with reversed winding (see SecToMesh), so their selection
 // outlines would be back-face culled on the outside; draw them without culling
 Procedure SetCullFor(sec:TJKSector);
 begin
  if (sec.Flags and SF_3DO)<>0 then glDisable(GL_CULL_FACE)
  else glEnable(GL_CULL_FACE);
 end;

 // outlines / tints the multiselected surfaces
 Procedure DrawMultiSelSurf(surf:TJKSurface;fill:boolean);
 var q:integer;
 begin
  if fill then glBegin(GL_POLYGON) else glBegin(GL_LINE_LOOP);
  for q:=0 to surf.Vertices.Count-1 do
  begin
   vx:=surf.GetVXs.GetItem(q);
   glVertex3f(vx.x,vx.y,vx.z);
  end;
  glEnd();
 end;

 begin

 if (JedMain.Map_mode = MM_SF) then
 begin

 //multiselection: every selected surface gets a translucent tint and a thick outline in the wireframe multiselection colour (clMSel)
 if JedMain.sfsel.Count>0 then
 begin
  glDisable(GL_TEXTURE_2D);
  glEnable(GL_POLYGON_OFFSET_FILL);
  glPolygonOffset(-1.0, -1.0);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
  glDepthMask(False);
  glDepthFunc(GL_LEQUAL);
  glColor4ub(clMSel.r,clMSel.g,clMSel.b,102);   // same colour as the wireframe multiselection
  for k:=0 to JedMain.sfsel.Count-1 do
  begin
   JedMain.sfsel.GetSCSF(k,msc,msf);
   if (msc<0) or (msc>=Level.Sectors.Count) then continue;
   if (msf<0) or (msf>=Level.Sectors[msc].Surfaces.Count) then continue;
   SetCullFor(Level.Sectors[msc]);
   DrawMultiSelSurf(Level.Sectors[msc].Surfaces[msf],true);
  end;
  glDepthMask(True);
  glDepthFunc(GL_LESS);
  glDisable(GL_BLEND);
  glDisable(GL_POLYGON_OFFSET_FILL);

  glEnable(GL_POLYGON_OFFSET_LINE);
  glPolygonOffset(-2.0, -2.0);
  glLineWidth(3.0);
  glColor3ub(clMSel.r,clMSel.g,clMSel.b);
  for k:=0 to JedMain.sfsel.Count-1 do
  begin
   JedMain.sfsel.GetSCSF(k,msc,msf);
   if (msc<0) or (msc>=Level.Sectors.Count) then continue;
   if (msf<0) or (msf>=Level.Sectors[msc].Surfaces.Count) then continue;
   SetCullFor(Level.Sectors[msc]);
   DrawMultiSelSurf(Level.Sectors[msc].Surfaces[msf],false);
  end;
  glLineWidth(1.0);
  glDisable(GL_POLYGON_OFFSET_LINE);
  glEnable(GL_TEXTURE_2D);
 end;

 glEnable(GL_POLYGON_OFFSET_LINE);
 glDisable(GL_TEXTURE_2D);
 glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
 SetCullFor(level.Sectors[JedMain.Cur_SC]);

 // current surface: a thick black halo under a thinner yellow line, so it stays visible on yellow (or any) textures
 for k:=0 to 1 do
 begin
  if k=0 then
  begin
   glPolygonOffset(-3.0, -3.0);
   glLineWidth(6.0);
   glColor3f(0.0, 0.0, 0.0);
  end else
  begin
   glPolygonOffset(-4.0, -4.0);
   glLineWidth(2.5);
   glColor3f(1.0, 1.0, 0.0);
  end;
  glBegin(GL_POLYGON);
  for s:=0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count-1 do
  begin
   vx:=level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].GetVXs.GetItem(s);
   glVertex3f(vx.x, vx.y, vx.z);
  end;
  glEnd();
 end;
 glLineWidth(1.0);
 glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
 glEnable(GL_TEXTURE_2D);

 glDisable(GL_POLYGON_OFFSET_LINE);
 glEnable(GL_CULL_FACE);

 end;
 end;


Function TOGLPRenderer.ProjectToScreen(x,y,z:double;var sx,sy:double):boolean;
var
   vp:TVector4i;
   pmx,mmx:TGLMatrixd4;
   wx,wy,wz:double;
begin
 Result:=false;
 sx:=0;sy:=0;
 SetMatrix;
 glgetIntegerv(GL_VIEWPORT,@vp);
 glGetDoublev(GL_MODELVIEW_MATRIX,@mmx);
 glGetDoublev(GL_PROJECTION_MATRIX,@pmx);
 if gluProject(x,y,z,mmx,pmx,vp,@wx,@wy,@wz)=0 then exit;
 if (wz<0) or (wz>1) then exit;   // behind the camera / beyond the far plane
 sx:=wx;
 sy:=vp[3]-wy;
 Result:=true;
end;

Procedure TOGLPRenderer.DrawMarquee;
var vp:TVector4i;
    x1,y1,x2,y2:integer;
begin
 if not MqOn then exit;
 glgetIntegerv(GL_VIEWPORT,@vp);
 x1:=MqX1;y1:=MqY1;x2:=MqX2;y2:=MqY2;
 glMatrixMode(GL_PROJECTION);
 glPushMatrix;
 glLoadIdentity;
 glOrtho(0,vp[2],vp[3],0,-1,1);
 glMatrixMode(GL_MODELVIEW);
 glPushMatrix;
 glLoadIdentity;
 glDisable(GL_TEXTURE_2D);
 glDisable(GL_DEPTH_TEST);
 glDisable(GL_CULL_FACE);
 glEnable(GL_BLEND);
 glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
 glColor4ub(clMSel.r,clMSel.g,clMSel.b,50);
 glBegin(GL_QUADS);
  glVertex2f(x1,y1);glVertex2f(x2,y1);glVertex2f(x2,y2);glVertex2f(x1,y2);
 glEnd;
 glDisable(GL_BLEND);
 glLineWidth(2.0);
 glColor3ub(clMSel.r,clMSel.g,clMSel.b);
 glBegin(GL_LINE_LOOP);
  glVertex2f(x1,y1);glVertex2f(x2,y1);glVertex2f(x2,y2);glVertex2f(x1,y2);
 glEnd;
 glLineWidth(1.0);
 glEnable(GL_DEPTH_TEST);
 glEnable(GL_CULL_FACE);
 glEnable(GL_TEXTURE_2D);
 glPopMatrix;
 glMatrixMode(GL_PROJECTION);
 glPopMatrix;
 glMatrixMode(GL_MODELVIEW);
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
var a,nc,fc:double;
begin
 nc:=NearClip; fc:=FarClip;
 if nc<=0 then nc:=FrontPlane;   {CreateFromPanel may not run the base constructor}
 if fc<=nc then fc:=BackPlane;
 wglMakeCurrent(hdc,hglc);      //range check error
 glMatrixMode(GL_Projection);
 glLoadIdentity;
 a:=2*arctan(240/320)/pi*180;   //vertical viewing angle in degrees.
 gluPerspective(a, 320/240 , nc, fc);
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



 glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);


 if AlphaList=nil then AlphaList:=TList.Create;
 AlphaList.Clear;
 if GlowList=nil then GlowList:=TList.Create;
 GlowList.Clear;
 inherited Redraw;
 DrawGlowSurfs;
 DrawAlphaSurfs;
    RenderSelectedSurf;
 DrawMarquee;

 SwapBuffers(wglGetCurrentDC);

end;

Function TOGLPRenderer.LoadTexture(const name:string;const pal:TCMPPal;const cmp,dark:TCMPTable):T3DPTexture;
var i:integer;
    Ttx:TOGLTexture;
    pnew:TCMPPal;
begin
 wglMakeCurrent(hdc,hglc);    //range check error

 Result:=nil;
 pnew:=pal;
 ApplyCMPTable(pnew,cmp);
 ttx:=TOGLTexture.CreateFromMat(name,pnew,pal,dark,gamma);
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
  if TOGLTexture(txlist.Objects[i]).EmissIdx<>0 then
   glDeleteTextures(1,@TOGLTexture(txlist.Objects[i]).EmissIdx);
 end;
 inherited ClearTXList;
end;

Constructor TOGLTexture.CreateFromMat(const Mat:string;const Pal,GlowPal:TCMPPal;const Dark:TCMPTable;gamma:double);
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
    px:TPix16;
    c16:TRGBA8;
    hasAlpha:boolean;
    transIdx:integer;
    ebits,pe:pANSIchar;     // glow only copy, RGBA
    emis16,anyGlow:boolean;
    g8:TRGBA8;
    m:integer;

begin
if mat='00_GLASS.MAT' then
begin
 PanMessage(mt_warning,'Can''t find file anywhere: '+mat);
 exit;
end;

 f:=OpenGameFile(mat);
 mf:=TMat.Create(f,0);

 // geo mode 3 (solid colour): palette index from the mat, looked up in the same lit palette as the texels
 With Pal[mf.GetSolidIndex] do
 begin
  SolidR:=r;
  SolidG:=g;
  SolidB:=b;
 end;

 //usepalette:=(mf.info.storedas<>bylines16) and (@pPalProc<>nil);
 usepalette:=false;   //doesnt work with nvidia

 width:=mf.info.width;
 height:=mf.info.Height;
 hasAlpha:=false;
 AlphaMode:=0;
 GlowMode:=0;
 EmissIdx:=0;
 anyGlow:=false;
 emis16:=false;
 transIdx:=-1;
 GetMem(pb,width*height*4);   // 4 bytes per pixel max (RGBA)
 bits:=pb;
 GetMem(ebits,width*height*4);
 FillChar(ebits^,width*height*4,0);
 pe:=ebits;

 GetMem(pl,width*2);

if usepalette then mf.LoadBits(pb^)
else
begin

 if mf.info.storedas=bylines16 then
 begin
 // 565, or ARGB4444 / ARGB1555 / RGBA4444 / RGBA5551 (see MatPixels)
 px:=mf.GetPix16;
 hasAlpha:=Pix16HasAlpha(px);
 case Pix16AlphaBits(px) of
  1: AlphaMode:=1;      // cutout, alpha tested
  4: AlphaMode:=2;      // blended
 end;
 // flag 2: alpha is a glow mask, the surface is opaque
 emis16:=mf.IsEmissive16;
 if emis16 then
 begin
  hasAlpha:=false;
  AlphaMode:=0;
  GlowMode:=2;
 end;
 for i:=0 to height-1 do
 begin
  mf.getLine(pl^);
  pw:=pointer(pl);
  for j:=0 to width-1 do
  begin
   c16:=DecodePix16(pw^,px);
   pb^:=ANSIchar(chr(Min(Round(c16.r*gamma),255)));
   (pb+1)^:=ANSIchar(chr(Min(Round(c16.g*gamma),255)));
   (pb+2)^:=ANSIchar(chr(Min(Round(c16.b*gamma),255)));
   inc(pb,3);
   if hasAlpha then
   begin
    pb^:=ANSIchar(chr(c16.a));
    inc(pb);
   end;
   if emis16 then
   begin
    m:=c16.a;
    if m<>0 then anyGlow:=true;
    pe^:=ANSIchar(chr(Min(Round(c16.r*gamma*m/255),255)));
    (pe+1)^:=ANSIchar(chr(Min(Round(c16.g*gamma*m/255),255)));
    (pe+2)^:=ANSIchar(chr(Min(Round(c16.b*gamma*m/255),255)));
    (pe+3)^:=ANSIchar(chr(255));
    inc(pe,4);
   end;
   inc(pw);
  end;
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
 begin
 // 8 bit mats with the transparent flag: that palette index becomes alpha 0 (cutout)
 transIdx:=mf.GetTransIndex;
 if transIdx>=0 then
 begin
  hasAlpha:=true;
  AlphaMode:=1;
 end;
 GlowMode:=1;
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
   if hasAlpha then
   begin
    if ord(c)=transIdx then pb^:=ANSIchar(chr(0)) else pb^:=ANSIchar(chr(255));
    inc(pb);
   end;
   // glow: the colour this palette index keeps in the darkest light row of the CMP
   With GlowPal[Dark[ord(c)]] do g8:=Glow8(r,g,b);
   if (g8.r or g8.g or g8.b)<>0 then anyGlow:=true;
   pe^:=ANSIchar(chr(g8.r));
   (pe+1)^:=ANSIchar(chr(g8.g));
   (pe+2)^:=ANSIchar(chr(g8.b));
   if ord(c)=transIdx then (pe+3)^:=ANSIchar(chr(0)) else (pe+3)^:=ANSIchar(chr(255));
   inc(pe,4);
  end;

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

 

  if hasAlpha then
   glTexImage2D( GL_TEXTURE_2D, 0, GL_RGBA8,
          width, height, 0,
          GL_RGBA, GL_UNSIGNED_BYTE,
         bits )
  else
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

 // glow only copy (emissive 8 bit CMP colours, or the flag 2 mask of a 16 bit mat)
 if anyGlow and (GlowMode<>0) then
 begin
  glGenTextures(1,@EmissIdx);
  glBindTexture(GL_TEXTURE_2D,EmissIdx);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_nearest);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_nearest);
  glTexImage2D( GL_TEXTURE_2D, 0, GL_RGBA8,
          width, height, 0,
          GL_RGBA, GL_UNSIGNED_BYTE,
          ebits );
 end
 else GlowMode:=0;
 FreeMem(ebits);

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
