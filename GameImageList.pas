unit GameImageList;
//NJED JAN-2023
// http://www.delphigroups.info/2/3/312458.html
interface
 uses classes, Graphics;
Type

TBitMapList = Class
Private
fList : TList;
bmp : Tbitmap;
Protected

public
Constructor Create;
Destructor Destroy; Override;
Procedure AddImage(aBitMap : TBitMap);
Procedure GetImage(Index : Integer; aBitMap : TBitMap);
Function ImageCount : Integer;
Procedure Clear;
Procedure FreeBMP;
Procedure Notify(Ptr: Pointer; Action: TListNotification);
End;

implementation

Constructor TBitMapList.Create;
Begin
fList := TList.Create;
End;

Destructor TBitMapList.Destroy;
Begin
Clear;
fList.Free;
inherited Destroy;
End;

Procedure TBitMapList.AddImage(aBitMap : TBitMap);
Begin
bmp:=Tbitmap.Create;
bmp.Assign(aBitmap);
fList.Add(bmp);
End;

Procedure TBitMapList.GetImage(Index : Integer; aBitMap : TBitMap);
Begin
aBitMap.Assign(TBitMap(fList[Index]));
End;

procedure TBitMapList.Notify(Ptr: Pointer; Action: TListNotification);
begin
inherited;
end;

Procedure TBitMapList.FreeBMP;
var
i : Integer;
Begin
 for i := 0 to (fList.Count - 1) do
  begin
  Tbitmap(fList.Items[I]).Free;
  end;
  fList.Clear;
End;

Procedure TBitMapList.Clear;
Var
Index : Integer;
tbmp: Tbitmap;
Begin
Index := 0;
  While Index < fList.Count Do
    Begin
     tbmp:= TBitmap(fList.Items[Index]);
     tbmp.Free;
     tbmp:=nil;
     //Inc(Index);
     fList.Delete(0);
    End;

fList.Clear;
End;

Function TBitMapList.ImageCount : Integer;
Begin
Result := fList.Count;
End;


end.

