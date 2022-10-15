unit U_SurfaceToolspas;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls;

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
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  SurfaceTools: TSurfaceTools;

implementation

{$R *.dfm}

end.
