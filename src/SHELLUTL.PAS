unit ShellUtl;

interface

uses Windows,Ole2;

function CreateLink(lpszPathObj,lpszPathLink,lpszDesc:String):HResult;
function ResolveIt(Wnd:HWND; lpszLinkFile:String):String;


implementation

uses SysUtils,ShellAPI,ShellObj;

(*
The CreateLink function in the following example creates a shortcut.
The parameters include a pointer to the name of the file to link to,
a pointer to the name of the shortcut that you are creating, and a
pointer to the description of the link. The description consists of
the string, "Shortcut to filename," where filename is the name of the
file to link to.
Because CreateLink calls the CoCreateInstance function, it is assumed
that the CoInitialize function has already been called. CreateLink uses
the IPersistFile interface to save the shortcut and the IShellLink interface
to store the filename and description.

 CreateLink - uses the shell's IShellLink and IPersistFile interfaces
     to create and store a shortcut to the specified object.
 Returns the result of calling the member functions of the interfaces.
 lpszPathObj - address of a buffer containing the path of the object
 lpszPathLink - address of a buffer containing the path where the
               shell link is to be stored
 lpszDesc - address of a buffer containing the description of the
     shell link
*)
function CreateLink(lpszPathObj,lpszPathLink,lpszDesc:string):HResult;
var
  hRes: HRESULT;
  psl: IShellLink;
  ppf: IPersistFile;
  wsz: PWideChar;
begin
    GetMem(wsz,MAX_PATH*2);
    try
    { Get a pointer to the IShellLink interface. }
    hres := CoCreateInstance(CLSID_ShellLink, nil,
                            CLSCTX_INPROC_SERVER, IID_IShellLink, psl);
    if SUCCEEDED(hres) then
       begin
       { Set the path to the shortcut target, and add the
         description.  }
       psl.SetPath(@lpszPathObj[1]);
       psl.SetDescription(@lpszDesc[1]);
       { Query IShellLink for the IPersistFile interface for saving the
         shortcut in persistent storage. }
       if SUCCEEDED(psl.QueryInterface(IID_IPersistFile,ppf)) then
         begin
         { Ensure that the string is ANSI. }
         MultiByteToWideChar(CP_ACP, 0, @lpszPathLink[1],-1,wsz,MAX_PATH);
         { Save the link by calling IPersistFile::Save. }
         hres := ppf.Save(wsz,TRUE);
         ppf.Release;
         end;
       psl.Release;
       end;
    Result := hres;
 finally
    FreeMem(wsz,MAX_PATH*2);
    end;
end;


function ResolveIt(Wnd:HWND; lpszLinkFile:String):String;
var
  hres:HRESULT;
  psl:IShellLink;
  szGotPath: array[0..MAX_PATH-1] of char;
  szDescription: array[0..MAX_PATH-1] of char;
  wfd: TWin32FindData;
  ppf: IPersistFile;
  wsz: array[0..MAX_PATH-1] of WideChar;

begin
 Result := ''; { assume failure  }
 { Get a pointer to the IShellLink interface. }
 hres := CoCreateInstance(CLSID_ShellLink, nil,
         CLSCTX_INPROC_SERVER, IID_IShellLink, psl);
 if (SUCCEEDED(hres)) then
     begin
     { Get a pointer to the IPersistFile interface. }
     hres := psl.QueryInterface(IID_IPersistFile,ppf);
     if (SUCCEEDED(hres)) then
         begin
         { Ensure that the string is Unicode. }
         MultiByteToWideChar(CP_ACP, 0,@lpszLinkFile[1],-1,wsz,MAX_PATH);
         { Load the shortcut. }
         hres := ppf.Load(wsz, STGM_READ);
         if (SUCCEEDED(hres)) then
             begin
             { Resolve the link. }
             hres := psl.Resolve(wnd,SLR_ANY_MATCH);
             if (SUCCEEDED(hres)) then
                 begin
                 { Get the path to the link target. }
                 hres := psl.GetPath(szGotPath,MAX_PATH,wfd,SLGP_SHORTPATH);
                 if not SUCCEEDED(hres) then exit;
                 { Get the description of the target. }
                 hres := psl.GetDescription(szDescription, MAX_PATH);
                 if not SUCCEEDED(hres) then exit;
                 Result := StrPas(szGotPath)+'|'+StrPas(szDescription);
                 end;
             end;
         { Release the pointer to the IPersistFile interface. }
         ppf.Release;
         end;
     { Release the pointer to the IShellLink interface. }
     psl.Release;
     end;
end;


end.
