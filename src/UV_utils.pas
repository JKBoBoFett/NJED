unit UV_utils;

interface
uses
 math,geometry,J_Level;
  type
  TUVAxes = record
    UAxis, VAxis: TVector;
  end;
function VSnapToAxis(vec:TVector):TVector;
procedure getTopEdge(surf:TJKSurface;var X1,Y1,Z1,X2,Y2,Z2:double);
function GetReferenceVector(const Normal: TVector): TVector;
function CalculateAlignedUVAxes(const Normal: TVector): TUVAxes;
implementation
uses
 lev_utils;


  //03-NOV-2024
function GetReferenceVector(const Normal: TVector): TVector;
begin
  // Determine the largest component of the normal
  if ( (Abs(Normal.X) > Abs(Normal.Y)) and (Abs(Normal.X) > Abs(Normal.Z)) ) then
    SetVec(Result,0, 1, 0)   // Normal points mostly along X-axis
  else if Abs(Normal.Y) > Abs(Normal.Z) then
     SetVec(Result,1, 0, 0)  // Normal points mostly along Y-axis
  else
    SetVec(Result,1, 0, 0); // Normal points mostly along Z-axis


end;


function CalculateAlignedUVAxes(const Normal: TVector): TUVAxes;
var
  Reference, UAxis, VAxis: TVector;
  UVAxes: TUVAxes;
begin
  // Step 1: Choose a reference vector based on the primary axis of the normal
  Reference := GetReferenceVector(Normal);

  // Step 2: Calculate the U-axis by projecting the reference vector onto the plane
   SetVec(UVAxes.UAxis,
      Reference.X - VDotProduct(Reference, Normal) * Normal.X,
      Reference.Y - VDotProduct(Reference, Normal) * Normal.Y,
      Reference.Z - VDotProduct(Reference, Normal) * Normal.Z
      );

  Normalize(UVAxes.UAxis);

  // Step 3: Calculate the V-axis as the cross product of Normal and U-axis
  UVAxes.VAxis := VCross(Normal, UVAxes.UAxis);
  Normalize(VAxis);

  Result := UVAxes;
end;



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
