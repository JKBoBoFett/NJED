unit Images;

interface
uses Windows,Graphics, SysUtils, Classes, MatPixels;

Type
    TStoredAs=(ByLines,ByCols,byLines16,bylines24,bylines32);
    TImageInfo=class
      StoredAs:TStoredAs;
      width,height:word;
    end;

TImageSource=class
Protected
 FInfo:TImageInfo;
Public
 Pal:Array[0..255] of TRGBQuad;
 Property Info:TImageInfo read FInfo;
 Function GetPix16:TPix16;virtual;   // 16 bit pixel layout (565 unless a descendant knows better)
 Function GetTransIndex:Integer;virtual;   // 8 bit: palette index that is transparent, -1 = none
 Function IsEmissive16:Boolean;virtual;   // 16 bit, flag 2: alpha is a glow mask
 Function LoadBitmap(bw,bh:Integer):TBitmap;
 procedure GetLine(var buf);virtual;abstract;
 Procedure GetCol(var buf);virtual;abstract;
Protected
 Constructor Create;
 Destructor Destroy;override;
Private
 Function LoadByLines(w,h:Integer):TBitmap;
 Function LoadByCols(w,h:Integer):TBitmap;
 Procedure WriteHeader(f:TStream);
 Function LoadByLines16(w,h:Integer):TBitmap;
 Function LoadByLines16Alpha(w,h:Integer):TBitmap;
 Function LoadByLinesTrans(w,h:Integer):TBitmap;
 Function LoadByLines24(w,h:Integer):TBitmap;
 Function LoadByLines32(w,h:Integer):TBitmap;
 Procedure Dest;
end;

implementation

Constructor TImageSource.Create;
begin
 Finfo:=TImageInfo.Create;
end;

Procedure TImageSource.Dest;
begin
 FInfo.Free;
end;

Destructor TImageSource.Destroy;
begin
 Dest;
end;

Function TImageSource.LoadBitmap(bw,bh:Integer):TBitmap;
begin
 if (bw=-1) then bw:=Info.Width;
 if (bh=-1) then bh:=Info.Height;
 case Info.StoredAs of
  byLines: if GetTransIndex>=0 then Result:=LoadByLinesTrans(bw,bh) else Result:=LoadByLines(bw,bh);
   byCols: Result:=LoadByCols(bw,bh);
  byLines16: Result:=LoadByLines16(bw,bh);
  byLines24: Result:=LoadByLines24(bw,bh);
  byLines32: Result:=LoadByLines32(bw,bh);
 end;
end;

Procedure TImageSource.WriteHeader(f:TStream);
var
   Bi:TBitmapInfoHeader;
   Bfh:TBitmapFileHeader;
   bw,bh,bw4:Integer;
begin
 bw:=Info.Width;
 bh:=Info.Height;
 if bw and 3=0 then bw4:=bw else bw4:=bw and $FFFFFFFC+4;

 With Bfh do
 begin
  bfType:=$4D42; {'BM'}
  bfOffBits:=sizeof(bfh)+sizeof(bi)+sizeof(TRGBQuad)*256;
  bfReserved1:=0;
  bfReserved2:=0;
  bfSize:=bfOffBits+bh*bw4;
 end;

FillChar(Bi,Sizeof(bi),0);

 With BI do
 begin
  biSize:=sizeof(BI);
  biWidth:=bw;
  biHeight:=bh;
  biPlanes:=1;
  biBitCount:=8;
end;
f.Write(bfh,sizeof(bfh));
f.Write(bi,sizeof(bi));
f.Write(Pal,sizeof(Pal));
end;

Function TImageSource.LoadByLines(w,h:Integer):TBitmap;
var
   i:Integer;
   Ms:TMemoryStream;
   pLine:Pchar;
   pos:Longint;
   bw,bh,bw4:Integer;
begin
Result:=nil;
bw:=Info.Width;
bh:=Info.Height;
if bw and 3=0 then bw4:=bw else bw4:=bw and $FFFFFFFC+4;
GetMem(Pline,bw4);

ms:=TMemoryStream.Create;
WriteHeader(ms);
 Try
  Pos:=ms.Position;
  for i:=Bh-1 downto 0 do
  begin
   GetLine(Pline^);
   ms.Position:=Pos+i*bw4;
   ms.Write(PLine^,bw4);
  end;
  ms.Position:=0;
  Result:=TBitmap.Create;
  Result.LoadFromStream(ms);
  Ms.Free;

 finally
  FreeMem(pLine);
 end;
end;

Function TImageSource.LoadByCols(w,h:Integer):TBitmap;
Const HeaderSize=sizeof(TBitmapInfoHeader)+sizeof(TBitmapFileHeader)+256*sizeof(TRGBQuad);
var
   i,j:Integer;
   Ms:TMemoryStream;
   pCol,pc:Pchar;
   pos:Longint;
   bw,bh,bw4:Integer;
   pbits,pb:pchar;
begin
Result:=nil;
bw:=Info.Width;
bh:=Info.Height;
if bw and 3=0 then bw4:=bw else bw4:=bw and $FFFFFFFC+4;
GetMem(PCol,bh);
ms:=TMemoryStream.Create;
ms.SetSize(HeaderSize+bw4*bh);
WriteHeader(ms);
 Try
  Pos:=ms.Position;
  pBits:=ms.Memory;
  pBits:=PBits+Pos;
  for i:=0 to bw-1 do
  begin
   GetCol(PCol^);
   pc:=pCol;
   pb:=PBits+i;
   for j:=0 to bh-1 do
   begin
    PB^:=pc^; inc(pc); inc(pb,bw4);
   end;
  end;
  ms.Position:=0;
  Result:=TBitmap.Create;
  Result.LoadFromStream(ms);
  Ms.Free;

 finally
  FreeMem(PCol);
 end;
end;

Function TImageSource.LoadByLines16(w,h:Integer):TBitmap;
type TRGB=array[1..3] of longint;
var
   i:Integer;
   pLine:PANSIchar;     //NJED 08-FEB-2025 changed to ANSI
   bw,bh,bw4:Integer;
   hbm:HBITMAP;
   bits:pointer;
   pbi:^TBITMAPINFO;
   rgb:^TRGB;

begin
Result:=nil;

if GetPix16<>px565 then      // ARGB4444 / ARGB1555 / RGBA4444 / RGBA5551
begin
 Result:=LoadByLines16Alpha(w,h);
 exit;
end;

bw:=Info.Width;
bh:=Info.Height;
if bw*2 and 3=0 then bw4:=bw*2 else bw4:=bw*2 and $FFFFFFFC+4;

GetMem(pbi,sizeof(TBITMAPINFOHEADER)+12);
FillChar(pBi^,sizeof(TBITMAPINFOHEADER)+12,0);

 With pbi^.bmiHeader do
 begin
  biSize:=sizeof(TBITMAPINFOHEADER);
  biWidth:=bw;
  biHeight:=bh;
  biPlanes:=1;
  biBitCount:=16;
  biCompression:=BI_BITFIELDS;
  biSizeImage:=bh*bw4;
end;
 rgb:=@pbi^.bmiColors;
 rgb^[3]:=$1F;
 rgb^[2]:=$7E0;
 rgb^[1]:=$F800;

Result:=TBitmap.Create;

hbm:=CreateDIBSection(Result.Canvas.Handle,pbi^,DIB_RGB_COLORS,bits,0,0);

 Try
  for i:=Bh-1 downto 0 do
  begin
   pline:=pANSIchar(bits)+i*bw4;
   GetLine(Pline^);
  end;
  result.Handle:=hbm;
 finally
  FreeMem(pbi);
 end;
end;

Function TImageSource.GetPix16:TPix16;
begin
 Result:=px565;
end;

Function TImageSource.GetTransIndex:Integer;
begin
 Result:=-1;
end;

Function TImageSource.IsEmissive16:Boolean;
begin
 Result:=false;
end;

// 8 bit image with a transparent palette index. Drawn as 24 bit over a light/dark
// checkerboard so the transparent pixels can be seen in the 2D previews and thumbnails.
Function TImageSource.LoadByLinesTrans(w,h:Integer):TBitmap;
type
  TRGBTripleArray = array[0..65535] of TRGBTriple;
  pRGBTripleArray = ^TRGBTripleArray;
var
   x,y,bw,bh,ti:Integer;
   line:array of Byte;
   row:pRGBTripleArray;
   p:Byte;
begin
 bw:=Info.Width;
 bh:=Info.Height;
 ti:=GetTransIndex;
 SetLength(line,bw+4);
 Result:=TBitmap.Create;
 Result.PixelFormat:=pf24bit;
 Result.Width:=bw;
 Result.Height:=bh;
 for y:=0 to bh-1 do      // file line 0 is the top line
 begin
  GetLine(line[0]);
  row:=Result.ScanLine[y];
  for x:=0 to bw-1 do
  begin
   p:=line[x];
   if p=ti then
   begin
    if ((x div 8)+(y div 8)) and 1=0 then p:=204 else p:=153;
    row^[x].rgbtRed:=p;
    row^[x].rgbtGreen:=p;
    row^[x].rgbtBlue:=p;
   end
   else
   begin
    row^[x].rgbtRed:=Pal[p].rgbRed;
    row^[x].rgbtGreen:=Pal[p].rgbGreen;
    row^[x].rgbtBlue:=Pal[p].rgbBlue;
   end;
  end;
 end;
end;

// 16 bit formats with alpha. Drawn over a light/dark checkerboard so the
// transparency can be seen in the 2D previews and thumbnails.
Function TImageSource.LoadByLines16Alpha(w,h:Integer):TBitmap;
type
  TRGBTripleArray = array[0..65535] of TRGBTriple;
  pRGBTripleArray = ^TRGBTripleArray;
var
   x,y,bw,bh,bg:Integer;
   emis:Boolean;
   fmt:TPix16;
   line:array of Word;
   row:pRGBTripleArray;
   c:TRGBA8;
begin
 bw:=Info.Width;
 bh:=Info.Height;
 fmt:=GetPix16;
 emis:=IsEmissive16;
 SetLength(line,bw);
 Result:=TBitmap.Create;
 Result.PixelFormat:=pf24bit;
 Result.Width:=bw;
 Result.Height:=bh;
 for y:=0 to bh-1 do
 begin
  GetLine(line[0]);
  row:=Result.ScanLine[y];
  for x:=0 to bw-1 do
  begin
   c:=DecodePix16(line[x],fmt);
   if emis then
   begin
    // alpha is a glow mask, not transparency: show the texture as it looks in the dark
    // (30% base light, glowing parts at full brightness)
    bg:=77+(c.a*178) div 255;
    row^[x].rgbtRed:=(c.r*bg) div 255;
    row^[x].rgbtGreen:=(c.g*bg) div 255;
    row^[x].rgbtBlue:=(c.b*bg) div 255;
   end
   else
   begin
    if ((x div 8)+(y div 8)) and 1=0 then bg:=204 else bg:=153;
    row^[x].rgbtRed:=(c.r*c.a+bg*(255-c.a)) div 255;
    row^[x].rgbtGreen:=(c.g*c.a+bg*(255-c.a)) div 255;
    row^[x].rgbtBlue:=(c.b*c.a+bg*(255-c.a)) div 255;
   end;
  end;
 end;
end;

Function TImageSource.LoadByLines24(w,h:Integer):TBitmap;
const
  PixelCountMax = 65536;  // 2048 MAX WIDTH
type
  TRGBTripleArray = array[0..PixelCountMax - 1] of TRGBTriple;
  pRGBTripleArray = ^TRGBTripleArray;
type TRGB=array[1..3] of longint;
var
   i:Integer;
   pLine:Pchar;
   bw,bh,bw4:Integer;
   hbm:HBITMAP;
   bits:pointer;
   pbi:^TBITMAPINFO;
   rgb:^TRGB;
   RGBTripleLineArray: pRGBTripleArray;

begin
Result:=nil;

bw:=Info.Width;
bh:=Info.Height;
if bw*3 and 3=0 then bw4:=bw*3 else bw4:=bw*3 and $FFFFFFFC+4;

GetMem(pbi,sizeof(TBITMAPINFOHEADER)+12);
FillChar(pBi^,sizeof(TBITMAPINFOHEADER)+12,0);

 With pbi^.bmiHeader do
 begin
  biSize:=sizeof(TBITMAPINFOHEADER);
  biWidth:=bw;
  biHeight:=bh;
  biPlanes:=1;
  biBitCount:=16;
  biCompression:=BI_BITFIELDS;
  biSizeImage:=bh*bw4;
end;
 rgb:=@pbi^.bmiColors;
 rgb^[3]:=$FF;    //blue mask
 rgb^[2]:=$FF00;   // green mask
 rgb^[1]:=$FF0000;  // red mask

Result:=TBitmap.Create;
result.pixelformat:=pf24bit;
result.Width:=bw;
result.Height:=bh;

//hbm:=CreateDIBSection(Result.Canvas.Handle,pbi^,DIB_RGB_COLORS,bits,0,0);

 Try
  for i:=Bh-1 downto 0 do
  begin
  RGBTripleLineArray:= result.ScanLine[i];
  GetLine(RGBTripleLineArray^);
  end;
 // result.Handle:=hbm;
  //result.pixelformat:=pf16bit;
 finally
  FreeMem(pbi);
 end;
end;

Function TImageSource.LoadByLines32(w,h:Integer):TBitmap;
const
  PixelCountMax = 65536;  // 2048 MAX WIDTH
type
  TRGBQuadArray = array[0..PixelCountMax - 1] of TRGBQuad;
  pRGBQuadArray = ^TRGBQuadArray;
var
   i:Integer;
   RGBQuadLineArray: pRGBQuadArray;

begin
Result:=nil;

Result:=TBitmap.Create;
result.pixelformat:=pf32bit;
result.Width:=w;
result.Height:=h;

  for i:=h-1 downto 0 do
  begin
  RGBQuadLineArray:= result.ScanLine[i];
  GetLine(RGBQuadLineArray^);
  end;

end;



end.
