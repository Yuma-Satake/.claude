# pilot kit 共通規約

pilot kit 内の全 agent / skill が遵守する共通規約。各 skill / agent はここを参照する。

## phase ラベル（排他・1 Issue に 1 つ）

| label | 状態 |
|---|---|
| phase:proposed | Outcome のみ起票済み |
| phase:wait_spec_review | 仕様記入済み |
| phase:wait_spec_fix | 仕様に指摘あり |
| phase:coding | 仕様承認済み |
| phase:wait_code_review | タスク実装済み |
| phase:wait_code_fix | コードに指摘あり |
| phase:done | 全タスク完了 |

`blocked:human` は phase ラベルと併存する非排他ラベル。付いている Issue は attach 対象から除外される。

## pilot-log コメント

phase 遷移・cycle 境界をまたぐ判断を Issue に記録するための pilot kit 専用コメント。

- prefix: `[pilot-master]` または `[pilot-pm]` で本文を開始する
- 内容は言い切りで簡潔に
- pilot-worker / pilot-reviewer の長文出力をそのまま貼らない

履歴の参照時はコメント配列の添字直指定（`.comments[1]` 等）を使わない。コメント追加でインデックスが変わるため、author（`[pilot-master]` / `[pilot-pm]` で始まるか・botアカウント末尾が `[bot]` か）と body の内容でフィルタリングする。

### 記載粒度ルール（issue コメント肥大化対策）

レビュー指摘の全文転記は禁止。レビュー → 修正 → 再レビューは pilot-pm の同一セッション内コンテキストで完結させる。pilot-reviewer は issue に一切書き込まず、指摘リストを pilot-pm への戻り値として返すだけ。pilot-pm が必要最小限の情報のみを pilot-log として残す。

| 状況 | 記載内容 |
|---|---|
| phase 遷移（必須修正0件で完了） | 1行サマリのみ。`N往復` を **必ず含める**。例: `[pilot-pm] code-review 1往復で必須修正0件、phase:wait_code_review → phase:coding` |
| phase 遷移（未解決の必須修正あり） | 1行サマリ + 未解決の必須修正のみ箇条書き（指摘1件あたり1行）。1行サマリには `N往復` を必ず含める |
| ESCALATE 発生 | 質問または主張のみ。修正提案の詳細・背景説明は書かない |
| `blocked:human` 付与 | 未解決の必須修正のみ箇条書き。指摘の根拠・修正提案の詳細は書かない |
| cycle 境界をまたがない情報 | 記載しない（pilot-pm コンテキスト内に保持して完結） |

`N往復` は次 cycle の pilot-pm がレビューサイクル上限カウントを引き継ぐための必須情報である。省略すると次 cycle が0からカウントし直し、上限を超えても ESCALATE されない不具合となる。

レビュー指摘の根拠・修正提案・背景説明など人間裁定に不要な情報は記載しない。レビュー往復回数や対応詳細も記載しない。

### バックフロー（coding 側で仕様矛盾検出時の差し戻し）

coding cycle 中に reviewer または worker が「仕様矛盾」「受け入れ基準の不整合」を検出した場合、pilot-pm は ESCALATE で pilot-master に差し戻しを要求する。pilot-master は当該 Issue を `phase:wait_spec_fix` に戻し、`blocked:human` を付与する。pilot-log には未解決の仕様問題を箇条書きで残す（指摘の全文ではなく問題点のみ）。次の spec cycle で自動回収され、人間裁定後に pilot-pm（spec モード）が仕様を修正する。

## ESCALATE 規約

サブエージェントが「自分では判断できない」「指示に反論がある」場合、作業を中断して結果の先頭に以下を書いて呼び出し元へ返す:

```
ESCALATE: <質問または主張>
```

- pilot-worker / pilot-reviewer の ESCALATE → pilot-pm が pilot-master へ転送
- pilot-pm の ESCALATE → pilot-master が `blocked:human` 付与 + Discord 通知

ESCALATE を受けたエージェントは内容を判断せず、上流へ転送する。

## worktree 隔離

ファイルを変更するサブエージェント（pilot-worker）は必ず `isolation: "worktree"` で起動する。読み取り専用のサブエージェント（pilot-reviewer / Explore）は隔離不要。

worktree 内で作業するエージェントは最初に `git fetch origin` を実行し、`origin/<デフォルトブランチ>` または `origin/feature/issue-N` を起点にする。ローカルブランチを起点にしない（worktree はローカルの状態を共有しないため）。

## レビューサイクル上限

同一 Issue で以下の往復が **3回** に達したら、それ以上は遷移させず ESCALATE する:

- `wait_spec_review → wait_spec_fix`
- `wait_code_review → wait_code_fix`

通常は同一 pilot-pm セッション内で 1〜2 往復して完結するため、往復回数は pilot-pm が自セッションのコンテキストで保持する。cycle 境界をまたぐ場合（時間切れ・ESCALATE）は、phase 遷移サマリに `N往復` を含めて pilot-log に残し、次 cycle の pilot-pm がそこから引き継いでカウントする。pilot-master が裁定回収後に投稿する pilot-log を境にカウントをリセットする。

## 共有リソースの集約

複数 pilot-pm が並走する中で競合する共有リソースは **pilot-master に集約** する。pilot-pm は触らない:

- `docs/roadmap.md` の Issue 列更新
- ADR 連番採番と `docs/adr/NNNN-<slug>.md` への commit & push
- `blocked:human` ラベル付与
- Discord 通知（`blocked:human` 付与時）
- PR 作成・マージポリシー適用（`phase:done` 到達後）

pilot-pm の責務は担当 Issue の phase ラベル遷移・pilot-log 投稿・本文チェックボックス更新まで。

## サブエージェント起動の制約

| 起動元 | 起動可能なサブエージェント |
|---|---|
| pilot-master | pilot-pm のみ |
| pilot-pm | pilot-worker, pilot-reviewer, Explore のみ |
| pilot-worker | （子エージェント起動なし） |
| pilot-reviewer | （子エージェント起動なし） |

各サブエージェントへのプロンプトには「判断できない事項、または指示に対する反論がある場合は作業を中断し、結果の先頭に `ESCALATE:` と質問・主張を書いて報告せよ」を必ず含める。

## コンテキスト管理

メインセッションのコンテキストには「pilot-master 起動 + 数行の cycle 終了報告」しか積まない。これを守るため:

- pilot-worker / pilot-reviewer の長い出力は pilot-pm が要約してから pilot-master に返す
- pilot-pm の報告も数行に収める（実行した phase 遷移の列・ESCALATE 有無・ADR 起案有無・Feature done 到達有無）
- pilot-master の cycle 終了報告もメインセッションへ数行で返す

## エントリ skill の呼び出し制約

`pilot-spec` および `pilot-coding` はメインセッション専用。pilot-master・pilot-pm・pilot-worker・pilot-reviewer のいずれからも呼び出さない（再帰起動を防ぐ）。
