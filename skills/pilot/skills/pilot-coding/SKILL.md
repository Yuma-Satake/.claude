---
name: pilot-coding
description: pilot kit の coding セッション 1cycle を実行する。実装フェーズ専用（phase:coding・wait_code_review・wait_code_fix・done）。GitHub Issue を実装・コードレビュー・PR作成まで進める。「codingを回して」「実装を進めて」と依頼された場合、または /loop で coding セッションを常駐駆動する場合に必ず使用すること。メインセッション（ユーザとの直接の会話）でのみ有効。サブエージェント（pilot-master・pilot-pm・pilot-worker・pilot-reviewer）内からは絶対に呼び出さない。
---

# pilot-coding

pilot kit の **coding セッション** 1cycle を実行する。`/loop 30m /pilot:pilot-coding` のような長めの間隔で常駐駆動する想定。

実装（タスク実装・コードレビュー・PR 作成・マージ）に責務を限定したセッション。仕様策定は `pilot-spec` セッション側で行う。

## 設計意図

`pilot-spec` と `pilot-coding` を別セッションで並走させ、要件定義と実装のコンテキスト混線を防ぐ。

```
メインセッション A（spec）         メインセッション B（coding）
  └─ pilot-master                    └─ pilot-master
       └─ pilot-pm × N（specフェーズ）     └─ pilot-pm × N（codingフェーズ）
            └─ pilot-reviewer              ├─ pilot-worker
                                           └─ pilot-reviewer
```

phase 集合が排他なので同一 Issue を両セッションが同時に触ることはない。共有リソース（roadmap.md・ADR 連番・blocked:human 付与・Discord 通知・PR 作成）はそれぞれの pilot-master に集約される。

このスキルは pilot-master サブエージェントを coding モードで1体起動し、cycle 終了報告を受け取って終了するだけの薄いラッパーである。

## coding セッションの責務

- 担当 phase: `phase:coding` / `phase:wait_code_review` / `phase:wait_code_fix` / `phase:done`
- `phase:done` 到達後の PR 作成・マージ
- アーキテクチャ起源の ADR（実装中に発覚した技術判断）のコミット
- 上記 phase の `blocked:human` 付き Issue の裁定回収
- バックフロー: 実装中に仕様矛盾を検出した場合、`phase:wait_spec_fix` に戻して `blocked:human` 付与（次の spec cycle で自動回収される）

`phase:coding` より前の処理（仕様策定・起票・仕様レビュー）は coding セッションでは行わない。spec 側の責務である。

## 手順

以下の通り Agent ツールを呼び出す。`subagent_type` の指定は必須であり、省略すると general-purpose agent が起動してしまうため絶対に省略しない。

```
Agent(
  subagent_type: "pilot-master",
  description: "pilot coding 1cycle実行",
  prompt: "coding モードで自律開発ワークフローの1cycleを実行せよ。pilot:pilot-coding-cycle skill をロードして手順に従うこと"
)
```

pilot-master からの完了報告をそのままユーザに転送する。

共通規約は `${CLAUDE_PLUGIN_ROOT}/CONVENTIONS.md` を参照すること。

## 注意事項

- pilot-master の cycle 中の判断・遷移・コメント投稿には一切介入しない。報告を受け取って表示するだけ
- pilot-master から `ESCALATE:` や `blocked:human` 付与の報告があれば、その旨を簡潔にユーザへ示す（Discord 通知は pilot-master が行うため、メインから追加通知はしない）
- pilot-master 起動以外の作業（直接 `gh` を叩く、PR を作成する等）はこのスキルでは行わない
