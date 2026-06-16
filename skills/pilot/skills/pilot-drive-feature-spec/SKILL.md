---
name: pilot-drive-feature-spec
description: pilot kit の spec セッションで1つの Feature Issue を仕様策定フェーズ駆動する。pilot-pm agent が spec モードで起動された際にロードする内部skill。仕様記入・pilot-reviewerへの仕様レビュー依頼・指摘反映・phaseラベル遷移・最小限のpilot-logコメント投稿の手順を含む。pilot kit以外では使用しない。
---

# pilot-drive-feature-spec

pilot kit の **spec セッション** で1つの Feature Issue を仕様策定フェーズ駆動する手順。**pilot-pm agent 専用**（spec モードで起動された際にロードする）。pilot-master agent からは `pilot-spec-cycle` skill 経由で起動指示が来る。

共通規約は `${CLAUDE_PLUGIN_ROOT}/CONVENTIONS.md` を参照すること。

## phase ごとの責務

| label | 自分が起動された時の意味 | pilot-pm が行うアクション |
|---|---|---|
| phase:proposed | Outcome のみ起票済み | 仕様記入 → `phase:wait_spec_review` へ遷移 → pilot-reviewer 起動を連鎖 |
| phase:wait_spec_review | 仕様記入済み（前回の pilot-pm が残した状態） | pilot-reviewer 起動 |
| phase:wait_spec_fix | 仕様に指摘あり | 指摘を pilot-pm 自身のコンテキストから取り出して反映 → `phase:wait_spec_review` へ戻して再レビューに連鎖 |

`phase:coding` への遷移をもって spec セッションでの責務は完了する。`phase:coding` 以降は coding セッションが扱う。

ラベル遷移は pilot-pm 自身が `gh` コマンドで実行する。

## 動作手順

### 1. 状態復元

`gh issue view N --json number,title,body,labels,comments` で担当 Issue の完全な状態を取得する。

- 現在の phase ラベル
- 本文の受け入れ基準・タスク（チェックボックス状態）
- pilot-log コメントのうち cycle 境界をまたぐ判断・指示（直近の `[pilot-master]` または `[pilot-pm]` で始まるもの）

pilot-log は cycle 境界をまたぐ情報のみが残されている。レビュー指摘の全文は記載されていない前提で読むこと。前 cycle で残された未解決の必須修正の箇条書き、または phase 遷移の1行サマリのみが情報源である。

### 2. 現 phase に応じた処理（連鎖駆動）

このセッション内で `phase:proposed` から `phase:coding` 到達まで一気通貫で連鎖駆動してよい。各 phase の処理を順に実行する。

#### phase:proposed / phase:wait_spec_fix （仕様作成・修正）

- `docs/constitution.md` と `docs/vision.md` を読む（自分のコンテキストでロードする）
- Explore サブエージェントで関連コードを軽く調査する（thoroughness: quick〜medium）
- Issue 本文の「受け入れ基準」と「タスク」を本文の既存セクション構造を保って記入する

記述粒度の制約（厳守）:

- 受け入れ基準は1件1〜2行・簡潔な条件文のみ（検証手段の細部・判断根拠・設計経緯は書かない）
- タスクは `- [ ] 動詞から始める40文字以内のone-liner` 形式（目的・内容・依存等のサブフィールドは設けない）
- 粒度は2〜4時間で完了する単位を目安とし、1タスクに複数の成果物を詰め込まない
- タスクの実行順序は上から順に依存を暗黙表現する
- 並列実行可能なタスクは末尾に `(並列可)` を付記する
- 実装方針は書かない
- テンプレート由来の説明文・プレースホルダは記入時に除去する

受け入れ基準が5個以上になる場合は Feature 分割を検討し、分割する場合は `pilot:pilot-create-feature` skill をロードして新 Feature を起票し（自律実行であることを明示する）、本 Issue のスコープを縮小し、着手順は依存セクションで強制する。

`wait_spec_fix` の場合の指摘の取得元:

- 同一 pilot-pm セッション内の `wait_spec_review → wait_spec_fix` 遷移であれば、自分のコンテキストに保持している pilot-reviewer の出力から `## 必須修正` を取り出して反映する
- 前 cycle で `wait_spec_fix` のまま中断していた場合は、pilot-log の最新コメントに記載された未解決の必須修正の箇条書きを反映する
- coding セッションからのバックフロー由来（pilot-log に仕様矛盾の指摘が記録されている場合）は、その指摘を反映する

推奨・確認事項には対応しない。必須修正のみが対象である。

完了後、`gh issue edit N --remove-label phase:proposed,phase:wait_spec_fix --add-label phase:wait_spec_review` でラベル遷移する。同一セッション内で連鎖駆動する場合、この時点では pilot-log は投稿しない（cycle 末尾でまとめて1回投稿する）。続いて `phase:wait_spec_review` の処理に進む。

#### phase:wait_spec_review （仕様レビュー）

pilot-reviewer サブエージェントを1体起動する。プロンプト:

> 「`docs/constitution.md` と `docs/vision.md` と `docs/roadmap.md` をレビュー基準としてロードすること。Issue #N の本文と直近の pilot-pm 記入内容をレビュー対象とすること。観点: Outcome 自体の vision 整合（独立してデプロイ可能か・単体で価値を持つか）・非ゴールへの侵犯・優先順位の矛盾・依存セクションの妥当性・受け入れ基準がテスト可能な形か・タスクが pilot-worker 単独で実行できる粒度か。Outcome に問題があれば受け入れ基準より先に Outcome の修正を求めること。必須修正がある場合は `## 必須修正` セクションに列挙し、ない場合は `## 必須修正\nなし` と記載すること。指摘内容は issue コメントには書き込まず、本回答として返すこと。出力の最終行は必ず `spec-review: wait_spec_fix`（必須修正ありの場合）または `spec-review: coding`（必須修正なしの場合）の1行のみとすること」

pilot-reviewer の出力を自分のコンテキスト内に保持する。issue コメントへの転記はしない。出力の最終行を機械的に読み、推奨・確認事項が出力にあっても無視する。

- `spec-review: coding` → `phase:coding` に遷移して spec セッション完了（後述「cycle 末尾の pilot-log 投稿」へ進む）
- `spec-review: wait_spec_fix` → `## 必須修正` を自分のコンテキストに保持したまま `phase:wait_spec_fix` に遷移し、続いて `wait_spec_fix` 処理へ連鎖
- どちらも見つからない → `ESCALATE:` で pilot-master に報告（pilot-master が `blocked:human` を付与する）

レビューサイクル上限（共通規約参照）に達したら ESCALATE する。往復回数は自セッションのコンテキストでカウントする（前 cycle から引き継ぐ場合は pilot-log の遷移サマリから読み取る）。

### 3. cycle 末尾の pilot-log 投稿

担当セッションで動かした phase 遷移を pilot-log として `[pilot-pm]` プレフィックスで1回だけ投稿する。

記載粒度ルール（共通規約「pilot-log コメント」セクション参照）に厳格に従う:

| 状況 | 記載内容 |
|---|---|
| `phase:coding` に到達して完了 | 1行サマリのみ。`N往復` を **必ず含める**。例: `[pilot-pm] spec-review 1往復で必須修正0件、phase:proposed → phase:coding` |
| `phase:wait_spec_review` または `phase:wait_spec_fix` で終了（未解決の必須修正あり） | 1行サマリ + 未解決の必須修正のみ箇条書き（指摘1件あたり1行）。1行サマリには `N往復` を **必ず含める** |
| ESCALATE 発生 | 質問または主張のみ |

レビュー指摘の根拠・修正提案の詳細・背景説明は書かない。`N往復` は次 cycle の pilot-pm がレビューサイクル上限カウントを引き継ぐための必須情報であり、省略すると次 cycle が0からカウントし直し上限を超えても ESCALATE されない不具合となる（共通規約参照）。

### 4. ESCALATE の経路

pilot-reviewer の出力で判定できないケース、レビューサイクル上限到達、ADR 起案が必要なプロダクト判断・スコープ判断などに遭遇した場合は ESCALATE を発行する。

- 結果先頭に `ESCALATE: <質問または主張>` を書いて pilot-master に返す
- 自分で `blocked:human` を付与しない
- ADR 起案が必要な場合は、ADR 本文（テンプレート: `${CLAUDE_PLUGIN_ROOT}/skills/pilot-setup/templates/adr.md.tmpl`）を起案して報告に含める（pilot-master が `docs/adr/` にコミットする）

### 5. shutdown 指示への対応

pilot-master から「graceful shutdown」「現在の作業をキリの良いところで終えよ」という指示を受けた場合、以下のように振る舞う。

- 現在実行中のサブエージェント（pilot-reviewer）の完了は必ず待つ
- 受け取った結果は cycle 末尾の pilot-log として記録し、phase 遷移まで完了させる（中途半端な状態で止めない）
- 次の phase 処理には進まない（例: pilot-reviewer の `spec-review: wait_spec_fix` を受け取ったら `phase:wait_spec_fix` には遷移するが、その後の仕様修正には着手しない。未解決の必須修正を pilot-log に箇条書きで残す）
- pilot-master に「shutdown 完了。現 phase: <ラベル名>」と報告して終了する

### 6. pilot-master への完了報告

担当セッションの終了時、pilot-master に以下を簡潔に報告する。

- 担当 Issue 番号
- このセッションで実行した phase 遷移の列（例: `proposed → wait_spec_review → wait_spec_fix → wait_spec_review → coding`）
- `ESCALATE:` がある場合はその内容
- ADR 起案を要する判断があった場合は内容（pilot-master が ADR をコミットする）
- `phase:coding` に到達した場合は `phase:coding 到達` の通知（coding セッションが次 cycle で拾う）

長文の pilot-reviewer レポートは含めない。pilot-master のコンテキストを汚さない。

## 制約

- 実装には一切手を出さない。spec フェーズではコードを書かない（pilot-worker は起動しない）
- 起動してよいサブエージェントは pilot-reviewer・Explore のみ
- pilot-reviewer の指摘は自分のコンテキスト内に保持し、issue コメントには転記しない（共通規約「記載粒度ルール」参照）
- pilot-master のコンテキストを汚さない。サブエージェントの長い出力は自分の中で要約してから報告する
- 担当 Issue 以外には触らない。他 Feature のラベル遷移・pilot-log 投稿はしない
- 共有リソース（roadmap.md・ADR 連番・Discord 通知・`blocked:human` 付与）には触らない。pilot-master の責務である
- ESCALATE 経路: pilot-reviewer の ESCALATE は pilot-master に転送する。自分で `blocked:human` を付与しない
- `phase:coding` 以降の処理（実装・コードレビュー・PR 作成）には関与しない。coding セッションの責務である
