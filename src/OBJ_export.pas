unit OBJ_export;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,J_Level;

type
  TObjExport = class(TForm)
    Button1: TButton;
    GroupBox1: TGroupBox;
    CheckBox1: TCheckBox;
    SaveDialog1: TSaveDialog;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ObjExport: TObjExport;

implementation

{$R *.dfm}

procedure TObjExport.Button1Click(Sender: TObject);
Var
OutFile : TextFile;
numsectors,i,n: integer;
begin
      if savedialog1.Execute then
    begin
AssignFile(OutFile,savedialog1.FileName);
  Rewrite(OutFile);

  numsectors:=level.sectors.Count;

      for i := 0 to (level.sectors.Count - 1) do
     begin
       //loop through each vertex in the current sector
            //and ouput the vertices to the file
             for n := 0 to (level.sectors[i].vertices.Count - 1) do
              begin

              end;


     end;

    end;
end;

end.
