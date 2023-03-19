unit UV_utils;

interface
uses
 math,geometry,J_Level;

function VSnapToAxis(vec:TVector):TVector;
procedure getTopEdge(surf:TJKSurface;var X1,Y1,Z1,X2,Y2,Z2:double);

implementation
uses
 lev_utils;

function VSnapToAxis(vec:TVector):TVector;
var
lx,ly,lz:double;
begin
 lx:=abs(vec.x);
 ly:=abs(vec.y);
 lz:=abs(vec.z);

 if ( (lx > ly) and (lx > lz) ) then
  begin
  result.x := sign(vec.X);
  result.y :=0;
  result.z :=0;
  end
 else if ( (ly > lx) and (ly > lz) ) then
  begin
  result.x :=0;
  result.y :=sign(vec.Y);
  result.z :=0;
  end
 else
  begin
  result.x :=0;
  result.y :=0;
  result.z :=sign(vec.Z);
  end;

end;

procedure getTopEdge(surf:TJKSurface;var X1,Y1,Z1,X2,Y2,Z2:double);
var
SnapV:TVector;
cx,cy,cz:double;
var i:integer;
begin
x1:=999999999; x2:=-999999999;
y1:=999999999; y2:=-999999999;
z1:=999999999; z2:=-999999999;

SnapV:=VSnapToAxis(surf.normal);
NJEDCalcSurfCenter(surf,cx,cy,cz);

X1:=cx;X2:=cx;
Y1:=cy;Y2:=cy;
Z1:=cz;Z2:=cz;
//pos z normal
   if (SnapV.x = 0) and (SnapV.y = 0) and (SnapV.z = 1) then
    begin
      for i:=0 to surf.vertices.count-1 do
       With surf.vertices[i] do
       begin
        //if above left center
        if (surf.vertices[i].x<cx) and (surf.vertices[i].y>cy) then
         begin
          // if furthest top left set point
          if (surf.vertices[i].x<x1) and (surf.vertices[i].y>=y1) then
            x1:=x; y1:=y; z1:=z;
         end;
        //if above right center
        if (x>cx) and (y>cy) then
         begin
          // if furthest top right set point
          if (x>x1)and (y>=y1) then
           x2:=x; y2:=y; z2:=z;
         end;
    end;
  end;


end;

end.
