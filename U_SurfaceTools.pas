unit U_SurfaceTools;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,J_level,lev_utils,Jed_Main;

type
  TSurfaceTools = class(TForm)
    Memo1: TMemo;
    Info_Button: TButton;
    GroupBox1: TGroupBox;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    Edit3: TEdit;
    Edit1: TEdit;
    Label1: TLabel;
    Scale_UpDown: TUpDown;
    Scale_ComboBox: TComboBox;
    Label3: TLabel;
    Move_UpDown: TUpDown;
    Collapse_Button: TButton;
    Inset_Button: TButton;
    Inset_ComboBox: TComboBox;
    Extrude_Button: TButton;
    EDextrude: TEdit;
    procedure Extrude_ButtonClick(Sender: TObject);
    procedure Inset_ButtonClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  SurfaceTools: TSurfaceTools;

implementation

{$R *.dfm}

procedure TSurfaceTools.Extrude_ButtonClick(Sender: TObject);
begin
  ExtrudeSurface(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF],strtofloat(EDextrude.Text));
end;

procedure TSurfaceTools.Inset_ButtonClick(Sender: TObject);
begin
  InsetSurface(level.Sectors[JedMain.Cur_SC].surfaces[JedMain.Cur_SF], 0.5, true,true,true);
end;

end.
