unit OBJ_export;
{ Wavefront OBJ exporter for NJED.
  - Faces keep their original vertex count (quads stay quads, n-gons stay n-gons).
  - Optional UVs, normalised to 0..1 using the material's pixel size.
  - 'usemtl' with the surface's material name, plus an optional .mtl file.
  - Whole level, or only the selected sectors. }

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, J_Level;

type
  TObjExport = class(TForm)
    Button1: TButton;
    Button2: TButton;
    GroupBox1: TGroupBox;
    CheckBox1: TCheckBox;          { export UVs }
    CheckBoxMtl: TCheckBox;        { write .mtl file }
    CheckBoxSel: TCheckBox;        { selected sectors only }
    CheckBoxSkipAdj: TCheckBox;    { skip adjoined surfaces }
    CheckBoxYUp: TCheckBox;        { swap Y/Z }
    CheckBoxInvU: TCheckBox;
    CheckBoxInvV: TCheckBox;
    CheckBoxTri: TCheckBox;        { triangulate faces }
    SaveDialog1: TSaveDialog;
    procedure Button1Click(Sender: TObject);
  private
    FSel: TArray<Integer>;
  public
    { Sector indexes that count as "selected" for the selected-only option }
    procedure SetSelection(const Sectors: TArray<Integer>);
  end;

var
  ObjExport: TObjExport;

implementation

uses System.Generics.Collections, Geometry, Files, FileOperations, graph_files, misc_utils;

{$R *.dfm}

procedure TObjExport.SetSelection(const Sectors: TArray<Integer>);
begin
  FSel := Sectors;
end;

function SafeMatName(const s: string): string;
begin
  Result := Trim(s);
  Result := StringReplace(Result, ' ', '_', [rfReplaceAll]);
end;

procedure TObjExport.Button1Click(Sender: TObject);
var
  fs: TFormatSettings;
  sl, mtl: TStringList;
  texSizes: TDictionary<string, TPoint>;
  uvIndex: TDictionary<string, Integer>;
  vxIndex: TDictionary<TObject, Integer>;
  usedMats: TStringList;
  secIdx: TArray<Integer>;
  si, i, j, n, vi, vtTotal, vxTotal: Integer;
  nSec, nFace, nQuad, nTri, nNgon, nSkipped: Integer;
  sec: TJKSector;
  surf: TJKSurface;
  curMat, mname, fline, key, us, vs: string;
  withUV, yUp: Boolean;
  tsz: TPoint;
  uvi, ov, ou: array of Integer;
  k: Integer;
  fname, mtlName: string;
  vx: TJKVertex;
  tv: TTXVertex;
  u, v: Double;

  function F(x: Double): string;
  begin
    Result := FormatFloat('0.######', x, fs);
  end;

  function GetTexSize(const matname: string): TPoint;
  var
    fl: TFile;
    mat: TMAT;
    k: string;
  begin
    k := LowerCase(matname);
    if texSizes.TryGetValue(k, Result) then Exit;
    Result := Point(64, 64);
    try
      fl := OpenGameFile(matname);
      if fl = nil then
        PanMessage(mt_warning, 'OBJ export: material not found, assuming 64x64: ' + matname)
      else
      begin
        mat := TMAT.Create(fl, 0);   { mat now owns the file }
        try
          Result.X := mat.Info.width;
          Result.Y := mat.Info.height;
        finally
          mat.Free;
        end;
      end;
    except
      on Exception do
        PanMessage(mt_warning, 'OBJ export: cannot read material, assuming 64x64: ' + matname);
    end;
    if Result.X <= 0 then Result.X := 64;
    if Result.Y <= 0 then Result.Y := 64;
    texSizes.Add(k, Result);
  end;

  function Corner(idx: Integer): string;
  begin
    if ou[idx] > 0 then
      Result := IntToStr(ov[idx]) + '/' + IntToStr(ou[idx])
    else
      Result := IntToStr(ov[idx]);
  end;

  function GetVT(pu, pv: Double): Integer;
  var k: string;
  begin
    us := F(pu);
    vs := F(pv);
    k := us + ' ' + vs;
    if not uvIndex.TryGetValue(k, Result) then
    begin
      Inc(vtTotal);
      Result := vtTotal;
      uvIndex.Add(k, Result);
      sl.Add('vt ' + us + ' ' + vs);
    end;
  end;

begin
  if not SaveDialog1.Execute then Exit;
  fname := SaveDialog1.FileName;
  if ExtractFileExt(fname) = '' then fname := fname + '.obj';

  fs := TFormatSettings.Create('en-US');
  withUV := CheckBox1.Checked;
  yUp := CheckBoxYUp.Checked;

  { which sectors }
  if CheckBoxSel.Checked then
    secIdx := FSel
  else
  begin
    SetLength(secIdx, Level.Sectors.Count);
    for i := 0 to High(secIdx) do secIdx[i] := i;
  end;

  sl := TStringList.Create;
  mtl := TStringList.Create;
  usedMats := TStringList.Create;
  texSizes := TDictionary<string, TPoint>.Create;
  uvIndex := TDictionary<string, Integer>.Create;
  vxIndex := TDictionary<TObject, Integer>.Create;
  try
    sl.LineBreak := #10;
    mtl.LineBreak := #10;
    usedMats.CaseSensitive := False;
    usedMats.Sorted := True;
    usedMats.Duplicates := dupIgnore;

    mtlName := ChangeFileExt(fname, '.mtl');

    sl.Add('# Exported from NJED');
    if CheckBoxMtl.Checked then sl.Add('mtllib ' + ExtractFileName(mtlName));

    vtTotal := 0; vxTotal := 0;
    nSec := 0; nFace := 0; nQuad := 0; nTri := 0; nNgon := 0; nSkipped := 0;
    curMat := #0;

    for si := 0 to High(secIdx) do
    begin
      if (secIdx[si] < 0) or (secIdx[si] >= Level.Sectors.Count) then Continue;
      sec := Level.Sectors[secIdx[si]];
      Inc(nSec);

      sl.Add('g sector_' + IntToStr(secIdx[si]));

      { vertices of this sector (indices are global and 1-based) }
      vxIndex.Clear;
      for i := 0 to sec.vertices.Count - 1 do
      begin
        vx := sec.vertices[i];
        Inc(vxTotal);
        vxIndex.AddOrSetValue(vx, vxTotal);
        if yUp then
          sl.Add('v ' + F(vx.x) + ' ' + F(vx.z) + ' ' + F(-vx.y))
        else
          sl.Add('v ' + F(vx.x) + ' ' + F(vx.y) + ' ' + F(vx.z));
      end;

      { faces }
      for i := 0 to sec.surfaces.Count - 1 do
      begin
        surf := sec.surfaces[i];
        n := surf.Vertices.Count;
        if n < 3 then begin Inc(nSkipped); Continue; end;
        if CheckBoxSkipAdj.Checked and (surf.Adjoin <> nil) then Continue;

        mname := SafeMatName(surf.Material);
        if (mname <> '') and (mname <> curMat) then
        begin
          sl.Add('usemtl ' + mname);
          usedMats.Add(mname);
          curMat := mname;
        end;

        { UVs - same order as the face vertices below }
        SetLength(uvi, n);
        if withUV and (surf.TXVertices.Count >= n) then
        begin
          tsz := GetTexSize(surf.Material);
          for j := n - 1 downto 0 do
          begin
            tv := surf.TXVertices[j];
            u := tv.u / tsz.X;
            v := tv.v / tsz.Y;
            if CheckBoxInvU.Checked then u := -u;
            if CheckBoxInvV.Checked then v := -v;
            uvi[j] := GetVT(u, v);
          end;
        end
        else
          for j := 0 to n - 1 do uvi[j] := 0;

        { JK winding is the reverse of OBJ winding (same as the importer) }
        SetLength(ov, n);
        SetLength(ou, n);
        k := 0;
        for j := n - 1 downto 0 do
          if vxIndex.TryGetValue(surf.Vertices[j], vi) then
          begin
            ov[k] := vi;
            ou[k] := uvi[j];
            Inc(k);
          end;
        if k < 3 then begin Inc(nSkipped); Continue; end;

        if CheckBoxTri.Checked and (k > 3) then
        begin
          { fan triangulation }
          for j := 1 to k - 2 do
          begin
            sl.Add('f ' + Corner(0) + ' ' + Corner(j) + ' ' + Corner(j + 1));
            Inc(nFace);
            Inc(nTri);
          end;
        end
        else
        begin
          fline := 'f';
          for j := 0 to k - 1 do fline := fline + ' ' + Corner(j);
          sl.Add(fline);
          Inc(nFace);
          case k of
            3: Inc(nTri);
            4: Inc(nQuad);
          else Inc(nNgon);
          end;
        end;
      end;
    end;

    sl.SaveToFile(fname, TEncoding.ASCII);

    if CheckBoxMtl.Checked then
    begin
      mtl.Add('# Exported from NJED');
      for i := 0 to usedMats.Count - 1 do
      begin
        mtl.Add('newmtl ' + usedMats[i]);
        mtl.Add('Kd 1.0 1.0 1.0');
        mtl.Add('');
      end;
      mtl.SaveToFile(mtlName, TEncoding.ASCII);
    end;

    ShowMessage(Format('Exported %d sector(s): %d faces (%d quads, %d triangles, %d n-gons), %d vertices, %d materials.',
      [nSec, nFace, nQuad, nTri, nNgon, vxTotal, usedMats.Count]));
    ModalResult := mrOk;
  finally
    vxIndex.Free;
    uvIndex.Free;
    texSizes.Free;
    usedMats.Free;
    mtl.Free;
    sl.Free;
  end;
end;

end.
