unit PreviewUnit;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  LCLType, LCLIntf, ExtCtrls, StdCtrls, Windows;

type

  { TPreviewForm }

  TPreviewForm = class(TForm)
    Image1: TImage;
    Label1: TLabel;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    FParentHWND: HWND;
    FImagePath: string;
    FSSaverName: string;
    procedure SetImagePath(const imgPath: string);
    procedure UpdateLabel;

  protected
    procedure WndProc(var Message: TMessage); override;
  public
    procedure EmbedIntoParent(pHWND: HWND);
    property SSaverName: string read FSSaverName write FSSaverName;
    property ImagePath: string read FImagePath write SetImagePath;

  end;

var
  PreviewForm: TPreviewForm;

implementation

{$R *.lfm}

{ TPreviewForm }

{ キーが押された時の処理 }
procedure TPreviewForm.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if FParentHWND <> 0 then
    Exit;

  // 開発用。ESCキーが押さえたら終了
  if Key = VK_ESCAPE then
    Application.Terminate;
end;

{ フォーム生成時処理 }
procedure TPreviewForm.FormCreate(Sender: TObject);
begin
  Timer1.Interval := 100;
  Timer1.Enabled := True;
end;

{ フォームが表示された時の処理 }
procedure TPreviewForm.FormShow(Sender: TObject);
begin
  BorderStyle := bsNone;
  Left := 0;
  Top := 0;
  Width := 152;
  Height := 112;

  UpdateLabel;
end;

{ 一定時間毎に行う処理 }
procedure TPreviewForm.Timer1Timer(Sender: TObject);
begin
  // 一定時間毎に自身が消えるべきかチェックする
  if (FParentHWND <> 0) and (not Windows.IsWindow(FParentHWND)) then
  begin
    // 親ウインドウが存在していないので終了
    Application.Terminate;
  end
  else if not Windows.IsWindowVisible(self.Handle) then
  begin
    // 自分が非表示にされているなら終了
    Application.Terminate;
  end;
end;

{ 親ウインドウを指定された時の処理 }
procedure TPreviewForm.EmbedIntoParent(pHWND: HWND);
var
  R: TRect;
begin
  FParentHWND := pHWND;
  if pHWND <> 0 then
  begin
    //Self.ParentWindow := pHWND;

    // フォームの拡張スタイルから「タスクバー表示フラグ」を除去して
    // 「ツールウィンドウ」属性を付与
    SetWindowLong(Handle, GWL_EXSTYLE,
      (GetWindowLong(Handle, GWL_EXSTYLE) and not WS_EX_APPWINDOW) or WS_EX_TOOLWINDOW);

    // フォームのスタイルを「子ウィンドウ」化してタイトルバーなどを除去
    SetWindowLong(Handle, GWL_STYLE,
      (GetWindowLong(Handle, GWL_STYLE) or WS_CHILD) and not
      (WS_POPUP or WS_CAPTION or WS_THICKFRAME));

    // 親ウィンドウをプレビュー枠に設定
    Windows.SetParent(Handle, FParentHWND);

    // サイズ合わせ
    Windows.GetClientRect(FParentHWND, @R);
    SetBounds(0, 0, R.Right, R.Bottom);

    // 表示。これでLCLの描画サイクルが正常に回る
    Self.Visible := True;
  end;
end;

{ Windowsからのメッセージを処理 }
procedure TPreviewForm.WndProc(var Message: TMessage);
begin
  //Windowsから閉じろとメッセージが来ているなら終了
  case Message.Msg of
    WM_CLOSE, WM_DESTROY, WM_NCDESTROY:
    begin
      Application.Terminate;
    end;
  end;

  inherited WndProc(Message);
end;

{ フォームが非表示になった時の処理 }
procedure TPreviewForm.FormHide(Sender: TObject);
begin
  Application.Terminate;
end;

{ 画像ファイルのパスが .lpr 側から指定された時の処理 }
procedure TPreviewForm.SetImagePath(const imgPath: string);
begin
  FImagePath := imgPath;
  UpdateLabel;
end;

{ ラベルもしくは表示画像を更新 }
procedure TPreviewForm.UpdateLabel;
begin
  if (FImagePath <> '') and (FileExists(FImagePath)) then
  begin
    // 画像を表示
    Label1.Visible := False;
    Image1.Visible := True;
    Image1.Picture.LoadFromFile(FImagePath);
    Image1.Align := alClient;
  end
  else
  begin
    // ラベルを表示
    Image1.Visible := False;
    Label1.Visible := True;
    Label1.Caption := FSSaverName;
    // Label1.Font.Color := RGB(0, 0, 0);
    Label1.Left := (ClientWidth - Label1.Width) div 2;
    Label1.Top := (ClientHeight - Label1.Height) div 2;
  end;
end;

end.
