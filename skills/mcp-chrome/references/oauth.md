# OAuth 認証操作ナレッジ

Google / X（Twitter）/ Apple などの OAuth プロバイダ経由のログインを Chrome MCP で操作する場合の共通ナレッジ。

## ポップアップの問題

OAuth 認証ボタン（Google・X・Apple など）は `window.open()` で新規ウィンドウを開くため、Chrome 拡張機能の制約により `left_click` 時に **「Detached while handling command」** エラーが発生する。

## 回避策: 同タブで OAuth URL を開く

クリック前に `javascript_tool` で `window.open` をオーバーライドし、OAuth URL を同タブでリダイレクトさせる:

```js
window.open = function(url, ...args) {
  window.location.href = url;
  return { closed: false, focus: () => {}, close: () => {} };
};
```

オーバーライド後は JavaScript からボタンをクリックする:

```js
document.querySelector('button[aria-label="X"]').click();
```

`computer` ツールの座標クリックではタイミング的に間に合わない場合があるため、JS クリックを優先する。

## アカウント不一致への対処

OAuth ページで、既存ログイン中のアカウントと操作対象アカウントが異なる場合がある。

- このまま進めると **意図しないアカウントでログインしてしまう**
- **キャンセルして別の認証方法（メール/ID + パスワード）に切り替える**
- ID/パスワードでのログインではパスワードはユーザーに手入力してもらう

## プロバイダ別の特記事項

### X（Twitter）OAuth

- note や他の X 連携サイトでも上記ポップアップ制限に引っかかりやすい
- 個人アカウントでログイン中なのに別のアカウントで認証したい場合は、必ずキャンセルして別方法で進める

### Google OAuth

- Google Workspace のセッション状態によってはアカウント選択画面が出ない場合がある
- その場合は一度 `accounts.google.com/Logout` でログアウトしてから再試行する

## デバッグのコツ

- オーバーライドが効いているかは `JSON.stringify({ open: window.open.toString().slice(0,100) })` などで確認する
- OAuth 後のリダイレクト先が想定と違う場合は、URL を `console.log(window.location.href)` で都度確認する
