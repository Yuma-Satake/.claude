---
name: hunk-check
description: 現在作業中のworktreeに対応するHunkセッションからユーザーコメントを回収し、指摘への対応・検証・対応済み注記まで行う。「Hunkのコメントを確認して対応して」「Hunkの指摘を回収して直して」「hunk-checkして」と依頼された場合に使用する。
---

# hunk-check

現在作業中のworktreeに対応するHunkセッションから、ユーザーがHunk上で付けたコメントを回収し、すべての指摘への対応と検証まで行う。

## 実行時コンテキスト

以下の前処理で、現在のworktreeに一致するライブHunkセッションとユーザーコメントを注入する。

```!
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$repo_root" ]; then
  printf '%s\n' 'error: not-git-repository'
  exit 0
fi

if ! session_list="$(hunk session list --json 2>&1)"; then
  printf 'repoRoot: %s\nerror: hunk-session-list-failed\ndetail: %s\n' "$repo_root" "$session_list"
  exit 0
fi

if ! matching_sessions="$(printf '%s' "$session_list" | jq -c --arg root "$repo_root" '[.sessions[] | select(.repoRoot == $root) | {sessionId, title}]' 2>&1)"; then
  printf 'repoRoot: %s\nerror: invalid-hunk-session-list\ndetail: %s\n' "$repo_root" "$matching_sessions"
  exit 0
fi

matching_count="$(printf '%s' "$matching_sessions" | jq 'length')"
printf 'repoRoot: %s\nmatchingSessionCount: %s\n' "$repo_root" "$matching_count"

tab="$(printf '\t')"
printf '%s' "$matching_sessions" | jq -r '.[] | [.sessionId, .title] | @tsv' |
while IFS="$tab" read -r session_id title; do
  if user_comments="$(hunk session comment list "$session_id" --type user --json 2>&1)"; then
    printf 'sessionId: %s\ntitle: %s\nuserComments: %s\n' "$session_id" "$title" "$user_comments"
  else
    printf 'sessionId: %s\ntitle: %s\nerror: hunk-comment-list-failed\ndetail: %s\n' "$session_id" "$title" "$user_comments"
  fi
done
```

## 手順

1. 注入されたセッションとユーザーコメントを確認する。前処理が無効化または失敗している場合だけ、同じ情報をBashツールで取得する
2. 各コメントについて対象ファイルと周辺コードを確認し、指摘の意図と必要な対応（コード修正・説明・対応不可）を判断する
3. コード修正が必要な場合は、変更対象に応じたコーディング規約Skillを読み込み、コード・テスト・ドキュメント・設定・Skillなど必要な箇所を修正する
4. 同じ種類の問題が変更差分内のほかの箇所にもないか検索し、該当箇所をまとめて修正する
5. 編集を行った場合は、対象の各Hunkセッションに対して `hunk session reload <session-id> -- diff` を実行し、変更後の差分を再読み込みする
6. 対応内容を対象ごとに検証する。コード変更では関連する最小のテスト・ビルド・lintを実行する
7. `hunk session comment list <session-id> --type all --json` で既存注記を確認する
8. 各ユーザーコメントについて、元コメントと同じファイル・同じ側・同じ開始行へ `hunk session comment add` で以下のいずれかの返信注記を追加する
   - コード修正コメント: 対応と検証が成功したら対応済み注記を追加する
   - 説明を求めるコメント: 説明注記を追加する
9. 全コメントについて、対応内容と結果を最終報告する

## セッションが見つからない場合

現在のworktreeに対応するライブセッションがないことを伝え、ユーザーにそのworktreeで `hunk diff` を起動してもらう。別のworktreeやリポジトリのセッションからコメントを回収しない。

## 対応方針

- コメントの文面だけで判断せず、対象行と周辺コードを確認して根本原因に対応する
- 指摘が「これ何？」「なぜ」「どうして」「説明して」など理解のための説明を求めているだけの場合は、コードやドキュメントを変更せず、意図や背景を元コメントと同じ差分位置に説明注記としてHunkコメントで返信する。最終報告本文で長々と説明せず、要点のみに留める
- 指摘が規約や再発防止策への反映を求めている場合は、該当するSkillや設定も更新する
- 複数コメントが同じ原因を指している場合は、一貫した修正としてまとめて対応する
- 指摘同士が矛盾し、解消に重要な仕様判断が必要な場合は、推測で変更せずAskUserQuestionToolで確認する
- 指摘が現在のコードに適用できない場合は変更せず、最終報告に理由を記載する
- コメントの対象外にある無関係な変更は行わない

## 返信注記

Hunkには返信スレッドやresolve状態がないため、返信は元コメントと同じ差分位置に並ぶ独立したエージェントコメントとして追加する。返信注記には対応済み注記と説明注記の2種類がある。

### 共通ルール

- `newRange` がある場合はその先頭を `--new-line`、なければ `oldRange` の先頭を `--old-line` に指定する
- `--author` は `hunk-check` とする
- `--rationale` の先頭に `source-note: <元コメントのnoteId>` を記載する
- `--summary`・`--rationale` には、紐づく元コメント1件に対する内容のみを書く。他のコメントへの言及や、複数コメントをまとめた全体的な内容・総括は書かない
- 既存コメントのうち、`author` が `hunk-check` かつ `body` に同じ `source-note: <noteId>` を含むものがある場合は重複追加しない。`comment list` では追加時のsummaryとrationaleが`body`へ結合される
- 元の差分位置がHunk上から消えて注記を追加できない場合は、別の位置へ付け替えず最終報告に理由を記載する
- 注記追加時に `--focus` は指定せず、ユーザーの表示位置を変更しない

### 対応済み注記（コード修正コメント用）

- `--summary` は `対応済み: <実施した変更>`
- `--rationale` には元コメントの `source-note` に続けて、必要に応じて対応理由や補足を記載する
- lint・テスト・ビルドの通過や実行結果などの検証内容は注記本文に記載しない。検証結果は最終報告にのみ記載する
- 対応と検証の両方が成功したコメントにだけ追加する。未対応、部分対応、検証失敗には追加しない

### 説明注記（説明を求めるコメント用）

- `--summary` は `説明: <要点1行>`
- `--rationale` には元コメントの `source-note` に続けて、根拠となる該当コード・型・設計上の理由を簡潔に記載する
- コード修正が発生しないコメントに対して追加する
- 「説明できません」「わかりません」といった内容は書かない。説明できない場合は注記を追加せず、最終報告に理由を記載する

## 最終報告

実施した変更、Hunkのリロード結果、検証結果、返信注記（対応済み注記・説明注記）の追加結果を簡潔に報告する。説明注記を追加した場合、報告本文には説明内容を再掲せず、注記を追加したファイル・行のみを列挙する。対応・説明のいずれもできなかったコメントがある場合に限り、対象箇所と理由を明記する。コメントが0件の場合は変更を行わず、その旨を明示する。

## 制約

- Hunkコメントの削除、編集、クリアを行わない
- 対応済み注記・説明注記以外のHunkコメントを追加しない
- Hunkの表示位置を変更しない
- このSkillではコミットやpushを行わない
- 対応が完了する前に、コメントの一覧を報告するだけで終了しない
