unit U_SurfaceTools;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls,J_level,lev_utils,Jed_Main,misc_utils,geometry;

type
  TSurfaceTools = class(TForm)
    Label1: TLabel;
    Label3: TLabel;
    Info_Button: TButton;
    GroupBox1: TGroupBox;
    XCB: TCheckBox;
    YCB: TCheckBox;
    ZCB: TCheckBox;
    Edit3: TEdit;
    Edit1: TEdit;
    Scale_UpDown: TUpDown;
    Scale_ComboBox: TComboBox;
    Move_UpDown: TUpDown;
    Collapse_Button: TButton;
    Inset_Button: TButton;
    Inset_ComboBox: TComboBox;
    Extrude_Button: TButton;
    EDextrude: TEdit;
    Memo1: TMemo;
    procedure Extrude_ButtonClick(Sender: TObject);
    procedure Inset_ButtonClick(Sender: TObject);
    procedure Scale_UpDownClick(Sender: TObject; Button: TUDBtnType);
    procedure Collapse_ButtonClick(Sender: TObject);
    procedure Move_UpDownClick(Sender: TObject; Button: TUDBtnType);
    procedure Info_ButtonClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  SurfaceTools: TSurfaceTools;

implementation

{$R *.dfm}

procedure TSurfaceTools.Collapse_ButtonClick(Sender: TObject);
begin
 NJEDCollapseSurface(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF]);
end;

procedure TSurfaceTools.Extrude_ButtonClick(Sender: TObject);
begin
 ExtrudeSurface(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF],strtofloat(EDextrude.Text));
end;

procedure TSurfaceTools.Info_ButtonClick(Sender: TObject);
var
MVec:Tvector;
Nvec:TVector;
begin
 NJEDCalcSurfCenter(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF],MVec.x,MVec.y,MVec.z);
 Nvec:=level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].normal;
 PanMessage(mt_info,'Surface Center: '+Format('%.3f ',[Mvec.x])+Format('%.3f ',[Mvec.y])+Format('%.3f', [Mvec.z])
   +', Surface Normal: '+Format('%.3f ',[Nvec.x])+Format('%.3f ',[Nvec.y])+Format('%.3f',[Nvec.z])
   +', V: '+Format('%d',[level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF].Vertices.Count]));

end;

procedure TSurfaceTools.Inset_ButtonClick(Sender: TObject);
begin
 InsetSurface(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF], StrToFloat(inset_combobox.text), true,true,true);
end;

procedure TSurfaceTools.Move_UpDownClick(Sender: TObject; Button: TUDBtnType);
var
 Down:Boolean;
begin
 down:=true;

  case Button of
     btPrev:  down:=false;
  end;

  NJEDMoveSurface(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF], 0.1,down, true,true,true);
end;

procedure TSurfaceTools.Scale_UpDownClick(Sender: TObject; Button: TUDBtnType);
var
  Pos: double;
  scale_factor:double;
begin
 scale_factor:=StrToFloat(scale_combobox.text);

  case Button of
   btNext:  Pos :=1+scale_factor;
   btPrev:  Pos :=1-scale_factor;
 end;

 NJEDScaleSurface(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF], pos, true,true,true);
end;

end.
