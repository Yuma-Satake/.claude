# Git操作規約

## General Principles

- ユーザの指示がないのにcommitやpushを絶対に行わないこと

## Branching

- 新規タスクに着手する前に、現在のブランチが今回のタスク専用かを確認する（`git branch --show-current` と `git log --oneline -5` で直近コミットの目的を見る）。作業ツリーがクリーンでも、既にマージ済みのPRに対応するブランチや別目的の既存ブランチをチェックアウトしたまま作業を始めると、無関係な変更が同じブランチに混在する。目的が異なる／不明な場合は、ベースブランチ（各リポの既定ブランチ）から新規ブランチを切ってから実装を始める
- ファイルの編集を伴う作業時に、すでにdiffのあるファイルが存在している場合、他のエージェントが実装を行なっている可能性があるため、stashしたりブランチを切り替えたりせず、ユーザにworktreeを作成するか確認してから作業すること

## Commit / Staging

- git管理されたファイルのリネーム・移動には `git mv` を使用
- 内容がほぼ同じファイルを別名で置き換える場合、旧ファイルの削除と新ファイルの作成を別々に行わず、`git mv` で旧ファイルをリネームしてから内容を編集し、差分を最小限にすること

## Merge / Rebase

- マージ・リベースでコンフリクトを解消した後は、コンフリクトマーカーの消し忘れがないか確認するだけでなく、build・testを実行して解決内容に異常が無いかを検証してからコミットすること。構文的にマージできていても、両ブランチの変更が意味的に矛盾したまま残ることがある

## Stash

- 未コミットの変更を別ブランチ・別worktreeに一時退避する場合、仮コミットを作らずstashを使うこと。git stashのスタックはメインチェックアウトと全worktreeで共有され他セッションが同時にpush/popしうる（bareな`git stash`/`git stash pop`/`git stash save`はPreToolUseフック`~/.claude/hooks/block-bare-git-stash.sh`でブロックされる）ため、`git stash push -u -m "<一意なタグ>"`で退避し、直後にSHAを記録する。`git stash list --format='%H %gs'`はハッシュ列が空になり機能しないことがあるため、`git rev-parse stash@{0}`で直接SHAを取得する方を使う。`git stash apply <sha>`（popではない）で復元する。使用後はそのエントリを削除するが、`git stash drop`はコミットSHAを受け付けず`stash@{n}`形式の参照が必要なため、`git stash drop <sha>`は失敗する。`git stash list`で該当エントリの`stash@{n}`インデックスを特定し（記録したSHAやメッセージと突き合わせる）、`git stash drop stash@{n}`で削除する
- 未コミットの変更が残っている状態での`git switch`はPreToolUseフック（`~/.claude/hooks/block-dirty-git-switch.sh`）でブロックされる。ただし、切り替え前にworking treeの内容を`git show HEAD:<path> > <path>`等で元に戻す操作を挟むと、working treeの内容が切り替え先のHEADと偶然一致し、フックのdirty検知をすり抜けて`git stash apply`で復元した変更が跡形もなく消失することもある。この操作は避けること

## Worktree

- worktreeの作成・切り替え・削除には`git worktree add`等を直接使わず、EnterWorktree/ExitWorktreeツールを使うこと。Bashで`git worktree add`等を直接実行しようとするとPreToolUseフック（`~/.claude/hooks/block-git-worktree.sh`）がブロックし、EnterWorktreeを使うよう促す。EnterWorktree・Agentツールの`isolation: "worktree"`はWorktreeCreate/WorktreeRemoveフック（`~/.claude/hooks/worktree-create-wt.sh`・`worktree-remove-wt.sh`）経由の処理に差し替えられており、gitignore対象のファイル（`.env`・`node_modules`等untrackedなもの）が自動コピーされるため、手動でのコピー確認は不要。依存関係のロックファイルに差分がある場合など、コピーだけでは不十分で再インストールが必要になるケースがあることには注意する
- 既存ブランチ（他人のPRのheadRefName等）をworktreeでチェックアウトしたい場合は、`EnterWorktree`の`name`にそのブランチ名をそのまま渡す。`worktree-create-wt.sh`が、ローカルブランチまたはリモート追跡ブランチと名前が一致すればそのブランチをチェックアウトし、一致しなければ新規ブランチを作る。リモートにしかないブランチは、先に`git fetch origin <ブランチ名>`で追跡ブランチを取得しておく。そのブランチが既に別のworktreeでチェックアウト済みの場合はエラーになるため、`path`引数で切り替える
- `EnterWorktree`は`path`引数で既存worktreeへの切り替えにも使えるが、現在セッションが「既にworktree内にいる状態」から呼ぶと、切り替え先が`.claude/worktrees/`配下のworktree（Claude Code自身が作成したもの）でない限り拒否される。`open-feature`等のスキルが`git worktree add`で作った`.claude/worktrees/`配下ではないworktree（プロジェクト独自の命名規則のディレクトリ等）へ切り替えたい場合は、まず`ExitWorktree`（`action: "keep"`）で元のディレクトリに戻り、そこから改めて`EnterWorktree(path: <対象>)`を呼ぶ。「launchディレクトリからの初回entry」であれば、対象リポの`git worktree list`に登録されている任意のworktreeへ切り替えられる

## GitHub (issue / PR)

- GitHub issueやPRの編集（コメント追加・タイトル変更・説明更新等）を行う前に、必ず `gh` コマンドで最新の状態をfetchし、更新がないか確認してから操作を行うこと
- forkしたリポジトリで作業する場合、`git remote -v` でupstreamが設定されているか確認し、未設定であれば `gh repo view --json parent` でfork元を特定してupstreamの追加を提案すること

## Image Attachments on GitHub

issueやPRの本文・コメントに画像を貼り付ける場合は、`tool-gh-image` skillを必ず使用する。
