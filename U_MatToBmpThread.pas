unit U_MatToBmpThread;
//NJED JAN-2023
interface

uses
  Classes,StdCtrls,graphics,graph_files,files,fileoperations;

type
  TMatToBmpThread = class(TThread)
  private
    { Private declarations }
  FList: Tstringlist;
  Fcmppal:TCMPPal;
  bm:TBitmap;
  procedure UpdateBmpList;
  procedure OnComplete;
  procedure UpdateCellCnt;
  protected
  procedure Execute; override;
  public
  { Public declarations }
  isRunning :boolean;
  constructor Create(AList: TStringlist;Acmppal:TCMPPal);
 end;

implementation
uses MatThumbNails;
{ Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure MatToBmp.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; }

{ MatToBmp }

procedure TMatToBmpThread.OnComplete;
begin
 frmThumbNails.OKButton.Enabled:=true;
 frmThumbNails.PB_BuildThumbs.Visible:=false;
 bm:=nil;
end;

procedure TMatToBmpThread.UpdateBmpList;
begin
 bmpList.AddImage(bm);
 bm.Free;
 frmThumbNails.DrawGrid1.Repaint;
 frmThumbNails.OKButton.Enabled:=true;
 frmThumbNails.PB_BuildThumbs.Position:=frmThumbNails.PB_BuildThumbs.Position+1;
end;

procedure TMatToBmpThread.UpdateCellCnt;
begin
 frmThumbNails.UpdateCellCnt(FList.Count);
 frmThumbNails.DrawGrid1.Invalidate;
 
 frmThumbNails.PB_BuildThumbs.Visible:=true;
 frmThumbNails.PB_BuildThumbs.Min:=0;
 frmThumbNails.PB_BuildThumbs.Max:=FList.Count;
 frmThumbNails.PB_BuildThumbs.Position:=0;
end;

constructor TMatToBmpThread.Create(AList: TStringlist;Acmppal:TCMPPal);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FList := AList;
  Fcmppal := Acmppal;
end;

procedure TMatToBmpThread.Execute;
var
i:integer;
mat:TMAT;

begin
  { Place thread code here }
Synchronize(UpdateCellCnt);
isRunning:=true;
for i := 0 to (FList.Count - 1) do
  begin
   if Terminated then break;
   
   mat:=TMat.Create(OpenGameFile(FList[i]),0);
   Mat.SetPal(Fcmppal);
   bm:=MAT.LoadBitmap(-1,-1);   // Creates new bitmap, make sure to free it
   MAT.Free;
   Synchronize(UpdateBmpList);
  end;
   //FList.Clear;
  Synchronize(OnComplete);
  isRunning:=false;
end;

end.
