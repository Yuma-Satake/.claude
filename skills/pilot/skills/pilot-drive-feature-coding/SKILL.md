---
name: pilot-drive-feature-coding
description: pilot kit の coding セッションで1つの Feature Issue を実装フェーズ駆動する。pilot-pm agent が coding モードで起動された際にロードする内部skill。pilot-workerへの実装依頼・コードレビューの並列実行・指摘反映・phaseラベル遷移・最小限のpilot-logコメント投稿・仕様矛盾検出時のバックフロー要求の手順を含む。pilot kit以外では使用しない。
---

# pilot-drive-feature-coding

pilot kit の **coding セッション** で1つの Feature Issue を実装フェーズ駆動する手順。**pilot-pm agent 専用**（coding モードで起動された際にロードする）。pilot-master agent からは `pilot-coding-cycle` skill 経由で起動指示が来る。

共通規約は `${CLAUDE_PLUGIN_ROOT}/CONVENTIONS.md` を参照すること。

## phase ごとの責務

| label | 自分が起動された時の意味 | pilot-pm が行うアクション |
|---|---|---|
| phase:coding | 仕様承認済み | pilot-worker に1タスク実装を依頼 → 完了後 `phase:wait_code_review` へ遷移 → コードレビューに連鎖 |
| phase:wait_code_review | タスク実装済み | 並列 pilot-reviewer にコードレビュー依頼 |
| phase:wait_code_fix | コードに指摘あり | 指摘を pilot-pm 自身のコンテキストから取り出して pilot-worker に修正依頼 → 再レビューに連鎖 |
| phase:done | 全タスク完了 | 自分は何もしない（pilot-master が PR 作成を担当する） |

`phase:proposed` / `phase:wait_spec_*` への遷移はバックフロー時のみ pilot-master が行う。pilot-pm 自身は spec 側の phase ラベルを操作しない。

ラベル遷移とチェックボックス更新は pilot-pm 自身が `gh` コマンドで実行する。

## 動作手順

### 1. 状態復元

`gh issue view N --json number,title,body,labels,comments` で担当 Issue の完全な状態を取得する。

- 現在の phase ラベル
- 本文の受け入れ基準・タスク（チェックボックス状態）
- pilot-log コメントのうち cycle 境界をまたぐ判断・指示（直近の `[pilot-master]` または `[pilot-pm]` で始まるもの）

pilot-log は cycle 境界をまたぐ情報のみが残されている。レビュー指摘の全文は記載されていない前提で読むこと。前 cycle で残された未解決の必須修正の箇条書き、または phase 遷移の1行サマリのみが情報源である。

### 2. 現 phase に応じた処理（連鎖駆動）

このセッション内で動かせるだけ phase を連鎖駆動してよい（例: `phase:coding` から `phase:wait_code_review` → `phase:wait_code_fix` → `phase:wait_code_review` → 次タスクの `phase:coding` まで）。各 phase の処理を順に実行する。

#### phase:coding （タスク実装）

pilot-worker サブエージェントを **必ず `isolation: "worktree"` を指定して** 1体起動する。Agent ツール呼び出しで `isolation: "worktree"` パラメータを明示する（隔離なしで起動するとメインリポジトリの作業ツリーに変更が直接入ってしまい、複数 pilot-pm 並走時にコンフリクトが発生する）。プロンプト:

> 「Skill ツールで `pilot:pilot-fix-feature` をロードし、Issue #N を処理すること」

pilot-worker 完了後の処理:

- pilot-worker が `ESCALATE:` を返したら、その内容を `ESCALATE:` で pilot-master に転送する（pilot-master が `blocked:human` を付与）
- pilot-worker が仕様矛盾を報告した場合（実装中に受け入れ基準の不整合や仕様の欠落を発見した場合）は、`ESCALATE: 仕様差し戻し要求` で pilot-master に転送する（バックフロー処理）。未解決の仕様問題を箇条書きで添える
- pilot-worker の `COMPLETED_TASK:` 行を自分のコンテキスト内に保持する（チェックボックスはまだ更新しない）
- `phase:wait_code_review` に遷移し、続いて `phase:wait_code_review` 処理へ連鎖

#### phase:wait_code_review （コードレビュー・並列）

`git fetch origin` を実行し、`git diff --name-only origin/<デフォルトブランチ>...origin/feature/issue-N` で変更ファイル一覧を取得する。

変更ファイルの拡張子・パスからレビュー観点を判定する。

| 条件 | ロードする skill |
|---|---|
| `.ts` / `.tsx` ファイルを含む | coding-typescript, coding-js |
| `.js` / `.jsx` ファイルを含む | coding-js |
| React コンポーネント（`.tsx` / `.jsx`、または `import React` を含む）を含む | coding-react |
| `apps/web` 配下のファイルを含む（Next.js） | coding-nextjs |
| Go ファイル（`.go`）を含む | coding-go |

判定された skill を重複排除した上で、pilot-reviewer A（仕様観点）と、規約観点の pilot-reviewer を判定 skill ごとに1体ずつ **並列起動** する（同一メッセージ内で複数 Agent 呼び出し）。pilot-reviewer agent は1体につき最大1 skill しかロードできないため、規約観点の pilot-reviewer は skill の数だけ起動する。

**pilot-reviewer A（仕様観点・skill なし）**:

> 「`git fetch origin` を実行した上で、`origin/feature/issue-N` と `origin/<デフォルトブランチ>` の diff をレビューすること。評価対象は今回完了したタスク（pilot-pm から渡された `COMPLETED_TASK:` のテキストと一致するもの）に対応する受け入れ基準のみとすること。未着手タスクに対応する基準は評価しない（未実装は必須修正ではなく次タスクで対応される）。観点: 対象受け入れ基準とテストコードの対応が取れているか・アーキテクチャ判断に ADR（`docs/adr/`）が起案されているか・受け入れ基準自体に不整合や仕様矛盾がないか。受け入れ基準の不整合・仕様矛盾を発見した場合は本回答の冒頭に `SPEC_CONFLICT:` と書き、問題点を箇条書きで報告すること（pilot-pm がバックフロー処理する）。必須修正の判定基準: 受け入れ基準の未達・セキュリティ問題・ビルドまたはテスト失敗を引き起こすもののみ。指摘内容は issue コメントには書き込まず、本回答として返すこと。出力の最終行は必ず `code-review: wait_code_fix` または `code-review: coding` の1行のみとすること」

**pilot-reviewer B群（規約観点・判定 skill 1つにつき1体）**:

判定された skill ごとに1体の pilot-reviewer を起動する。各 pilot-reviewer のプロンプトは以下とする:

> 「`git fetch origin` を実行した上で、`origin/feature/issue-N` と `origin/<デフォルトブランチ>` の diff をレビューすること。Skill ツールで `<割り当てる skill 名>` をロードし、そのコーディング規約に照らしてレビューすること。必須修正の判定基準（以下に該当するもののみ）: 返り値型・引数型の未定義による型安全性の欠如・破壊的メソッドの使用・hooks 規約違反・nullable の未処理。推奨止まりにする基準（`## 軽微修正` セクションに分離し code-review に影響させないこと）: 型エイリアスと interface の使い分け・命名スタイル・インポート順・末尾改行・コメント追加。指摘内容は issue コメントには書き込まず、本回答として返すこと。出力の最終行は必ず `code-review: wait_code_fix` または `code-review: coding` の1行のみとすること」

すべての結果を回収して自分のコンテキスト内に保持する。issue コメントへの転記はしない。最終判定:

- pilot-reviewer A が `SPEC_CONFLICT:` を返した → `ESCALATE: 仕様差し戻し要求` で pilot-master に報告（バックフロー）。問題点の箇条書きを添える。pilot-reviewer B 群（規約観点）が誤って `SPEC_CONFLICT:` を返した場合は仕様差し戻しと扱わず、通常の `ESCALATE:` として「規約観点の reviewer が SPEC_CONFLICT を返却」と pilot-master に報告する（仕様判断は A の専管）
- いずれか1体でも `code-review: wait_code_fix` → 全 pilot-reviewer の `## 必須修正` をマージ（同一指摘は重複排除）して自分のコンテキスト内に保持し、`phase:wait_code_fix` に遷移して続いて `wait_code_fix` 処理へ連鎖
- すべて `code-review: coding` → pilot-worker の `COMPLETED_TASK:` 行のテキストを使い Issue 本文の `- [ ] <テキスト>` を `- [x] <テキスト>` に置換してチェックボックスを更新する。置換結果のチェックボックス数が0件（一致するタスクが存在しない）または `COMPLETED_TASK:` の数より少ない場合は **必ず ESCALATE する**（`ESCALATE: COMPLETED_TASK と Issue 本文のタスク文字列が一致しません。<対象テキスト>` の形式で pilot-master に報告）。チェックボックス更新を一切行わず、phase 遷移もしない。誤判定による `phase:done` 早期到達と二重 PR 作成を防ぐ。置換が全件成功した場合のみ、未チェックタスクが残れば `phase:coding` に遷移して続いて `phase:coding` 処理へ、全完了なら `phase:done` に遷移して pilot-master に完了報告（done の PR 処理は pilot-master が行う）
- code-review が見つからない pilot-reviewer がいる → `ESCALATE:` で pilot-master に報告

レビューサイクル上限（共通規約参照）に達したら ESCALATE する。往復回数は自セッションのコンテキストでカウントする（前 cycle から引き継ぐ場合は pilot-log の遷移サマリから読み取る）。

#### phase:wait_code_fix （コード修正）

指摘の取得元:

- 同一 pilot-pm セッション内の `wait_code_review → wait_code_fix` 遷移であれば、自分のコンテキストに保持している pilot-reviewer の出力をマージした必須修正を反映する
- 前 cycle で `wait_code_fix` のまま中断していた場合は、pilot-log の最新コメントに記載された未解決の必須修正の箇条書きを反映する

pilot-worker サブエージェントを **必ず `isolation: "worktree"` を指定して** 1体起動する。Agent ツール呼び出しで `isolation: "worktree"` パラメータを明示する。プロンプト:

> 「Skill ツールで `pilot:pilot-fix-feature` をロードし、Issue #N に対して以下の必須修正を反映すること: <自分のコンテキストから取り出した必須修正の箇条書きを埋め込む>。指摘はこのプロンプト内に含めており、issue コメントには記載されていない」

pilot-worker 完了後、`phase:wait_code_review` に遷移して続いて `wait_code_review` 処理へ連鎖。

#### phase:done

pilot-master に「Feature done」を報告する。PR 作成は pilot-master の責務であり、pilot-pm は何もしない。

### 3. cycle 末尾の pilot-log 投稿

担当セッションで動かした phase 遷移を pilot-log として `[pilot-pm]` プレフィックスで1回だけ投稿する。

記載粒度ルール（共通規約「pilot-log コメント」セクション参照）に厳格に従う:

| 状況 | 記載内容 |
|---|---|
| `phase:done` に到達して完了 | 1行サマリのみ。`N往復` を **必ず含める**。例: `[pilot-pm] code-review 1往復で必須修正0件、phase:wait_code_review → phase:done` |
| `phase:coding` / `phase:wait_code_review` / `phase:wait_code_fix` で終了（未解決の必須修正あり） | 1行サマリ + 未解決の必須修正のみ箇条書き（指摘1件あたり1行）。1行サマリには `N往復` を **必ず含める** |
| ESCALATE 発生 | 質問または主張のみ |
| `ESCALATE: 仕様差し戻し要求` | pilot-master 側で「coding セッションからの仕様差し戻し」として pilot-log を投稿するため、pilot-pm 側では pilot-log を残さない |

レビュー指摘の根拠・修正提案の詳細・背景説明は書かない。`N往復` は次 cycle の pilot-pm がレビューサイクル上限カウントを引き継ぐための必須情報であり、省略すると次 cycle が0からカウントし直し上限を超えても ESCALATE されない不具合となる（共通規約参照）。

### 4. ESCALATE の経路

- 通常の判断不能事項・指示への反論: `ESCALATE: <質問または主張>` で pilot-master に返す
- 仕様矛盾検出（バックフロー要求）: `ESCALATE: 仕様差し戻し要求` で pilot-master に返す。pilot-master が `phase:wait_spec_fix` に戻して `blocked:human` 付与する
- レビューサイクル上限到達: 通常の ESCALATE で報告
- ADR 起案が必要なアーキテクチャ判断（実装方式・技術選定）: ADR 本文（テンプレート: `${CLAUDE_PLUGIN_ROOT}/skills/pilot-setup/templates/adr.md.tmpl`）を起案して報告に含める（pilot-master が `docs/adr/` にコミットする）

自分で `blocked:human` を付与しない。phase ラベルをバックフロー方向（`phase:wait_spec_*`）に戻さない（pilot-master が行う）。

### 5. shutdown 指示への対応

pilot-master から「graceful shutdown」「現在の作業をキリの良いところで終えよ」という指示を受けた場合、以下のように振る舞う。

- 現在実行中のサブエージェント（pilot-worker / pilot-reviewer）の完了は必ず待つ
- 受け取った結果は cycle 末尾の pilot-log として記録し、phase 遷移まで完了させる（中途半端な状態で止めない）
- 次の phase 処理には進まない（例: pilot-worker 完了後 `wait_code_review` に遷移はするが pilot-reviewer 起動はしない）
- pilot-master に「shutdown 完了。現 phase: <ラベル名>」と報告して終了する

### 6. pilot-master への完了報告

担当セッションの終了時、pilot-master に以下を簡潔に報告する。

- 担当 Issue 番号
- このセッションで実行した phase 遷移の列（例: `coding → wait_code_review → wait_code_fix → wait_code_review → coding`）
- `ESCALATE:` がある場合はその内容（通常 ESCALATE か仕様差し戻し要求かを明示）
- ADR 起案を要する判断があった場合は内容（pilot-master が ADR をコミットする）
- `phase:done` に到達した場合は `Feature done` の通知（pilot-master が PR 作成を行う）

長文の pilot-worker 出力や pilot-reviewer レポートは含めない。pilot-master のコンテキストを汚さない。

## 制約

- 実装には一切手を出さない。コードは pilot-worker、検証は pilot-reviewer
- 起動してよいサブエージェントは pilot-worker・pilot-reviewer・Explore のみ
- pilot-reviewer の指摘は自分のコンテキスト内に保持し、issue コメントには転記しない（共通規約「記載粒度ルール」参照）
- pilot-master のコンテキストを汚さない。サブエージェントの長い出力は自分の中で要約してから報告する
- 担当 Issue 以外には触らない。他 Feature のラベル遷移・pilot-log 投稿はしない
- 共有リソース（ADR 連番・PR 作成・Discord 通知・`blocked:human` 付与・バックフロー時の phase 戻し）には触らない。pilot-master の責務である。`docs/roadmap.md` は spec セッション専属の共有リソースであり coding 側からは一切触らない
- ESCALATE 経路: pilot-worker / pilot-reviewer の ESCALATE は pilot-master に転送する。自分で `blocked:human` を付与しない
- `phase:proposed` / `phase:wait_spec_*` の Issue には触らない。spec 側 phase へのラベル戻しは pilot-master のバックフロー処理に任せる（自分で `gh issue edit` を spec 側 phase に向けて実行しない）
