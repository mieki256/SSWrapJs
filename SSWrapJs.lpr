program SSWrapJs;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  Controls,
  LCLIntf,
  LCLType,
  Windows,
  SysUtils,
  Dialogs,
  process,
  Classes,
  FullScrnUnit,
  PreviewUnit,
  ConfigUnit,
  ConfigData { you can add units after this };

  {$R *.res}
  {$R myresources.res}

const
  MUTEX_NAME: string = 'SSaverWrapperJavaScriptMutex';

var
  arg: string;
  phwnd: HWND;
  hMutex: THandle;

{ FullScreen Mode }
procedure FullScreenMode;
var
  dt: TSaverItem;
  uri: string;
begin
  // 多重起動禁止
  hMutex := CreateMutex(nil, False, PChar(MUTEX_NAME));
  if (hMutex = 0) or (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    // Mutex取得に失敗したか既に存在してる
    if hMutex <> 0 then
      CloseHandle(hMutex);
    Exit;
  end;

  try
    // 設定ファイルを読み込み
    dt := GetSelectedItem;

    // フルスクリーン表示用フォームを生成
    Application.CreateForm(TFullScrnForm, FullScrnForm);

    // 何故かフルスクリーン表示にならないのでこのタイミングでも設定、
    // してみたけれど OnShow のタイミングで行うだけでいいかも？
    //FullScrnForm.SetFullScreen;

    uri := dt.Uri;
    if (dt.Name = 'None') or (dt.Name = 'none') or (dt.Name = '') then
      uri := '';

    // URIとスクリーンセーバの終了条件を指定
    FullScrnForm.OpenUri := uri;
    FullScrnForm.ChkKeyDown := dt.KeyDown;
    FullScrnForm.ChkMouseDown := dt.MouseDown;
    FullScrnForm.ChkMouseMove := dt.MouseMove;

    Application.Run;
  finally
    if hMutex <> 0 then
      CloseHandle(hMutex);
  end;
end;

{ Config Mode }
procedure ConfigMode;
begin
  Application.CreateForm(TConfigForm, ConfigForm);
  Application.Run;
end;

{ Preview Mode }
procedure PreviewMode;
var
  s: string;
  ExSaver: TSaverItem;
  imgPath: string;
  Name: string;
begin
  // 設定ファイル読み込み
  ExSaver := GetSelectedItem;
  Name := ExSaver.Name;
  imgPath := ExSaver.Preview;

  if (Name = '') or (Name = 'None') or (Name = 'none') then
    Name := APP_NAME;

  if (imgPath <> '') and (not FileExists(imgPath)) then
    imgPath := '';

  // "/p" or "/p:HWND"
  s := ParamStr(1);
  phwnd := 0;
  if Length(s) = 2 then
  begin
    // "/p HWND"
    if ParamCount >= 2 then
      phwnd := HWND(StrToInt64Def(ParamStr(2), 0));
  end
  else if (Length(s) > 3) and (s[3] = ':') then
  begin
    // "/p:HWND"
    phwnd := HWND(StrToInt64Def(Copy(s, 4, MaxInt), 0));
  end;

  Application.CreateForm(TPreviewForm, PreviewForm);

  {$PUSH}
  {$WARN 5044 OFF}
  Application.MainFormOnTaskbar := False;
  {$POP}

  {$PUSH}
  {$WARN SYMBOL_PLATFORM OFF}
  // Application(隠し窓)にツールウィンドウ属性を与えてタスクバーから隠す
  SetWindowLong(Application.Handle, GWL_EXSTYLE,
    GetWindowLong(Application.Handle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW);
  {$POP}

  PreviewForm.EmbedIntoParent(phwnd);
  PreviewForm.SSaverName := Name;
  PreviewForm.ImagePath := imgPath;

  Application.Run;
end;

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  {$PUSH}
  {$WARN 5044 OFF}
  //Application.MainFormOnTaskbar := True;
  Application.MainFormOnTaskbar := False;
  {$POP}
  Application.Initialize;

  arg := '';
  if ParamCount >= 1 then
    arg := LowerCase(Copy(ParamStr(1), 1, 2));

  case arg of
    '/s': FullScreenMode;
    '/c': ConfigMode;
    '/p': PreviewMode
    else
      ConfigMode
  end;
end.
