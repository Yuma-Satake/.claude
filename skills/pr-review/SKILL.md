---
name: pr-review
description: GitHub PRまたはローカルの変更差分をコーディング規約に従ってレビューする。ユーザーが「PRをレビューして」「#123をレビューして」「今の変更をレビューして」「このPRをチェックして」と依頼した場合に使用する。引数にPR番号を取り、指定があればそのPRの差分を、省略した場合はデフォルトブランチとのローカルの差分（未コミット含む）を対象にする。coding-standards/coding-architectureを常に含め、それ以外のレビュー用skillは変更内容に応じてAIが自動選定（選定結果はユーザに報告）し、skillごとにcode-reviewer agentを並列起動して指摘を収集・報告する。他人のPRの場合は報告のみで終える。自分のPR、またはローカル差分の場合は、指摘への修正・再レビューのサイクルを回すか報告のみで終えるかをAskUserQuestionで確認する。
argument-hint: "[pr-number]"
---

# pr-review

引数: $ARGUMENTS

引数の解釈:

- PR番号: 引数がPRのURLならURL末尾の番号、そうでなければ引数中の最初の数値トークン。以下 `<PR番号>` と表記する
- 対象リポジトリ: 引数がPRのURLならURL中の `owner/repo`。URLでない場合のみ「現在のGit状態」のリポジトリを使う。以下 `<owner>/<repo>` と表記する
- 引数なし: ローカルの変更差分（現在のブランチとデフォルトブランチの差分、未コミット含む）を対象にする

以降 `gh` は常に `-R <owner>/<repo>` で対象リポジトリを明示する。マルチリポ構成では、カレントディレクトリが対象PRとは別のリポジトリ（ワークスペースのルート等）であることがある。「対象PRの情報」が `PR番号指定なし` と表示されていても、引数にPR番号またはPR URLが含まれているなら指定ありとして扱い、`gh pr view <PR番号> -R <owner>/<repo>` で取得し直してから進める。

## 現在のGit状態

- デフォルトブランチ: !`git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'`
- 現在のブランチ: !`git branch --show-current`
- リポジトリ: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "不明"`
- 現在の認証ユーザー: !`gh api user --jq .login 2>/dev/null || echo "不明"`

## 対象PRの情報

!`u=$(echo "$ARGUMENTS" | grep -oE 'github\.com/[^/]+/[^/]+/pull/[0-9]+' | head -1); if [ -n "$u" ]; then n=$(echo "$u" | grep -oE '[0-9]+$'); r=$(echo "$u" | sed -E 's#github\.com/([^/]+)/([^/]+)/pull/[0-9]+#\1/\2#'); else n=$(echo "$ARGUMENTS" | tr ' ' '\n' | grep -m1 -E '^[0-9]+$'); r=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); fi; if [ -n "$n" ]; then echo "repo: $r"; gh pr view "$n" -R "$r" --json title,author,baseRefName,headRefName --jq '"title: " + .title + " / author: " + .author.login + " / base: " + .baseRefName + " / head: " + .headRefName' 2>/dev/null || echo "PR #$n が見つかりません"; else echo "PR番号指定なし（ローカルdiffを対象）"; fi`

- PR番号を指定したがPRが見つからない場合、ユーザに番号の確認を求めて終了する

## 1. レビュー対象の差分を確定する

作業ツリー・現在のブランチには一切手を加えない（`git checkout` / `gh pr checkout` 等でのブランチ切り替えは行わない）。

### PR番号が指定されている場合

- `git fetch --force origin pull/<PR番号>/head:refs/pr-review/<PR番号>` でPRの内容を一時refとして取得する
- `git fetch origin <PRのbaseRefName>` でベースブランチを最新化する
- 差分は `git diff $(git merge-base refs/pr-review/<PR番号> origin/<PRのbaseRefName>) refs/pr-review/<PR番号>` で確認する（baseRefNameは「対象PRの情報」で取得した値を使う。デフォルトブランチに固定しない）
- 差分が空の場合は「差分なし」をユーザに報告してここで終了する
- PRのauthorが「現在の認証ユーザー」と一致するかどうかを控えておく（後述の対応方針の分岐で使う）

### PR番号が指定されていない場合

- `git fetch origin <デフォルトブランチ>` でデフォルトブランチを最新化する
- 差分は `git diff $(git merge-base origin/<デフォルトブランチ> HEAD)` で確認する（マージベースからの差分。未コミットの変更も含む）
- 差分が空の場合は「差分なし」をユーザに報告してここで終了する
- 常に「自分の変更」として扱う（後述の対応方針の分岐で「自分のPR」と同様に扱う）

## 2. レビュー用skillの選定

- レビュー用skillには **coding-standards を常に無条件で含める**。言語・フレームワーク・レイヤーを問わず適用される規約であるため、必ず含める
- レビュー用skillには **coding-architecture も原則含める**。変更差分が特定の単一層にとどまるなど、関心の分離・DRY原則の観点からどう見ても不要と判断できる場合に限り、含めないことができる
- 上記2つ以外の追加skillは、ユーザに確認せず、変更ファイルの言語・フレームワーク・レイヤー・変更の性質（機能追加/バグ修正/リファクタ）からAIが推論して選定する
- PR番号省略時（ローカルdiff）で `coding-regression` を選定skillに含める場合、対象のissue番号またはNotionページのURLを確認する。ローカルdiffでの変更は基本的に既存のissue・Notionタスクを元に実装しているため、この参照を必須情報として扱う（自由入力のため通常のテキストで確認し、AskUserQuestionは使わない）
  - 参照が得られない場合、ユーザに確認せず `coding-regression` を選定skillから外す
- 決定したレビュー用skillの一覧、`coding-architecture` を除外した場合はその判断根拠、`coding-regression` を除外した場合はその理由を、3.でcode-reviewer agentを起動する前に通常のテキスト出力でユーザに報告する

## 3. レビュー実行

決定したskillごとに **code-reviewer agentを1体ずつ並列起動** する（同一メッセージ内で複数Agent呼び出し）。code-reviewer agentは1体につき最大1 skillしかロードできないため、skillの数だけcode-reviewerを起動する。

各code-reviewerへの指示には以下を含める：

- レビュー対象の差分の確認方法
  - PR番号指定時: `refs/pr-review/<PR番号>` にPRの内容を取得済みである旨、差分は `git diff $(git merge-base refs/pr-review/<PR番号> origin/<PRのbaseRefName>) refs/pr-review/<PR番号>` で確認できる旨、変更ファイルの全文は `git show refs/pr-review/<PR番号>:<path>` で参照できる旨
  - PR番号省略時: 現在のディレクトリの `git diff $(git merge-base origin/<デフォルトブランチ> HEAD)` で確認できる旨
- 変更の概要（わかる範囲で）
- 割り当てるskill名（1体につき1skillのみ）
- 今回並列起動する全code-reviewerへの割り当てskill名の一覧
- `coding-regression` を割り当てる場合、PR番号省略時（ローカルdiff）は2.で確認したissue番号またはNotionページのURL
- 「このタスクの調査・実行にあたって追加のエージェントを起動しないこと」
- 「ReportFindingsツールで指摘を報告すること。ReportFindingsが見つからない場合はToolSearchで探さず、直接プレーンテキストで報告してよい」

## 4. 指摘の集約

- 全code-reviewerの結果を回収し、重複する指摘は1件にまとめる
- 必須修正 → 推奨 → 確認事項の順に整理し、ユーザに報告する

## 5. 対応方針の分岐

- **他人のPR**（PR番号指定時、authorが「現在の認証ユーザー」と異なる場合）: 指摘一覧を報告して終了する。修正ループは行わず、AskUserQuestionでの確認もしない
- **自分のPR**（PR番号指定時、authorが「現在の認証ユーザー」と一致する場合）、または **ローカル差分**（PR番号省略時）: 指摘一覧を報告した上で、**AskUserQuestion** で「指摘への修正・再レビューのサイクルを回すか、報告のみで終えるか」を確認する
  - 修正ループを回す場合:
    - PR番号指定時のみ: 修正はこの一時ref上ではなく実際のブランチに対して行う必要があるため、現在のブランチが対象PRの `headRefName` と一致するか確認する
      - 一致しない場合、修正は行わない。現在のブランチに手を加えず、`wt switch <headRefName>`（ローカルにブランチが存在しない場合は先に `git fetch origin <headRefName>:<headRefName>`）で別のworktreeを作成し、そのパスを基準に修正・再レビューを進める（既存チェックアウトを別ブランチに切り替えずに済む）。この場合も一時refは6.に従って削除する
      - 一致する場合、`git update-ref -d refs/pr-review/<PR番号>` で一時refを直ちに削除する。これ以降の再レビューは作業ツリーが正になるため、code-reviewerへの差分確認方法を `git diff $(git merge-base origin/<PRのbaseRefName> HEAD)` に切り替える（一時refは既に削除済みのため参照させない）
    - 指摘に対応する → 該当skillのcode-reviewer agentを再度並列起動して再レビューを依頼する → 指摘がなくなるまで繰り返す。指摘内容のうち判断・意思決定が必要な事項は、推奨の対応が判断できる場合はその推奨で対応し、判断できない場合はAskUserQuestionで確認する
    - 2周目以降の再レビューでは、各code-reviewerのプロンプトに「採らないと判断した指摘」を明示的なリストとして渡す。ユーザーが却下したものだけでなく、自分の判断で見送ったものも必ず含める。渡さないと、前の周で意図して採らなかった選択（文言・重複の許容・設計判断など）を毎周蒸し返され、収束しない
    - 指摘に対応する際、code-reviewerが示した行番号や「本PRで追加された行」という帰属をそのまま信じて編集しない。対象行が実際にレビュー範囲の差分に含まれるかを `git diff` で確認してから着手する。既存行を変更対象と誤認すると、スコープ外の変更が混入する
    - 収束判定は「起動した全skillで必須修正0件」とする。推奨・確認事項が残っていても、必須修正が0件になったらループを終える
  - 報告のみを選んだ場合: そのまま終了する

## 6. 一時refの後始末（PR番号指定時のみ）

以下のいずれかで終了する場合、`git update-ref -d refs/pr-review/<PR番号>` で一時的に作成したrefを削除する（5.で既に削除済みの場合は不要）。

- 差分なしで1.の時点で終了した
- 他人のPRとして報告のみで終了した
- 自分のPRで報告のみを選んで終了した
- ブランチ不一致で修正を行わず終了した

## 完了時の報告

以下をユーザに報告する。

- レビュー対象（PR番号、またはローカルdiffである旨）
- 使用したレビュー用skill一覧
- 指摘内容（必須修正/推奨/確認事項別）
- 対応方針（報告のみ／修正ループ実施）とその結果

修正ループを実施した場合は、報告の前にPR本文・タイトルが修正後の実装と食い違っていないか確認する。ループ中に識別子名・DOM構造・表示文言・定数値を変えた場合、PR本文の説明やスクリーンショットが古いまま残る。
