unit U_SurfaceTools;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls,J_level,lev_utils,Jed_Main;

type
  TSurfaceTools = class(TForm)
    Label1: TLabel;
    Label3: TLabel;
    Memo1: TMemo;
    Info_Button: TButton;
    GroupBox1: TGroupBox;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
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
begin
  PanMessage(mt_info,'Sectors unadjoined');
end;

procedure TSurfaceTools.Inset_ButtonClick(Sender: TObject);
begin
 InsetSurface(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF], 0.5, true,true,true);
end;

procedure TSurfaceTools.Move_UpDownClick(Sender: TObject; Button: TUDBtnType);
var
 Down:Boolean;
begin
 down:=False;

  case Button of
     btPrev:  down:=true;
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
