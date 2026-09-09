---
name: hunk-open-pr
description: Herdr環境で、指定したGitHub PRの全diffをローカルのHunkペインに表示する。PRのURLからowner/repo/番号を解析し、ワークスペース内で対応するローカルリポジトリ（root/submodule/その兄弟worktree）を特定し、PRのbase/headをfetchしてhunk diffで開く。右側にまだ無ければ起動し、既に起動していれば表示対象を照合してリロードまたは再起動する。ユーザーがGitHubのPR URLを渡し「このPRの差分を見せて」「このPRをHunkで開いて」などと依頼した場合に使用する。ローカルの未コミット差分を見せる場面ではhunk-openを使う（本skillの対象ではない）。Herdr環境でない場合は何もしない。
argument-hint: "[pr-url]"
---

対象PRのURLからowner/repo/PR番号を解析し、ローカルリポジトリの特定・PRのbase/head取得・Hunkペインの起動/リロード/再起動までを1本のスクリプトで行う。判定ロジック・除外理由はスクリプト内コメントを参照する（ここには書かない）。

## 引数

$ARGUMENTS

- `$0`: 対象PRのURL（`https://github.com/<owner>/<repo>/pull/<number>` の形式。`/files`等の付加パスがあっても番号部分だけを解析するので構わない）

## 実行

以下の前処理で、渡されたPRのdiffをHunkペインに表示する。

```!
bash ~/.claude/skills/hunk-open-pr/scripts/hunk_open_pr.sh --pr-url "$0"
```

前処理が無効化または失敗している場合だけ、`bash ~/.claude/skills/hunk-open-pr/scripts/hunk_open_pr.sh --pr-url "$0"` をBashツールで実行し同じ結果を取得する。

標準出力の最後の1行をそのままユーザーに報告する。これはグローバル言語ルール（常に日本語で応答する）に対する明示的な例外であり、再要約・再翻訳しない。

## 前提

- `gh` コマンドで対象リポジトリにアクセス可能であること（未認証・権限不足の場合は失敗する）。
- 対象リポジトリが、このワークスペース内にローカルクローンとして存在すること（root・submodule・その兄弟worktreeのいずれか）。見つからない場合は失敗する。
