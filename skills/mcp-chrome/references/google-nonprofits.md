# Google for Nonprofits 操作ナレッジ

Google for Nonprofits（www.google.com/nonprofits）のダッシュボードと、サポートの問い合わせフォーム（support.google.com/nonprofits）を Chrome MCP で操作する場合のナレッジ。

## ダッシュボードのログイン確認画面

- `https://www.google.com/nonprofits/account/?authuser=<u/Nの番号>` で開くと、「Confirm your Google account」の画面（「For new requests, this account will be added as an administrator...」）が出る。表示されたアカウントが団体の管理者アカウントであることを確認して「Continue」を押す
- 「Continue」は1回目のクリックで反応せず同じ画面のままのことがある。`tabs_context_mcp` で状態を確認し、同じボタンをもう一度押す
- 個人アカウントが選ばれている場合は「Use a different account」で管理者アカウントに切り替える。`authuser` の番号は Gmail の `u/N` と同じ並びで、ログイン中のアカウントを順に試して確認する

## Google Workspace for Nonprofits のアクティベーション

1. ダッシュボードの「Google Workspace for Nonprofits」カードの「Learn more」を開く
2. 「Does your nonprofit currently use Google Workspace?」で「Yes, we currently use Google Workspace」を選んで「Next」を押す
3. 「What is your nonprofit's domain name?」でドメイン名を入力して「Next」を押す（2026-09-06の操作にはなかった画面）
4. 「Your domain is eligible ... offered at no charge」の画面で「Activate」を押す。送信すると、ステータスが「Activation request received」になる

「Activate」は取り消せない送信なので、押す前に内容をユーザーに見せて承認を得る。却下されたときのステータスは「Your activation request needs work」で、手順2の質問が再び表示される。

## サポートの問い合わせフォーム

- URL: `https://support.google.com/nonprofits/contact/contact_us?hl=en&authuser=<番号>`。日本語表示では日本語のサポートがないとして入力欄が出ない。英語（`hl=en`）で開く
- 必須項目は、連絡先メール、氏名、法人名、Charity ID、対象プロダクト（ラジオ）、カテゴリ（チェックボックス）、本文。添付ファイルは任意
- 入力欄は `find` で取得した `ref` を指定しても反映されなかった。座標指定の `left_click` → `type` で入力できる。入力後に `screenshot` で反映を確認する
- 本文欄（Your issue or question）は1行入力で、改行を含む文字列を `type` すると、Enter で送信される。「Your email has been sent」の画面に遷移し、送信済みの内容は Gmail に控えとして届かなかった。改行を含まない1行の文章にするか、ユーザー自身に貼り付けてもらう（`browser-patterns.md` の「改行を含む文字列の入力でフォームが意図せず送信されることがある」参照）
- 添付ファイルの選択は、ユーザーがローカルのファイルを選ぶ操作になる。ファイルのパスが分からない場合はユーザー自身に添付してもらい、送信前に最終確認を取る
