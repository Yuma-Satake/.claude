# Gmail 操作ナレッジ

Gmail（mail.google.com）を Chrome MCP で操作する場合のナレッジ。

## メッセージパーマリンクからスレッドを開く

`https://mail.google.com/mail?extsrc=sync&client=docs&plid=...` 形式のメッセージパーマリンク（Gmail APIの`GmailThread#getPermalink()`等で取得できるもの）は、`navigate`で開くと認証済みのGmailセッション上でそのまま該当スレッドへ直接遷移する。遷移後のURLは `https://mail.google.com/mail/u/<index>/?...&th=<threadId>&search=all` のように、ログイン中の複数アカウントのうち実際にそのメールが届いたアカウントの `u/<index>` パスに解決される。

複数のGoogleアカウントでログインしている場合、`u/<index>` の値でどのアカウントのメールボックスが開かれたかを判別できる。返信メールを送信する場面では、送信元（From）がそのアカウント・宛先エイリアスと一致しているかを送信前に確認すること。
