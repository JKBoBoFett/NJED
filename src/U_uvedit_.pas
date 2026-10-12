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
  ExtCtrls,files, ComCtrls, Geometry,math,globalvars, Grids,dglOpenGL,System.Types,U_Preview;
  type
  TEdgePair = record
    DeltaU, DeltaV: Double;   // translation to apply to dragged face
    Score: Double;             // lower = better match
  end;
type
  TUVEdit = class(TForm)
    StatusBar1: TStatusBar;
    Memo1: TMemo;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Panel1: TPanel;
    UV_StringGrid: TStringGrid;
    SetUVButton: TButton;
    Panel2: TPanel;
    Timer1: TTimer;
    procedure FormShow(Sender: TObject);
    Procedure SetPointSize(size:double);


    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    procedure SetUVButtonClick(Sender: TObject);

    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure Timer1Timer(Sender: TObject);
    procedure Panel2Resize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormHide(Sender: TObject);
    function ScreenToUV(ScreenX, ScreenY: Integer): TPointf;
    procedure Panel2MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Panel2MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure Panel2MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);

    procedure CalcCentroid;
    procedure ScaleUVs(ScaleFactor: Double);
    procedure RotateUVs(AngleDeg: Double);
    function PointInFace(U, V: Double; F: Integer): Boolean;
    function SnapToNearestEdge(U, V: Double;  IgnoreFace: Integer): TPointF;
    function FindBestEdgeSnapDelta(  FaceIdx: Integer;   CurrentDeltaU, CurrentDeltaV: Double): TEdgePair;
    procedure ScaleAllUVs(ScaleFactor: Double);
  private

    { Private declarations }
    halfpsize,psizeodd:integer;
    YOffset,XOffset,TexAspect:double;
    ZoomFactor:double;
    Dc:TCanvas;
     bm,bmp:TBitmap;
     FTexWidth, FTexHeight: Integer;
     SelectedVertex: Integer;  // -1 = none selected
  Dragging: Boolean;
  DragStartU, DragStartV: Double;  // UV coords where drag began
  UVCentroidU, UVCentroidV: Double;  // center of all UV points
  DragFace: Boolean;  // true = moving whole face, false = moving single vert
  SnapEnabled: Boolean;
  SnapThreshold: Double;  // in UV units
  public
    { Public declarations }
     procedure DrawScene;
     procedure LoadTexture;
  end;

var
  UVEdit: TUVEdit;
  glDC: HDC;
  RC: HGLRC;
  PixelFormat: Integer;
  PFD: TPixelFormatDescriptor;
  FTexture: GLuint;

const
  UVMin = -1.0;  // show 1 tile before origin
  UVMax =  3.0;  // show 3 tiles after origin



implementation

{$R *.dfm}


procedure TUVEdit.FormCreate(Sender: TObject);
begin

  // Get the Device Context of the panel
  // InitOpenGL;
  glDC := GetDC(panel2.Handle);

  // Define the Pixel Format Descriptor
  RC := CreateRenderingContext(glDC, [opDoubleBuffered], 32, 24, 0, 0, 0, 0);
end;

procedure TUVEdit.FormDeactivate(Sender: TObject);
begin
    DeactivateRenderingContext;
end;

procedure TUVEdit.FormDestroy(Sender: TObject);
begin
   // Disable render context
DeactivateRenderingContext;
// "Free" render context
wglDeleteContext(RC);
// Release received device context again
ReleaseDC(Handle, glDC);
end;

procedure TUVEdit.FormHide(Sender: TObject);
begin
    timer1.Enabled:=false;
end;

procedure TUVEdit.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  memo1.Lines.Add('Key: ' + IntToStr(Key));  // debug - does this fire?
// Pan
  case Key of
    VK_RIGHT: XOffset := XOffset + 0.1 * ZoomFactor;
    VK_LEFT:  XOffset := XOffset - 0.1 * ZoomFactor;
    VK_UP:    YOffset := YOffset + 0.1 * ZoomFactor;  // flipped
    VK_DOWN:  YOffset := YOffset - 0.1 * ZoomFactor;  // flipped
  end;

case Key of
  // Scale
  187, VK_ADD:      if ssCtrl in Shift then ScaleUVs(1.1)   // Ctrl+= scale up
                    else ZoomFactor := ZoomFactor * 0.9;
  189, VK_SUBTRACT: if ssCtrl in Shift then ScaleUVs(0.9)   // Ctrl+- scale down
                    else ZoomFactor := ZoomFactor * 1.1;

  // Rotate
  Ord('Q'): RotateUVs(-5.0);   // Q = rotate 5 degrees CCW
  Ord('E'): RotateUVs( 5.0);   // E = rotate 5 degrees CW

  // Fine rotate
  Ord('A'): RotateUVs(-1.0);   // A = rotate 1 degree CCW
  Ord('D'): RotateUVs( 1.0);   // D = rotate 1 degree CW


  {<}  188: if shift=[ssShift] then JedMain.ShiftTexture(st_up)
            else if shift=[ssCtrl] then JedMain.RotateTexture(st_left)
            else if shift=[ssAlt] then JedMain.ScaleTexture(st_down)
            else JedMain.ShiftTexture(st_left);
  {>}  190: if shift=[ssShift] then JedMain.ShiftTexture(st_down)
            else if shift=[ssCtrl] then JedMain.RotateTexture(st_right)
            else if shift=[ssAlt] then JedMain.ScaleTexture(st_up)
            else JedMain.ShiftTexture(st_right);
  Ord('S'): ScaleAllUVs(0.9);   // S = scale down
Ord('W'): ScaleAllUVs(1.1);   // W = scale up
end;

 Preview3D.ReloadLevel;
end;

procedure TUVEdit.FormPaint(Sender: TObject);
begin
label1.Caption:='Paint';
  DrawScene;
end;

procedure TUVEdit.FormResize(Sender: TObject);
begin
label1.Caption:='Resize';
   DrawScene;
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
    MinU, MaxU, MinV, MaxV,AR: Double;

begin
    label1.Caption:='Show';
    ActivateRenderingContext(glDC, RC);
    wglMakeCurrent(glDC, RC);


     timer1.Enabled:=TRUE;

    YOffset:=0;XOffset:=0;
      ZoomFactor:=1;

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


           end;
ZoomFactor := 11.0;   // shows ~22 UV units — fits the 20x20 polygon
XOffset    := -10.0;  // center of -20..0
YOffset    := -10.0;  // center of -20..0



LoadTexture;


MinU := 1e10; MaxU := -1e10;
MinV := 1e10; MaxV := -1e10;

  for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count - 1 do
  begin
    txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(s);
    // Texture quad — tex coords ARE already in 0-1 space so UVMin/Max
// must also be in 0-1 space — fix FormShow:
if txv.u < MinU then MinU := txv.u;
if txv.u > MaxU then MaxU := txv.u;
if txv.v < MinV then MinV := txv.v;
if txv.v > MaxV then MaxV := txv.v;
  end;

  // Center on the UV polygon
 XOffset    := (MinU + MaxU) / 2.0;
YOffset    := ((MinV + MaxV) / 2.0);  // negated to match -(txv.v)
 AR := Double(Panel2.Width) / Double(Panel2.Height);
ZoomFactor := Max((MaxU - MinU) / AR, (MaxV - MinV)) * 0.8;
if ZoomFactor = 0 then ZoomFactor := FTexWidth;

//ShowMessage(
//  'TexSize: ' + IntToStr(FTexWidth) + 'x' + IntToStr(FTexHeight) + #13 +
//  'UScale: ' + FloatToStr(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].uscale) + #13 +
//  'VScale: ' + FloatToStr(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].vscale) + #13 +
//  'UV0: ' + FloatToStr(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(0).u) + ',' +
//            FloatToStr(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(0).v)
//);
  SelectedVertex := -1;
Dragging := False;
SnapEnabled := True;
SnapThreshold := 0.05;  // snaps when within 5% of a tile width
end;



procedure TUVEdit.DrawScene;
const
  TileFactor = 2; // Adjust this value to control tiling
var
 u,v:single;
 s:integer;
 txv:TTXVertex;
 ViewportWidth, ViewportHeight: Integer;
 TilesX, TilesY: Integer;
 x, y,f: Integer;
  HalfW, HalfH: Double;
  AspectRatio: Double;
   UVMin, UVMax: Double;
   UVMinU, UVMaxU: Double;
  UVMinV, UVMaxV,UVMinY,UVMaxY: Double;
  currentMat: String;
begin
 if not wglMakeCurrent(glDC, RC) then Exit;  // ADD THIS FIRST LINE


  // ADD DEBUG HERE:
//  memo1.Clear;
//  memo1.Lines.Add('Tex: ' + IntToStr(FTexWidth) + 'x' + IntToStr(FTexHeight));
//  memo1.Lines.Add('--- Current face verts ---');
//  for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count - 1 do
//  begin
//    txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(s);
//    memo1.Lines.Add('v' + IntToStr(s) +
//      ' u=' + FormatFloat('0.00', txv.u) +
//      ' v=' + FormatFloat('0.00', txv.v) +
//      ' norm_u=' + FormatFloat('0.000', txv.u/FTexWidth) +
//      ' norm_v=' + FormatFloat('0.000', txv.v/FTexHeight));
//  end;

  glDisable(GL_DEPTH_TEST);
  glViewport(0, 0, Panel2.Width, Panel2.Height);


// Get viewport dimensions
 TilesX := Ceil(Panel2.Width / 32);
 TilesY := Ceil(Panel2.Height / 32);


 // glClearColor ( 0.3 ,  0.4 ,  0.7 ,  0.0 ) ;

 glDisable(GL_DEPTH_TEST);

glViewport(0, 0, Panel2.Width, Panel2.Height);


 // glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

glClearColor(0.15, 0.15, 0.15, 1.0);  // dark grey background
glClear(GL_COLOR_BUFFER_BIT);


glMatrixMode(GL_PROJECTION);
glClear(GL_COLOR_BUFFER_BIT);
glLoadIdentity();




AspectRatio := Double(Panel2.Width) / Double(Panel2.Height);
TexAspect   := Double(FTexWidth) / Double(FTexHeight);  // 128/256 = 0.5

HalfH := ZoomFactor;
HalfW := ZoomFactor * AspectRatio;  // <-- multiply by aspect ratio

UVMinU := -HalfW + XOffset;
UVMaxU :=  HalfW + XOffset;
UVMinV := -HalfH + YOffset;
UVMaxV :=  HalfH + YOffset;

 memo1.Lines.Add('HalfW=' + FormatFloat('0.000', HalfW) +
               ' HalfH=' + FormatFloat('0.000', HalfH) +
               ' TexAspect=' + FormatFloat('0.000', TexAspect));

glOrtho(
  -HalfW + XOffset,   // left
   HalfW + XOffset,   // right
   -HalfH + YOffset,   // bottom
  HalfH + YOffset,   // top
  -1.0, 1.0
);


  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();




   glEnable(GL_TEXTURE_2D);


 // --- TILED TEXTURE ---
  // Tex coords == vertex coords in UV space, GL_REPEAT does the rest
  // Draw enough to cover the visible area regardless of zoom/pan
UVMinU := (-HalfW + XOffset);
UVMaxU := ( HalfW + XOffset);
UVMinV := (-HalfH + YOffset);
UVMaxV := ( HalfH + YOffset);



//memo1.Clear;
//memo1.Lines.Add('Panel: ' + IntToStr(Panel2.Width) + 'x' + IntToStr(Panel2.Height));
//memo1.Lines.Add('Tex: ' + IntToStr(FTexWidth) + 'x' + IntToStr(FTexHeight));
//memo1.Lines.Add('AspectRatio: ' + FormatFloat('0.000', Double(Panel2.Width)/Double(Panel2.Height)));
//memo1.Lines.Add('ZoomFactor: ' + FormatFloat('0.000', ZoomFactor));
//memo1.Lines.Add('XOffset: ' + FormatFloat('0.000', XOffset));
//memo1.Lines.Add('YOffset: ' + FormatFloat('0.000', YOffset));
//memo1.Lines.Add('UVMinU: ' + FormatFloat('0.000', -ZoomFactor * (Double(Panel2.Width)/Double(Panel2.Height)) + XOffset));
//memo1.Lines.Add('UVMaxU: ' + FormatFloat('0.000',  ZoomFactor * (Double(Panel2.Width)/Double(Panel2.Height)) + XOffset));
//memo1.Lines.Add('UVMinV: ' + FormatFloat('0.000', -ZoomFactor + YOffset));
//memo1.Lines.Add('UVMaxV: ' + FormatFloat('0.000',  ZoomFactor + YOffset));

glEnable(GL_TEXTURE_2D);
glBindTexture(GL_TEXTURE_2D, FTexture);
glColor3f(1.0, 1.0, 1.0); // reset color so texture isn't tinted


glEnable(GL_BLEND);
glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
glColor4f(1.0, 1.0, 1.0, 0.4);  // 0.4 = 40% opacity, adjust to taste

glBegin(GL_QUADS);
  glTexCoord2f(UVMinU / FTexWidth, -(UVMinV / FTexHeight));  glVertex2f(UVMinU, UVMinV);
glTexCoord2f(UVMaxU / FTexWidth, -(UVMinV / FTexHeight));  glVertex2f(UVMaxU, UVMinV);
glTexCoord2f(UVMaxU / FTexWidth, -(UVMaxV / FTexHeight));  glVertex2f(UVMaxU, UVMaxV);
glTexCoord2f(UVMinU / FTexWidth, -(UVMaxV / FTexHeight));  glVertex2f(UVMinU, UVMaxV);
glEnd;


glDisable(GL_BLEND);
glColor4f(1.0, 1.0, 1.0, 1.0);  // reset alpha for lines/points


glDisable(GL_TEXTURE_2D);
  // Set line color (e.g., white)
  glColor3f(0.0, 1.0, 1.0);



// Draw surface UV loop
glColor3f(0.0, 1.0, 1.0);
glLineWidth(1.5);
//glBegin(GL_LINE_LOOP);
//for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count - 1 do
//begin
//  txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(s);
//glVertex2f(txv.u / FTexWidth, txv.v / FTexWidth);
//end;
//glEnd;
 currentMat := level.Sectors[JedMain.Cur_SC]
                     .surfaces[JedMain.Cur_SF].Material;

 for f := 0 to level.Sectors[JedMain.Cur_SC].surfaces.Count - 1 do
  begin
    // Skip faces that don't share the same texture
    if level.Sectors[JedMain.Cur_SC].surfaces[f].Material <> currentMat then
      Continue;

    if f = JedMain.Cur_SF then
      glColor3f(0.0, 1.0, 1.0)   // cyan = current face
    else
      glColor3f(0.5, 0.5, 0.5);  // grey = same texture faces

    glBegin(GL_LINE_LOOP);
    for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[f]
                        .Vertices.Count - 1 do
    begin
      txv := level.Sectors[JedMain.Cur_SC].surfaces[f]
                  .TXVertices.GetItem(s);
     glVertex2f(txv.u, (txv.v));  // raw pixels, negate V
    end;
    glEnd;
  end;




// --- UV VERTICES ---
  glPointSize(8.0);
  glBegin(GL_POINTS);
  for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count - 1 do
  begin
    txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(s);
    if s = SelectedVertex then
      glColor3f(0.0, 1.0, 0.0)   // green = currently dragging
    else if s = 0 then
      glColor3f(1.0, 0.0, 0.0)   // red = first vert
    else
      glColor3f(1.0, 1.0, 0.0);  // yellow = normal
    glVertex2f(txv.u, (txv.v));  // raw pixels, negate V
  end;
  glEnd;

 // --- ORIGIN MARKER ---
  glColor3f(1.0, 0.5, 0.0);
  glPointSize(6.0);
  glBegin(GL_POINTS);
    glVertex2f(0.0, 0.0);
  glEnd;


  // U axis - red, goes right from origin
glColor3f(1.0, 0.0, 0.0);
glBegin(GL_LINES);
  glVertex2f(-1000.0, 0.0);
  glVertex2f( 1000.0, 0.0);
glEnd;

// V axis - green, goes down from origin
glColor3f(0.0, 1.0, 0.0);
glBegin(GL_LINES);
  glVertex2f(0.0, -1000.0);
  glVertex2f(0.0,  1000.0);
glEnd;



    glColor3f(1.0, 1.0, 1.0);



    glDisable(GL_TEXTURE_2D);
 

glEnable(GL_TEXTURE_2D);


    glFlush;
  SwapBuffers(glDC);
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


procedure TUVEdit.LoadTexture;
type
  TRGBTripleArray = ARRAY[Word] of TRGBTriple;
  pRGBTripleArray = ^TRGBTripleArray; // Use a PByteArray for pf8bit color.
var
Fname:String;
cmppal:TCMPPal;
F:TFile;
nMatCell,Y,X:integer;
mat:TMAT;
bm,bmp:TBitmap;

Pixels: TArray<TRGBTriple>;
Row: PRGBTripleArray;
begin
  Fname:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Material;
  GetLevelPal(Level,cmpPal);

  f:=OpenGameFile(Fname);
  if f=nil then begin  Raise Exception.Create(Fname+' not found'); end;

  mat:=TMat.Create(f,nMatCell);
  Mat.SetPal(cmpPal);
  bm:=MAT.LoadBitmap(mat.Info.width,mat.Info.height);
  bm.PixelFormat:=pf24bit;
  glGenTextures(1, @FTexture);
  glBindTexture(GL_TEXTURE_2D, FTexture);

   SetLength(Pixels, bm.Width * bm.Height);

   FTexWidth  := bm.Width;
FTexHeight := bm.Height;

for Y := 0 to bm.Height - 1 do
begin
  Row := bm.ScanLine[bm.Height - 1 - Y];  // read bottom-to-top
  for X := 0 to bm.Width - 1 do
    Pixels[Y * bm.Width + X] := Row[X];
end;

  mat.Free;

 glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
 glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
 glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
 glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
 glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_nearest);
 glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_nearest);

 // Load the texture data into the texture object
     glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, bm.Width, bm.Height, 0, GL_BGR, GL_UNSIGNED_BYTE, @pixels[0]);

//    glEnable(GL_TEXTURE_2D);

//     glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
//glEnable(GL_CULL_FACE);

 //glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
 //glBindTexture(GL_TEXTURE_2D, FTexture);

  //glPushMatrix();

end;



procedure TUVEdit.Panel2MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  s,f: Integer;
  txv: TTXVertex;
  UV, VertUV: TPointF;
  PickRadius: Double;
  dist: Double;
  mflag:longint;
  currentMat: String;
begin
  UV := ScreenToUV(X, Y);
  SnapThreshold := ZoomFactor * 0.02;
  memo1.Lines.Add('--- Click ---');
memo1.Lines.Add('Screen: ' + IntToStr(X) + ',' + IntToStr(Y));
memo1.Lines.Add('ScreenToUV result: ' + FloatToStr(UV.X) + ',' + FloatToStr(UV.Y));

// Print what the verts actually are in draw space
for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                    .Vertices.Count - 1 do
begin
  txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
              .TXVertices.GetItem(s);
  memo1.Lines.Add('Vert ' + IntToStr(s) +
    ' drawn at: ' + FloatToStr(txv.u / FTexWidth) +
    ',' + FloatToStr(-txv.v / FTexWidth));
end;




  PickRadius := ZoomFactor * 0.015;

  // Debug — show click position and radius
  memo1.Lines.Add('--- Click ---');
  memo1.Lines.Add('Screen: ' + IntToStr(X) + ',' + IntToStr(Y));
  memo1.Lines.Add('UV: ' + FloatToStr(UV.X) + ',' + FloatToStr(UV.Y));
  memo1.Lines.Add('PickRadius: ' + FloatToStr(PickRadius));
  memo1.Lines.Add('ZoomFactor: ' + FloatToStr(ZoomFactor));
   mflag:= level.sectors[JedMain.Cur_SC].Flags;
  for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                      .Vertices.Count - 1 do
  begin
    txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                .TXVertices.GetItem(s);
    VertUV.X :=  txv.u;
    VertUV.Y := (txv.v);

    dist := Sqrt(Sqr(UV.X - VertUV.X) + Sqr(UV.Y - VertUV.Y));

    // Debug — show each vert position and distance from click
    memo1.Lines.Add('Vert ' + IntToStr(s) +
      ' UV:(' + FloatToStr(VertUV.X) + ',' + FloatToStr(VertUV.Y) + ')' +
      ' dist:' + FloatToStr(dist) +
      ' radius:' + FloatToStr(PickRadius));

    if dist < PickRadius then
    begin
      SelectedVertex := s;
      DragStartU := UV.X;
      DragStartV := UV.Y;
      Dragging := True;
      SetCapture(Panel2.Handle);
      memo1.Lines.Add('HIT vert ' + IntToStr(s));
      Break;
    end;
  end;

  if SelectedVertex = -1 then
    memo1.Lines.Add('No hit');


currentMat := level.Sectors[JedMain.Cur_SC]
                     .surfaces[JedMain.Cur_SF].Material;

if SelectedVertex = -1 then
begin
  // Try face hit
  for f := 0 to level.Sectors[JedMain.Cur_SC].surfaces.Count - 1 do
  begin

    // Only test faces with same material
      if level.Sectors[JedMain.Cur_SC].surfaces[f].Material <> currentMat then
        Continue;


    if PointInFace(UV.X, UV.Y, f) then
    begin
      // Select this face
      JedMain.Cur_SF := f;  // or whatever your setter is
      DragStartU := UV.X;
      DragStartV := UV.Y;
      Dragging   := True;
      DragFace   := True;
      SetCapture(Panel2.Handle);
      memo1.Lines.Add('HIT face ' + IntToStr(f));
      Break;
    end;
  end;
end
else
begin
  DragFace := False;  // vertex drag
end;



end;

procedure TUVEdit.Panel2MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  UV: TPointF;
  DeltaU, DeltaV: Double;
  txv: TTXVertex;
  s: Integer;
  snapPt: TPointF;
  pu, pv: Double;
  snapDist: Double;
  snap: TEdgePair;
begin
  UV := ScreenToUV(X, Y);
  SnapThreshold := ZoomFactor * 0.02;

  StatusBar1.Panels[2].Text := 'UV: ' + FormatFloat('0.00', UV.X) +
                                ', '  + FormatFloat('0.00', UV.Y);

  if Dragging and (ssLeft in Shift) then
  begin
    DeltaU := (UV.X - DragStartU) ;
    DeltaV := (UV.Y - DragStartV);

    if DragFace then
    begin
      // --- Edge-loop snap ---
      snap := FindBestEdgeSnapDelta(JedMain.Cur_SF, DeltaU, DeltaV);

      if snap.Score < SnapThreshold then
      begin
        DragStartU := UV.X + (snap.DeltaU - DeltaU) ;
        DragStartV := UV.Y - (snap.DeltaV - DeltaV) ;
        DeltaU := snap.DeltaU;
        DeltaV := snap.DeltaV;
      end
      else
      begin
        DragStartU := UV.X;
        DragStartV := UV.Y;
      end;

      // Apply delta to all verts of the face
      for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                          .Vertices.Count - 1 do
      begin
        txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                    .TXVertices.GetItem(s);
        txv.u := txv.u + DeltaU;
        txv.v := txv.v + DeltaV;
        level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
             .TXVertices.Items[s] := txv;
      end;
    end
    else if SelectedVertex >= 0 then
    begin
      // --- Single vertex drag with edge snap ---
      txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                  .TXVertices.GetItem(SelectedVertex);
      txv.u := txv.u + DeltaU;
      txv.v := txv.v + DeltaV;

      // Snap single vert to nearest edge/vertex on adjacent faces
      pu :=  txv.u;
      pv := txv.v;
      snapPt   := SnapToNearestEdge(pu, pv, JedMain.Cur_SF);
      snapDist := Sqrt(Sqr(pu - snapPt.X) + Sqr(pv - snapPt.Y));

      if snapDist <= SnapThreshold then
      begin
        txv.u :=  snapPt.X;
        txv.v := snapPt.Y;
      end;

      level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
           .TXVertices.Items[SelectedVertex] := txv;

      UV_StringGrid.Cells[1, SelectedVertex + 1] := FloatToStr(txv.u);
      UV_StringGrid.Cells[2, SelectedVertex + 1] := FloatToStr(txv.v);

      DragStartU := UV.X;
      DragStartV := UV.Y;
    end;

    Timer1.Enabled := False;
    DrawScene;
    Timer1.Enabled := True;
  end;
end;
procedure TUVEdit.Panel2MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  Dragging   := False;
  DragFace   := False;
  SelectedVertex := -1;
  ReleaseCapture;
  DrawScene;

   Preview3D.ReloadLevel;
end;

procedure TUVEdit.Panel2Resize(Sender: TObject);
begin
//    glViewport(0, 0, Panel2.Width, Panel2.Height);
//
//  glMatrixMode(GL_PROJECTION);
//  glLoadIdentity();
//  gluPerspective(45.0, Panel2.Width / Panel2.Height, 0.1, 1000.0);
//
//  glMatrixMode(GL_MODELVIEW);
//  glLoadIdentity();
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

procedure TUVEdit.Timer1Timer(Sender: TObject);
begin
label1.Caption:='Timer';
  DrawScene;
end;


function TUVEdit.ScreenToUV(ScreenX, ScreenY: Integer): TPointF;
var
  HalfW, HalfH: Double;
begin
  HalfH := ZoomFactor;
  HalfW := ZoomFactor * (Double(Panel2.Width) / Double(Panel2.Height));
  Result.X :=  (ScreenX / Panel2.Width)  * (HalfW * 2) + (-HalfW + XOffset);
  Result.Y := -(( ScreenY / Panel2.Height) * (HalfH * 2)) + (HalfH + YOffset);
end;


procedure TUVEdit.CalcCentroid;
var
  s: Integer;
  txv: TTXVertex;
  sumU, sumV: Double;
  count: Integer;
begin
  sumU := 0; sumV := 0;
  count := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count;

  for s := 0 to count - 1 do
  begin
    txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                .TXVertices.GetItem(s);
    sumU := sumU + txv.u;
    sumV := sumV + txv.v;
  end;

  UVCentroidU := sumU / count;
  UVCentroidV := sumV / count;
end;

procedure TUVEdit.ScaleUVs(ScaleFactor: Double);
var
  s: Integer;
  txv: TTXVertex;
begin
  CalcCentroid;

  for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                     .Vertices.Count - 1 do
  begin
    txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                .TXVertices.GetItem(s);

    // Scale relative to centroid
    txv.u := UVCentroidU + (txv.u - UVCentroidU) * ScaleFactor;
    txv.v := UVCentroidV + (txv.v - UVCentroidV) * ScaleFactor;

    level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
         .TXVertices.Items[s] := txv;

    // Update grid
    UV_StringGrid.Cells[1, s+1] := FloatToStr(txv.u);
    UV_StringGrid.Cells[2, s+1] := FloatToStr(txv.v);
  end;
  DrawScene;
end;

procedure TUVEdit.RotateUVs(AngleDeg: Double);
var
  s: Integer;
  txv: TTXVertex;
  AngleRad, cosA, sinA: Double;
  relU, relV: Double;
begin
  CalcCentroid;
  AngleRad := AngleDeg * Pi / 180.0;
  cosA := Cos(AngleRad);
  sinA := Sin(AngleRad);

  for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                     .Vertices.Count - 1 do
  begin
    txv := level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
                .TXVertices.GetItem(s);

    // Translate to centroid
    relU := txv.u - UVCentroidU;
    relV := txv.v - UVCentroidV;

    // Rotate
    txv.u := UVCentroidU + (relU * cosA - relV * sinA);
    txv.v := UVCentroidV + (relU * sinA + relV * cosA);

    level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]
         .TXVertices.Items[s] := txv;

    // Update grid
    UV_StringGrid.Cells[1, s+1] := FloatToStr(txv.u);
    UV_StringGrid.Cells[2, s+1] := FloatToStr(txv.v);
  end;
  DrawScene;
end;

function TUVEdit.PointInFace(U, V: Double; F: Integer): Boolean;
var
  s, j: Integer;
  txv1, txv2: TTXVertex;
  u1, v1, u2, v2: Double;
  dx, dy, t, distToSeg: Double;
  EdgeThreshold: Double;
  crossings: Integer;
begin
  Result := False;
  EdgeThreshold := ZoomFactor * 0.04;
  crossings := 0;

  for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[F].Vertices.Count - 1 do
  begin
    j := (s + 1) mod level.Sectors[JedMain.Cur_SC].surfaces[F].Vertices.Count;
    txv1 := level.Sectors[JedMain.Cur_SC].surfaces[F].TXVertices.GetItem(s);
    txv2 := level.Sectors[JedMain.Cur_SC].surfaces[F].TXVertices.GetItem(j);

    u1 := txv1.u;  v1 := txv1.v;
    u2 := txv2.u;  v2 := txv2.v;

    // --- Edge proximity test ---
    dx := u2 - u1;
    dy := v2 - v1;
    if not ((dx = 0) and (dy = 0)) then
    begin
      t := ((U - u1) * dx + (V - v1) * dy) / (dx * dx + dy * dy);
      t := Max(0, Min(1, t));
      distToSeg := Sqrt(Sqr(U - (u1 + t * dx)) + Sqr(V - (v1 + t * dy)));
      if distToSeg < EdgeThreshold then
      begin
        Result := True;
        Exit;
      end;
    end;

    // --- Interior ray casting ---
    if ((v1 <= V) and (v2 > V)) or
       ((v2 <= V) and (v1 > V)) then
      if U < (u1 + (V - v1) / (v2 - v1) * (u2 - u1)) then
        Inc(crossings);
  end;

  if (crossings mod 2) = 1 then
    Result := True;
end;

function TUVEdit.SnapToNearestEdge(U, V: Double;
  IgnoreFace: Integer): TPointF;
var
  f, s: Integer;
  txv: TTXVertex;
  bestU, bestV: Double;
  bestDist, dist: Double;
  currentMat: String;
  pu, pv: Double;
begin
  Result.X := U;
  Result.Y := V;

  if not SnapEnabled then Exit;

  currentMat := level.Sectors[JedMain.Cur_SC]
                     .surfaces[JedMain.Cur_SF].Material;
  bestDist := SnapThreshold;
  bestU := U;
  bestV := V;

  for f := 0 to level.Sectors[JedMain.Cur_SC].surfaces.Count - 1 do
  begin
    // Skip current face and faces with different material
    if f = IgnoreFace then Continue;
    if level.Sectors[JedMain.Cur_SC].surfaces[f].Material <> currentMat then
      Continue;

    for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[f]
                        .Vertices.Count - 1 do
    begin
      txv := level.Sectors[JedMain.Cur_SC].surfaces[f]
                  .TXVertices.GetItem(s);
      pu :=  txv.u;
      pv := txv.v;

      // Check distance to this vert
      dist := Sqrt(Sqr(U - pu) + Sqr(V - pv));
      memo1.Lines.Add('Candidate f=' + IntToStr(f) +
  ' s=' + IntToStr(s) +
  ' pu=' + FormatFloat('0.00', pu) +
  ' pv=' + FormatFloat('0.00', pv) +
  ' dist=' + FormatFloat('0.000', dist) +
  ' bestDist=' + FormatFloat('0.000', bestDist));


      if dist < bestDist then
      begin
        bestDist := dist;
        bestU := pu;
        bestV := pv;
      end;
    end;
  end;

  Result.X := bestU;
  Result.Y := bestV;
end;



function TUVEdit.FindBestEdgeSnapDelta(
  FaceIdx: Integer;
  CurrentDeltaU, CurrentDeltaV: Double): TEdgePair;
var
  f, s, j, s2, j2: Integer;
  txvA1, txvA2, txvB1, txvB2: TTXVertex;
  au1, av1, au2, av2: Double;   // dragged face edge (in UV space after delta)
  bu1, bv1, bu2, bv2: Double;   // candidate edge
  dist_fwd, dist_rev: Double;
  dU, dV, score: Double;
  currentMat: String;
  best: TEdgePair;
begin
  best.DeltaU := CurrentDeltaU;
  best.DeltaV := CurrentDeltaV;
  best.Score  := SnapThreshold * 2;  // must beat this to snap

  currentMat := level.Sectors[JedMain.Cur_SC].surfaces[FaceIdx].Material;

  // Loop over every edge of the face being dragged
  for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[FaceIdx]
                      .Vertices.Count - 1 do
  begin
    j := (s + 1) mod level.Sectors[JedMain.Cur_SC].surfaces[FaceIdx].Vertices.Count;

    txvA1 := level.Sectors[JedMain.Cur_SC].surfaces[FaceIdx].TXVertices.GetItem(s);
    txvA2 := level.Sectors[JedMain.Cur_SC].surfaces[FaceIdx].TXVertices.GetItem(j);

    // Apply current drag delta to get where these verts would land
    au1 :=  (txvA1.u + CurrentDeltaU);
    av1 := (txvA1.v + CurrentDeltaV);
    au2 :=  (txvA2.u + CurrentDeltaU);
    av2 := (txvA2.v + CurrentDeltaV);

    // Test against every edge on every other face with same material
    for f := 0 to level.Sectors[JedMain.Cur_SC].surfaces.Count - 1 do
    begin
      if f = FaceIdx then Continue;
      if level.Sectors[JedMain.Cur_SC].surfaces[f].Material <> currentMat then
        Continue;

      for s2 := 0 to level.Sectors[JedMain.Cur_SC].surfaces[f]
                           .Vertices.Count - 1 do
      begin
        j2 := (s2 + 1) mod level.Sectors[JedMain.Cur_SC].surfaces[f].Vertices.Count;

        txvB1 := level.Sectors[JedMain.Cur_SC].surfaces[f].TXVertices.GetItem(s2);
        txvB2 := level.Sectors[JedMain.Cur_SC].surfaces[f].TXVertices.GetItem(j2);

        bu1 :=  txvB1.u;
        bv1 := txvB1.v;
        bu2 :=  txvB2.u;
        bv2 := txvB2.v;

        // --- Forward match: A1?B1, A2?B2 ---
        dist_fwd := Sqrt(Sqr(au1-bu1) + Sqr(av1-bv1)) +
                    Sqrt(Sqr(au2-bu2) + Sqr(av2-bv2));
        score := dist_fwd / 2;
        if score < best.Score then
        begin
          best.Score  := score;
          // Delta needed to move A endpoints onto B endpoints (average both)
          dU := ((bu1 - au1) + (bu2 - au2)) / 2 ;
          dV := ((bv1 - av1) + (bv2 - av2)) / 2 ;
          best.DeltaU := CurrentDeltaU + dU;
          best.DeltaV := CurrentDeltaV + dV;
        end;

        // --- Reverse match: A1?B2, A2?B1 ---
        dist_rev := Sqrt(Sqr(au1-bu2) + Sqr(av1-bv2)) +
                    Sqrt(Sqr(au2-bu1) + Sqr(av2-bv1));
        score := dist_rev / 2;
        if score < best.Score then
        begin
          best.Score  := score;
          dU := ((bu2 - au1) + (bu1 - au2)) / 2 ;
          dV := ((bv2 - av1) + (bv1 - av2)) / 2;
          best.DeltaU := CurrentDeltaU + dU;
          best.DeltaV := CurrentDeltaV + dV;
        end;

      end;
    end;
  end;

  Result := best;
end;

procedure TUVEdit.ScaleAllUVs(ScaleFactor: Double);
var
  f, s: Integer;
  txv: TTXVertex;
  sumU, sumV: Double;
  count: Integer;
  centU, centV: Double;
  currentMat: String;
begin
  currentMat := level.Sectors[JedMain.Cur_SC]
                     .surfaces[JedMain.Cur_SF].Material;

  // --- Calc centroid across ALL visible faces ---
  sumU := 0; sumV := 0; count := 0;
  for f := 0 to level.Sectors[JedMain.Cur_SC].surfaces.Count - 1 do
  begin
    if level.Sectors[JedMain.Cur_SC].surfaces[f].Material <> currentMat then
      Continue;
    for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[f].Vertices.Count - 1 do
    begin
      txv := level.Sectors[JedMain.Cur_SC].surfaces[f].TXVertices.GetItem(s);
      sumU := sumU + txv.u;
      sumV := sumV + txv.v;
      Inc(count);
    end;
  end;

  if count = 0 then Exit;
  centU := sumU / count;
  centV := sumV / count;

  // --- Scale all visible faces around shared centroid ---
  for f := 0 to level.Sectors[JedMain.Cur_SC].surfaces.Count - 1 do
  begin
    if level.Sectors[JedMain.Cur_SC].surfaces[f].Material <> currentMat then
      Continue;
    for s := 0 to level.Sectors[JedMain.Cur_SC].surfaces[f].Vertices.Count - 1 do
    begin
      txv := level.Sectors[JedMain.Cur_SC].surfaces[f].TXVertices.GetItem(s);
      txv.u := centU + (txv.u - centU) * ScaleFactor;
      txv.v := centV + (txv.v - centV) * ScaleFactor;
      level.Sectors[JedMain.Cur_SC].surfaces[f].TXVertices.Items[s] := txv;
    end;
  end;

  DrawScene;
end;

end.
