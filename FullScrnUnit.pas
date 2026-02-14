unit FullScrnUnit;

{$mode objfpc}{$H+}

interface

uses
  //JwaWindows,
  Windows,
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls,
  ExtCtrls,
  LazFileUtils,
  LCLType,
  ComCtrls,
  uWVWindowParent, uWVBrowser,
  uWVLoader, uWVBrowserBase,
  uWVTypes,
  uWVTypeLibrary,
  ConfigData;

type

  { TFullScrnForm }

  TFullScrnForm = class(TForm)
    InitTimer: TTimer;
    Label1: TLabel;
    Label2: TLabel;
    MouseCheckTimer: TTimer;
    Panel1: TPanel;
    WVBrowser1: TWVBrowser;
    WVWindowParent1: TWVWindowParent;
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure InitTimerTimer(Sender: TObject);
    procedure MouseCheckTimerTimer(Sender: TObject);
    procedure WVBrowser1AfterCreated(Sender: TObject);
    procedure WVBrowser1InitializationError(Sender: TObject;
      aErrorCode: HRESULT; const aErrorMessage: wvstring);
    procedure WVBrowser1NavigationCompleted(Sender: TObject;
      const aWebView: ICoreWebView2;
      const aArgs: ICoreWebView2NavigationCompletedEventArgs);
  private
    FLastPos: Classes.TPoint;
    FChkKeyDown: boolean;
    FChkMouseDown: boolean;
    FChkMouseMove: boolean;
    FOpenUri: string;
    function GetHtmlFromResource(ResName: string): string;
  public
    property ChkKeyDown: boolean read FChkKeyDown write FChkKeyDown;
    property ChkMouseDown: boolean read FChkMouseDown write FChkMouseDown;
    property ChkMouseMove: boolean read FChkMouseMove write FChkMouseMove;
    property OpenUri: string read FOpenUri write FOpenUri;
    procedure SetFullScreen;
  end;

var
  FullScrnForm: TFullScrnForm;

implementation

{$R *.lfm}

const
  WH_KEYBOARD_LL = 13;

var
  hhkLowLevelKybd: HHOOK;
  keyDownFg: boolean;

// キーボードフック時に呼ばれるコールバック関数
function LowLevelKbdProc(nCode: integer; wParam: WPARAM; lParam: LPARAM): LRESULT;
  stdcall;
begin
  // nCodeが0以上の場合、有効なキーイベント
  if nCode = HC_ACTION then
  begin
    if (wParam = WM_KEYDOWN) or (wParam = WM_SYSKEYDOWN) then
    begin
      // キーが押された
      keyDownFg := True;
    end;
  end;

  // 次のフックへ処理を渡す
  Result := CallNextHookEx(hhkLowLevelKybd, nCode, wParam, lParam);
end;

{ TFullScrnForm }

{ フォームが表示される時の処理 }
procedure TFullScrnForm.FormShow(Sender: TObject);
begin
  Left := 0;
  Top := 0;

  // フルスクリーン表示を指定
  SetFullScreen;

  // キー押し下げを検出できるようにする
  KeyPreview := True;

  FLastPos.X := -1;
  FLastPos.Y := -1;

  if GlobalWebView2Loader.InitializationError then
  begin
    // ブラウザ部分の初期化失敗
    ShowMessage(UTF8Encode(GlobalWebView2Loader.ErrorMessage));
    Application.Terminate;
    Exit;
  end;

  if GlobalWebView2Loader.Initialized then
  begin
    // ブラウザ部分の初期化に成功
    WVBrowser1.CreateBrowser(WVWindowParent1.Handle);
  end
  else
  begin
    // 初期化失敗。タイマーを使って少し後から初期化できないか試す
    ShowMessage('Error: ' + UTF8Encode(GlobalWebView2Loader.ErrorMessage));
    InitTimer.Enabled := True;
    InitTimer.Interval := 500;
  end;

  // キーボードフックを設定。
  // WebView2にフォーカスが当たってると
  // フォームのOnKeyDownイベントが取得できなくなるのでこうして処理する
  hhkLowLevelKybd := SetWindowsHookEx(WH_KEYBOARD_LL, @LowLevelKbdProc, HInstance, 0);
  keyDownFg := False;

  if hhkLowLevelKybd = 0 then
  begin
    ShowMessage('Error: Initializing keyboard hook.');
  end;
end;

{ フルスクリーン表示を指定 }
procedure TFullScrnForm.SetFullScreen;
begin
  BorderStyle := bsNone;      // タイトルバー消去
  WindowState := wsMaximized; // 最大化
  FormStyle := fsStayOnTop;   // 最前面表示

  if FChkMouseMove then
  begin
    // マウスカーソル非表示
    ShowCursor(False);
  end;
end;

{ ブラウザ部分の初期化リトライ }
procedure TFullScrnForm.InitTimerTimer(Sender: TObject);
begin
  InitTimer.Enabled := False;

  if GlobalWebView2Loader.Initialized then
  begin
    // 初期化成功
    WVBrowser1.CreateBrowser(WVWindowParent1.Handle);
  end
  else
  begin
    // 初期化失敗。またリトライするように指定
    ShowMessage('Error: ' + UTF8Encode(GlobalWebView2Loader.ErrorMessage));
    InitTimer.Enabled := True;
  end;
end;

{ タイマーを使って一定時間毎に終了条件を満たしているか調べる }
procedure TFullScrnForm.MouseCheckTimerTimer(Sender: TObject);
const
  DIST: integer = 128;
var
  cpos: Classes.TPoint;
  dx, dy: integer;
begin
  MouseCheckTimer.Enabled := False;

  // ESCキーが押されてるかチェック
  if (Windows.GetAsyncKeyState(VK_ESCAPE) and $8000) <> 0 then
  begin
    Application.Terminate;
    Exit;
  end;

  // マウスボタンが押されたかチェック
  if FChkMouseDown then
  begin
    if (GetAsyncKeyState(VK_LBUTTON) and $8000) <> 0 then
    begin
      Application.Terminate;
      Exit;
    end;
  end;

  // マウスカーソルが動いたかチェック
  if FChkMouseMove then
  begin
    GetCursorPos(cpos);
    if (FLastPos.X <> -1) or (FLastPos.Y <> -1) then
    begin
      dx := FLastPos.X - cpos.X;
      dy := FLastPos.Y - cpos.Y;
      if ((dx * dx) + (dy * dy)) > (DIST * DIST) then
      begin
        Application.Terminate;
        Exit;
      end;
    end;
    FLastPos := cpos;
  end;

  // 何かキーが押されてたら終了
  if (FChkKeyDown) and (keyDownFg) then
  begin
    Application.Terminate;
    Exit;
  end;

  MouseCheckTimer.Enabled := True;
end;

{ キーの押し下げを判定。フォームの KeyPreview を有効にしておくこと }
procedure TFullScrnForm.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  // ESCキーなら必ず終了させる
  if Key = VK_ESCAPE then
  begin
    Application.Terminate;
    Exit;
  end;

  if FChkKeyDown then
    Application.Terminate;
end;

{ フォームを破棄する際の処理 }
procedure TFullScrnForm.FormDestroy(Sender: TObject);
begin
  if FChkMouseMove then
  begin
    // カーソル表示を有効化
    ShowCursor(True);
  end;

  // キーボードフックを解除
  if hhkLowLevelKybd <> 0 then
    UnhookWindowsHookEx(hhkLowLevelKybd);
end;

{ ブラウザ部分が生成された直後の処理 }
procedure TFullScrnForm.WVBrowser1AfterCreated(Sender: TObject);
var
  uri: string;
  uri_orig: string;
  localFile: boolean;
  Content: string;
begin
  WVBrowser1.DefaultBackgroundColor := clBlack; // 背景色を黒に
  WVWindowParent1.UpdateSize;                   // 表示サイズを更新

  if FOpenUri = '' then
  begin
    // 開くべきURIが指定されてない。
    // リソースからHTML内の文字列を取得してブラウザ部分に送る
    Content := GetHtmlFromResource('MY_HTML_FILE');
    WVBrowser1.NavigateToString(UTF8Decode(Content));
    Exit;
  end;

  // 開くべきURIが指定されている
  localFile := True;
  uri := FOpenUri;
  uri_orig := uri;
  if (Pos('http://', LowerCase(uri)) = 1) or
    (Pos('https://', LowerCase(uri)) = 1) then
  begin
    // Web上のURLを指定されている
    localFile := False;
  end
  else if (not FilenameIsAbsolute(uri)) then
  begin
    // 相対パスでローカルファイルを指定されている
    uri := ExpandFileName(uri);
  end;

  if localFile then
  begin
    // ローカルファイルが指定されている

    if (not FileExists(uri)) then
    begin
      // ローカルファイルが存在しない
      ShowMessage('Error : Not found HTML. : ' + uri_orig);
      Application.Terminate;
      Exit;
    end;

    // "\" を "/" に変換
    uri := StringReplace(uri, '\', '/', [rfReplaceAll]);

    // ローカルファイルなら "file:///" を先頭に追加
    uri := 'file:///' + uri;
  end;

  // URIを開く
  WVBrowser1.Navigate(UTF8Decode(uri));
end;

procedure TFullScrnForm.WVBrowser1InitializationError(Sender: TObject;
  aErrorCode: HRESULT; const aErrorMessage: wvstring);
begin
  ShowMessage(UTF8Encode('Error: ' + aErrorMessage));
end;

procedure TFullScrnForm.WVBrowser1NavigationCompleted(Sender: TObject;
  const aWebView: ICoreWebView2;
  const aArgs: ICoreWebView2NavigationCompletedEventArgs);
begin
  // ブラウザ部分がURIを開けたら上に被せてるパネルを非表示にする。
  // これをしないと灰色のウインドウがしばらく表示されてしまう
  Panel1.Visible := False;

  // キーの押し下げやマウスの監視を開始
  MouseCheckTimer.Interval := 50;
  MouseCheckTimer.Enabled := True;
end;

{ リソースファイル内のファイルから文字列を取り出す }
function TFullScrnForm.GetHtmlFromResource(ResName: string): string;
var
  ResStream: TResourceStream;
  StringStream: TStringStream;
begin
  Result := '';
  try
    // リソース名と型(RT_RCDATA)を指定してストリームを作成
    ResStream := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
    try
      StringStream := TStringStream.Create('');
      try
        // リソースの内容をStringStreamにコピー
        StringStream.CopyFrom(ResStream, ResStream.Size);
        Result := StringStream.DataString;
      finally
        StringStream.Free;
      end;
    finally
      ResStream.Free;
    end;
  except
    on E: Exception do
    begin
      // リソースが見つからない
      ShowMessage('Error loading resource: ' + E.Message);
      Application.Terminate;
    end;
  end;
end;

initialization
  // ブラウザ部分の初期化処理
  GlobalWebView2Loader := TWVLoader.Create(nil);
  GlobalWebView2Loader.UseInternalLoader := True; // DLL不要設定

  GlobalWebView2Loader.UserDataFolder :=
    UTF8Decode(ConcatPaths([GetConfigDir, 'CustomCache']));

  //GlobalWebView2Loader.UserDataFolder :=
  //  UTF8Decode(ExtractFileDir(Application.ExeName) + '\CustomCache');

  GlobalWebView2Loader.AllowFileAccessFromFiles := True;
  GlobalWebView2Loader.StartWebView2;

end.
