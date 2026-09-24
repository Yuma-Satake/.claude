# Google Analytics（analytics.google.com）

## プロパティ作成ウィザード完了直後のストリーム行クリックで Permission Denied

「Start collecting data」画面（プロパティ作成ウィザードのStep 4）でストリーム行を直接クリックしてストリーム詳細を開こうとすると `Permission Denied` トーストが出て遷移に失敗することがある。この場合はウィザードの「Next」でウィザードそのものを完了させ、通常の管理画面（データストリーム一覧）から改めてストリーム行を開くと遷移できる。

## 測定ID（G-から始まるID）の確認場所

測定IDはストリーム詳細画面に直接表示されない。ストリーム詳細 →「View tag instructions」→「Install manually」タブを開くと、`gtag('config', 'G-XXXXXXXXXX')` を含むGoogleタグ（gtag.js）のスニペットが表示され、ここで測定IDを確認できる。CMSやウェブサイトビルダーを使わない静的サイトへの組み込みでは、このタブのスニペットをそのままコピーして使う。

## 既存プロパティの用途はデータストリームURLで判別する

アカウント配下に同名または紛らわしい名前のプロパティが複数存在する場合、プロパティ名だけでは対象サイト用かどうか判断できないことがある（例:「My portfolio」という名前だが実際のストリームURLは `*.myportfolio.com` で別サービスだった）。対象サイト用の既存プロパティが既にあるかを確認する際は、プロパティ名の一致だけで判断せず、管理画面の「Data streams」でストリームURLまで確認すること。

## gtag導入後の動作確認手順

サイトへのタグ組み込み後、GA管理画面上の「No data received in past 48 hours.」は反映まで時間がかかるため即時の確認には使えない。代わりにローカルで以下を確認する。

1. 組み込んだページをローカルサーバー（`python3 -m http.server` 等）で配信し、ブラウザで開く
2. `read_network_requests`（`urlPattern: "google"` 等で絞り込み）で `googletagmanager.com/gtag/js?id=<測定ID>` へのリクエストが `statusCode: 200` で成功しているか確認する。ネットワーク監視はツール呼び出し後に開始されるため、初回呼び出しで0件なら一度リロードしてから再取得する
3. `javascript_tool` で `window.dataLayer` が配列であること、`window.gtag` が関数であることに加え、`dataLayer` の中身に `gtag('config', ...)` の呼び出しが実際に積まれているかを確認する
4. `read_console_messages` でエラー・警告が出ていないか確認する（コンソール監視も同様にツール呼び出し後に開始されるため、必要ならリロードして再取得する）
