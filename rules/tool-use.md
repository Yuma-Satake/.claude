# ツールを使用する際に守るべきルール

- ユーザに確認をする必要がある場合には、絶対にAskUserQuestionToolを使用すること
- リサーチのためのスクリプトの実行などはユーザに確認をせず、積極的に自身で実行し、状況の把握に努めること
- スクリプトはバックエンドで実行すること
- PDFファイルの読み取りにはReadツールを使用すること（他のツールは使わない）
- 勝手にツールはダウンロードせず、必要な場合はユーザに確認を取ること
- 一時的にインストールしたツールは、作業が終わったらアンインストールすること
- BASH_MAX_OUTPUT_LENGTHを絞っているので、出力が多くなりそうなコマンドは事前にhead/tail/grep等で絞り込んでから実行すること
- Readツールでファイル全体を読まず、必要な範囲がわかっている場合はoffset/limitパラメータで対象範囲のみ読むこと
- Grepツールはまずデフォルトのfiles_with_matchesモードで該当ファイルを絞り込み、内容確認が必要な場合のみcontentモードに切り替えること。ヒット件数が多い場合はhead_limitで絞ること
- 上記いずれのツールでも、出力が大量になると予想される場合は先に絞り込み条件（正規表現・範囲・件数上限）を検討してから実行すること
- `git reset`（`--hard`/`--soft`問わず）は権限設定によって実行がユーザーに拒否され続けることがある。resetが必要な場面（ブランチの起点修正、一時コミットの取り消しなど）では、resetを使わない代替手段（例: `git switch --detach <target> && git branch -f <branch> <target> && git switch <branch>`）を優先する。それでも解消できない場合は同じコマンドを繰り返し試行せず、ユーザーに`! <command>`形式での実行を依頼する
- バックグラウンドで実行中のAgent等の完了を待つ目的だけで`ScheduleWakeup`を使わないこと。完了時はtask-notificationで自動的に通知されるため、待機目的の呼び出しは不要かつ意図しない自律ループの誤発火を招く
- 未コミットの変更を別ブランチ・別worktreeに一時退避する場合、ユーザー確認なしに仮コミットを作らず、stashを使うこと。git stashのスタックはメインチェックアウトと全worktreeで共有され他セッションが同時にpush/popしうるため、bare `git stash`/`git stash pop`は使わない。`git stash push -u -m "<一意なタグ>"`で退避し、直後に`git stash list --format='%H %gs'`でSHAを記録し、`git stash apply <sha>`（popではない）で復元する。使用後はそのエントリを削除するが、`git stash drop`はコミットSHAを受け付けず`stash@{n}`形式の参照が必要なため、`git stash drop <sha>`は失敗する。`git stash list`で該当エントリの`stash@{n}`インデックスを特定し（記録したSHAやメッセージと突き合わせる）、`git stash drop stash@{n}`で削除する
