---
name: pilot-spec
description: pilot kit の spec セッション 1cycle を実行する。要件定義フェーズ専用（phase:proposed・wait_spec_review・wait_spec_fix）。GitHub Issue を起票・仕様記入・仕様レビューまで進める。「specを回して」「要件定義を進めて」と依頼された場合、または /loop で spec セッションを常駐駆動する場合に必ず使用すること。メインセッション（ユーザとの直接の会話）でのみ有効。サブエージェント（pilot-master・pilot-pm・pilot-worker・pilot-reviewer）内からは絶対に呼び出さない。
---

# pilot-spec

pilot kit の **spec セッション** 1cycle を実行する。`/loop 30m /pilot:pilot-spec` のような長めの間隔で常駐駆動する想定。

要件定義（Issue 起票・受け入れ基準とタスクの記入・仕様レビュー）に責務を限定したセッション。実装は `pilot-coding` セッション側で行う。

## 設計意図

`pilot-spec` と `pilot-coding` を別セッションで並走させ、要件定義と実装のコンテキスト混線を防ぐ。

```
メインセッション A（spec）         メインセッション B（coding）
  └─ pilot-master                    └─ pilot-master
       └─ pilot-pm × N（specフェーズ）     └─ pilot-pm × N（codingフェーズ）
            └─ pilot-reviewer              ├─ pilot-worker
                                           └─ pilot-reviewer
```

phase 集合が排他なので同一 Issue を両セッションが同時に触ることはない。共有リソース（roadmap.md・ADR 連番・blocked:human 付与・Discord 通知）はそれぞれの pilot-master に集約される。

このスキルは pilot-master サブエージェントを spec モードで1体起動し、cycle 終了報告を受け取って終了するだけの薄いラッパーである。

## spec セッションの責務

- 担当 phase: `phase:proposed` / `phase:wait_spec_review` / `phase:wait_spec_fix`
- 未起票 Feature の逐次起票（`docs/roadmap.md` 参照）と起票後の roadmap 更新
- 仕様起源の ADR（プロダクト判断・スコープ判断）のコミット
- 上記 phase の `blocked:human` 付き Issue の裁定回収
- `phase:wait_spec_fix` で `blocked:human` 付きの Issue は、coding 側からの仕様差し戻し由来も含めて回収する

`phase:coding` 以降の処理（実装・PR 作成・コードレビュー）は spec セッションでは行わない。coding 側の責務である。

## 手順

以下の通り Agent ツールを呼び出す。`subagent_type` の指定は必須であり、省略すると general-purpose agent が起動してしまうため絶対に省略しない。

```
Agent(
  subagent_type: "pilot-master",
  description: "pilot spec 1cycle実行",
  prompt: "spec モードで自律開発ワークフローの1cycleを実行せよ。pilot:pilot-spec-cycle skill をロードして手順に従うこと"
)
```

pilot-master からの完了報告をそのままユーザに転送する。

共通規約は `${CLAUDE_PLUGIN_ROOT}/CONVENTIONS.md` を参照すること。

## 注意事項

- pilot-master の cycle 中の判断・遷移・コメント投稿には一切介入しない。報告を受け取って表示するだけ
- pilot-master から `ESCALATE:` や `blocked:human` 付与の報告があれば、その旨を簡潔にユーザへ示す（Discord 通知は pilot-master が行うため、メインから追加通知はしない）
- pilot-master 起動以外の作業（直接 `gh` を叩く、roadmap.md を書き換える等）はこのスキルでは行わない
