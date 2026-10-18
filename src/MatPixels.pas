unit MatPixels;
{ 16-bit MAT pixel formats (JK / Indiana Jones style) - NJED
  Added for ARGB4444 / ARGB1555 / RGBA4444 / RGBA5551 support.

  How the formats are told apart (matches what the game engines do):
   - Indy style: no transparency flag, the header's alpha_bpp / alpha_shift describe the pixel.
        alpha_bpp=4, 4/4/4 colour bits : 4444.  alpha_shift=0 -> RGBA (R12 G8 B4 A0)
                                                 alpha_shift=12 -> ARGB (A12 R8 G4 B0)
        alpha_bpp=1, 5/5/5 colour bits : alpha_shift=0 -> RGBA5551 (R11 G6 B1 A0)
                                         else           -> ARGB1555 (A15 R10 G5 B0)
   - Stock JK: the per-texture 'transparent' flag (TTextureData.Pad[0]) selects ARGB1555,
     the header colour / alpha fields are ignored by the engine.
   - Anything else is RGB565 (what NJED always assumed before). }

interface

type
  TPix16 = (px565, px1555, px5551, px4444ARGB, px4444RGBA);

  TRGBA8 = record
    r, g, b, a: Byte;
  end;

{ rBits,gBits,bBits : header colour bit counts
  aBpp,aShift       : header alpha_bpp and alpha_sh
  transFlag         : texture header 'transparent' flag (TTextureData.Pad[0]) }
function DetectPix16(rBits, gBits, bBits, aBpp, aShift, transFlag: Longint): TPix16;

function Pix16HasAlpha(f: TPix16): Boolean;
function Pix16AlphaBits(f: TPix16): Integer;   { 0, 1 or 4 }
{ True for the 16 bit emissive mode: texture flag 2 and a format that has alpha.
  The alpha channel is then a glow mask and the surface is opaque (OpenJKDF2). }
function IsEmissive16(f: TPix16; transFlag: Longint): Boolean;
{ 8 bit: glow colour of a palette colour taken from the darkest row of the CMP light table.
  Same maths as OpenJKDF2's shader (colour * 0.85 * luminance * 0.5), times GlowGain8. }
function Glow8(r, g, b: Integer): TRGBA8;
function DecodePix16(v: Word; f: TPix16): TRGBA8;

const
  GlowGain8 = 2.0;   { stand-in for the bloom the game adds on top }

var
  PreviewGlow: Boolean = True;   { set False to switch the 3D glow pass off }
  PreviewUntextured: Boolean = False;   { 3D preview menu: draw surfaces without their textures (lit, flat) }
  PreviewForceGeo3: Boolean = False;    { 3D preview menu: draw every surface as geo mode 3 (the mat's solid colour) }

implementation

function DetectPix16(rBits, gBits, bBits, aBpp, aShift, transFlag: Longint): TPix16;
begin
  if (aBpp = 4) and (rBits = 4) and (gBits = 4) and (bBits = 4) then
  begin
    if aShift = 0 then Result := px4444RGBA else Result := px4444ARGB;
  end
  else if (aBpp = 1) and (rBits = 5) and (gBits = 5) and (bBits = 5) then
  begin
    if aShift = 0 then Result := px5551 else Result := px1555;
  end
  else if (transFlag and 1) <> 0 then     { the game only tests bit 0 for transparency }
    Result := px1555
  else
    Result := px565;
end;

function Pix16HasAlpha(f: TPix16): Boolean;
begin
  Result := f <> px565;
end;

function IsEmissive16(f: TPix16; transFlag: Longint): Boolean;
begin
  Result := (transFlag = 2) and Pix16HasAlpha(f);
end;

function Glow8(r, g, b: Integer): TRGBA8;
var
  l, k: Double;

  function Cl(v: Double): Byte;
  begin
    if v < 0 then Result := 0
    else if v > 255 then Result := 255
    else Result := Round(v);
  end;

begin
  l := (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  k := 0.85 * (l * 0.5) * GlowGain8;
  Result.r := Cl(r * k);
  Result.g := Cl(g * k);
  Result.b := Cl(b * k);
  Result.a := 255;
end;

function Pix16AlphaBits(f: TPix16): Integer;
begin
  case f of
    px1555, px5551: Result := 1;
    px4444ARGB, px4444RGBA: Result := 4;
  else
    Result := 0;
  end;
end;

function E5(x: Integer): Byte;
begin
  Result := (x * 527 + 23) shr 6;
end;

function E6(x: Integer): Byte;
begin
  Result := (x * 259 + 33) shr 6;
end;

function DecodePix16(v: Word; f: TPix16): TRGBA8;
begin
  case f of
    px1555:
      begin
        Result.a := (v shr 15) * 255;
        Result.r := E5((v shr 10) and $1F);
        Result.g := E5((v shr 5) and $1F);
        Result.b := E5(v and $1F);
      end;
    px5551:
      begin
        Result.r := E5(v shr 11);
        Result.g := E5((v shr 6) and $1F);
        Result.b := E5((v shr 1) and $1F);
        Result.a := (v and 1) * 255;
      end;
    px4444ARGB:
      begin
        Result.a := (v shr 12) * 17;
        Result.r := ((v shr 8) and $F) * 17;
        Result.g := ((v shr 4) and $F) * 17;
        Result.b := (v and $F) * 17;
      end;
    px4444RGBA:
      begin
        Result.r := (v shr 12) * 17;
        Result.g := ((v shr 8) and $F) * 17;
        Result.b := ((v shr 4) and $F) * 17;
        Result.a := (v and $F) * 17;
      end;
  else { px565 }
    Result.r := E5(v shr 11);
    Result.g := E6((v shr 5) and $3F);
    Result.b := E5(v and $1F);
    Result.a := 255;
  end;
end;

end.
