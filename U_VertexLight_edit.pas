unit U_VertexLight_edit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Grids, ExtCtrls, u_undo, render,Jed_Main,J_Level,Geometry,misc_utils;

type
  TVertexLight = class(TForm)
    Panel1: TPanel;
    SGValues: TStringGrid;
    BNSet: TButton;
    CBVertex0_Master: TCheckBox;
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure BNSetClick(Sender: TObject);
    procedure SGValuesSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
  private
    { Private declarations }
  public
    { Public declarations }
    Procedure LoadSurface();
  end;

var
  VertexLight: TVertexLight;
  undocnt: Integer;

implementation

{$R *.dfm}

procedure TVertexLight.BNSetClick(Sender: TObject);
 var
 i:integer;
 txv:TTXVertex;
begin

 // StartUndoRec('Change surface Vertex Intensity '+undocnt.ToString);
 // JedMain.SaveSelSurfUndo('Change surface Vertex Intensity '+undocnt.ToString,ch_changed,sc_geo);
  undocnt:=undocnt+1;

   if CBVertex0_Master.Checked then
    begin
      for i:=1 to SGValues.RowCount-1 do
      begin
        SGValues.Cells[1,i] := SGValues.Cells[1,0];
      end;
    end;


   for i:=0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.Count-1 do
  With level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices[i] do
  begin
  txv:= level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.GetItem(i);
  txv.Intensity:= strtofloat(SGValues.Cells[1,i]);

  if txv.Intensity > 5 then txv.Intensity:=5;   // JKSpecs state max is 1, but some JKlevels are set as 5 and default JED value is 5
  if txv.Intensity < 0 then txv.Intensity:=0;
  SGValues.Cells[1,i]:= Sprintf('%.4f',[txv.Intensity]);

  level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.Items[i]:=txv;
  end;

  JedMain.SectorChanged(level.Sectors[JedMain.Cur_SC]);

end;

procedure TVertexLight.FormClose(Sender: TObject; var Action: TCloseAction);
begin
 JedMain.SelectedSurfaceVertex:=0;
 JedMain.SurfaceVertexLightMode:=false;
 JedMain.redraw;
end;

procedure TVertexLight.FormCreate(Sender: TObject);
begin
 JedMain.SelectedSurfaceVertex:=0;
 JedMain.SurfaceVertexLightMode:=false;
end;

procedure TVertexLight.FormShow(Sender: TObject);
begin
 JedMain.SelectedSurfaceVertex:=0;
 JedMain.SurfaceVertexLightMode:=true;
 JedMain.redraw;
 undocnt:=0;
end;

Procedure TVertexLight.LoadSurface();
var
 i:integer;
begin

  SGValues.RowCount:=level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.Count;

   for i:=0 to level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices.Count-1 do
  With level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].TXVertices[i] do
  begin

  SGValues.Cells[0,i]:='Vertex '+inttostr(i);
  SGValues.Cells[1,i]:= Sprintf('%.4f',[Intensity]);

  end;


end;

procedure TVertexLight.SGValuesSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
 JedMain.SelectedSurfaceVertex:=Arow;
 JedMain.ReDraw;
end;

end.
