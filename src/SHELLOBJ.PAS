Unit ShellOBJ;

interface

uses
  Windows,
  Messages,
  OLE2,
  COMMCTRL,
  ShellAPI,
  REGSTR;


{=========================================================================== }
{ Object identifiers in the explorer's name space (ItemID and IDList) }
{  All the items that the user can browse with the explorer (such as files, }
{ directories, servers, work-groups, etc.) has an identifier which is unique }
{ among items within the parent folder. Those identifiers are called item }
{ IDs (SHITEMID). Since all its parent folders have their own item IDs, }
{ any items can be uniquely identified by a list of item IDs, which is called }
{ an ID list (ITEMIDLIST). }

{  ID lists are almost always allocated by the task allocator (see some }
{ description below as well as OLE 2.0 SDK) and may be passed across }
{ some of shell interfaces (such as IShellFolder). Each item ID in an ID list }
{ is only meaningful to its parent folder (which has generated it), and all }
{ the clients must treat it as an opaque binary data except the first two }
{ bytes, which indicates the size of the item ID. }

{  When a shell extension -- which implements the IShellFolder interace -- }
{ generates an item ID, it may put any information in it, not only the data }
{ with that it needs to identifies the item, but also some additional }
{ information, which would help implementing some other functions efficiently. }
{ For example, the shell's IShellFolder implementation of file system items }
{ stores the primary (long) name of a file or a directory as the item }
{ identifier, but it also stores its alternative (short) name, size and date }
{ etc. }

{  When an ID list is passed to one of shell APIs (such as SHGetPathFromIDList), }
{ it is always an absolute path -- relative from the root of the name space, }
{ which is the desktop folder. When an ID list is passed to one of IShellFolder }
{ member function, it is always a relative path from the folder (unless it }
{ is explicitly specified). }

const
 CLSID_ShellDesktop: TGUID = (
       D1:$00021400; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
 CLSID_ShellLink: TGUID = (
       D1:$00021401; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));

 IID_IContextMenu : TGUID = (
       D1:$000214E4; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
 IID_IShellFolder : TGUID = (
       D1:$000214E6; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
 IID_IShellExtInit : TGUID = (
       D1:$000214E8; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
 IID_IShellPropSheetExt : TGUID = (
       D1:$000214E9; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
 IID_IExtractIcon : TGUID = (
       D1:$000214EB; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
 IID_IShellLink : TGUID = (
       D1:$000214EE; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
 IID_IShellCopyHook : TGUID = (
       D1:$000214EF; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
 IID_IFileViewer : TGUID = (
       D1:$000214F0; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
 IID_IEnumIDList : TGUID = (
       D1:$000214F2; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
 IID_IFileViewerSite : TGUID = (
       D1:$000214F3; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));

{ SHITEMID -- Item ID }
type
  PSHItemID = ^TSHItemID;
  TSHItemID = record        { mkid }
    cb:word;             { Size of the ID (including cb itself) }
    abID:array[0..0] of BYTE;        { The item ID (variable length) }
    end;

{ ITEMIDLIST -- List if item IDs (combined with 0-terminator) }
  PItemIDList = ^TItemIDList;
  TItemIDList = record { idl }
     mkid: TSHITEMID;
     end;

{=========================================================================== }
{ Task allocator API }
{  All the shell extensions MUST use the task allocator (see OLE 2.0 }
{ programming guild for its definition) when they allocate or free }
{ memory objects (mostly ITEMIDLIST) that are returned across any }
{ shell interfaces. There are two ways to access the task allocator }
{ from a shell extension depending on whether or not it is linked with }
{ OLE32.DLL or not (virtual; stdcall; abstractly for efficiency). }

{ (1) A shell extension which calls any OLE API (i.e., linked with }
{  OLE32.DLL) should call OLE's task allocator (by retrieving }
{  the task allocator by calling CoGetMalloc API). }

{ (2) A shell extension which does not call any OLE API (i.e., not linked }
{  with OLE32.DLL) should call the shell task allocator API (defined }
{  below), so that the shell can quickly loads it when OLE32.DLL is not }
{  loaded by any application at that point. }

{ Notes: }
{  In next version of Windowso release, SHGetMalloc will be replaced by }
{ the following macro. }

{ #define SHGetMalloc(ppmem)   CoGetMalloc(MEMCTX_TASK, ppmem) }

{=========================================================================== }


function SHGetMalloc(var ppMalloc: IMALLOC):HResult;


{=========================================================================== }
{ IContextMenu interface }
{ [OverView] }
{  The shell uses the IContextMenu interface in following three cases. }

{ case-1: The shell is loading context menu extensions. }
{   When the user clicks the right mouse button on an item within the shell's }
{  name space (i.g., file, directory, server, work-group, etc.), it creates }
{  the default context menu for its type, then loads context menu extensions }
{  that are registered for that type (and its base type) so that they can }
{  add extra menu items. Those context menu extensions are registered at }
{  HKCR\beginProgIDend\shellex\ContextMenuHandlers. }

{ case-2: The shell is retrieving a context menu of sub-folders in extended }
{   name-space. }
{   When the explorer's name space is extended by name space extensions, }
{  the shell calls their IShellFolder::GetUIObjectOf to get the IContextMenu }
{  objects when it creates context menus for folders under those extended }
{  name spaces. }

{ case-3: The shell is loading non-default drag and drop handler for directories. }
{   When the user performed a non-default drag and drop onto one of file }
{  system folders (i.e., directories), it loads shell extensions that are }
{  registered at HKCR\beginProgIDend\DragDropHandlers. }

{ [Member functions] }

{ IContextMenu::QueryContextMenu }
{  This member function may insert one or more menuitems to the specified }
{  menu (hmenu) at the specified location (indexMenu which is never be -1). }
{  The IDs of those menuitem must be in the specified range (idCmdFirst and }
{  idCmdLast). It returns the maximum menuitem ID offset (ushort) in the }
{  'code' field (low word) of the scode. }

{  The uFlags specify the context. It may have one or more of following }
{  flags. }

{  CMF_DEFAULTONLY: This flag is passed if the user is invoking the default }
{  action (typically by double-clicking, case 1 and 2 only). Context menu }
{  extensions (case 1) should not add any menu items, and returns NOERROR. }

{  CMF_VERBSONLY: The explorer passes this flag if it is constructing }
{  a context menu for a short-cut object (case 1 and case 2 only). If this }
{  flag is passed, it should not add any menu-items that is not appropriate }
{  from a short-cut. }
{  A good example is the 'Delete' menuitem, which confuses the user }
{  because it is not clear whether it deletes the link source item or the }
{  link itself. }

{  CMF_EXPLORER: The explorer passes this flag if it has the left-side pane }
{   (case 1 and 2 only). Context menu extensions should ignore this flag. }

{  High word (16-bit) are reserved for context specific communications }
{  and the rest of flags (13-bit) are reserved by the system. }


{ IContextMenu::InvokeCommand }

{   This member is called when the user has selected one of menuitems that }
{  are inserted by previous QueryContextMenu member. In this case, the }
{  LOWORD(lpici->lpVerb) contains the menuitem ID offset (menuitem ID - }
{  idCmdFirst). }

{   This member function may also be called programmatically. In such a case, }
{  lpici->lpVerb specifies the canonical name of the command to be invoked, }
{  which is typically retrieved by GetCommandString member previously. }

{  Parameters in lpci: }
{    cbSize -- Specifies the size of this structure (sizeof(*lpci)) }
{    hwnd   -- Specifies the owner window for any message/dialog box. }
{    fMask  -- Specifies whether or not dwHotkey/hIcon paramter is valid. }
{    lpVerb -- Specifies the command to be invoked. }
{    lpParameters -- Parameters (optional) }
{    lpDirectory  -- Working directory (optional) }
{    nShow -- Specifies the flag to be passed to ShowWindow (SW_*). }
{    dwHotKey -- Hot key to be assigned to the app after invoked (optional). }
{    hIcon -- Specifies the icon (optional). }


{ IContextMenu::GetCommandString }

{   This member function is called by the explorer either to get the }
{  canonical (language independent) command name (uFlags == GCS_VERB) or }
{  the help text ((uFlags & GCS_HELPTEXT) != 0) for the specified command. }
{  The retrieved canonical string may be passed to its InvokeCommand }
{  member function to invoke a command programmatically. The explorer }
{  displays the help texts in its status bar; therefore, the length of }
{  the help text should be reasonably short (<40 characters). }

{  Parameters: }
{   idCmd -- Specifies menuitem ID offset (from idCmdFirst) }
{   uFlags -- Either GCS_VERB or GCS_HELPTEXT }
{   pwReserved -- Reserved (must pass NULL when calling, must ignore when called) }
{   pszName -- Specifies the string buffer. }
{   cchMax -- Specifies the size of the string buffer. }

{=========================================================================== }

const
   { QueryContextMenu uFlags }
   CMF_NORMAL             = $00000000;
   CMF_DEFAULTONLY        = $00000001;
   CMF_VERBSONLY          = $00000002;
   CMF_EXPLORE            = $00000004;
   CMF_RESERVED           = $ffff0000      { View specific };

   { GetCommandString uFlags }
   GCS_VERB         =$00000000     { canonical verb };
   GCS_HELPTEXT     =$00000001     { help text (for status bar) };
   GCS_VALIDATE     =$00000002     { validate command exists };

   CMDSTR_NEWFOLDER    = 'NewFolder';
   CMDSTR_VIEWLIST     = 'ViewList';
   CMDSTR_VIEWDETAILS  = 'ViewDetails';

   CMIC_MASK_HOTKEY       = SEE_MASK_HOTKEY;
   CMIC_MASK_ICON         = SEE_MASK_ICON;
   CMIC_MASK_FLAG_NO_UI   = SEE_MASK_FLAG_NO_UI;
   CMIC_MASK_MODAL         =$80000000        (* ; Internal *);

  (*!! CMIC_VALID_SEE_FLAGS   = SEE_VALID_CMIC_FLAGS;   (* ; Internal *)


type
  PCMInvokeCommandInfo = ^TCMInvokeCommandInfo;
  TCMInvokeCommandInfo = record
     cbSize:DWORD;        { must be sizeof(CMINVOKECOMMANDINFO) }
     fMask:DWORD;         { any combination of CMIC_MASK_* }
     hwnd:HWND;           { might be NULL (indicating no owner window) }
     lpVerb:LPCSTR;       { either a string of MAKEINTRESOURCE(idOffset) }
     lpParameters:LPCSTR; { might be NULL (indicating no parameter) }
     lpDirectory:LPCSTR;  { might be NULL (indicating no specific directory) }
     nShow:integer;           { one of SW_ values for ShowWindow() API }

     dwHotKey:DWORD;
     hIcon:THANDLE;
     end;

  IContextMenu = class(IUnknown)
    function QueryContextMenu(Menu:HMENU; indexMenu:UINT;
                              idCmdFirst:UINT;idCmdLast:UINT;
                              uFlags:UINT):HResult; virtual; stdcall; abstract;

    function InvokeCommand(lpici: PCMINVOKECOMMANDINFO): HResult; virtual; stdcall; abstract;

    function GetCommandString(idCmd:UINT; uType:UINT; var pwReserved:UINT;
                              pszName:LPSTR; cchMax:UINT):HResult; virtual; stdcall; abstract;
    end;

{=========================================================================== }

{ Interface: IShellExtInit }

{  The IShellExtInit interface is used by the explorer to initialize shell }
{ extension objects. The explorer (1) calls CoCreateInstance (or equivalent) }
{ with the registered CLSID and IID_IShellExtInit, (2) calls its Initialize }
{ member, then (3) calls its QueryInterface to a particular interface (such }
{ as IContextMenu or IPropSheetExt and (4) performs the rest of operation. }


{ [Member functions] }

{ IShellExtInit::Initialize }

{  This member function is called when the explorer is initializing either }
{ context menu extension, property sheet extension or non-default drag-drop }
{ extension. }

{  Parameters: (context menu or property sheet extension) }
{   pidlFolder -- Specifies the parent folder }
{   lpdobj -- Spefifies the set of items selected in that folder. }
{   hkeyProgID -- Specifies the type of the focused item in the selection. }

{  Parameters: (non-default drag-and-drop extension) }
{   pidlFolder -- Specifies the target (destination) folder }
{   lpdobj -- Specifies the items that are dropped (see the description }
{    about shell's clipboard below for clipboard formats). }
{   hkeyProgID -- Specifies the folder type. }

{=========================================================================== }

type
    IShellExtInit = class(IUnknown)
      function Initialize(pidlFolder:PItemIDList;
                          lpdobj: IDataObject;
                          hKeyProgID:HKEY):HResult; virtual; stdcall; abstract;
    end;

{=========================================================================== }

{ Interface: IShellPropSheetExt }

{  The explorer uses the IShellPropSheetExt to allow property sheet }
{ extensions or control panel extensions to add additional property }
{ sheet pages. }


{ [Member functions] }

{ IShellPropSheetExt::AddPages }

{  The explorer calls this member function when it finds a registered }
{ property sheet extension for a particular type of object. For each }
{ additional page, the extension creates a page object by calling }
{ CreatePropertySheetPage API and calls lpfnAddPage. }

{  Parameters: }
{   lpfnAddPage -- Specifies the callback function. }
{   lParam -- Specifies the opaque handle to be passed to the callback function. }


{ IShellPropSheetExt::ReplacePage }

{  The explorer never calls this member of property sheet extensions. The }
{ explorer calls this member of control panel extensions, so that they }
{ can replace some of default control panel pages (such as a page of }
{ mouse control panel). }

{  Parameters: }
{   uPageID -- Specifies the page to be replaced. }
{   lpfnReplace Specifies the callback function. }
{   lParam -- Specifies the opaque handle to be passed to the callback function. }

{=========================================================================== }

type
 IShellPropSheetExt = class(IUnknown)
    function AddPages(lpfnAddPage: TFNADDPROPSHEETPAGE; lParam:LPARAM):HResult; virtual; stdcall; abstract;
    function ReplacePage(uPageID:UINT;
                         lpfnReplaceWith:TFNADDPROPSHEETPAGE;
                          lParam:LPARAM):HResult; virtual; stdcall; abstract;
    end;

{=========================================================================== }

{ IExtractIcon interface }

{  This interface is used in two different places in the shell. }

{ Case-1: Icons of sub-folders for the scope-pane of the explorer. }

{  It is used by the explorer to get the 'icon location' of }
{ sub-folders from each shell folders. When the user expands a folder }
{ in the scope pane of the explorer, the explorer does following: }
{  (1) binds to the folder (gets IShellFolder), }
{  (2) enumerates its sub-folders by calling its EnumObjects member, }
{  (3) calls its GetUIObjectOf member to get IExtractIcon interface }
{     for each sub-folders. }
{  In this case, the explorer uses only IExtractIcon::GetIconLocation }
{ member to get the location of the appropriate icon. An icon location }
{ always consists of a file name (typically DLL or EXE) and either an icon }
{ resource or an icon index. }


{ Case-2: Extracting an icon image from a file }

{  It is used by the shell when it extracts an icon image }
{ from a file. When the shell is extracting an icon from a file, }
{ it does following: }
{  (1) creates the icon extraction handler object (by getting its CLSID }
{     under the beginProgIDend\shell\ExtractIconHanler key and calling }
{     CoCreateInstance requesting for IExtractIcon interface). }
{  (2) Calls IExtractIcon::GetIconLocation. }
{  (3) Then, calls IExtractIcon::Extract with the location/index pair. }
{  (4) If (3) returns NOERROR, it uses the returned icon. }
{  (5) Otherwise, it recursively calls this logic with new location }
{     assuming that the location string contains a fully qualified path name. }

{  From extension programmer's point of view, there are only two cases }
{ where they provide implementations of IExtractIcon: }
{  Case-1) providing explorer extensions (i.e., IShellFolder). }
{  Case-2) providing per-instance icons for some types of files. }

{ Because Case-1 is described above, we'll explain only Case-2 here. }

{ When the shell is about display an icon for a file, it does following: }
{  (1) Finds its ProgID and ClassID. }
{  (2) If the file has a ClassID, it gets the icon location string from the }
{    'DefaultIcon' key under it. The string indicates either per-class }
{    icon (e.g., 'FOOBAR.DLL,2') or per-instance icon (e.g., '%1,1'). }
{  (3) If a per-instance icon is specified, the shell creates an icon }
{    extraction handler object for it, and extracts the icon from it }
{    (which is described above). }

{  It is important to note that the shell calls IExtractIcon::GetIconLocation }
{ first, then calls IExtractIcon::Extract. Most application programs }
{ that support per-instance icons will probably store an icon location }
{ (DLL/EXE name and index/id) rather than an icon image in each file. }
{ In those cases, a programmer needs to implement only the GetIconLocation }
{ member and it Extract member simply returns S_FALSE. They need to }
{ implement Extract member only if they decided to store the icon images }
{ within files themselved or some other database (which is very rare). }



{ [Member functions] }


{ IExtractIcon::GetIconLocation }

{  This function returns an icon location. }

{  Parameters: }
{   uFlags     [in]  -- Specifies if it is opened or not (GIL_OPENICON or 0) }
{   szIconFile [out] -- Specifies the string buffer buffer for a location name. }
{   cchMax     [in]  -- Specifies the size of szIconFile (almost always MAX_PATH) }
{   piIndex    [out] -- Sepcifies the address of UINT for the index. }
{   pwFlags    [out] -- Returns GIL_* flags }
{  Returns: }
{   NOERROR, if it returns a valid location; S_FALSE, if the shell use a }
{   default icon. }

{  Notes: The location may or may not be a path to a file. The caller can }
{   not assume anything unless the subsequent Extract member call returns }
{   S_FALSE. }

{   if the returned location is not a path to a file, GIL_NOTFILENAME should }
{   be set in the returned flags. }

{ IExtractIcon::Extract }

{  This function extracts an icon image from a specified file. }

{  Parameters: }
{   pszFile [in] -- Specifies the icon location (typically a path to a file). }
{   nIconIndex [in] -- Specifies the icon index. }
{   phiconLarge [out] -- Specifies the HICON variable for large icon. }
{   phiconSmall [out] -- Specifies the HICON variable for small icon. }
{   nIconSize [in] -- Specifies the size icon required (size of large icon) }
{                     LOWORD is the requested large icon size }
{                     HIWORD is the requested small icon size }
{  Returns: }
{   NOERROR, if it extracted the from the file. }
{   S_FALSE, if the caller should extract from the file specified in the }
{           location. }

{=========================================================================== }

{ GetIconLocation() input flags }
const
  GIL_OPENICON     =$0001      { allows containers to specify an 'open' look };
  GIL_FORSHELL     =$0002      { icon is to be displayed in a ShellFolder };

  { GetIconLocation() return flags }

  GIL_SIMULATEDOC  =$0001      { simulate this document icon for this };
  GIL_PERINSTANCE  =$0002      { icons from this class are per instance (each file has its own) };
  GIL_PERCLASS     =$0004      { icons from this class per class (shared for all files of this type) };
  GIL_NOTFILENAME  =$0008      { location is not a filename, must call ::Extract };
  GIL_DONTCACHE    =$0010      { this icon should not be cached };

type
  IExtractIcon = class(IUnknown)      { exic }
    function GetIconLocation(uFlags:UINT; szIconFile:LPSTR; cchMax:UINT;
                           var piIndex:integer;
                           var pwFlags:UINT):HResult; virtual; stdcall; abstract;

    function Extract(pszFile:LPCSTR; nIconIndex:UINT; var phiconLarge:HICON;
                     var phiconSmall:HICON;
                     nIconSize:UINT):HResult; virtual; stdcall; abstract;
    end;


{=========================================================================== }

{ IShellLink Interface }

{=========================================================================== }
const
    { IShellLink::Resolve fFlags }
    SLR_NO_UI           = $0001;
    SLR_ANY_MATCH       = $0002;
    SLR_UPDATE          = $0004;

    { IShellLink::GetPath fFlags }
    SLGP_SHORTPATH      = $0001;
    SLGP_UNCPRIORITY    = $0002;

type
  IShellLink = class(IUnknown) { sl }
    function GetPath(pszFile:LPSTR; cchMaxPath:integer;
                     var pfd:TWin32FindData;
                     fFlags:DWORD):HResult; virtual; stdcall; abstract;

    function GetIDList(var ppidl:PITEMIDLIST):HResult; virtual; stdcall; abstract;
    function SetIDList(pidl:PITEMIDLIST):HResult; virtual; stdcall; abstract;

    function GetDescription(pszName:LPSTR; cchMaxName:integer):HResult; virtual; stdcall; abstract;
    function SetDescription(pszName:LPSTR):HResult; virtual; stdcall; abstract;

    function GetWorkingDirectory(pszDir:LPSTR; cchMaxPath:integer):HResult; virtual; stdcall; abstract;
    function SetWorkingDirectory(pszDir:LPSTR):HResult; virtual; stdcall; abstract;

    function GetArguments(pszArgs:LPSTR; cchMaxPath:integer):HResult; virtual; stdcall; abstract;
    function SetArguments(pszArgs:LPSTR):HResult; virtual; stdcall; abstract;

    function GetHotkey(var pwHotkey:word):HResult; virtual; stdcall; abstract;
    function SetHotkey(wHotkey:word):HResult; virtual; stdcall; abstract;

    function GetShowCmd(var piShowCmd:integer):HResult; virtual; stdcall; abstract;
    function SetShowCmd(iShowCmd:integer):HResult; virtual; stdcall; abstract;

    function GetIconLocation(pszIconPath:LPSTR; cchIconPath:integer;
                             var piIcon:integer):HResult; virtual; stdcall; abstract;
    function SetIconLocation(pszIconPath:LPSTR; iIcon:integer):HResult; virtual; stdcall; abstract;

    function SetRelativePath(pszPathRel:LPSTR; dwReserved:DWORD):HResult; virtual; stdcall; abstract;

    function Resolve(Wnd:HWND; fFlags: DWORD):HResult; virtual; stdcall; abstract;

    function SetPath(pszFile:LPSTR):HResult; virtual; stdcall; abstract;
end;

{=========================================================================== }
{ ICopyHook Interface }
{  The copy hook is called whenever file system directories are }
{  copy/moved/deleted/renamed via the shell.  It is also called by the shell }
{  on changes of status of printers. }
{  Clients register their id under STRREG_SHEX_COPYHOOK for file system hooks }
{  and STRREG_SHEx_PRNCOPYHOOK for printer hooks. }
{  the CopyCallback is called prior to the action, so the hook has the chance }
{  to allow, deny or cancel the operation by returning the falues: }
{     IDYES  -  means allow the operation }
{     IDNO   -  means disallow the operation on this file, but continue with }
{              any other operations (eg. batch copy) }
{     IDCANCEL - means disallow the current operation and cancel any pending }
{              operations }
{   arguments to the CopyCallback }
{      hwnd - window to use for any UI }
{      wFunc - what operation is being done }
{      wFlags - and flags (FOF_*) set in the initial call to the file operation }
{      pszSrcFile - name of the source file }
{      dwSrcAttribs - file attributes of the source file }
{      pszDestFile - name of the destiation file (for move and renames) }
{      dwDestAttribs - file attributes of the destination file }
{=========================================================================== }

type
  ICopyHook = class(IUnknown) { sl }
    function CopyCallback(Wnd:HWND;wFunc:UINT; wFlags:UINT;
                          pszSrcFile:LPSTR; dwSrcAttribs:DWORD;
                          pszDestFile:LPSTR; dwDestAttribs:DWORD):UINT; virtual; stdcall; abstract;
    end;

{=========================================================================== }

{ IFileViewerSite Interface }

{=========================================================================== }

type
  IFileViewerSite = class(IUnknown)
    function SetPinnedWindow(Wnd:HWND):HResult; virtual; stdcall; abstract;
    function GetPinnedWindow(var Wnd:HWND):HResult; virtual; stdcall; abstract;
    end;

{=========================================================================== }
{ IFileViewer Interface }
{ Implemented in a FileViewer component object.  Used to tell a }
{ FileViewer to PrintTo or to view, the latter happening though }
{ ShowInitialize and Show.  The filename is always given to the }
{ viewer through IPersistFile. }
{=========================================================================== }

type
  PFVShowInfo = ^TFVShowInfo;
  TFVShowInfo = record
    { Stuff passed into viewer (in) }
     cbSize:DWORD;           { Size of structure for future expansion... }
     hwndOwner:HWND;         { who is the owner window. }
     iShow:integer;              { The show command }
    { Passed in and updated  (in/Out) }
     dwFlags:DWORD;          { flags }
     rect:TRECT;              { Where to create the window may have defaults }
     punkRel:IUNKNOWN;       { Relese this interface when window is visible }
    { Stuff that might be returned from viewer (out) }
     strNewFile:array[0..MAX_PATH-1] of TOLECHAR;   { New File to view. }
    end;

   { Define File View Show Info Flags. }
const
   FVSIF_RECT      =$00000001      { The rect variable has valid data. };
   FVSIF_PINNED    =$00000002      { We should Initialize pinned };

   FVSIF_NEWFAILED =$08000000      { The new file passed back failed };
                                           { to be viewed. }

   FVSIF_NEWFILE   =$80000000      { A new file to view has been returned };
   FVSIF_CANVIEWIT =$40000000      { The viewer can view it. };

type
  IFileViewer = class(IUnknown)
    function ShowInitialize(fsi:IFILEVIEWERSITE):HResult; virtual; stdcall; abstract;
    function Show(pvsi:PFVSHOWINFO):HResult; virtual; stdcall; abstract;
    function PrintTo(pszDriver:LPSTR; fSuppressUI:BOOL):HResult; virtual; stdcall; abstract;
    end;

{------------------------------------------------------------------------- }
{ struct STRRET }
{ structure for returning strings from IShellFolder member functions }
{------------------------------------------------------------------------- }
const
  STRRET_WSTR     =$0000;
  STRRET_OFFSET   =$0001;
  STRRET_CSTR     =$0002;

type
  PSTRRet = ^TStrRet;
  TSTRRET = record
     uType:UINT; { One of the STRRET_* values }
     case integer of
       0:(pOleStr:LPWSTR);        { OLESTR that will be freed }
       1:(uOffset:UINT);        { Offset into SHITEMID (ANSI) }
       2:(cStr: array[0..MAX_PATH-1] of char); { Buffer to fill in }
    end;

{------------------------------------------------------------------------- }
{ SHGetPathFromIDList }
{  This function assumes the size of the buffer (MAX_PATH). The pidl }
{ should point to a file system object. }
{------------------------------------------------------------------------- }

function SHGetPathFromIDList(pidl:PITEMIDLIST; pszPath:LPSTR):BOOL; stdcall;

{------------------------------------------------------------------------- }
{ SHGetSpecialFolderLocation }
{  Caller should call SHFree to free the returned pidl. }
{------------------------------------------------------------------------- }

{ registry entries for special paths are kept in : }
const
  REGSTR_PATH_SPECIAL_FOLDERS   = REGSTR_PATH_EXPLORER+'\Shell Folders';
  CSIDL_DESKTOP            =$0000;
  CSIDL_PROGRAMS           =$0002;
  CSIDL_CONTROLS           =$0003;
  CSIDL_PRINTERS           =$0004;
  CSIDL_PERSONAL           =$0005;
  CSIDL_FAVORITES          =$0006;
  CSIDL_STARTUP            =$0007;
  CSIDL_RECENT             =$0008;
  CSIDL_SENDTO             =$0009;
  CSIDL_BITBUCKET          =$000a;
  CSIDL_STARTMENU          =$000b;
  CSIDL_DESKTOPDIRECTORY   =$0010;
  CSIDL_DRIVES             =$0011;
  CSIDL_NETWORK            =$0012;
  CSIDL_NETHOOD            =$0013;
  CSIDL_FONTS              =$0014;
  CSIDL_TEMPLATES          =$0015;

function SHGetSpecialFolderLocation(hwndOwner:HWND; nFolder:integer;
                                    var ppidl:PITEMIDLIST):HResult; stdcall;

{------------------------------------------------------------------------- }
{ SHBrowseForFolder API }
{------------------------------------------------------------------------- }

type
  BFFCALLBACK = function(Wnd:HWND;uMsg:UINT;lParam,lpData:LPARAM):integer stdcall;
  PBrowseInfo = ^TBrowseInfo;
  TBrowseInfo = record
     hwndOwner:HWND;
     pidlRoot:PITEMIDLIST;
     pszDisplayName:LPSTR;  { Return display name of item selected. }
     lpszTitle:LPCSTR;      { text to go in the banner over the tree. }
     ulFlags:UINT;          { Flags that control the return stuff }
     lpfn:BFFCALLBACK;
     lParam:LPARAM;         { extra info that's passed back in callbacks }
     iImage:integer;        { output var: where to return the Image index. }
     end;

const
{ Browsing for directory. }
   BIF_RETURNONLYFSDIRS   =$0001  { For finding a folder to start document searching };
   BIF_DONTGOBELOWDOMAIN  =$0002  { For starting the Find Computer };
   BIF_STATUSTEXT         =$0004;
   BIF_RETURNFSANCESTORS  =$0008;

   BIF_BROWSEFORCOMPUTER  =$1000  { Browsing for Computers. };
   BIF_BROWSEFORPRINTER   =$2000  { Browsing for Printers };

   { message from browser }
   BFFM_INITIALIZED       = 1;
   BFFM_SELCHANGED        = 2;

   { messages to browser }
   BFFM_SETSTATUSTEXT      =(WM_USER + 100);
   BFFM_ENABLEOK           =(WM_USER + 101);
   BFFM_SETSELECTION       =(WM_USER + 102);

function SHBrowseForFolder(lpbi:PBROWSEINFO):PItemIDList; stdcall;

{------------------------------------------------------------------------- }
{ SHLoadInProc }
{   When this function is called, the shell calls CoCreateInstance }
{  (or equivalent) with CLSCTX_INPROC_SERVER and the specified CLSID }
{  from within the shell's process and release it immediately. }
{------------------------------------------------------------------------- }

function SHLoadInProc(rclsid:TCLSID):HRESULT; stdcall;

{------------------------------------------------------------------------- }
{ IEnumIDList interface }
{  IShellFolder::EnumObjects member returns an IEnumIDList object. }
{------------------------------------------------------------------------- }

type
  IEnumIDList = class(IUnknown)
    function Next( celt:ULONG;
                   var rgelt: PITEMIDLIST;
                   var pceltFetched:ULONG):HResult; virtual; stdcall; abstract;
    function Skip(celt:ULONG):HResult; virtual; stdcall; abstract;
    function Reset:HResult; virtual; stdcall; abstract;
    function Clone(var ppenum:IEnumIDList):HResult; virtual; stdcall; abstract;
    end;

{------------------------------------------------------------------------- }
{ IShellFolder interface }
{ [Member functions] }
{ IShellFolder::BindToObject(pidl, pbc, riid, ppvOut) }
{   This function returns an instance of a sub-folder which is specified }
{   by the IDList (pidl). }
{ IShellFolder::BindToStorage(pidl, pbc, riid, ppvObj) }
{   This function returns a storage instance of a sub-folder which is }
{   specified by the IDList (pidl). The shell never calls this member }
{   function in the first release of Win95. }
{ IShellFolder::CompareIDs(lParam, pidl1, pidl2) }
{   This function compares two IDLists and returns the result. The shell }
{   explorer always passes 0 as lParam, which indicates 'sort by name'. }
{   It should return 0 (as CODE of the scode), if two id indicates the }
{   same object; negative value if pidl1 should be placed before pidl2; }
{   positive value if pidl2 should be placed before pidl1. }
{ IShellFolder::CreateViewObject(hwndOwner, riid, ppvOut) }
{   This function creates a view object of the folder itself. The view }
{   object is a difference instance from the shell folder object. }
{ IShellFolder::GetAttributesOf(cidl, apidl, prgfInOut) }
{   This function returns the attributes of specified objects in that }
{   folder. 'cidl' and 'apidl' specifies objects. 'apidl' contains only }
{   simple IDLists. The explorer initializes *prgfInOut with a set of }
{   flags to be evaluated. The shell folder may optimize the operation }
{   by not returning unspecified flags. }
{ IShellFolder::GetUIObjectOf(hwndOwner, cidl, apidl, riid, prgfInOut, ppvOut) }
{   This function creates a UI object to be used for specified objects. }
{   The shell explorer passes either IID_IDataObject (for transfer operation) }
{   or IID_IContextMenu (for context menu operation) as riid. }
{ IShellFolder::GetDisplayNameOf }
{   This function returns the display name of the specified object. }
{   If the ID contains the display name (in the locale character set), }
{   it returns the offset to the name. Otherwise, it returns a pointer }
{   to the display name string (UNICODE), which is allocated by the }
{   task allocator, or fills in a buffer. }
{ IShellFolder::SetNameOf }
{   This function sets the display name of the specified object. }
{   If it changes the ID as well, it returns the new ID which is }
{   alocated by the task allocator. }
{------------------------------------------------------------------------- }

const
  { IShellFolder::GetDisplayNameOf/SetNameOf uFlags }
  SHGDN_NORMAL     = 0;        { default (display purpose) }
  SHGDN_INFOLDER   = 1;        { displayed under a folder (relative) }
  SHGDN_FORPARSING = $8000;    { for ParseDisplayName or path }

  { IShellFolder::EnumObjects }
  SHCONTF_FOLDERS         = 32;       { for shell browser }
  SHCONTF_NONFOLDERS      = 64;       { for default view }
  SHCONTF_INCLUDEHIDDEN   = 128;      { for hidden/system objects }

  { IShellFolder::GetAttributesOf flags }
  SFGAO_CANCOPY          = DROPEFFECT_COPY { Objects can be copied };
  SFGAO_CANMOVE          = DROPEFFECT_MOVE { Objects can be moved };
  SFGAO_CANLINK          = DROPEFFECT_LINK { Objects can be linked };
  SFGAO_CANRENAME         =$00000010     { Objects can be renamed };
  SFGAO_CANDELETE         =$00000020     { Objects can be deleted };
  SFGAO_HASPROPSHEET      =$00000040     { Objects have property sheets };
  SFGAO_DROPTARGET        =$00000100     { Objects are drop target };
  SFGAO_CAPABILITYMASK    =$00000177;
  SFGAO_LINK              =$00010000     { Shortcut (link) };
  SFGAO_SHARE             =$00020000     { shared };
  SFGAO_READONLY          =$00040000     { read-only };
  SFGAO_GHOSTED           =$00080000     { ghosted icon };
  SFGAO_DISPLAYATTRMASK   =$000F0000;
  SFGAO_FILESYSANCESTOR   =$10000000     { It contains file system folder };
  SFGAO_FOLDER            =$20000000     { It's a folder. };
  SFGAO_FILESYSTEM        =$40000000     { is a file system thing (file/folder/root) };
  SFGAO_HASSUBFOLDER      =$80000000     { Expandable in the map pane };
  SFGAO_CONTENTSMASK      =$80000000;
  SFGAO_VALIDATE          =$01000000     { invalidate cached information };
  SFGAO_REMOVABLE         =$02000000     { is this removeable media? };

type
   IShellFolder = class(IUnknown)
    function ParseDisplayName(hwndOwner:HWND;
             pbcReserved:{LPBC}pointer; lpszDisplayName:POLESTR;
             var pchEaten:ULONG; var ppidl:PITEMIDLIST;
             var dwAttributes:ULONG):HResult; virtual; stdcall; abstract;
    function EnumObjects(hwndOwner:HWND; grfFlags:DWORD;
                         var EnumIDList: IENUMIDLIST):HResult; virtual; stdcall; abstract;
    function BindToObject(pidl:PITEMIDLIST; pbcReserved:{LPBC}pointer;
                          riid:TIID; var ppvOut:pointer):HResult; virtual; stdcall; abstract;
    function BindToStorage(pidl:PITEMIDLIST; pbcReserved:{LPBC}pointer;
                           riid:TIID; var ppvObj:pointer):HResult; virtual; stdcall; abstract;
    function CompareIDs(lParam:LPARAM;
                        pidl1,pidl2: PITEMIDLIST):HResult; virtual; stdcall; abstract;
    function CreateViewObject(hwndOwner:HWND; riid:TIID;
                              var ppvOut: pointer):HResult; virtual; stdcall; abstract;
    function GetAttributesOf(cidl:UINT; var apidl: PITEMIDLIST;
                             var rgfInOut:UINT):HResult; virtual; stdcall; abstract;
    function GetUIObjectOf(hwndOwner:HWND; cidl:UINT; var apidl: PITEMIDLIST;
                           riid:TIID; var  prgfInOut:UINT; var ppvOut:pointer):HResult; virtual; stdcall; abstract;
    function GetDisplayNameOf(pidl: PITEMIDLIST; uFlags:DWORD;
                              lpName: PSTRRET):HResult; virtual; stdcall; abstract;
    function SetNameOf(hwndOwner:HWND; pidl: PITEMIDLIST;
                       lpszName:POLEStr; uFlags: DWORD;
                       var ppidlOut: PITEMIDLIST):HResult; virtual; stdcall; abstract;
    end;

{  Helper function which returns a IShellFolder interface to the desktop }
{ folder. This is equivalent to call CoCreateInstance with CLSID_ShellDesktop. }

{  CoCreateInstance(CLSID_Desktop, NULL, }
{                   CLSCTX_INPROC, IID_IShellFolder, &pshf); }

function SHGetDesktopFolder(var ppshf: ISHELLFOLDER):HResult; stdcall;

{========================================================================== }
{ Clipboard format which may be supported by IDataObject from system }
{ defined shell folders (such as directories, network, ...). }
{========================================================================== }
const
  CFSTR_SHELLIDLIST       ='Shell IDList Array'    { CF_IDLIST };
  CFSTR_SHELLIDLISTOFFSET ='Shell Object Offsets'  { CF_OBJECTPOSITIONS };
  CFSTR_NETRESOURCES      ='Net Resource'          { CF_NETRESOURCE };
  CFSTR_FILEDESCRIPTOR    ='FileGroupDescriptor'   { CF_FILEGROUPDESCRIPTOR };
  CFSTR_FILECONTENTS      ='FileContents'          { CF_FILECONTENTS };
  CFSTR_FILENAME          ='FileName'              { CF_FILENAME };
  CFSTR_PRINTERGROUP      ='PrinterFriendlyName'   { CF_PRINTERS };
  CFSTR_FILENAMEMAP       ='FileNameMap'           { CF_FILENAMEMAP };

  { CF_OBJECTPOSITIONS }

  DVASPECT_SHORTNAME     = 2 { use for CF_HDROP to get short name version };

{ format of CF_NETRESOURCE }

type
  PNRESARRAY = ^TNRESARRAY;
  TNRESARRAY = record { anr }
     cItems:UINT;
     nr: array[0..0] of TNETRESOURCE;
     end;


{ format of CF_IDLIST }
  PIDA = ^TIDA;
  TIDA = record
     cidl:UINT;          { number of relative IDList }
     aoffset: array[0..0] of UINT;    { [0]: folder IDList, [1]-[cidl]: item IDList }
     end;


{ FILEDESCRIPTOR.dwFlags field indicate which fields are to be used }
const
    FD_CLSID            = $0001;
    FD_SIZEPOINT        = $0002;
    FD_ATTRIBUTES       = $0004;
    FD_CREATETIME       = $0008;
    FD_ACCESSTIME       = $0010;
    FD_WRITESTIME       = $0020;
    FD_FILESIZE         = $0040;
    FD_LINKUI           = $8000;       { 'link' UI is prefered }

type
  PFILEDESCRIPTOR = ^TFILEDESCRIPTOR;
  TFILEDESCRIPTOR = record { fod }
     dwFlags:DWORD;
     clsid:TCLSID;
     sizel:TSIZE;
     pointl:TPOINT;
     dwFileAttributes:DWORD;
     ftCreationTime:TFILETIME;
     ftLastAccessTime:TFILETIME;
     ftLastWriteTime:TFILETIME;
     nFileSizeHigh:DWORD;
     nFileSizeLow:DWORD;
     cFileName: array[0..MAX_PATH-1] of CHAR;
     end;


{ format of CF_FILEGROUPDESCRIPTOR }
  PFILEGROUPDESCRIPTOR = ^TFILEGROUPDESCRIPTOR;
  TFILEGROUPDESCRIPTOR = record { fgd }
      cItems:UINT;
      fgd: array[0..0] of TFILEDESCRIPTOR;
      end;


{ format of CF_HDROP and CF_PRINTERS, in the HDROP case the data that follows }
{ is a double null terinated list of file names, for printers they are printer }
{ friendly names }
  PDROPFILES = ^TDROPFILES;
  TDROPFILES = record
    pFiles:DWORD;                       { offset of file list }
    pt:TPOINT;                          { drop point (client coords) }
    fNC:BOOL;                           { is it on NonClient area }
                                        { and pt is in screen coords }
    fWide:BOOL;                         { WIDE character switch }
    end;

{====== File System Notification APIs =============================== }
const
   {  File System Notification flags }
   SHCNE_RENAMEITEM          =$00000001;
   SHCNE_CREATE              =$00000002;
   SHCNE_DELETE              =$00000004;
   SHCNE_MKDIR               =$00000008;
   SHCNE_RMDIR               =$00000010;
   SHCNE_MEDIAINSERTED       =$00000020;
   SHCNE_MEDIAREMOVED        =$00000040;
   SHCNE_DRIVEREMOVED        =$00000080;
   SHCNE_DRIVEADD            =$00000100;
   SHCNE_NETSHARE            =$00000200;
   SHCNE_NETUNSHARE          =$00000400;
   SHCNE_ATTRIBUTES          =$00000800;
   SHCNE_UPDATEDIR           =$00001000;
   SHCNE_UPDATEITEM          =$00002000;
   SHCNE_SERVERDISCONNECT    =$00004000;
   SHCNE_UPDATEIMAGE         =$00008000;
   SHCNE_DRIVEADDGUI         =$00010000;
   SHCNE_RENAMEFOLDER        =$00020000;
   SHCNE_FREESPACE           =$00040000;

   SHCNE_ASSOCCHANGED        =$08000000;

   SHCNE_DISKEVENTS          =$0002381F;
   SHCNE_GLOBALEVENTS        =$0C0581E0 { Events that dont match pidls first };
   SHCNE_ALLEVENTS           =$7FFFFFFF;
   SHCNE_INTERRUPT           =$80000000 { The presence of this flag indicates };
                                        { that the event was generated by an }
                                        { interrupt.  It is stripped out before }
                                        { the clients of SHCNNotify_ see it. }

   { Flags }
   { uFlags & SHCNF_TYPE is an ID which indicates what dwItem1 and dwItem2 mean }
   SHCNF_IDLIST      =$0000        { LPITEMIDLIST };
   SHCNF_PATH        =$0001        { path name };
   SHCNF_PRINTER     =$0002        { printer friendly name };
   SHCNF_DWORD       =$0003        { DWORD };
   SHCNF_TYPE        =$00FF;
   SHCNF_FLUSH       =$1000;
   SHCNF_FLUSHNOWAIT =$2000;

{  APIs }

procedure SHChangeNotify(wEventId:longint; uFlags:UINT;
                         dwItem1,dwItem2:pointer); stdcall;

procedure SHAddToRecentDocs(uFlags:UINT; pv:pointer); stdcall;

function SHGetInstanceExplorer(var Unk:IUnknown):HResult; stdcall;

{ SHAddToRecentDocs }
const
  SHARD_PIDL      =$00000001;
  SHARD_PATH      =$00000002;


implementation

const Shell32DLL = 'shell32.dll';

function SHGetMalloc(var ppMalloc: IMALLOC):HResult;
begin
  Result := CoGetMalloc(MEMCTX_TASK,ppMalloc);
end;

function SHGetPathFromIDList; external Shell32DLL name 'SHGetPathFromIDList';
function SHGetSpecialFolderLocation; external Shell32DLL name 'SHGetSpecialFolderLocation';
function SHBrowseForFolder; external Shell32DLL name 'SHBrowseForFolder';
function SHLoadInProc; external Shell32DLL name 'SHLoadInProc';
function SHGetDesktopFolder; external Shell32DLL name 'SHGetDesktopFolder';
procedure SHChangeNotify;    external Shell32DLL name 'SHChangeNotify';
procedure SHAddToRecentDocs; external Shell32DLL name 'SHAddToRecentDocs';
function SHGetInstanceExplorer;  external Shell32DLL name 'SHGetInstanceExplorer';

end.
