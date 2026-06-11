---
name: pilot-run
description: 自律開発ワークフローの1サイクルを実行する。GitHub Issueのphaseラベルを見て、動かせるFeatureにpmサブエージェントを振り分け、結果に応じてphaseを遷移させる。「cycleを回して」「自律開発を進めて」「Issueを進めて」「開発を自動で回して」と依頼された場合、または /loop で常駐駆動する場合に必ず使用すること。constitution.mdとroadmap.mdが揃っているプロジェクトで開発を進める状況なら、ユーザーが「実装して」と明示しなくても積極的に呼び出す。メインセッション（ユーザとの直接の会話）でのみ有効。サブエージェント（master・pm・worker・reviewer）内からは絶対に呼び出さない。
---

# pilot-run

自律開発ワークフローの1cycleを実行する。`/loop 30m /pilot-run` のような長めの間隔で常駐駆動する想定。

## 設計意図

このスキルは master サブエージェントを1体起動し、cycle 終了報告を受け取って終了するだけの薄いラッパーである。実際の cycle 処理（Issue 選定・pm 起動・共有リソース管理）は master が担い、Feature 内の spec→implement→review の連鎖駆動は master が起動する pm サブエージェントが担う。

```
メインセッション
  └─ master（1 cycle = 1 体・cycle終了で破棄）
       ├─ pm A（Feature #1 owner）
       │    ├─ worker
       │    └─ reviewer
       ├─ pm B（Feature #2 owner）
       └─ pm C（Feature #3 owner）
```

これにより:
- メインセッションのコンテキストには「master 起動 + 数行の cycle 終了報告」しか積まれない
- worker / reviewer の長い出力は pm 内に閉じ、pm が要約して master に報告するため master のコンテキストも肥大化しない
- master / pm は cycle 終了で破棄される。cycle 間の状態引き継ぎは GitHub Issue（phase ラベル + 本文タスクチェックボックス + pilot-log コメント）に集約される
- 「同じ Feature には常に同じ pm ロール」というオーナーシップは、Issue からの状態復元で実現される（インスタンスは cycle ごとに再生成）

`/loop` の呼び出し間隔は、長めに設定するほど1 cycle 内で同じ pm が担当する phase 数が増え、文脈連続性のメリットが大きくなる。短すぎると pm が「現状を読んで1 phase 進めて終わる」だけになり現状と変わらない。30分程度が目安。

## 手順

1. Agent ツールで `subagent_type: "master"` を起動する
2. プロンプトは次の通り: 「自律開発ワークフローの1cycleを実行せよ。手順は agents/master.md の定義に従うこと」
3. master からの完了報告をそのままユーザに転送する

## 注意事項

- master の cycle 中の判断・遷移・コメント投稿には一切介入しない。報告を受け取って表示するだけ
- master から `ESCALATE:` や `blocked:human` 付与の報告があれば、その旨を簡潔にユーザへ示す（Discord 通知は master が行うため、メインから追加通知はしない）
- master 起動以外の作業（直接 `gh` を叩く、roadmap.md を書き換える等）はこのスキルでは行わない

## cycle 内 graceful shutdown

将来的にメインから master へ「いま止めて」と指示する仕組みが必要になった場合（例: ユーザの中断要求への対応）、master は受け取った時点で各 pm に shutdown 指示を送る。pm は実行中の worker / reviewer の完了を待ち、phase 遷移と pilot-log 記録までを完了させて終了する。これにより中途半端な状態で破棄されることを防ぐ。現状の `/loop` ベースの定常運用ではこの経路は使われず、cycle が自然完了するのを待てばよい。
