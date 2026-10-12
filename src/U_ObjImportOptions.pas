unit U_ObjImportOptions;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TobjImportOptions = class(TForm)
    B_Done: TButton;
    GroupBox_TextureSize: TGroupBox;
    Edit_Height: TEdit;
    Edit_Width: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    CheckBox_InvertU: TCheckBox;
    CheckBox_InvertV: TCheckBox;
    procedure B_DoneClick(Sender: TObject);
    procedure Edit_WidthKeyPress(Sender: TObject; var Key: Char);
    procedure Edit_HeightKeyPress(Sender: TObject; var Key: Char);

    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    obj_tex_width:integer;
    obj_tex_height:integer;
  end;

var
  objImportOptions: TobjImportOptions;

implementation

{$R *.dfm}

procedure TobjImportOptions.B_DoneClick(Sender: TObject);
begin

   if strtoint(Edit_Width.Text) <32 then  Edit_Width.Text:='32';
   if strtoint(Edit_Height.Text) <32 then  Edit_Height.Text:='32';

   obj_tex_width:=strtoint(Edit_Width.Text);
   obj_tex_height:=strtoint(Edit_Height.Text);
   self.Close;
end;

procedure TobjImportOptions.Edit_HeightKeyPress(Sender: TObject; var Key: Char);
begin
// 8=Bakspace; 48-57=0..9
if (Ord(Key)<>8) and (Ord(Key)<>7) then
if (Ord(Key)<48) or (Ord(Key)>57) then
key:=#0;
end;

procedure TobjImportOptions.Edit_WidthKeyPress(Sender: TObject; var Key: Char);
begin
  // 8=Bakspace; 48-57=0..9
if (Ord(Key)<>8) and (Ord(Key)<>7) then
if (Ord(Key)<48) or (Ord(Key)>57) then
key:=#0;
end;



procedure TobjImportOptions.FormShow(Sender: TObject);
begin
   obj_tex_width:=32;
   obj_tex_height:=32;
end;

end.
