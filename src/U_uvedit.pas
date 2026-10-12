unit U_uvedit;
{
Notes:
JED creates negative TX coords, but the LEC levels all have positive values
 vertex order is counter clockwise

UV space: display X = u/FTexWidth, display Y = v/FTexWidth (no negation).
Texture rows are uploaded in stored MAT order and sampled at t = v/height,
exactly like JED's 3D view. The view shows V increasing UPWARD, which is how
V runs on JK walls, so the editor looks like the surface in the 3D preview.
glOrtho uses square HalfW=HalfH=ZoomFactor — ScreenToUV must match exactly.
}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus, Vcl.Imaging.pngimage, J_Level, StdCtrls, Jed_Main, FileOperations, graph_files, lev_utils,
  ExtCtrls, files, ComCtrls, Geometry, math, globalvars, Grids, dglOpenGL,
  System.Types;

const
  UVRotStep   = 5.0;   { degrees per rotate key press }
  UVScaleStep = 1.1;   { factor per scale key press }

type
  { Plain-value copy of a vertex's UV. TTXVertex is an object: GetItem returns
    the live instance, so storing it would NOT snapshot anything. }
  TUVPair = record
    u, v: Double;
  end;

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
    Procedure SetPointSize(size: Double);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SetUVButtonClick(Sender: TObject);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure Timer1Timer(Sender: TObject);
    procedure Panel2Resize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormHide(Sender: TObject);
    function  ScreenToUV(ScreenX, ScreenY: Integer): TPointf;
    procedure Panel2MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Panel2MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure Panel2MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  protected
    procedure MouseWheelHandler(var Message: TMessage); override;
  private
    FSC, FSF: Integer;         // sector/surface this editor is showing
    halfpsize, psizeodd: Integer;
    YOffset, XOffset, TexAspect: Double;
    ZoomFactor: Double;
    Dc: TCanvas;
    bm, bmp: TBitmap;
    FTexWidth, FTexHeight: Integer;
    FGroup: array of Integer;  // surfaces edited together: [0] = shown surface, rest = linked neighbours
    WGrp: array of Integer;   // entry k belongs to FGroup[WGrp[k]]
    WSurf, WVert: array of Integer;   // flat list of every vertex of the group: entry k = (surface, vertex)
    FSel: array of Boolean;    // FSel[k] = group entry k is selected
    BoxMode: Boolean;          // rubber-band selection in progress
    BoxAdd: Boolean;           // Shift held: add box contents to the selection
    BoxX0, BoxY0, BoxX1, BoxY1: Integer;   // rubber-band corners, panel pixels
    Dragging: Boolean;
    DragStartU, DragStartV: Double;
    ShowAllFaces: Boolean;     // show other surfaces with same material
    SnapEnabled: Boolean;
    SnapThreshold: Double;
    SavedUVs: array of TUVPair;    // undo / drag-start snapshot (value copies)
    FAlign: Boolean;               // T: align view to surface (vs plain texture space)
    FRa, FRb, FRc, FRd: Double;    // view rotation/mirror: screen = R * (uv - centre)
    FAlignInfo: String;
    FTexPix: TArray<TRGBTriple>;   // texture pixels, GL row order (row 0 = bottom of the picture in the editor)
    FRot: Integer;                 // R: extra view rotation in 90 degree steps
    FFlip: Boolean;              // M: manual left/right flip (for odd meshes)
    FLastNotify: Cardinal;         // tick of the last 3D-preview refresh
    function  SnapToNearestEdge(U, V: Double; IgnoreFace: Integer): TPointF;
    procedure SaveUVsForUndo;
    procedure RestoreUVsFromUndo;
    function  IsSel(i: Integer): Boolean;
    function  SelCount: Integer;
    procedure SelectAll(Value: Boolean);
    procedure ShowSelInfo;
    procedure ExportOutline(WithTexture: Boolean);
    procedure ExportLayout;
    procedure WriteMat16(const fn: String; bmp: TBitmap);
    function  InGroup(f: Integer): Boolean;
    procedure RebuildWS;
    function  FaceAtUV(u, v: Double): Integer;
    function  FaceSelState(gi: Integer; var AllSel: Boolean): Boolean;
    procedure ResetGroup;
    function  WSValid: Boolean;
    function  SharedVerts(a, b: Integer): Integer;
    procedure GrowGroup(All: Boolean);
    function  WGet(k: Integer): TTXVertex;
    procedure WSetUV(k: Integer; u, v: Double);
    procedure MenuClick(Sender: TObject);
    procedure BuildMenu;
    procedure TransformSelection(s11, s12, s21, s22: Double);
    function  FaceHanded(f: Integer): Integer;
    function  MirroredCount: Integer;
    procedure MirrorTool(FixThem: Boolean);
    procedure PackLayout(Separate: Boolean);
    procedure RotateSel(Deg: Double);
    procedure ScaleSel(Factor: Double);
    procedure NotifyJED;
    procedure SyncGrid;
    function  ValidSel(sc, sf: Integer): Boolean;
    procedure ZoomAt(ScreenX, ScreenY: Integer; Factor: Double);
    procedure LoadSurface;
    procedure ComputeViewAlign;
  public
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

implementation

{$R *.dfm}

{ Facing direction of the level's player start (first 'walkplayer' thing),
  as a horizontal unit vector. JK/JED convention: yaw 0 faces +Y and the
  forward vector is (-sin yaw, cos yaw, 0) - this is what JED's own
  SetViewToThing uses. False if the level has no walkplayer. }
function GetWalkplayerForward(var fx, fy: Double): Boolean;
var
  i: Integer;
  yaw: Double;
begin
  Result := False;
  if level = nil then Exit;
  for i := 0 to level.Things.Count - 1 do
    if CompareText(level.Things[i].name, 'walkplayer') = 0 then
    begin
      { Snap to the nearest 90 deg so axis-aligned rooms show axis-aligned
        in the editor even if the player start is angled a few degrees. }
      yaw := DegToRad(Round(level.Things[i].yaw / 90.0) * 90.0);
      fx := -Sin(yaw);
      fy :=  Cos(yaw);
      if Abs(fx) < 1e-9 then fx := 0;
      if Abs(fy) < 1e-9 then fy := 0;
      Result := True;
      Exit;
    end;
end;

{ ── helpers ─────────────────────────────────────────────────────────────────── }

procedure TUVEdit.SaveUVsForUndo;
var
  k: Integer;
  txv: TTXVertex;
begin
  SetLength(SavedUVs, Length(WSurf));
  for k := 0 to High(SavedUVs) do
  begin
    txv := WGet(k);
    SavedUVs[k].u := txv.u;
    SavedUVs[k].v := txv.v;
  end;
end;

{ ── linked faces (group) ────────────────────────────────────────────────────── }

function TUVEdit.InGroup(f: Integer): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FGroup) do
    if FGroup[i] = f then begin Result := True; Exit; end;
end;

function TUVEdit.WGet(k: Integer): TTXVertex;
begin
  Result := level.Sectors[FSC].surfaces[WSurf[k]].TXVertices.GetItem(WVert[k]);
end;

procedure TUVEdit.WSetUV(k: Integer; u, v: Double);
var
  txv: TTXVertex;
begin
  txv := WGet(k);
  txv.u := u;
  txv.v := v;
  level.Sectors[FSC].surfaces[WSurf[k]].TXVertices.Items[WVert[k]] := txv;
end;

{ Flatten the group into one list of (surface, vertex) entries and clear the
  vertex selection. }
procedure TUVEdit.RebuildWS;
var
  gi, vi, k, cnt: Integer;
begin
  cnt := 0;
  for gi := 0 to High(FGroup) do
    cnt := cnt + level.Sectors[FSC].surfaces[FGroup[gi]].Vertices.Count;
  SetLength(WSurf, cnt);
  SetLength(WVert, cnt);
  SetLength(WGrp, cnt);
  SetLength(FSel, cnt);
  k := 0;
  for gi := 0 to High(FGroup) do
    for vi := 0 to level.Sectors[FSC].surfaces[FGroup[gi]].Vertices.Count - 1 do
    begin
      WSurf[k] := FGroup[gi];
      WVert[k] := vi;
      WGrp[k]  := gi;
      FSel[k]  := False;
      Inc(k);
    end;
  SaveUVsForUndo;
end;

{ Back to just the shown surface. }
procedure TUVEdit.ResetGroup;
begin
  if not ValidSel(FSC, FSF) then
  begin
    SetLength(FGroup, 0); SetLength(WSurf, 0); SetLength(WVert, 0); SetLength(FSel, 0);
    Exit;
  end;
  SetLength(FGroup, 1);
  FGroup[0] := FSF;
  RebuildWS;
end;

{ True while the group lists still match the level (surfaces may have been
  deleted or re-triangulated behind our back). }
function TUVEdit.WSValid: Boolean;
var
  gi, cnt: Integer;
begin
  Result := False;
  if not ValidSel(FSC, FSF) then Exit;
  if (Length(FGroup) = 0) or (FGroup[0] <> FSF) then Exit;
  cnt := 0;
  for gi := 0 to High(FGroup) do
  begin
    if (FGroup[gi] < 0) or (FGroup[gi] >= level.Sectors[FSC].surfaces.Count) then Exit;
    cnt := cnt + level.Sectors[FSC].surfaces[FGroup[gi]].Vertices.Count;
  end;
  Result := (cnt = Length(WSurf)) and (cnt = Length(WVert));
end;

{ Index in FGroup of the face whose UV polygon contains (u,v), or -1.
  Later (linked) faces win over the shown one where they overlap. }
function TUVEdit.FaceAtUV(u, v: Double): Integer;
var
  gi, s, j, n: Integer;
  inside: Boolean;
  xi, yi, xj, yj: Double;
  a, b: TTXVertex;
begin
  Result := -1;
  if (FTexWidth <= 0) or not WSValid then Exit;
  for gi := High(FGroup) downto 0 do
  begin
    n := level.Sectors[FSC].surfaces[FGroup[gi]].Vertices.Count;
    inside := False;
    j := n - 1;
    for s := 0 to n - 1 do
    begin
      a := level.Sectors[FSC].surfaces[FGroup[gi]].TXVertices.GetItem(s);
      b := level.Sectors[FSC].surfaces[FGroup[gi]].TXVertices.GetItem(j);
      xi := a.u / FTexWidth; yi := a.v / FTexWidth;
      xj := b.u / FTexWidth; yj := b.v / FTexWidth;
      if ((yi > v) <> (yj > v)) and
         (u < (xj - xi) * (v - yi) / (yj - yi) + xi) then
        inside := not inside;
      j := s;
    end;
    if inside then begin Result := gi; Exit; end;
  end;
end;

{ Result = any vertex of face gi is selected; AllSel = every vertex is. }
function TUVEdit.FaceSelState(gi: Integer; var AllSel: Boolean): Boolean;
var
  k, cnt, sel: Integer;
begin
  cnt := 0; sel := 0;
  for k := 0 to High(WGrp) do
    if WGrp[k] = gi then
    begin
      Inc(cnt);
      if IsSel(k) then Inc(sel);
    end;
  Result := sel > 0;
  AllSel := (cnt > 0) and (sel = cnt);
end;

{ Number of corners surface a shares with surface b (same 3D vertex). Two or
  more = they share an edge. }
function TUVEdit.SharedVerts(a, b: Integer): Integer;
var
  i, j: Integer;
  pa, pb: TJKVertex;
begin
  Result := 0;
  for i := 0 to level.Sectors[FSC].surfaces[a].Vertices.Count - 1 do
  begin
    pa := level.Sectors[FSC].surfaces[a].GetVXs.GetItem(i);
    for j := 0 to level.Sectors[FSC].surfaces[b].Vertices.Count - 1 do
    begin
      pb := level.Sectors[FSC].surfaces[b].GetVXs.GetItem(j);
      if (pa = pb) or
         ((Abs(pa.x - pb.x) < 1e-5) and (Abs(pa.y - pb.y) < 1e-5) and
          (Abs(pa.z - pb.z) < 1e-5)) then
      begin
        Inc(Result);
        Break;
      end;
    end;
  end;
end;

{ Add the faces of this sector that touch the group along an edge and use the
  same material. One ring per call, or everything connected if All. }
procedure TUVEdit.GrowGroup(All: Boolean);
var
  f, gi, n0: Integer;
  added: Boolean;
  mat: String;
begin
  if not WSValid then ResetGroup;
  if not ValidSel(FSC, FSF) then Exit;
  mat := level.Sectors[FSC].surfaces[FSF].Material;
  repeat
    added := False;
    n0 := Length(FGroup);
    for f := 0 to level.Sectors[FSC].surfaces.Count - 1 do
      if (not InGroup(f)) and
         (CompareText(level.Sectors[FSC].surfaces[f].Material, mat) = 0) and
         (level.Sectors[FSC].surfaces[f].Vertices.Count >= 3) then
        for gi := 0 to n0 - 1 do
          if SharedVerts(f, FGroup[gi]) >= 2 then
          begin
            SetLength(FGroup, Length(FGroup) + 1);
            FGroup[High(FGroup)] := f;
            added := True;
            Break;
          end;
  until (not All) or (not added);
  RebuildWS;
  ShowSelInfo;
end;

{ ── multi-select helpers ─────────────────────────────────────────────────────── }

function TUVEdit.IsSel(i: Integer): Boolean;
begin
  Result := (i >= 0) and (i < Length(FSel)) and FSel[i];
end;

function TUVEdit.SelCount: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(FSel) do
    if FSel[i] then Inc(Result);
end;

procedure TUVEdit.SelectAll(Value: Boolean);
var
  i: Integer;
begin
  SetLength(FSel, Length(WSurf));
  for i := 0 to High(FSel) do FSel[i] := Value;
end;

procedure TUVEdit.ShowSelInfo;
begin
  StatusBar1.Panels[1].Text := 'Snap: ' + BoolToStr(SnapEnabled, True) +
                               '   Faces: ' + IntToStr(Length(FGroup)) +
                               '   Selected: ' + IntToStr(SelCount) +
                               '   Mirrored vs this face: ' + IntToStr(MirroredCount);
end;

{ +1 / -1 = how this face's UVs are wound compared with its 3D vertex order
  (does the texture read normally or mirrored on the model); 0 = degenerate. }
function TUVEdit.FaceHanded(f: Integer): Integer;
var
  sf: TJKSurface;
  i, j, n: Integer;
  a, b: TTXVertex;
  nx, ny, nz, area, d: Double;
  p, q: TJKVertex;
begin
  Result := 0;
  sf := level.Sectors[FSC].surfaces[f];
  n := sf.Vertices.Count;
  if n < 3 then Exit;
  nx := 0; ny := 0; nz := 0; area := 0;
  for i := 0 to n - 1 do
  begin
    j := (i + 1) mod n;
    p := sf.GetVXs.GetItem(i);
    q := sf.GetVXs.GetItem(j);
    nx := nx + (p.y - q.y) * (p.z + q.z);      { Newell normal of the 3D polygon }
    ny := ny + (p.z - q.z) * (p.x + q.x);
    nz := nz + (p.x - q.x) * (p.y + q.y);
    a := sf.TXVertices.GetItem(i);
    b := sf.TXVertices.GetItem(j);
    area := area + (a.u * b.v - b.u * a.v);    { signed area in UV space }
  end;
  d := nx * sf.normal.dx + ny * sf.normal.dy + nz * sf.normal.dz;
  if (Abs(area) < 1e-9) or (Abs(d) < 1e-12) then Exit;
  if (area > 0) = (d > 0) then Result := 1 else Result := -1;
end;

{ number of linked faces whose texture is mirrored compared with the current face }
function TUVEdit.MirroredCount: Integer;
var
  gi, ref, h: Integer;
begin
  Result := 0;
  if (Length(FGroup) < 2) or not ValidSel(FSC, FSF) then Exit;
  ref := FaceHanded(FSF);
  if ref = 0 then Exit;
  for gi := 0 to High(FGroup) do
  begin
    h := FaceHanded(FGroup[gi]);
    if (h <> 0) and (h <> ref) then Inc(Result);
  end;
end;

{ X = select every linked face that is mirrored compared with the current face;
  Shift+X = also flip those faces left/right in U about their own centre so
  they read the same way as the current face (Esc undoes). }
procedure TUVEdit.MirrorTool(FixThem: Boolean);
var
  gi, k, ref, h, cnt: Integer;
  mir: array of Boolean;
  mn, mx: Double;
  txv: TTXVertex;
begin
  if (FTexWidth <= 0) or not WSValid then Exit;
  ref := FaceHanded(FSF);
  if ref = 0 then
  begin
    StatusBar1.Panels[0].Text := 'Mirror check: the current face has no usable UV area';
    Exit;
  end;
  SetLength(mir, Length(FGroup));
  cnt := 0;
  for gi := 0 to High(FGroup) do
  begin
    h := FaceHanded(FGroup[gi]);
    mir[gi] := (h <> 0) and (h <> ref);
    if mir[gi] then Inc(cnt);
  end;
  if Length(FSel) <> Length(WSurf) then SelectAll(False);

  if FixThem and (cnt > 0) then
  begin
    SaveUVsForUndo;
    for gi := 0 to High(FGroup) do
      if mir[gi] then
      begin
        mn := 1e30; mx := -1e30;
        for k := 0 to High(WGrp) do
          if WGrp[k] = gi then
          begin
            txv := WGet(k);
            if txv.u < mn then mn := txv.u;
            if txv.u > mx then mx := txv.u;
          end;
        for k := 0 to High(WGrp) do
          if WGrp[k] = gi then
          begin
            txv := WGet(k);
            WSetUV(k, mn + mx - txv.u, txv.v);
          end;
      end;
    SyncGrid;
    NotifyJED;
    StatusBar1.Panels[0].Text := Format('Flipped %d mirrored face(s) to match the current face', [cnt]);
  end
  else
  begin
    SelectAll(False);
    for k := 0 to High(WGrp) do
      FSel[k] := mir[WGrp[k]];
    StatusBar1.Panels[0].Text := Format('%d of %d linked faces are mirrored compared with the current face ' +
      '(selected; Shift+X flips them)', [cnt, Length(FGroup)]);
  end;
  ShowSelInfo;
  DrawScene;
end;

{ Lay the linked faces out on the texture with no overlap. Faces whose UV edges
  already touch (seams you snapped together) stay together as one piece; every
  piece keeps its shape and scale and is only moved. Pieces are packed in rows
  into the smallest power-of-two texture with a 1 texel gap, starting at 0,0.
  Esc undoes it. }
procedure TUVEdit.PackLayout(Separate: Boolean);
const
  Gap = 1;
var
  ng, nc, a, b, i, j, k, c, ia, ib, na, nb, hits, tmp: Integer;
  trialW, bestW, bestArea, area, x, y, rowH, usedW, hNeed, maxPieceW: Integer;
  par, cl, order: array of Integer;
  rootOf: array of Integer;
  minU, minV, maxU, maxV: array of Double;
  pw, ph: array of Integer;
  px, py, bx, by: array of Integer;
  txv, ta, tb: TTXVertex;
  fits: Boolean;

  function Find(v: Integer): Integer;
  begin
    while par[v] <> v do
    begin
      par[v] := par[par[v]];
      v := par[v];
    end;
    Result := v;
  end;

  function Pow2(v: Integer): Integer;
  begin
    Result := 1;
    while Result < v do Result := Result * 2;
  end;

begin
  if (FTexWidth <= 0) or not WSValid then Exit;
  ng := Length(FGroup);
  if ng < 2 then
  begin
    StatusBar1.Panels[0].Text := 'Pack: link the faces first (Ctrl+G)';
    Exit;
  end;

  { faces that already share a UV edge (two corners in the same place) = one piece }
  SetLength(par, ng);
  for i := 0 to ng - 1 do par[i] := i;
  for a := 0 to ng - 2 do
    for b := a + 1 to ng - 1 do
    begin
      na := level.Sectors[FSC].surfaces[FGroup[a]].Vertices.Count;
      nb := level.Sectors[FSC].surfaces[FGroup[b]].Vertices.Count;
      hits := 0;
      for ia := 0 to na - 1 do
      begin
        ta := level.Sectors[FSC].surfaces[FGroup[a]].TXVertices.GetItem(ia);
        for ib := 0 to nb - 1 do
        begin
          tb := level.Sectors[FSC].surfaces[FGroup[b]].TXVertices.GetItem(ib);
          if (Abs(ta.u - tb.u) < 0.01) and (Abs(ta.v - tb.v) < 0.01) then
          begin
            Inc(hits);
            Break;
          end;
        end;
      end;
      if (hits >= 2) and not Separate then par[Find(a)] := Find(b);
    end;

  { piece number for every face }
  SetLength(cl, ng);
  SetLength(rootOf, ng);
  nc := 0;
  for i := 0 to ng - 1 do
  begin
    c := -1;
    for j := 0 to nc - 1 do
      if rootOf[j] = Find(i) then begin c := j; Break; end;
    if c < 0 then
    begin
      c := nc;
      rootOf[nc] := Find(i);
      Inc(nc);
    end;
    cl[i] := c;
  end;

  SetLength(minU, nc); SetLength(minV, nc); SetLength(maxU, nc); SetLength(maxV, nc);
  for c := 0 to nc - 1 do
  begin
    minU[c] := 1e30; minV[c] := 1e30; maxU[c] := -1e30; maxV[c] := -1e30;
  end;
  for k := 0 to High(WGrp) do
  begin
    c := cl[WGrp[k]];
    txv := WGet(k);
    if txv.u < minU[c] then minU[c] := txv.u;
    if txv.v < minV[c] then minV[c] := txv.v;
    if txv.u > maxU[c] then maxU[c] := txv.u;
    if txv.v > maxV[c] then maxV[c] := txv.v;
  end;

  SetLength(pw, nc); SetLength(ph, nc);
  maxPieceW := 1;
  for c := 0 to nc - 1 do
  begin
    pw[c] := Ceil(maxU[c] - minU[c] - 1e-6) + Gap;
    ph[c] := Ceil(maxV[c] - minV[c] - 1e-6) + Gap;
    if pw[c] < 1 + Gap then pw[c] := 1 + Gap;
    if ph[c] < 1 + Gap then ph[c] := 1 + Gap;
    if pw[c] > maxPieceW then maxPieceW := pw[c];
  end;

  { tallest first }
  SetLength(order, nc);
  for c := 0 to nc - 1 do order[c] := c;
  for i := 0 to nc - 2 do
    for j := i + 1 to nc - 1 do
      if ph[order[j]] > ph[order[i]] then
      begin
        tmp := order[i]; order[i] := order[j]; order[j] := tmp;
      end;

  { try every power-of-two width, keep the one that wastes the least texture }
  SetLength(px, nc); SetLength(py, nc); SetLength(bx, nc); SetLength(by, nc);
  bestW := 0; bestArea := MaxInt;
  trialW := Pow2(maxPieceW);
  while trialW <= 4096 do
  begin
    x := 0; y := 0; rowH := 0; fits := True;
    for i := 0 to nc - 1 do
    begin
      c := order[i];
      if x + pw[c] > trialW then
      begin
        x := 0;
        y := y + rowH;
        rowH := 0;
      end;
      px[c] := x; py[c] := y;
      x := x + pw[c];
      if ph[c] > rowH then rowH := ph[c];
    end;
    hNeed := Pow2(y + rowH);
    area := trialW * hNeed;
    if (hNeed <= 4096) and (area < bestArea) then
    begin
      bestArea := area;
      bestW := trialW;
      for c := 0 to nc - 1 do begin bx[c] := px[c]; by[c] := py[c]; end;
    end;
    trialW := trialW * 2;
  end;
  if bestW = 0 then
  begin
    ShowMessage('The pieces do not fit in a 4096 x 4096 texture.');
    Exit;
  end;

  SaveUVsForUndo;
  for k := 0 to High(WGrp) do
  begin
    c := cl[WGrp[k]];
    txv := WGet(k);
    WSetUV(k, txv.u - minU[c] + bx[c], txv.v - minV[c] + by[c]);
  end;
  XOffset := 0; YOffset := 0;
  SyncGrid;
  NotifyJED;
  StatusBar1.Panels[0].Text := Format('Packed %d face(s) as %d piece(s) with no overlap; needs a %d x %d texture. ' +
    'Ctrl+E exports it (Esc undoes)', [ng, nc, bestW, Pow2(bestArea div bestW)]);
  ShowSelInfo;
  DrawScene;
end;

{ Apply a 2x2 transform S, given in SCREEN (view) space, to the selected
  vertices about the centre of their bounding box (all vertices if none are
  selected). M = R^T * S * R converts it to UV space, so rotations and flips
  look right on screen even when the view is rotated or mirrored. }
procedure TUVEdit.TransformSelection(s11, s12, s21, s22: Double);
var
  k, n: Integer;
  txv: TTXVertex;
  MinU, MaxU, MinV, MaxV, px, py, du, dv: Double;
  t11, t12, t21, t22, m11, m12, m21, m22: Double;
  useAll: Boolean;
begin
  if (FTexWidth <= 0) or not WSValid then Exit;
  n := Length(WSurf);
  if Length(FSel) <> n then SelectAll(False);
  useAll := SelCount = 0;      // nothing selected = the whole group

  MinU := 1e30; MaxU := -1e30; MinV := 1e30; MaxV := -1e30;
  for k := 0 to n - 1 do
    if useAll or FSel[k] then
    begin
      txv := WGet(k);
      if txv.u / FTexWidth < MinU then MinU := txv.u / FTexWidth;
      if txv.u / FTexWidth > MaxU then MaxU := txv.u / FTexWidth;
      if txv.v / FTexWidth < MinV then MinV := txv.v / FTexWidth;
      if txv.v / FTexWidth > MaxV then MaxV := txv.v / FTexWidth;
    end;
  px := (MinU + MaxU) / 2;
  py := (MinV + MaxV) / 2;

  { T = S * R }
  t11 := s11*FRa + s12*FRc;  t12 := s11*FRb + s12*FRd;
  t21 := s21*FRa + s22*FRc;  t22 := s21*FRb + s22*FRd;
  { M = R^T * T }
  m11 := FRa*t11 + FRc*t21;  m12 := FRa*t12 + FRc*t22;
  m21 := FRb*t11 + FRd*t21;  m22 := FRb*t12 + FRd*t22;

  SaveUVsForUndo;              // Esc undoes the last operation
  for k := 0 to n - 1 do
    if useAll or FSel[k] then
    begin
      txv := WGet(k);
      du  := txv.u / FTexWidth - px;
      dv  := txv.v / FTexWidth - py;
      WSetUV(k, (px + m11*du + m12*dv) * FTexWidth,
                (py + m21*du + m22*dv) * FTexWidth);
    end;
  SyncGrid;
  NotifyJED;
end;

{ Positive = counter-clockwise on screen }
procedure TUVEdit.RotateSel(Deg: Double);
var
  c, sn: Double;
begin
  c := Cos(DegToRad(Deg)); sn := Sin(DegToRad(Deg));
  TransformSelection(c, -sn, sn, c);
end;

procedure TUVEdit.ScaleSel(Factor: Double);
begin
  if Factor <= 0 then Exit;
  TransformSelection(Factor, 0, 0, Factor);
end;

{ ── menu ─────────────────────────────────────────────────────────────────────── }

{ Every menu item just replays its keyboard shortcut through FormKeyDown, so
  the menu and the keys can never disagree. Tag = key code + (modifiers shl 16),
  modifiers: 1 = Shift, 2 = Ctrl. }
procedure TUVEdit.MenuClick(Sender: TObject);
var
  t: Integer;
  k: Word;
  sh: TShiftState;
begin
  t := (Sender as TMenuItem).Tag;
  k := t and $FFFF;
  sh := [];
  if (t and $10000) <> 0 then Include(sh, ssShift);
  if (t and $20000) <> 0 then Include(sh, ssCtrl);
  if (t and $40000) <> 0 then Include(sh, ssAlt);
  FormKeyDown(Self, k, sh);
  Self.SetFocus;
end;

procedure TUVEdit.BuildMenu;
var
  mm: TMainMenu;

  function AddTop(const Cap: String): TMenuItem;
  begin
    Result := TMenuItem.Create(Self);
    Result.Caption := Cap;
    mm.Items.Add(Result);
  end;

  procedure Add(Parent: TMenuItem; const Cap: String; KeyCode: Word; Mods: Integer);
  var
    mi: TMenuItem;
  begin
    mi := TMenuItem.Create(Self);
    mi.Caption := Cap;
    if Cap <> '-' then
    begin
      mi.Tag := KeyCode or (Mods shl 16);
      mi.OnClick := MenuClick;
    end;
    Parent.Add(mi);
  end;

var
  m: TMenuItem;
begin
  if Menu <> nil then mm := TMainMenu(Menu)
  else
  begin
    mm := TMainMenu.Create(Self);
    Menu := mm;
  end;

  m := AddTop('&File');
  Add(m, 'Export layout as 16-bit MAT + outline PNG...'#9'Ctrl+E', Ord('E'), 2);
  Add(m, 'Export outline over current texture (PNG)...'#9'Ctrl+Shift+E', Ord('E'), 3);

  m := AddTop('&Edit');
  Add(m, 'Undo last action'#9'Esc', VK_ESCAPE, 0);
  Add(m, '-', 0, 0);
  Add(m, 'Select all'#9'Ctrl+A', Ord('A'), 2);
  Add(m, 'Select none'#9'Ctrl+Shift+A', Ord('A'), 3);
  Add(m, 'Invert selection'#9'Ctrl+I', Ord('I'), 2);

  m := AddTop('&Faces');
  Add(m, 'Add neighbouring faces (same texture)'#9'G', Ord('G'), 0);
  Add(m, 'Add all connected faces (same texture)'#9'Ctrl+G', Ord('G'), 2);
  Add(m, 'This face only'#9'Shift+G', Ord('G'), 1);
  Add(m, '-', 0, 0);
  Add(m, 'Select faces mirrored vs this face'#9'X', Ord('X'), 0);
  Add(m, 'Flip mirrored faces to match this face'#9'Shift+X', Ord('X'), 1);
  Add(m, 'Pack linked faces with no overlap (touching faces stay together)'#9'P', Ord('P'), 0);
  Add(m, 'Pack every face separately (no two faces overlap)'#9'Shift+P', Ord('P'), 1);

  m := AddTop('&Transform');
  Add(m, 'Rotate texture left'#9'Ctrl+,', 188, 2);
  Add(m, 'Rotate texture right'#9'Ctrl+.', 190, 2);
  Add(m, 'Rotate left 1 deg'#9'Ctrl+Shift+,', 188, 3);
  Add(m, 'Rotate right 1 deg'#9'Ctrl+Shift+.', 190, 3);
  Add(m, 'Rotate by angle...'#9'D', Ord('D'), 0);
  Add(m, '-', 0, 0);
  Add(m, 'Scale texture down'#9'Alt+,', 188, 4);
  Add(m, 'Scale texture up'#9'Alt+.', 190, 4);
  Add(m, 'Scale by factor...'#9'F', Ord('F'), 0);
  Add(m, '-', 0, 0);
  Add(m, 'Flip left/right'#9'H', Ord('H'), 0);
  Add(m, 'Flip up/down'#9'V', Ord('V'), 0);

  m := AddTop('&View');
  Add(m, 'Zoom in'#9'+', 187, 0);
  Add(m, 'Zoom out'#9'-', 189, 0);
  Add(m, '-', 0, 0);
  Add(m, 'Align view to surface / texture space'#9'T', Ord('T'), 0);
  Add(m, 'Mirror view (left/right)'#9'M', Ord('M'), 0);
  Add(m, 'Rotate view 90 deg'#9'R', Ord('R'), 0);
  Add(m, '-', 0, 0);
  Add(m, 'Snap on/off'#9'S', Ord('S'), 0);
  Add(m, 'Show other faces on/off'#9'O', Ord('O'), 0);

  m := AddTop('&Help');
  Add(m, 'Controls...'#9'F1', VK_F1, 0);
end;

{ True if (sc,sf) names a real surface in the loaded level. }
function TUVEdit.ValidSel(sc, sf: Integer): Boolean;
begin
  Result := (level <> nil) and
            (sc >= 0) and (sc < level.Sectors.Count) and
            (sf >= 0) and (sf < level.Sectors[sc].Surfaces.Count) and
            (level.Sectors[sc].Surfaces[sf].Vertices.Count > 0);
end;

{ Tell JED the surface's UVs changed so the 3D preview rebuilds this sector.
  JED's own texture tools do the same thing after editing a surface. }
{ Copy the surface's current UVs into the grid. }
procedure TUVEdit.SyncGrid;
var
  s: Integer;
  txv: TTXVertex;
begin
  if not ValidSel(FSC, FSF) then Exit;
  for s := 0 to level.Sectors[FSC].surfaces[FSF].Vertices.Count - 1 do
  begin
    txv := level.Sectors[FSC].surfaces[FSF].TXVertices.GetItem(s);
    UV_StringGrid.Cells[1, s + 1] := FloatToStr(txv.u);
    UV_StringGrid.Cells[2, s + 1] := FloatToStr(txv.v);
  end;
end;

procedure TUVEdit.NotifyJED;
begin
  if not ValidSel(FSC, FSF) then Exit;
  JedMain.SectorChanged(level.Sectors[FSC]);
end;

procedure TUVEdit.RestoreUVsFromUndo;
var
  k: Integer;
begin
  if not WSValid then Exit;
  if Length(SavedUVs) <> Length(WSurf) then Exit;
  for k := 0 to High(SavedUVs) do
    WSetUV(k, SavedUVs[k].u, SavedUVs[k].v);
  SyncGrid;
  NotifyJED;
end;

{ SnapToNearestEdge — returns snapped UV position if within SnapThreshold,
  otherwise returns (U,V) unchanged.  IgnoreFace skips the face being dragged. }
function TUVEdit.SnapToNearestEdge(U, V: Double; IgnoreFace: Integer): TPointF;
var
  f, s, k, gi: Integer;
  txv: TTXVertex;
  bestU, bestV, bestDist, dist, pu, pv: Double;
  currentMat: String;
  moving: array of Boolean;
  dummy: Boolean;
begin
  Result.X := U;
  Result.Y := V;
  if not SnapEnabled then Exit;

  bestDist := SnapThreshold;
  bestU    := U;
  bestV    := V;

  { 1. vertices of linked faces that are NOT being moved: always visible, so
       always snap targets (this is what lets you line faces up on a seam).
       A face that has selected vertices is skipped - it would snap to itself. }
  if Length(FGroup) > 1 then
  begin
    SetLength(moving, Length(FGroup));
    for gi := 0 to High(FGroup) do moving[gi] := FaceSelState(gi, dummy);
    for k := 0 to High(WSurf) do
      if (not moving[WGrp[k]]) then
      begin
        txv  := WGet(k);
        pu   := txv.u / FTexWidth;
        pv   := txv.v / FTexWidth;
        dist := Sqrt(Sqr(U - pu) + Sqr(V - pv));
        if dist <= bestDist then
        begin
          bestDist := dist;
          bestU    := pu;
          bestV    := pv;
        end;
      end;
  end;

  { 2. other faces with the same material, only while they are shown (O):
       invisible targets cause sudden jumps. }
  if ShowAllFaces then
  begin
    currentMat := level.Sectors[FSC].surfaces[FSF].Material;
    for f := 0 to level.Sectors[FSC].surfaces.Count - 1 do
    begin
      if InGroup(f) then Continue;
      if level.Sectors[FSC].surfaces[f].Material <> currentMat then Continue;

      for s := 0 to level.Sectors[FSC].surfaces[f].Vertices.Count - 1 do
      begin
        txv := level.Sectors[FSC].surfaces[f].TXVertices.GetItem(s);
        pu  := txv.u / FTexWidth;
        pv  := txv.v / FTexWidth;
        dist := Sqrt(Sqr(U - pu) + Sqr(V - pv));
        if dist <= bestDist then
        begin
          bestDist := dist;
          bestU    := pu;
          bestV    := pv;
        end;
      end;
    end;
  end;

  Result.X := bestU;
  Result.Y := bestV;
end;

{ ── form lifecycle ───────────────────────────────────────────────────────────── }

procedure TUVEdit.FormCreate(Sender: TObject);
begin
  KeyPreview := True;          // form receives key events before controls
  Panel2.TabStop := False;     // panel won't steal focus on click

  glDC := GetDC(Panel2.Handle);
  RC   := CreateRenderingContext(glDC, [opDoubleBuffered], 32, 24, 0, 0, 0, 0);

  SnapEnabled  := True;
  ShowAllFaces := False;
  FAlign := True;
  FRa := 1; FRb := 0; FRc := 0; FRd := 1;
  BuildMenu;
end;

procedure TUVEdit.FormDeactivate(Sender: TObject);
begin
  DeactivateRenderingContext;
end;

procedure TUVEdit.FormDestroy(Sender: TObject);
begin
  DeactivateRenderingContext;
  wglDeleteContext(RC);
  ReleaseDC(Handle, glDC);
end;

procedure TUVEdit.FormHide(Sender: TObject);
begin
  Timer1.Enabled := False;
end;

procedure TUVEdit.FormShow(Sender: TObject);
begin
  Label1.Caption := 'Show';
  Caption := 'UV Editor (build 33)';   // confirms this file is the one compiled
  ActivateRenderingContext(glDC, RC);
  wglMakeCurrent(glDC, RC);
  SetPointSize(3);
  FTexWidth := 0;
  if not ValidSel(JedMain.Cur_SC, JedMain.Cur_SF) then
  begin
    Memo1.Lines.Text := 'No surface selected in JED.';
    Timer1.Enabled := True;   // will load as soon as one is picked
    Exit;
  end;
  LoadSurface;
  Timer1.Enabled := True;
  Self.SetFocus;
end;

{ Load whatever surface JED currently has selected: grid, texture, view.
  Called on show and again whenever the selection in JED changes. }
procedure TUVEdit.LoadSurface;
var
  s, row: Integer;
  txv: TTXVertex;
  v: TJKVertex;
  MinU, MaxU, MinV, MaxV: Double;
begin
  if not ValidSel(JedMain.Cur_SC, JedMain.Cur_SF) then Exit;
  FSC := JedMain.Cur_SC;
  FSF := JedMain.Cur_SF;
  ResetGroup;

  Memo1.Clear;
  Memo1.Lines.Add(Format('Sector %d  Surface %d  Mat %s',
    [FSC, FSF, level.Sectors[FSC].surfaces[FSF].Material]));

  UV_StringGrid.RowCount := level.Sectors[FSC].surfaces[FSF].Vertices.Count + 1;
  UV_StringGrid.Cells[1, 0] := 'U';
  UV_StringGrid.Cells[2, 0] := 'V';
  for s := 0 to level.Sectors[FSC].surfaces[FSF].Vertices.Count - 1 do
  begin
    txv := level.Sectors[FSC].surfaces[FSF].TXVertices.GetItem(s);
    v   := level.Sectors[FSC].surfaces[FSF].GetVXs.GetItem(s);
    Memo1.Lines.Add('U:' + FloatToStr(txv.u) + ',V:' + FloatToStr(txv.v) +
                    ',vertex:' + FloatToStr(v.x) + ',' + FloatToStr(v.y));
    UV_StringGrid.Cells[0, s + 1] := IntToStr(s);
    UV_StringGrid.Cells[1, s + 1] := FloatToStr(txv.u);
    UV_StringGrid.Cells[2, s + 1] := FloatToStr(txv.v);
  end;

  LoadTexture;   // reload — the new surface may use a different material
  ComputeViewAlign;
  Memo1.Lines.Insert(1, FAlignInfo);   // line 1, so T/R can update it in place

  { Centre the view on the polygon }
  MinU :=  1e30; MaxU := -1e30;
  MinV :=  1e30; MaxV := -1e30;
  for s := 0 to level.Sectors[FSC].surfaces[FSF].Vertices.Count - 1 do
  begin
    txv := level.Sectors[FSC].surfaces[FSF].TXVertices.GetItem(s);
    if txv.u / FTexWidth < MinU then MinU := txv.u / FTexWidth;
    if txv.u / FTexWidth > MaxU then MaxU := txv.u / FTexWidth;
    if txv.v / FTexWidth < MinV then MinV := txv.v / FTexWidth;
    if txv.v / FTexWidth > MaxV then MaxV := txv.v / FTexWidth;
  end;
  XOffset    := (MinU + MaxU) / 2.0;
  YOffset    := (MinV + MaxV) / 2.0;
  ZoomFactor := Max(Abs(MaxU - MinU), Abs(MaxV - MinV)) * 0.6;
  if ZoomFactor = 0 then ZoomFactor := 1.0;

  SelectAll(False);
  BoxMode := False;
  Dragging := False;
  SaveUVsForUndo;
  ShowSelInfo;
  DrawScene;
end;

{ ── view alignment ────────────────────────────────────────────────────────────

  JK stores a free U,V per vertex, so a surface's texture can be rotated by
  any angle, mirrored, sheared or scaled. To show the UVs the way the surface
  looks in 3D we:
    1. build a 2D frame ON the surface: Up = world Z (JK up) projected into
       the surface plane (world +Y for floors/ceilings), Right = (-normal) x Up,
       i.e. the right-hand side for someone looking at the surface's front;
    2. solve the 2x2 linear map L from that frame to (u,v) using vertex 0 plus
       the two vertices giving the largest triangle (most stable);
    3. L's second column is "up the wall" expressed in UV space, and sign(det L)
       says whether the texture is mirrored. Build R = Rotate * Mirror so that
       direction points up the screen.
  Only the view changes; U,V values are never touched.                         }
procedure TUVEdit.ComputeViewAlign;
var
  n, k, k2, i, j: Integer;
  nx, ny, nz, upx, upy, upz, rx, ry, rz, d, len: Double;
  P0, Pk: TJKVertex;
  t0, tk: TTXVertex;
  a, b, du, dv: array of Double;
  detA, L11, L12, L21, L22, detL, ux, uy, ang, c, sn, mx: Double;
  fx, fy: Double;
  flat, is3do: Boolean;
  refName: String;
begin
  FRa := 1; FRb := 0; FRc := 0; FRd := 1;
  FAlignInfo := 'View: texture space (T to align)';
  if not FAlign then Exit;
  FAlignInfo := 'View: align failed, texture space';
  if not ValidSel(FSC, FSF) then Exit;
  n := level.Sectors[FSC].surfaces[FSF].Vertices.Count;
  if n < 3 then Exit;

  { surface normal (JK normals face the visible side, into the sector) }
  nx := level.Sectors[FSC].surfaces[FSF].normal.dx;
  ny := level.Sectors[FSC].surfaces[FSF].normal.dy;
  nz := level.Sectors[FSC].surfaces[FSF].normal.dz;
  len := Sqrt(nx*nx + ny*ny + nz*nz);
  if len < 1e-9 then Exit;
  nx := nx/len; ny := ny/len; nz := nz/len;

  { 3DO model meshes are wound the opposite way to level geometry (the
    renderer reverses their vertex order), so their normal points to the back
    of the face. Flip it so left/right comes out right; M flips it manually. }
  is3do := (level.Sectors[FSC].Flags and SF_3DO) <> 0;
  if is3do <> FFlip then
  begin
    nx := -nx; ny := -ny; nz := -nz;
  end;

  { Reference "up" laid into the surface plane:
      walls and slopes  -> world Z (JK up), i.e. up the wall / up the slope;
      flat floors/ceilings (world Z is along the normal, so it can't be
      projected) -> the direction the level's walkplayer faces, or world +Y
      if there is no walkplayer.
    Right = (-normal) x Up is the right-hand side when facing the surface's
    front, so the normal also decides whether the texture shows mirrored.
    Nothing here depends on the 3D preview or the camera. }
  flat := Abs(nz) > 0.995;
  if not flat then
  begin
    upx := 0; upy := 0; upz := 1;
    refName := 'up the surface';
  end
  else if GetWalkplayerForward(fx, fy) then
  begin
    upx := fx; upy := fy; upz := 0;
    refName := 'walkplayer facing (snapped 90)';
  end
  else
  begin
    upx := 0; upy := 1; upz := 0;
    refName := 'map north (no walkplayer)';
  end;
  d := upx*nx + upy*ny + upz*nz;
  upx := upx - d*nx; upy := upy - d*ny; upz := upz - d*nz;
  len := Sqrt(upx*upx + upy*upy + upz*upz);
  if len < 1e-9 then Exit;
  upx := upx/len; upy := upy/len; upz := upz/len;
  rx := -(ny*upz - nz*upy);
  ry := -(nz*upx - nx*upz);
  rz := -(nx*upy - ny*upx);

  { Each vertex in the surface frame (a,b) and in UV (du,dv), relative to vertex 0 }
  SetLength(a, n); SetLength(b, n); SetLength(du, n); SetLength(dv, n);
  P0 := level.Sectors[FSC].surfaces[FSF].GetVXs.GetItem(0);
  t0 := level.Sectors[FSC].surfaces[FSF].TXVertices.GetItem(0);
  for k := 0 to n - 1 do
  begin
    Pk := level.Sectors[FSC].surfaces[FSF].GetVXs.GetItem(k);
    tk := level.Sectors[FSC].surfaces[FSF].TXVertices.GetItem(k);
    a[k]  := (Pk.x-P0.x)*rx  + (Pk.y-P0.y)*ry  + (Pk.z-P0.z)*rz;
    b[k]  := (Pk.x-P0.x)*upx + (Pk.y-P0.y)*upy + (Pk.z-P0.z)*upz;
    du[k] := tk.u - t0.u;
    dv[k] := tk.v - t0.v;
  end;

  { Pick the vertex pair forming the largest triangle with vertex 0 }
  detA := 0; i := -1; j := -1;
  for k := 1 to n - 1 do
    for k2 := k + 1 to n - 1 do
      if Abs(a[k]*b[k2] - a[k2]*b[k]) > Abs(detA) then
      begin
        detA := a[k]*b[k2] - a[k2]*b[k];
        i := k; j := k2;
      end;
  if (i < 0) or (Abs(detA) < 1e-9) then Exit;

  { L = [du dv] * inverse([a b]) }
  L11 := (du[i]*b[j] - du[j]*b[i]) / detA;
  L12 := (du[j]*a[i] - du[i]*a[j]) / detA;
  L21 := (dv[i]*b[j] - dv[j]*b[i]) / detA;
  L22 := (dv[j]*a[i] - dv[i]*a[j]) / detA;
  detL := L11*L22 - L12*L21;
  if Abs(detL) < 1e-12 then Exit;

  { Mirror first if needed (flip U), then rotate "up the surface" to screen-up }
  if detL < 0 then mx := -1 else mx := 1;
  ux := mx * L12;
  uy := L22;
  ang := Pi/2 - ArcTan2(uy, ux);
  { 3DO model parts have no meaningful "up the wall"; their textures are
    authored upright in texture space, so snap to the nearest 90 degrees. }
  if is3do then ang := Round(ang/(Pi/2)) * (Pi/2);
  ang := ang + FRot * (Pi/2);          { R key: manual 90 degree steps }
  c := Cos(ang); sn := Sin(ang);
  FRa := c*mx;  FRb := -sn;
  FRc := sn*mx; FRd := c;

  FAlignInfo := Format('View: up = %s, rotated %.0f deg', [refName, RadToDeg(ang)]);
  if mx < 0 then FAlignInfo := FAlignInfo + ', mirrored';
  if is3do then FAlignInfo := FAlignInfo + ', 3DO model';
  if FFlip then FAlignInfo := FAlignInfo + ', manual flip';
  FAlignInfo := FAlignInfo + '  (T = texture space, M = flip, R = rotate 90)';
end;

{ ── export ───────────────────────────────────────────────────────────────────── }

{ Save the UV layout of every face that uses this material as a PNG the same
  size as the texture, so it can be used as a template in a paint program:
  one pixel of the PNG = one texel, outline points sit exactly on the UV
  coordinates. Lines wrap around like the tiled texture does.
  WithTexture = False: transparent background (outline only);
  WithTexture = True : the texture itself underneath.
  The picture is oriented like the game's texture: row 0 = top, v = row. }
procedure TUVEdit.ExportOutline(WithTexture: Boolean);
const
  Key: TColor = $00FE00FF;           // background colour that is made transparent
  Pal: array[0..7] of TColor = (clRed, clLime, clAqua, clYellow, $0000A5FF,
                                $00FF8000, clWhite, $00808000);
var
  dlg: TSaveDialog;
  bmp: TBitmap;
  png: TPngImage;
  bi: TBitmapInfo;
  tmp: TArray<Byte>;
  pts: array of TPoint;
  W, H, f, s, n, ox, oy, r, stride: Integer;
  txv: TTXVertex;
  mat, fn: String;
  minU, minV, sh, sv, cx, cy: Double;
  col: TColor;
begin
  W := FTexWidth;
  H := FTexHeight;
  if (W <= 0) or (H <= 0) or not ValidSel(FSC, FSF) then Exit;
  mat := level.Sectors[FSC].surfaces[FSF].Material;

  dlg := TSaveDialog.Create(Self);
  try
    dlg.Filter     := 'PNG image (*.png)|*.png';
    dlg.DefaultExt := 'png';
    dlg.Options    := dlg.Options + [ofOverwritePrompt];
    dlg.FileName   := ChangeFileExt(ExtractFileName(mat), '') + '_uv.png';
    if not dlg.Execute then Exit;
    fn := dlg.FileName;
  finally
    dlg.Free;
  end;

  bmp := TBitmap.Create;
  try
    bmp.PixelFormat := pf24bit;
    bmp.SetSize(W, H);

    if WithTexture and (Length(FTexPix) = W * H) then
    begin
      { FTexPix row r = MAT row r = picture row r from the top: draw each one
        explicitly so the orientation does not depend on how a TBitmap indexes
        its scanlines }
      FillChar(bi, SizeOf(bi), 0);
      bi.bmiHeader.biSize        := SizeOf(TBitmapInfoHeader);
      bi.bmiHeader.biWidth       := W;
      bi.bmiHeader.biHeight      := 1;
      bi.bmiHeader.biPlanes      := 1;
      bi.bmiHeader.biBitCount    := 24;
      bi.bmiHeader.biCompression := BI_RGB;
      stride := ((W * 3 + 3) div 4) * 4;
      SetLength(tmp, stride);
      for r := 0 to H - 1 do
      begin
        FillChar(tmp[0], stride, 0);
        Move(FTexPix[r * W], tmp[0], W * 3);
        SetDIBitsToDevice(bmp.Canvas.Handle, 0, r, W, 1, 0, 0, 0, 1,
                          @tmp[0], bi, DIB_RGB_COLORS);
      end;
    end
    else
    begin
      bmp.Canvas.Brush.Color := Key;
      bmp.Canvas.FillRect(Rect(0, 0, W, H));
    end;

    bmp.Canvas.Brush.Style := bsClear;
    bmp.Canvas.Font.Size   := 8;

    for f := 0 to level.Sectors[FSC].surfaces.Count - 1 do
    begin
      if CompareText(level.Sectors[FSC].surfaces[f].Material, mat) <> 0 then Continue;
      n := level.Sectors[FSC].surfaces[f].Vertices.Count;
      if n < 3 then Continue;
      SetLength(pts, n + 1);
      col := Pal[f mod 8];
      bmp.Canvas.Pen.Color  := col;
      bmp.Canvas.Font.Color := col;
      if InGroup(f) then bmp.Canvas.Pen.Width := 2 else bmp.Canvas.Pen.Width := 1;

      { move the polygon into the first texture tile, then draw it with its
        8 neighbours so parts that wrap around show up }
      minU := 1e30; minV := 1e30;
      for s := 0 to n - 1 do
      begin
        txv := level.Sectors[FSC].surfaces[f].TXVertices.GetItem(s);
        if txv.u < minU then minU := txv.u;
        if txv.v < minV then minV := txv.v;
      end;
      sh := Floor(minU / W) * W;
      sv := Floor(minV / H) * H;

      for oy := -1 to 1 do
        for ox := -1 to 1 do
        begin
          for s := 0 to n - 1 do
          begin
            txv := level.Sectors[FSC].surfaces[f].TXVertices.GetItem(s);
            pts[s].X := Round(txv.u - sh + ox * W);
            pts[s].Y := Round((txv.v - sv) + oy * H);
          end;
          pts[n] := pts[0];
          bmp.Canvas.Polyline(pts);
        end;

      { vertex marks and the surface number, on the main copy }
      cx := 0; cy := 0;
      for s := 0 to n - 1 do
      begin
        txv := level.Sectors[FSC].surfaces[f].TXVertices.GetItem(s);
        pts[s].X := Round(txv.u - sh);
        pts[s].Y := Round(txv.v - sv);
        cx := cx + pts[s].X;
        cy := cy + pts[s].Y;
        bmp.Canvas.Rectangle(pts[s].X - 1, pts[s].Y - 1, pts[s].X + 2, pts[s].Y + 2);
      end;
      bmp.Canvas.TextOut(Round(cx / n), Round(cy / n), IntToStr(f));
    end;

    png := TPngImage.Create;
    try
      png.Assign(bmp);
      if not WithTexture then
      begin
        png.TransparentColor := Key;
        png.Transparent      := True;
      end;
      png.SaveToFile(fn);
    finally
      png.Free;
    end;
    StatusBar1.Panels[0].Text := 'Saved ' + fn;
  finally
    bmp.Free;
  end;
end;

{ Write bmp as a 16 bit (RGB 5-6-5) JK MAT with a 4 level mip chain.
  Layout (matches TMatHeader / TTextureHeader / TTextureData in graph_files):
    76 byte header, 40 byte cell header, 24 byte texture data, then the mips.
  Rows are stored top row first, so MAT row y = texel row v = y. }
procedure TUVEdit.WriteMat16(const fn: String; bmp: TBitmap);
var
  S: TFileStream;
  W, H, lv, nLev, x, y, wl, hl, i, ch: Integer;
  rgb, nxt: TArray<Byte>;
  c: TColor;
  px: Word;

  procedure PutI(v: Cardinal);
  begin
    S.WriteBuffer(v, 4);
  end;

begin
  W := bmp.Width;
  H := bmp.Height;
  SetLength(rgb, W * H * 3);
  for y := 0 to H - 1 do
    for x := 0 to W - 1 do
    begin
      c := ColorToRGB(bmp.Canvas.Pixels[x, y]);
      rgb[(y * W + x) * 3]     := GetRValue(c);
      rgb[(y * W + x) * 3 + 1] := GetGValue(c);
      rgb[(y * W + x) * 3 + 2] := GetBValue(c);
    end;

  nLev := 1; wl := W; hl := H;
  while (nLev < 4) and (wl >= 2) and (hl >= 2) do
  begin
    wl := wl div 2; hl := hl div 2; Inc(nLev);
  end;

  S := TFileStream.Create(fn, fmCreate);
  try
    S.WriteBuffer(PAnsiChar('MAT ')^, 4);
    PutI($32);          // version
    PutI(2);            // type 2 = texture
    PutI(1);            // number of textures (cels)
    PutI(1);            // number of textures again
    PutI(1);            // colour mode 1 = RGB
    PutI(16);           // bits per pixel
    PutI(5); PutI(6); PutI(5);        // red / green / blue bits
    PutI(11); PutI(5); PutI(0);       // red / green / blue shift left
    PutI(3); PutI(2); PutI(3);        // red / green / blue shift right (bit loss)
    PutI(0); PutI(0); PutI(0);        // alpha bits / shift / loss: none

    { cell header }
    PutI(8); PutI(0);
    for i := 0 to 3 do PutI($3F800000);
    PutI(0); PutI(0);
    PutI($BFF78482);
    PutI(0);

    { texture data header }
    PutI(W); PutI(H);
    PutI(0); PutI(0); PutI(0);        // pad[0] = 0: not transparent
    PutI(nLev);

    wl := W; hl := H;
    for lv := 0 to nLev - 1 do
    begin
      for y := 0 to hl - 1 do
        for x := 0 to wl - 1 do
        begin
          i  := (y * wl + x) * 3;
          px := ((rgb[i] shr 3) shl 11) or ((rgb[i + 1] shr 2) shl 5) or (rgb[i + 2] shr 3);
          S.WriteBuffer(px, 2);
        end;
      if lv < nLev - 1 then
      begin
        SetLength(nxt, (wl div 2) * (hl div 2) * 3);
        for y := 0 to hl div 2 - 1 do
          for x := 0 to wl div 2 - 1 do
            for ch := 0 to 2 do
              nxt[(y * (wl div 2) + x) * 3 + ch] :=
                (rgb[((2 * y) * wl + 2 * x) * 3 + ch] +
                 rgb[((2 * y) * wl + 2 * x + 1) * 3 + ch] +
                 rgb[((2 * y + 1) * wl + 2 * x) * 3 + ch] +
                 rgb[((2 * y + 1) * wl + 2 * x + 1) * 3 + ch] + 2) div 4;
        rgb := nxt;
        wl := wl div 2;
        hl := hl div 2;
      end;
    end;
  finally
    S.Free;
  end;
end;

{ Export the arranged layout.

  Saves a MAT (16 bit, ready to apply to the model: every linked face drawn as
  a tinted, outlined, numbered shape at its UV position) and, next to it, a
  transparent PNG of the same size with just the outlines for painting over.
  One pixel = one texel; MAT row y = v = y, so the picture is oriented exactly
  like the game's texture (top row first).

  The layout is first shifted (all linked faces by the same amount) so its
  top-left corner sits at the texture's corner; that is the only change made
  to the UVs, and Esc undoes it. }
procedure TUVEdit.ExportLayout;
const
  Key: TColor = $00FE00FF;           // PNG background colour made transparent
  Pal: array[0..7] of TColor = (clRed, clLime, clAqua, clYellow, $0000A5FF,
                                $00FF8000, clWhite, $00808000);
  Bg: TColor = $00302828;            // MAT background

  function Pow2Ceil(x: Integer): Integer;
  begin
    Result := 8;
    while (Result < x) and (Result < 8192) do Result := Result * 2;
  end;

  function Tint(c: TColor): TColor;     // 25% of c over the MAT background
  var
    r, g, b: Integer;
  begin
    c := ColorToRGB(c);
    r := (GetRValue(c) + 3 * GetRValue(Bg)) div 4;
    g := (GetGValue(c) + 3 * GetGValue(Bg)) div 4;
    b := (GetBValue(c) + 3 * GetBValue(Bg)) div 4;
    Result := RGB(r, g, b);
  end;

  { draw all linked faces; forMat = filled shapes on the MAT background,
    otherwise outlines on the transparent key colour }
  procedure DrawFaces(bmp: TBitmap; forMat: Boolean);
  var
    gi, s, n, pass: Integer;
    txv: TTXVertex;
    cx, cy: Double;
    pts: array of TPoint;
  begin
    bmp.Canvas.Brush.Style := bsSolid;
    if forMat then bmp.Canvas.Brush.Color := Bg else bmp.Canvas.Brush.Color := Key;
    bmp.Canvas.FillRect(Rect(0, 0, bmp.Width, bmp.Height));
    bmp.Canvas.Font.Size := 8;

    { pass 0 = tinted fills (MAT only), pass 1 = outlines + corner dots + numbers,
      so overlapping faces still show every edge }
    for pass := 0 to 1 do
    for gi := 0 to High(FGroup) do
    begin
      if (pass = 0) and not forMat then Continue;
      n := level.Sectors[FSC].surfaces[FGroup[gi]].Vertices.Count;
      if n < 3 then Continue;
      SetLength(pts, n + 1);
      cx := 0; cy := 0;
      for s := 0 to n - 1 do
      begin
        txv := level.Sectors[FSC].surfaces[FGroup[gi]].TXVertices.GetItem(s);
        pts[s].X := Round(txv.u);
        pts[s].Y := Round(txv.v);          // GL row r = MAT row r (editor + preview both sample t = v / height)
        cx := cx + pts[s].X;
        cy := cy + pts[s].Y;
      end;
      pts[n] := pts[0];
      bmp.Canvas.Pen.Color := Pal[FGroup[gi] mod 8];
      if pass = 0 then
      begin
        bmp.Canvas.Brush.Style := bsSolid;
        bmp.Canvas.Brush.Color := Tint(Pal[FGroup[gi] mod 8]);
        bmp.Canvas.Pen.Color := Tint(Pal[FGroup[gi] mod 8]);
        bmp.Canvas.Polygon(pts);
        Continue;
      end;
      bmp.Canvas.Brush.Style := bsClear;
      bmp.Canvas.Polyline(pts);
      for s := 0 to n - 1 do
        bmp.Canvas.Rectangle(pts[s].X - 1, pts[s].Y - 1, pts[s].X + 2, pts[s].Y + 2);
      bmp.Canvas.Font.Color := Pal[FGroup[gi] mod 8];
      bmp.Canvas.TextOut(Round(cx / n), Round(cy / n), IntToStr(FGroup[gi]));
    end;
  end;

var
  k, n, p, Wn, Hn, minW, minH, cnt: Integer;
  txv: TTXVertex;
  minU, minV, maxU, maxV, shU, shV: Double;
  sizeStr, fn, pngName: String;
  dlg: TSaveDialog;
  bmp: TBitmap;
  png: TPngImage;
  isMat: Boolean;
begin
  if (FTexWidth <= 0) or not WSValid then Exit;
  n := Length(WSurf);
  if n = 0 then Exit;

  { bounding box of the linked faces, in texels }
  minU := 1e30; minV := 1e30; maxU := -1e30; maxV := -1e30;
  for k := 0 to n - 1 do
  begin
    txv := WGet(k);
    if txv.u < minU then minU := txv.u;
    if txv.u > maxU then maxU := txv.u;
    if txv.v < minV then minV := txv.v;
    if txv.v > maxV then maxV := txv.v;
  end;
  shU := -minU;                      // exact: the layout's top-left corner lands on 0,0
  shV := -minV;
  minW := Pow2Ceil(Ceil(maxU + shU - 1e-6));
  minH := Pow2Ceil(Ceil(maxV + shV - 1e-6));

  sizeStr := Format('%d x %d', [minW, minH]);
  if not InputQuery('Export layout',
       'Texture size, width x height (powers of two). The layout needs at least ' +
       sizeStr + ':', sizeStr) then Exit;
  p := Pos('x', LowerCase(sizeStr));
  if p = 0 then p := Pos(',', sizeStr);
  if p = 0 then begin ShowMessage('Enter the size like  256 x 256'); Exit; end;
  Wn := StrToIntDef(Trim(Copy(sizeStr, 1, p - 1)), 0);
  Hn := StrToIntDef(Trim(Copy(sizeStr, p + 1, 20)), 0);
  if (Wn < Ceil(maxU + shU - 1e-6)) or (Hn < Ceil(maxV + shV - 1e-6)) or (Wn > 4096) or (Hn > 4096) then
  begin
    ShowMessage(Format('That size does not fit: the layout is %d x %d texels. ' +
      'Use at least %d x %d (at most 4096).', [Ceil(maxU + shU - 1e-6), Ceil(maxV + shV - 1e-6), minW, minH]));
    Exit;
  end;

  cnt := Length(FGroup);
  if MessageDlg(Format('Export a %d x %d layout of %d face(s).'#13#10#13#10 +
       'The UVs of these faces will be moved by (%g, %g) texels so the layout ' +
       'starts at the texture corner (Esc undoes it).'#13#10 +
       'Faces of this texture that are NOT linked are left alone - link them ' +
       'first (Ctrl+G) if they must line up too.',
       [Wn, Hn, cnt, shU, shV]), mtConfirmation, [mbOK, mbCancel], 0) <> mrOk then Exit;

  dlg := TSaveDialog.Create(Self);
  try
    dlg.Filter     := 'JK material (*.mat)|*.mat|PNG outline only (*.png)|*.png';
    dlg.DefaultExt := 'mat';
    dlg.Options    := dlg.Options + [ofOverwritePrompt];
    dlg.FileName   := ChangeFileExt(ExtractFileName(
                        level.Sectors[FSC].surfaces[FSF].Material), '') + '_layout.mat';
    if not dlg.Execute then Exit;
    fn := dlg.FileName;
  finally
    dlg.Free;
  end;
  isMat := SameText(ExtractFileExt(fn), '.mat');

  { move the layout into the texture }
  if (shU <> 0) or (shV <> 0) then
  begin
    SaveUVsForUndo;
    for k := 0 to n - 1 do
    begin
      txv := WGet(k);
      WSetUV(k, txv.u + shU, txv.v + shV);
    end;
    XOffset := XOffset + shU / FTexWidth;     // keep the view on the layout
    YOffset := YOffset + shV / FTexWidth;
    SyncGrid;
    NotifyJED;
  end;

  bmp := TBitmap.Create;
  try
    bmp.PixelFormat := pf24bit;
    bmp.SetSize(Wn, Hn);

    if isMat then
    begin
      DrawFaces(bmp, True);
      WriteMat16(fn, bmp);
    end;

    { transparent outline PNG for painting: next to the MAT, or the file itself }
    DrawFaces(bmp, False);
    if isMat then pngName := ChangeFileExt(fn, '.png') else pngName := fn;
    png := TPngImage.Create;
    try
      png.Assign(bmp);
      png.TransparentColor := Key;
      png.Transparent      := True;
      png.SaveToFile(pngName);
    finally
      png.Free;
    end;
  finally
    bmp.Free;
  end;

  StatusBar1.Panels[0].Text := 'Saved ' + fn;
  if isMat then
    ShowMessage(Format('Saved %s (%d x %d, 16 bit) and %s.'#13#10#13#10 +
      'Apply the MAT to the model to check that every face lines up. The PNG has ' +
      'only the outlines (transparent): paint under it at exactly this size, ' +
      'hide the outlines, and convert the result to a MAT.',
      [ExtractFileName(fn), Wn, Hn, ExtractFileName(pngName)]))
  else
    ShowMessage(Format('Saved %s (%d x %d).', [ExtractFileName(fn), Wn, Hn]));
  ShowSelInfo;
  DrawScene;
end;

{ ── keyboard ─────────────────────────────────────────────────────────────────── }

procedure TUVEdit.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  sVal: String;
  sIdx: Integer;
begin
  case Key of
    { pan in SCREEN directions: map the screen step back through R^T }
    VK_RIGHT: if ssCtrl in Shift then RotateSel(UVRotStep) else begin XOffset := XOffset + FRa*0.1*ZoomFactor; YOffset := YOffset + FRb*0.1*ZoomFactor; end;
    VK_LEFT:  if ssCtrl in Shift then RotateSel(-UVRotStep) else begin XOffset := XOffset - FRa*0.1*ZoomFactor; YOffset := YOffset - FRb*0.1*ZoomFactor; end;
    VK_UP:    begin XOffset := XOffset + FRc*0.1*ZoomFactor; YOffset := YOffset + FRd*0.1*ZoomFactor; end;
    VK_DOWN:  begin XOffset := XOffset - FRc*0.1*ZoomFactor; YOffset := YOffset - FRd*0.1*ZoomFactor; end;
    Ord('M'): begin
                FFlip := not FFlip;
                FAlign := True;
                ComputeViewAlign;
                if Memo1.Lines.Count > 1 then Memo1.Lines[1] := FAlignInfo;
              end;
    Ord('R'): begin
                FRot := (FRot + 1) mod 4;
                FAlign := True;
                ComputeViewAlign;
                if Memo1.Lines.Count > 1 then Memo1.Lines[1] := FAlignInfo;
              end;
    Ord('T'): begin
                FAlign := not FAlign;
                ComputeViewAlign;
                if Memo1.Lines.Count > 1 then Memo1.Lines[1] := FAlignInfo;
              end;
    187, VK_ADD:      ZoomFactor := ZoomFactor * 0.9;
    189, VK_SUBTRACT: ZoomFactor := ZoomFactor * 1.1;
    Ord('S'): begin SnapEnabled := not SnapEnabled; ShowSelInfo; end;
    Ord('O'): begin ShowAllFaces := not ShowAllFaces;
                    StatusBar1.Panels[1].Text := 'AllFaces: ' + BoolToStr(ShowAllFaces, True); end;
    { rotate / scale use the same keys as the 3D preview's Texturing menu:
      Ctrl+, / Ctrl+.  (or Ctrl+Left / Ctrl+Right)  rotate texture left / right
      Alt+, / Alt+.                                 scale texture down / up
      Shift added to a rotate key = fine 1 degree step }
    188: if ssCtrl in Shift then
           RotateSel(-IfThen(ssShift in Shift, 1.0, UVRotStep))
         else if ssAlt in Shift then ScaleSel(UVScaleStep)
         else Exit;
    190: if ssCtrl in Shift then
           RotateSel(IfThen(ssShift in Shift, 1.0, UVRotStep))
         else if ssAlt in Shift then ScaleSel(1/UVScaleStep)
         else Exit;
    { flip the selection on screen: H = left/right, V = up/down }
    Ord('X'): if not (ssCtrl in Shift) and not (ssAlt in Shift) then MirrorTool(ssShift in Shift) else Exit;
    Ord('P'): if not (ssCtrl in Shift) and not (ssAlt in Shift) then PackLayout(ssShift in Shift) else Exit;
    Ord('H'): TransformSelection(-1, 0, 0, 1);
    Ord('V'): TransformSelection(1, 0, 0, -1);
    { numeric entry }
    Ord('D'): begin
                sVal := '0';
                if InputQuery('Rotate', 'Degrees (+ = counter-clockwise):', sVal) then
                  RotateSel(StrToFloatDef(sVal, 0));
              end;
    Ord('F'): begin
                sVal := '1';
                if InputQuery('Scale', 'Scale factor (1 = unchanged):', sVal) then
                  ScaleSel(StrToFloatDef(sVal, 1));
              end;
    { linked faces: G = add neighbouring faces with the same texture,
      Ctrl+G = add everything connected, Shift+G = this face only }
    Ord('G'): begin
                if ssCtrl in Shift then GrowGroup(True)
                else if ssShift in Shift then ResetGroup
                else GrowGroup(False);
                ShowSelInfo;
              end;
    { Ctrl+E = export outline (transparent PNG), Ctrl+Shift+E = outline over the texture }
    Ord('E'): if ssCtrl in Shift then
              begin
                if ssShift in Shift then ExportOutline(True) else ExportLayout;
              end
              else Exit;
    Ord('A'): if ssCtrl in Shift then
              begin
                SelectAll(not (ssShift in Shift));   // Ctrl+A all, Ctrl+Shift+A none
                ShowSelInfo;
              end
              else Exit;
    Ord('I'): if ssCtrl in Shift then
              begin
                if Length(FSel) = 0 then SelectAll(False);
                for sIdx := 0 to High(FSel) do FSel[sIdx] := not FSel[sIdx];
                ShowSelInfo;
              end
              else Exit;
    VK_F1: ShowMessage(
      'MOUSE'#13#10 +
      '  Click vertex: select    Shift+click: add/remove'#13#10 +
      '  Drag empty space: box select (Shift adds, Ctrl forces box)'#13#10 +
      '  Drag selected vertex / inside face: move'#13#10 +
      '  Wheel: zoom at cursor'#13#10#13#10 +
      'KEYS (also in the menus)'#13#10 +
      '  Arrows pan   + / - zoom   Esc undo'#13#10 +
      '  Ctrl+A all   Ctrl+Shift+A none   Ctrl+I invert'#13#10 +
      '  Ctrl+E export the linked-face layout as a 16-bit MAT + outline PNG (moves the UVs into the texture)'#13#10 +
      '  Ctrl+Shift+E outline over the current texture (no UV change)'#13#10 +
      '  P pack linked faces with no overlap (touching faces stay together)   Shift+P every face on its own'#13#10 +
      '  X select faces mirrored vs this face   Shift+X flip them to match'#13#10 +
      '  G add neighbouring faces (same texture)   Ctrl+G all connected   Shift+G one face'#13#10 +
      '  With linked faces: click inside a face = select + move just that face'#13#10 +
      '    (Shift+click adds/removes a face, Alt+drag moves all together).'#13#10 +
      '    Rotate/scale act on the selected face(s); moving snaps to the other faces.'#13#10 +
      '  Ctrl+, / Ctrl+.  rotate (same as 3D preview; Ctrl+arrows too)'#13#10 +
      '  Alt+, / Alt+.  scale (same as 3D preview)'#13#10 +
      '  D  rotate by angle   F  scale by factor   H / V  flip'#13#10 +
      '  S  snap   O  show other faces'#13#10 +
      '  T  texture space   M  mirror view   R  rotate view');
    VK_ESCAPE:
      if BoxMode then
      begin
        BoxMode := False;              // cancel rubber-band
        ReleaseCapture;
      end
      else if Dragging then
      begin
        { Cancel drag: restore saved UVs (selection is kept) }
        RestoreUVsFromUndo;
        Dragging := False;
        ReleaseCapture;
      end
      else
        RestoreUVsFromUndo;  // full undo even outside drag
  else
    Exit;  // not our key — let the focused control have it
  end;

  Key := 0;  // consumed — stop the grid/memo also reacting
  DrawScene;
end;

{ ── paint / resize ───────────────────────────────────────────────────────────── }

procedure TUVEdit.FormPaint(Sender: TObject);
begin
  Label1.Caption := 'Paint';
  DrawScene;
end;

procedure TUVEdit.FormResize(Sender: TObject);
begin
  Label1.Caption := 'Resize';
  DrawScene;
end;

{ ── coordinate conversion ────────────────────────────────────────────────────── }

{ Exact inverse of the glOrtho used in DrawScene.
  DrawScene uses HalfW = HalfH = ZoomFactor (SQUARE — no AspectRatio on W).
  glOrtho( -HalfW+XOffset,  HalfW+XOffset,
           -HalfH+YOffset,  HalfH+YOffset, -1, 1 )
  Standard orientation: V increases upward on screen.                          }
function TUVEdit.ScreenToUV(ScreenX, ScreenY: Integer): TPointf;
var
  HalfW, HalfH, sx, sy: Double;
begin
  HalfH := ZoomFactor;
  HalfW := ZoomFactor;   // square — matches glOrtho

  // pixel -> view coords centred on 0 (Y up), then undo the view rotation:
  // uv = R^T * view + centre   (R is a rotation/reflection, so R^-1 = R^T)
  sx := (ScreenX / Panel2.Width) * (HalfW * 2) - HalfW;
  sy := HalfH - (ScreenY / Panel2.Height) * (HalfH * 2);
  Result.X := FRa*sx + FRc*sy + XOffset;
  Result.Y := FRb*sx + FRd*sy + YOffset;
end;

{ ── main rendering ───────────────────────────────────────────────────────────── }

procedure TUVEdit.DrawScene;
var
  s, f, gi, k: Integer;
  selAll: Boolean;
  txv: TTXVertex;
  HalfW, HalfH: Double;
  UVMinU, UVMaxU, UVMinV, UVMaxV: Double;
  currentMat: String;
  pu, pv: Double;
  M: array[0..15] of GLdouble;
begin
  { Nothing to draw until a surface + texture are loaded }
  if (FTexWidth <= 0) or (FTexHeight <= 0) or not ValidSel(FSC, FSF) then Exit;
  if not WSValid then ResetGroup;
  wglMakeCurrent(glDC, RC);   // required — must be called each frame

  glDisable(GL_DEPTH_TEST);
  glViewport(0, 0, Panel2.Width, Panel2.Height);

  glMatrixMode(GL_PROJECTION);
  glClear(GL_COLOR_BUFFER_BIT);
  glLoadIdentity;

  TexAspect := Double(FTexWidth) / Double(FTexHeight);

  HalfH := ZoomFactor;
  HalfW := ZoomFactor;  // square projection

  { View space centred on 0, Y up }
  glOrtho(-HalfW, HalfW, -HalfH, HalfH, -1.0, 1.0);

  { Modelview: view = R * (uv - centre). Column-major for GL. }
  glMatrixMode(GL_MODELVIEW);
  M[0] := FRa; M[1] := FRc; M[2] := 0; M[3] := 0;
  M[4] := FRb; M[5] := FRd; M[6] := 0; M[7] := 0;
  M[8] := 0;   M[9] := 0;   M[10] := 1; M[11] := 0;
  M[12] := -(FRa*XOffset + FRb*YOffset);
  M[13] := -(FRc*XOffset + FRd*YOffset);
  M[14] := 0;  M[15] := 1;
  glLoadMatrixd(@M[0]);

  { ── tiled texture background ───────────────────────────────
    Cover the panel: take its 4 corners back into UV space (the view may be
    rotated, so this quad can be rotated in UV). GL_REPEAT tiles it. }
  glEnable(GL_TEXTURE_2D);
  glBindTexture(GL_TEXTURE_2D, FTexture);
  glColor3f(1.0, 1.0, 1.0);

  glBegin(GL_QUADS);
  for s := 0 to 3 do
  begin
    case s of
      0: begin pu := -HalfW; pv := -HalfH; end;
      1: begin pu :=  HalfW; pv := -HalfH; end;
      2: begin pu :=  HalfW; pv :=  HalfH; end;
    else begin pu := -HalfW; pv :=  HalfH; end;
    end;
    UVMinU := FRa*pu + FRc*pv + XOffset;   // corner in UV space
    UVMinV := FRb*pu + FRd*pv + YOffset;
    glTexCoord2f(UVMinU, UVMinV * TexAspect);
    glVertex2f(UVMinU, UVMinV);
  end;
  glEnd;

  glDisable(GL_TEXTURE_2D);

  { ── other surfaces with same material (grey) ─────────────── }
  if ShowAllFaces and (FTexWidth > 0) then
  begin
    currentMat := level.Sectors[FSC].surfaces[FSF].Material;
    for f := 0 to level.Sectors[FSC].surfaces.Count - 1 do
    begin
      if InGroup(f) then Continue;
      if level.Sectors[FSC].surfaces[f].Material <> currentMat then Continue;

      glColor3f(0.5, 0.5, 0.5);
      glLineWidth(1.0);
      glBegin(GL_LINE_LOOP);
      for s := 0 to level.Sectors[FSC].surfaces[f].Vertices.Count - 1 do
      begin
        txv := level.Sectors[FSC].surfaces[f].TXVertices.GetItem(s);
        pu  :=  txv.u / FTexWidth;
        pv  := txv.v / FTexWidth;
        glVertex2f(pu, pv);
      end;
      glEnd;
    end;
  end;

  { ── group faces: shown surface cyan, linked neighbours magenta ── }
  glLineWidth(1.5);
  for gi := 0 to High(FGroup) do
  begin
    if gi = 0 then glColor3f(0.0, 1.0, 1.0) else glColor3f(1.0, 0.35, 1.0);
    if (Length(FGroup) > 1) and FaceSelState(gi, selAll) then
      glLineWidth(3.5) else glLineWidth(1.5);
    glBegin(GL_LINE_LOOP);
    for s := 0 to level.Sectors[FSC].surfaces[FGroup[gi]].Vertices.Count - 1 do
    begin
      txv := level.Sectors[FSC].surfaces[FGroup[gi]].TXVertices.GetItem(s);
      glVertex2f(txv.u / FTexWidth, txv.v / FTexWidth);
    end;
    glEnd;
  end;

  { ── UV vertices of every face in the group ───────────────────── }
  glPointSize(8.0);
  glBegin(GL_POINTS);
  for k := 0 to High(WSurf) do
  begin
    txv := WGet(k);
    if IsSel(k) then
      glColor3f(0.0, 1.0, 0.0)   // selected = green
    else if (WSurf[k] = FSF) and (WVert[k] = 0) then
      glColor3f(1.0, 0.0, 0.0)   // first vertex of the shown face = red
    else
      glColor3f(1.0, 1.0, 0.0);  // rest = yellow
    glVertex2f(txv.u / FTexWidth, txv.v / FTexWidth);
  end;
  glEnd;

  { ── origin marker ────────────────────────────────────────── }
  glColor3f(1.0, 0.5, 0.0);
  glPointSize(6.0);
  glBegin(GL_POINTS);
    glVertex2f(0.0, 0.0);
  glEnd;

  { ── rubber-band selection box (screen space) ─────────────── }
  if BoxMode then
  begin
    glLoadIdentity;
    glColor3f(1.0, 1.0, 1.0);
    glLineWidth(1.0);
    glBegin(GL_LINE_LOOP);
    for s := 0 to 3 do
    begin
      case s of
        0: begin pu := BoxX0; pv := BoxY0; end;
        1: begin pu := BoxX1; pv := BoxY0; end;
        2: begin pu := BoxX1; pv := BoxY1; end;
      else begin pu := BoxX0; pv := BoxY1; end;
      end;
      glVertex2f((pu / Panel2.Width) * (HalfW * 2) - HalfW,
                 HalfH - (pv / Panel2.Height) * (HalfH * 2));
    end;
    glEnd;
  end;

  glFlush;
  SwapBuffers(glDC);
end;

{ ── mouse: down ────────────────────────────────────────────────────────────────
  Click a vertex      select it (and drag it; drags all selected if it was selected)
  Shift+click vertex  add / remove it from the selection
  Drag empty space    rubber-band box select (Shift = add to selection)
  Ctrl+drag           box select even when starting inside the face
  Drag inside face    move the whole face                                        }

procedure TUVEdit.Panel2MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  k, n, hit: Integer;
  txv: TTXVertex;
  UV: TPointF;
  PickRadius, dist, bestD, hx, hy: Double;
  state, anySel, allSel: Boolean;
  gi: Integer;
begin
  Self.SetFocus;
  if (Button <> mbLeft) or (FTexWidth <= 0) or not WSValid then Exit;
  n := Length(WSurf);
  if Length(FSel) <> n then SelectAll(False);
  UV         := ScreenToUV(X, Y);
  PickRadius := ZoomFactor * 0.03;   // ~3% of view radius
  hit        := -1;
  bestD      := PickRadius;

  { Nearest vertex of any face in the group (not when Ctrl forces a box) }
  if not (ssCtrl in Shift) then
    for k := 0 to n - 1 do
    begin
      txv  := WGet(k);
      dist := Sqrt(Sqr(UV.X - txv.u / FTexWidth) + Sqr(UV.Y - txv.v / FTexWidth));
      if dist < bestD then
      begin
        bestD := dist;
        hit   := k;
      end;
    end;

  if hit >= 0 then
  begin
    txv := WGet(hit);
    hx  := txv.u / FTexWidth;
    hy  := txv.v / FTexWidth;
    if ssShift in Shift then
      state := not FSel[hit]            // toggle
    else
    begin
      state := True;
      if not FSel[hit] then SelectAll(False);
    end;
    { vertices sitting on the same spot (a corner shared by linked faces)
      are picked together }
    for k := 0 to n - 1 do
    begin
      txv := WGet(k);
      if Sqrt(Sqr(txv.u / FTexWidth - hx) + Sqr(txv.v / FTexWidth - hy)) <= PickRadius * 0.2 then
        FSel[k] := state;
    end;
    FSel[hit] := state;
    if FSel[hit] then
    begin
      Dragging := True; DragStartU := UV.X; DragStartV := UV.Y;
      SaveUVsForUndo; SetCapture(Panel2.Handle);
    end;
  end
  else
  begin
    gi := -1;
    if not (ssCtrl in Shift) and not (ssAlt in Shift) then
      gi := FaceAtUV(UV.X, UV.Y);

    if ssAlt in Shift then
    begin
      { Alt+drag = move the whole group together }
      SelectAll(True);
      Dragging := True; DragStartU := UV.X; DragStartV := UV.Y;
      SaveUVsForUndo; SetCapture(Panel2.Handle);
    end
    else if gi >= 0 then
    begin
      { click inside one face: select just that face's vertices and move
        them (the other linked faces stay put) }
      anySel := FaceSelState(gi, allSel);
      if ssShift in Shift then
      begin
        state := not allSel;                 // Shift+click toggles the face
        for k := 0 to n - 1 do
          if WGrp[k] = gi then FSel[k] := state;
      end
      else
      begin
        state := True;
        if not anySel then
        begin
          SelectAll(False);
          for k := 0 to n - 1 do
            if WGrp[k] = gi then FSel[k] := True;
        end;
      end;
      if state then
      begin
        Dragging := True; DragStartU := UV.X; DragStartV := UV.Y;
        SaveUVsForUndo; SetCapture(Panel2.Handle);
      end;
    end
    else
    begin
      { rubber-band box select }
      BoxMode := True;
      BoxAdd  := ssShift in Shift;
      BoxX0 := X; BoxY0 := Y; BoxX1 := X; BoxY1 := Y;
      if not BoxAdd then SelectAll(False);
      SetCapture(Panel2.Handle);
    end;
  end;

  ShowSelInfo;
  DrawScene;
end;

{ ── mouse: move ──────────────────────────────────────────────────────────────── }

procedure TUVEdit.Panel2MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  UV, SnapPt: TPointF;
  DeltaU, DeltaV: Double;          // mouse offset since mouse-down, UV units
  txv: TTXVertex;
  k, n: Integer;
  SnapDU, SnapDV, bestD, d: Double;
  pu, pv: Double;
begin
  UV := ScreenToUV(X, Y);
  StatusBar1.Panels[0].Text := 'UV: ' + FormatFloat('0.00', UV.X) +
                                ', '  + FormatFloat('0.00', UV.Y);

  if BoxMode and (ssLeft in Shift) then
  begin
    BoxX1 := X; BoxY1 := Y;
    DrawScene;
    Exit;
  end;

  if not (Dragging and (ssLeft in Shift)) then Exit;
  if (FTexWidth <= 0) or not WSValid then Exit;

  SnapThreshold := ZoomFactor * 0.02;   // ~2% of view, follows zoom
  n := Length(WSurf);
  if (Length(FSel) <> n) or (Length(SavedUVs) <> n) then Exit;

  { Absolute drag: new position = position at mouse-down + total mouse offset.
    SavedUVs holds the positions from mouse-down, so snapping never
    accumulates error and the selection can always be pulled off a snap point.
    All selected vertices move by the same (snapped) offset. }
  DeltaU := UV.X - DragStartU;
  DeltaV := UV.Y - DragStartV;
  SnapDU := 0; SnapDV := 0;

  { Find the selected vertex that lands closest to a snap target }
  bestD := 1e30;
  for k := 0 to n - 1 do
    if FSel[k] then
    begin
      pu := SavedUVs[k].u / FTexWidth + DeltaU;
      pv := SavedUVs[k].v / FTexWidth + DeltaV;
      SnapPt := SnapToNearestEdge(pu, pv, FSF);
      d := Sqr(SnapPt.X - pu) + Sqr(SnapPt.Y - pv);
      if ((SnapPt.X <> pu) or (SnapPt.Y <> pv)) and (d < bestD) then
      begin
        bestD  := d;
        SnapDU := SnapPt.X - pu;
        SnapDV := SnapPt.Y - pv;
      end;
    end;

  for k := 0 to n - 1 do
    if FSel[k] then
      WSetUV(k, SavedUVs[k].u + (DeltaU + SnapDU) * FTexWidth,
                SavedUVs[k].v + (DeltaV + SnapDV) * FTexWidth);

  { Rebuilding the sector in the 3D preview is the slow part, so during a
    drag refresh it at most ~7 times a second; the final state is pushed
    on mouse-up. }
  if GetTickCount - FLastNotify > 150 then
  begin
    FLastNotify := GetTickCount;
    NotifyJED;
  end;
  DrawScene;
end;

{ ── mouse: up ────────────────────────────────────────────────────────────────── }

procedure TUVEdit.Panel2MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  k: Integer;
  txv: TTXVertex;
  pu, pv, vx, vy, bx0, bx1, by0, by1: Double;
  P0, P1: TPointF;
begin
  if BoxMode then
  begin
    BoxMode := False;
    if WSValid and (FTexWidth > 0) then
    begin
      if Length(FSel) <> Length(WSurf) then SelectAll(False);
      { box corners in view space (screen -> UV -> view), then test each
        vertex in view space so the box stays axis-aligned on screen }
      P0 := ScreenToUV(BoxX0, BoxY0);
      P1 := ScreenToUV(BoxX1, BoxY1);
      bx0 := FRa*(P0.X-XOffset) + FRb*(P0.Y-YOffset);
      by0 := FRc*(P0.X-XOffset) + FRd*(P0.Y-YOffset);
      bx1 := FRa*(P1.X-XOffset) + FRb*(P1.Y-YOffset);
      by1 := FRc*(P1.X-XOffset) + FRd*(P1.Y-YOffset);
      if bx0 > bx1 then begin vx := bx0; bx0 := bx1; bx1 := vx; end;
      if by0 > by1 then begin vy := by0; by0 := by1; by1 := vy; end;
      for k := 0 to High(FSel) do
      begin
        txv := WGet(k);
        pu  := txv.u / FTexWidth - XOffset;
        pv  := txv.v / FTexWidth - YOffset;
        vx  := FRa*pu + FRb*pv;
        vy  := FRc*pu + FRd*pv;
        if (vx >= bx0) and (vx <= bx1) and (vy >= by0) and (vy <= by1) then
          FSel[k] := True;
      end;
    end;
  end
  else if Dragging then
  begin
    SyncGrid;
    NotifyJED;     // final, exact state to the 3D preview
  end;
  Dragging := False;
  ReleaseCapture;
  Self.SetFocus;
  ShowSelInfo;
  DrawScene;
end;

{ Zoom keeping the UV point under (ScreenX,ScreenY) fixed on screen.
  Factor < 1 zooms in, > 1 zooms out. }
procedure TUVEdit.ZoomAt(ScreenX, ScreenY: Integer; Factor: Double);
var
  UVBefore: TPointF;
begin
  UVBefore   := ScreenToUV(ScreenX, ScreenY);
  ZoomFactor := ZoomFactor * Factor;
  if ZoomFactor < 0.01 then ZoomFactor := 0.01;
  if ZoomFactor > 1000 then ZoomFactor := 1000;
  XOffset := UVBefore.X - (UVBefore.X - XOffset) * Factor;
  YOffset := UVBefore.Y - (UVBefore.Y - YOffset) * Factor;
  DrawScene;
end;

{ Windows sends WM_MOUSEWHEEL to the FOCUSED control, and a TPanel can never
  take focus, so Panel2.OnMouseWheel never fires. Every VCL control forwards
  wheel messages to its parent form's MouseWheelHandler, so catching it here
  works no matter which control (memo, grid, panel) currently has focus. }
procedure TUVEdit.MouseWheelHandler(var Message: TMessage);
var
  P: TPoint;
  Delta: SmallInt;
begin
  if Message.Msg = WM_MOUSEWHEEL then
  begin
    P := Panel2.ScreenToClient(Mouse.CursorPos);
    if PtInRect(Panel2.ClientRect, P) then
    begin
      Delta := SmallInt(HiWord(Message.WParam));
      if Delta > 0 then ZoomAt(P.X, P.Y, 0.85)        // wheel up = zoom in
      else              ZoomAt(P.X, P.Y, 1.0 / 0.85); // wheel down = zoom out
      Message.Result := 1;
      Exit;
    end;
  end;
  inherited MouseWheelHandler(Message);
end;

{ ── texture load ─────────────────────────────────────────────────────────────── }

procedure TUVEdit.LoadTexture;
type
  TRGBTripleArray  = ARRAY[Word] of TRGBTriple;
  pRGBTripleArray  = ^TRGBTripleArray;
var
  Fname: String;
  cmppal: TCMPPal;
  F: TFile;
  nMatCell, Yx, Xx: Integer;
  mat: TMAT;
  bm: TBitmap;
  Pixels: TArray<TRGBTriple>;
  Row: pRGBTripleArray;
begin
  Fname := level.Sectors[FSC].surfaces[FSF].Material;
  GetLevelPal(Level, cmpPal);

  F := OpenGameFile(Fname);
  if F = nil then Raise Exception.Create(Fname + ' not found');

  nMatCell := 0;                    // was uninitialised: random cel index
  mat := TMat.Create(F, nMatCell);
  mat.SetPal(cmpPal);
  bm := mat.LoadBitmap(mat.Info.width, mat.Info.height);
  bm.PixelFormat := pf24bit;

  FTexWidth  := bm.Width;
  FTexHeight := bm.Height;

  SetLength(Pixels, bm.Width * bm.Height);
  for Yx := 0 to bm.Height - 1 do
  begin
    { Rows in stored order: GL row r = MAT row r, same as JED's 3D view
      samples with t = v / height. Do NOT reverse — orientation is handled
      by the projection (V increases upward on screen). }
    Row := bm.ScanLine[Yx];
    for Xx := 0 to bm.Width - 1 do
      Pixels[Yx * bm.Width + Xx] := Row[Xx];
  end;

  FTexPix := Pixels;   // keep a copy for the outline export
  mat.Free;   // also frees bm — in NJED the MAT owns the bitmap from LoadBitmap,
              // so do NOT call bm.Free (double free -> FastMM error)

  wglMakeCurrent(glDC, RC);
  if FTexture <> 0 then glDeleteTextures(1, @FTexture);  // free previous surface's texture
  glGenTextures(1, @FTexture);
  glBindTexture(GL_TEXTURE_2D, FTexture);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, FTexWidth, FTexHeight, 0,   // bm is gone by now
               GL_BGR, GL_UNSIGNED_BYTE, @Pixels[0]);
end;

{ ── misc ─────────────────────────────────────────────────────────────────────── }

procedure TUVEdit.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  StatusBar1.Panels[0].Text := '(' + IntToStr(X) + ', ' + IntToStr(Y) + ')';
end;

procedure TUVEdit.Panel2Resize(Sender: TObject);
begin
  // viewport is set in DrawScene each frame — nothing needed here
end;

procedure TUVEdit.SetPointSize(size: Double);
begin
  halfpsize := Round(size / 2);
  psizeodd  := Round(size) mod 2;
end;

procedure TUVEdit.SetUVButtonClick(Sender: TObject);
var
  row, s: Integer;
  txv: TTXVertex;
begin
  row := UV_StringGrid.RowCount;
  for s := 1 to row - 1 do
  begin
    txv   := level.Sectors[FSC].surfaces[FSF].TXVertices.GetItem(s - 1);
    txv.u := StrToFloat(UV_StringGrid.Cells[1, s]);
    txv.v := StrToFloat(UV_StringGrid.Cells[2, s]);
    level.Sectors[FSC].surfaces[FSF].TXVertices.Items[s - 1] := txv;
  end;
  NotifyJED;
  Windows.SetFocus(0);
  DrawScene;
end;

procedure TUVEdit.Timer1Timer(Sender: TObject);
begin
  if not Visible then Exit;   // timer may be enabled in the .dfm — never work while hidden
  Label1.Caption := 'Timer';
  { Follow the selection in JED: if a different surface was picked in the
    3D view, reload grid + texture for it (not mid-drag). }
  if (not Dragging) and ValidSel(JedMain.Cur_SC, JedMain.Cur_SF) and
     ((JedMain.Cur_SC <> FSC) or (JedMain.Cur_SF <> FSF) or (FTexWidth <= 0)) then
    LoadSurface
  else if not Dragging then
    DrawScene;
end;

end.
