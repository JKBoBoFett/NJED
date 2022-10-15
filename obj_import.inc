
Procedure FlipSurface(surf:TJKSurface);
var n,i:integer;
    vx:TJKVertex;
    tv:TTXVertex;
begin
 for i:=0 to (surf.vertices.count div 2)-1 do
 begin
   n:=surf.vertices.count-i-1;
   vx:=surf.vertices[i];
   surf.vertices[i]:=surf.vertices[n];
   surf.vertices[n]:=vx;

   tv:=surf.txvertices[i];
   surf.txvertices[i]:=surf.txvertices[n];
   surf.txvertices[n]:=tv;
 end;
 //surf.recalc;

 //if IsTXFlipped(surf) then surf.surfFlags:=SetFlags(surf.surfFlags,SFF_FLIP)
 //else surf.surfFlags:=ClearFlags(surf.surfFlags,SFF_FLIP);

end;


   function OccurrencesOfChar(const S: string; const C: char): integer;
var
  i: Integer;
begin
  result := 0;
  for i := 1 to Length(S) do
    if S[i] = C then
      inc(result);
end;

Procedure TJKLevel.ImportObj(F:TFileName);
var
     w1,w2:String;
     t:TTextFile;
     n,i,p:Integer;
     s:String;

Procedure GetNextLine(var s:String);
var cmt_pos:word; {Position of #}
begin
 s:='';
 Repeat
  if t.eof then exit;
  t.Readln(s);
  cmt_pos:=Pos('#',s);
  if cmt_pos<>0 then SetLength(s,cmt_pos-1);
  s:=LowerCase(Trim(s));
 Until s<>'';
end; {GetNextLine}

Procedure FScanf(const s:string;const format:String;const Vals:array of pointer);
begin
 if not SScanf(s,format,vals) then
  PanMessage(mt_Error,SysUtils.Format('Conversion error at line %d in file %s',[t.CurrentLine,t.GetFullName]));
end;

Procedure FileError(const s:string);
begin
 PanMessageFmt(mt_warning,'Error loading file: %s at line %d',[f,t.curLine]);
end;

Function ReadInt(const s:string):Integer;
begin
 if not ValInt(s,Result) then
  PanMessage(mt_Error,Format('Invalid integer at line %d in file %s: %s',[t.CurrentLine,t.GetFullName,s]));
end;

Function ReadDouble(const s:string):Double;
begin
 if not ValDouble(s,Result) then
  PanMessage(mt_Error,Format('Invalid float at line %d in file %s: %s',[t.CurrentLine,t.GetFullName,s]));
end;

Function ReadDword(const s:string):Longint;
begin
 if not ValDword(s,Result) then
  PanMessage(mt_Error,Format('Invalid dword at line %d in file %s: %s',[t.CurrentLine,t.GetFullName,s]));
end;

Procedure LoadTriMesh(const s:string);
var i,j,nvx,nvxs,nsfs:integer; tmp,w:string;
    v:TJKVertex;
    sec:TJKSector;
    surf:TJKSurface;
    a,b,c:integer;
begin
if not SScanf(s,'%s vertices: %d faces: %d',[@tmp,@nvxs,@nsfs]) then exit;
 GetNextLine(tmp);
 getword(tmp,1,w);
 if w<>'vertex' then begin FileError('"Vertex List:" expected '+tmp+' found'); exit; end;


 sec:=NewSector;
 for i:=0 to nvxs-1 do
 begin
  GetNextLine(tmp);
  for j:=1 to length(tmp) do
   if tmp[j]=':' then tmp[j]:=' ';
   v:=sec.NewVertex;
   FScanf(tmp,'vertex %d x %f y %f z %f',[@nvx,@v.x,@v.y,@v.z]);
   if (i<>nvx) then FileError('Vertex '+IntToStr(nvx)+' expected '+tmp+' found');
 end;

 GetNextLine(tmp);
 getword(tmp,1,w);
 if w<>'face' then begin FileError('"Face List:" expected '+tmp+' found'); exit; end;

 i:=0;

 repeat
  if i>=nsfs then break;
  GetNextLine(tmp);
  getword(tmp,1,w);
  if w<>'face' then continue;
  for j:=1 to length(tmp) do
   if tmp[j]=':' then tmp[j]:=' ';

  FScanf(tmp,'face %d a %d b %d c %d',[@nvx,@a,@b,@c]);
  if (i<>nvx) then FileError('Face '+IntToStr(nvx)+' expected '+tmp+' found');
  inc(i);

  surf:=sec.newSurface;
  Surf.AddVertex(sec.vertices[a]);
  surf.AddVertex(sec.vertices[b]);
  surf.AddVertex(sec.vertices[c]);
  sec.surfaces.Add(surf);
 until t.eof;

 sectors.Add(sec);

 for i:=0 to sec.surfaces.count-1 do
  sec.surfaces[i].NewRecalcAll;

  Sec.Renumber;

end;

function IsVertex(const s:string):boolean;
var
w:string;
begin
  result:=false;
    getword(s,1,w);
if w<>'v' then begin
 //FileError('"Vertex List:" expected '+s+' found');
  exit; end
 else result:=true;

end;

function IsTVertex(const s:string):boolean;
var
w:string;
begin
  result:=false;
    getword(s,1,w);
if w<>'vt' then begin
 //FileError('"Texture Vertex List:" expected '+s+' found');
  exit; end
 else result:=true;

end;

function IsFace(const s:string):boolean;
var
w:string;
begin
  result:=false;
    getword(s,1,w);
if w<>'f' then
 begin
  exit;
  end
 else
 begin

  result:=true;
  end;

end;


Procedure LoadQuadMesh;
var i,j,nvx,nvxs,nsfs:integer; tmp,w:string;
    v:TJKVertex;
    sec:TJKSector;
    surf:TJKSurface;
    a,b,c:integer;
    VertsList:TStringList;
    GTXVXList:TList;
    txvx:TTempTXVertex;
    face_cnt:integer;
    buffer:string;
    List: TStrings;
     tv:TTempTXVertex;

     Function GetTXVX(n:integer):TTempTXVertex;
begin
 if (n<0) or (n>=GTXVXList.count) then result:=nil
 else result:=TTempTXVertex(GTXVXList[n]);
end;

begin

sec:=NewSector;
 ObjImportOptions.ShowModal;
//sec.Flags:=sec.Flags or SF_3DO;
GTXVXList:=TList.Create;

    repeat
  GetNextLine(tmp);

 While IsVertex(tmp) do
  begin
    v:=sec.NewVertex;
    FScanf(tmp,'v %f %f %f',[@v.x,@v.y,@v.z]);
   GetNextLine(tmp);
  end;

   While IsTVertex(tmp) do
  begin
  txvx:=TTempTXVertex.Create;
  SScanf(tmp,'vt %l %l',[@txvx.u,@txvx.v]);

  if (ObjImportOptions.CheckBox_InvertU.checked)
   then txvx.u:=-(txvx.u*ObjImportOptions.obj_tex_width)
   else txvx.u:=(txvx.u*ObjImportOptions.obj_tex_width);

   if (ObjImportOptions.CheckBox_InvertV.checked)
   then  txvx.v:=-(txvx.v*ObjImportOptions.obj_tex_height)
   else  txvx.v:=(txvx.v*ObjImportOptions.obj_tex_height);
  
  GTXVXList.Add(txvx);
  GetNextLine(tmp);
  end;

    While IsFace(tmp) do
  begin
  surf:=sec.newSurface;
   tmp:=copy(tmp,pos('f ',tmp)+2,length(tmp));
   trim(tmp);


  //face only has vertex info
   if (tmp <> '') and (pos('/',tmp) = 0)   then
           begin
            PanMessage(mt_warning,'Obj Import: Face has no texture vertices');

            tmp:=StringReplace(tmp, ' ', ',', [rfReplaceAll]);
            List := TStringList.Create;
            list.CommaText:=tmp;

            for i:=0 to list.count-1 do
                begin
                 a:=strtoint(list[i])-1;
                 Surf.AddVertex(sec.vertices[a]);
                end;


               sec.surfaces.Add(surf);
               surf.CalcNormal;
           end;

   //face  has vertex and normal info
   if (tmp <> '') and (pos('//',tmp) <> 0)   then
           begin
           PanMessage(mt_warning,'Obj Import: Unsupported Face');
           end;

  //face  has vertex and texture vertex info
   if (tmp <> '') and (pos('/',tmp) <> 0) and (pos('//',tmp) = 0)   then
           begin

           //  face_cnt:=  OccurrencesOfChar(tmp,'/');

            tmp:=StringReplace(tmp, ' ', ',', [rfReplaceAll]);
            List := TStringList.Create;
            list.CommaText:=tmp;

             for i:=0 to list.count-1 do
                begin
                //for faces with no normal vertex

                   buffer:=copy(list[i],1,pos('/',list[i])-1);  //read vertex
                
                a:=strtoint(buffer)-1;
                Surf.AddVertex(sec.vertices[a]);

                //for faces with no normal vertex
                if OccurrencesOfChar(list[i],'/') = 1  then
                  begin
                   buffer:=copy(list[i],pos('/',list[i])+1, length(list[i]) );  //read texture vertex
                   end;

                 //for faces with normal vertex
                if OccurrencesOfChar(list[i],'/') = 2  then
                  begin
                    buffer:=copy(list[i], pos('/',list[i])+1, length(list[i]));  //read past vertex
                    buffer:=copy(buffer,1,pos('/',buffer)-1);  //read texture vertex
                   end;

                buffer:=trim(buffer);
                b:=strtoint(buffer)-1;
                tv:=GetTXVX(b);

                 surf.TXVertices[i].u:=tv.u;
                 surf.TXVertices[i].v:=tv.v;   //was inverting here

                end;
            
            sec.surfaces.Add(surf);
           end;
   end;


 until t.eof;

 sectors.Add(sec);

 for i:=0 to sec.surfaces.count-1 do
 begin
 FlipSurface( sec.surfaces[i]);
 sec.surfaces[i].CalcNormal;
 FindUVScales(sec.surfaces[i]);
 end;


if not IsSectorConvex(sec) then
  begin
     for i:=0 to sec.surfaces.count-1 do
       begin
       FlipSurface( sec.surfaces[i]);
       end;
  end;


 //if IsTXFlipped(sec.surfaces[i]) then
 //    begin
      // PanMessage(mt_warning,'Obj Import: Face is inverted');
      //sec.Flags:=sec.Flags or SF_3DO;
      //sec.surfaces[i].surfFlags:=SetFlags(sec.surfaces[i].surfFlags,SFF_FLIP)
  //   end;

 //end;


 Sec.Renumber;

end;




Procedure FinishUp;
var th:TJKThing;
begin
 RenumSecs;
// th:=NewThing;
// Things.Add(th);
end;

const
     pi_steps=100;
var
     fsize,ppos:integer;


Procedure DO_Progress;
var pos:integer;
begin
 pos:=Trunc(t.fpos*pi_steps/fsize);
 While pos>ppos do
 begin
  inc(ppos);
  Progress.Step;
 end;
end;

var j:integer;

begin {TLevel.ImportObj}
 Try
 t:=TLECTextFile.CreateRead(OpenFileRead(F,0));
 //Clear;
 fsize:=t.fsize;
 ppos:=0;
 Progress.Reset(pi_steps);
 Progress.Msg:='Importing OBJ';
 Try
 Try
  While not t.eof do
  begin
  // GetNextLine(s);
  // p:=GetWord(s,1,w1); {w1 - first word, w2 - second}

   //if (w1='o') then
   //begin
    LoadQuadMesh;

    try
     DO_Progress;
     except
     on Exception do ;
     end;

    // end;

  end;

 Except
  On E:EConvertError do
   Raise Exception.CreateFmt('File %s: Error at line %d: %s',[F,t.CurrentLine,E.Message]);
 end;

 Finally
  Progress.hide;
  t.Fclose;
  FinishUp;
 // MasterCMP:='';
 end;

 Except
  On E:EInOutError do PanMessage(mt_error,E.Message+' '+F);
  On E:Exception do PanMessage(mt_error,E.Message);
 end;

end;
