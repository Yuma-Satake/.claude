# Git操作規約

- ユーザの指示がないのにcommitやpushを行わないこと
- ブランチの切り替え/新規作成においては絶対に `git checkout` ではなく必ず `git switch` を使用すること
- ファイルのリネーム・移動には絶対に `git mv` を使用すること（git管理されているファイルのみ）
- 内容がほぼ同じファイルを別名で置き換える場合、旧ファイルの削除と新ファイルの作成を別々に行わず、`git mv` で旧ファイルをリネームしてから内容を編集し、差分を最小限にすること
- GitHub issueやPRの編集（コメント追加・タイトル変更・説明更新等）を行う前に、必ず `gh` コマンドで最新の状態をfetchし、他者による更新がないか確認してから操作を行うこと
- forkしたリポジトリで作業する場合、`git remote -v` でupstreamが設定されているか確認し、未設定であれば `gh repo view --json parent` でfork元を特定してupstreamの追加を提案すること
- マージ・リベースでコンフリクトを解消した後は、コンフリクトマーカーの消し忘れがないか確認するだけでなく、可能であればビルド・テストを実行して解決内容がロジックとして正しいかを検証してからコミットすること。構文的にマージできていても、両ブランチの変更が意味的に矛盾したまま残ることがある
- `git add <path1> <path2> ...` で複数パスを同時指定した場合、いずれか1つでもパスが存在しない（例: 既に `git rm` 済み、`git mv` でパスが変わっている）と、コマンド全体が失敗し他の正当なパスも一切ステージされない。複数パスを1コマンドでaddした直後は必ず `git status` でステージ結果を確認すること
- `git status --short` の2文字ステータスコードは、1文字目=index（ステージ済み）、2文字目=ワークツリー（未ステージ）で独立した意味を持つ。例えば `RM` は「rename+modified という1つの状態」ではなく「indexでは既にリネーム済みだが、ワークツリーにはさらに未ステージの変更が残っている」ことを示す。1文字ずつ分けて読むこと
- GitHub REST API（`gh api`経由も含む）でissue・PR作成時に`labels`へ未作成のラベル名を指定した場合の挙動は公式ドキュメントに明記されていない（[Create an issue](https://docs.github.com/en/rest/issues/issues?apiVersion=2022-11-28#create-an-issue)は「Only users with push access can set labels for new issues. Labels are silently dropped otherwise.」とのみ記載）。ラベルを使う自動化を組む場合は、未作成ラベル名を渡して自動作成に賭けるのではなく、事前に`gh label create`で対象ラベルを作成しておくこと

## GitHubへの画像添付

issueやPRの本文・コメントに画像を貼り付ける場合は、`tool-gh-image` skillを必ず使用する。
