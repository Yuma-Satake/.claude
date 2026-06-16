---
name: pilot-coding-cycle
description: pilot kit の coding セッション 1cycle アルゴリズムを実行する。pilot-master agent が coding モードで起動された際にロードする内部skill。実装フェーズ（coding・wait_code_review・wait_code_fix・done）に絞った裁定回収・Issue選定・pilot-pm並列起動・PR作成・バックフロー処理・共有リソース管理・Discord通知の全手順を含む。pilot kit 以外では使用しない。
---

# pilot-coding-cycle

pilot kit の **coding セッション** 1cycle アルゴリズムを実行する。**pilot-master agent 専用**（coding モードで起動された際にロードする）であり、メインセッション・他 agent からはロードしない（メインセッションは `pilot-coding` skill 経由で pilot-master を起動する）。

共通規約は `${CLAUDE_PLUGIN_ROOT}/CONVENTIONS.md` を参照すること。

## このセッションが扱う phase

coding セッションは以下の phase のみを対象とする:

- `phase:coding`
- `phase:wait_code_review`
- `phase:wait_code_fix`
- `phase:done`

`phase:coding` より前は spec セッション（`pilot-spec` skill 経由）の責務である。

## 前提条件

cycle 開始時に確認し、欠けていたら `/pilot:pilot-setup` の実行が必要である旨を報告して終了する。/loop 実行中はユーザがループを止めるまで同じ報告を繰り返すだけになるため、修復を試みない。

- `docs/constitution.md`・`docs/vision.md`・`docs/roadmap.md` が存在すること
- `phase:*` ラベルがリポジトリに存在すること（`gh label list`）

## cycle アルゴリズム

### 1. 裁定の回収

`gh issue list --label "blocked:human" --state open --limit 200` でブロック中の Issue を取得し、**coding セッションが担当する phase のものだけ**を対象とする:

- phase が `phase:coding` / `phase:wait_code_review` / `phase:wait_code_fix` / `phase:done` のもの

`phase:done` の `blocked:human` は §5「phase:done の処理」中に pilot-master が自分で付与したケース（マージポリシー未記載・CI 失敗・コンフリクト・レビュー待ち停滞・中途半端な PR/ブランチ検出など）であり、coding セッションの責務として裁定後の対応（再 PR 作成・コンフリクト解消依頼・マージポリシー追記等）を本 cycle の §5 で行う。

`phase:wait_spec_*` の `blocked:human` Issue は spec セッションが回収するため、coding セッションでは何もしない（バックフローで戻したものも spec 側で処理される）。

各対象 Issue について `gh issue view N --json comments` で全コメントを取得し、`[pilot-master]` または `[pilot-pm]` で始まるコメントのうち最後のもの（ブロック時の質問）を内容でフィルタリングして特定する。それより後に `[pilot-master]` / `[pilot-pm]` で始まらず、かつ bot アカウント（login 末尾が `[bot]`）でないもの（= 人間の裁定）があるか確認する。

- 裁定があれば `blocked:human` を外し、裁定の要約を pilot-log コメント（`[pilot-master]` プレフィックス）として投稿する。このコメントを境にレビューサイクルの往復回数は0から数え直す
- ブロックの原因がレビューサイクル上限だった場合: `phase:wait_code_review → phase:wait_code_fix` に遷移させる
- ブロックの原因が pilot-pm / pilot-worker の ESCALATE だった場合: 裁定内容に従い phase はそのままにして選定対象に戻す
- 裁定がアーキテクチャ判断（実装方式・技術選定）の場合: ADR起案が必要かを判断する。必要な場合は対象 Issue の pilot-pm を起動して ADR 本文の起案を依頼する（プロンプトに「ADR起案を依頼」と明記、テンプレート: `${CLAUDE_PLUGIN_ROOT}/skills/pilot-setup/templates/adr.md.tmpl`、番号は既存ADRの連番）。pilot-pm が返した本文を pilot-master が `docs/adr/NNNN-<slug>.md` としてデフォルトブランチに直接コミットして push する。ADR 起案後、当該 Issue の phase はそのままとし選定対象に戻す

### 2. ボード取得と選定

```
gh issue list --state open --limit 200 --json number,title,labels,body
```

以下の条件で attach 対象を最大3件選ぶ（`phase:done` の処理は後述の通り別扱い）。

- `blocked:human` が付いていない
- phase が `phase:coding` / `phase:wait_code_review` / `phase:wait_code_fix` のいずれか
- 本文「依存」に記載された Issue がすべて closed である（`open` の Issue は phase:done であっても PR マージ前と扱い未完了とみなす。close は PR の `Closes #N` 経由で自動的に行われる）
- Issue 番号昇順。ただし依存関係が順序を上書きする
- 同一 Issue への attach は 1 cycle に1回まで

未起票 Feature の起票は spec セッションの責務であり、coding セッションでは行わない。

対象が0件で、かつ `phase:done` 処理対象もない場合、coding 側で動かす Feature がないことを1行で報告して cycle を終了する。

`phase:done` の処理は §3（pilot-pm 報告検収後）でまとめて行う。cycle 冒頭では行わない。

### 3. pilot-pm への attach（並列実行）

選定した各 Issue に対し、pilot-pm サブエージェントを起動する。独立した Issue 同士は同一メッセージ内で並列起動する（最大3体）。pilot-pm は隔離不要（pilot-pm が起動する pilot-worker が worktree 隔離を担う）。

attach プロンプトの骨子:

> 「自律実行モードで Feature #N『<タイトル>』の coding owner として担当せよ。Skill ツールで `pilot:pilot-drive-feature-coding` をロードし、その手順に従うこと。最初に `gh issue view N --json number,title,body,labels,comments` で Issue の現在状態を完全に取得し、phase ラベル（`phase:coding` / `phase:wait_code_review` / `phase:wait_code_fix` のいずれか）から現在の工程を判断して動作せよ。pilot-log コメント（`[pilot-master]` / `[pilot-pm]` で始まるもの）から前回までの cycle 境界をまたぐ判断と指示のみを読み取り、文脈を復元せよ。
>
> このcycle内で動かせるだけphaseを連鎖駆動してよい（例: `phase:coding` なら 実装 → `wait_code_review` → pilot-reviewer 並列起動 → 必須修正0件なら次タスクへ、必須修正ありなら `wait_code_fix` で連鎖修正）。レビュー指摘は pilot-pm 自身のコンテキスト内に保持し、issue コメントには転記しないこと。
>
> 実装規約: `docs/constitution.md`・`docs/vision.md`・`docs/roadmap.md` を参照すること。起動してよいサブエージェントは pilot-worker・pilot-reviewer・Explore のみ。
>
> 実装中に仕様矛盾・受け入れ基準の不整合を検出した場合は、結果先頭に `ESCALATE: 仕様差し戻し要求` と書いて未解決の仕様問題を箇条書きで報告せよ（pilot-master が `phase:wait_spec_fix` に戻し `blocked:human` 付与で spec セッションに差し戻す）。仕様矛盾以外の判断不能事項・指示への反論は通常の `ESCALATE:` で報告せよ。
>
> ADR 起案が必要なアーキテクチャ判断（実装方式・技術選定）に遭遇した場合は、ADR 本文を起案し報告に含めよ（pilot-master が `docs/adr/` にコミットする）。
>
> cycle 完了時の報告は簡潔に: 担当 Issue 番号、実行した phase 遷移の列、ESCALATE 有無、ADR 起案有無、`phase:done` 到達有無を数行で返すこと。pilot-worker 出力や pilot-reviewer レポートの長文は含めないこと」

### 4. pilot-pm からの報告検収と共有リソース更新

各 pilot-pm の完了報告を回収し、以下を処理する。

| 報告内容 | pilot-master の処理 |
|---|---|
| `ESCALATE: 仕様差し戻し要求` を含む | バックフロー処理を実行（後述「バックフロー処理」参照） |
| 通常の `ESCALATE:` を含む | 該当 Issue に `blocked:human` を付与し、質問・主張を pilot-log コメント（`[pilot-master]` プレフィックス）として投稿する。phase は変更しない。Discord 通知（後述） |
| ADR 起案あり | pilot-pm が返した ADR 本文を `docs/adr/NNNN-<slug>.md` としてデフォルトブランチに直接コミット & push する。番号は既存 ADR の連番。push 前に `git fetch origin` して `origin` 上の ADR と番号が重複していないか確認し、重複していれば振り直す。push が non-fast-forward で失敗した場合（spec cycle が同時刻に ADR を push したケース）は再度 `git fetch origin --prune` → 番号を取り直し → ファイル名変更 → 再コミット & push をリトライする（最大3回） |
| `Feature done` 報告 | §5「phase:done の処理」で本 cycle 内に PR 作成まで実行する |
| 通常の phase 遷移完了 | pilot-master は何もしない。次 cycle で新 pilot-pm が引き継ぐ |

pilot-master は pilot-pm が投稿した pilot-log コメントの内容を再投稿しない。pilot-pm が既に Issue に記録している。

### 5. phase:done の処理（並列枠外・本 cycle 末尾で実行）

本 cycle 中に `phase:done` に到達した Issue と、過去 cycle から残っている `phase:done` の Issue をまとめて処理する。`gh issue list --label phase:done --state open` で取得し、各 Issue に対し以下を pilot-master が直接実行する。並列 attach 枠（3件）には含めない。

1. 既存 PR の有無を多角的に確認する: `gh pr list --state all --search "Closes #N in:body" --json number,state,headRefName` で過去・現存のすべての PR を検索する。`feature/issue-N` ブランチが既に存在する場合（`git ls-remote --heads origin feature/issue-N`）も確認する。中途半端な PR・ブランチが残っていれば pilot-log に記録し、人間裁定が必要であれば `blocked:human` を付与する
2. PR がなく、かつブランチがクリーンに存在する場合のみ `gh pr create --head feature/issue-N` で本文に `Closes #N` を含む PR を作成し、`docs/constitution.md` のマージポリシーに従う（例: `gh pr merge --auto --squash`）。マージポリシーが `docs/constitution.md` に未記載なら `blocked:human` を付与して確認を仰ぐ
3. PR が既にある場合は状態を確認する。マージ済みなら Issue の close を確認して完了。CI 実行中なら何もせず次の cycle で再確認する。CI 失敗・コンフリクト・レビュー待ちで停滞している場合は `blocked:human` を付与し、状況を pilot-log コメントで報告する。その後 Discord に通知する

§1「裁定の回収」で `phase:done` の `blocked:human` 裁定を回収済みの Issue も、本ステップで再処理される（裁定後の再 PR 作成・コンフリクト解消依頼の実行はこのステップで行う）。

### 6. バックフロー処理（仕様差し戻し）

pilot-pm から `ESCALATE: 仕様差し戻し要求` を受けた場合、pilot-master は以下の **順序** で実行する。順序は spec cycle との race window を最小化するために重要である。

1. **先に `blocked:human` を付与**する: `gh issue edit N --add-label blocked:human`。これにより phase ラベルが `phase:wait_spec_fix` に変わった瞬間に spec cycle の選定対象になることを防ぐ（spec cycle は `blocked:human` 付き Issue を attach 対象から除外する）。なお、coding cycle 自身は「phase:coding + blocked:human」状態の Issue を裁定回収対象として拾ってしまう可能性があるが、§1 の裁定回収では `[pilot-master]` の直近 pilot-log コメントを必ず読むので、冒頭が「coding セッションから仕様差し戻し要求」となっていれば「人間裁定待ち」と判定でき自身では処理しない。pilot-log は §3 のステップで投稿する
2. **phase ラベル変更を atomic に実行**する: `gh issue edit N --remove-label phase:coding,phase:wait_code_review,phase:wait_code_fix --add-label phase:wait_spec_fix` を1コマンドで実行する。複数コマンドに分けるとラベル整合性が一瞬崩れるため、必ず単一コマンドで `--remove-label` と `--add-label` を同時に渡す
3. pilot-log コメント（`[pilot-master]` プレフィックス）として「coding セッションから仕様差し戻し要求」と冒頭に書き、pilot-pm が返した未解決の仕様問題の箇条書きをそのまま転記する。指摘の根拠・修正提案は転記しない（問題点のみ）。pilot-log の冒頭文言は coding cycle 自身が次 cycle で誤って裁定回収対象に拾わないための識別子としても機能する
4. Discord 通知を行う（メッセージは spec/coding を区別: `[backflow] 仕様差し戻し要求`）

次の spec cycle は `blocked:human` を裁定回収節で受け取り、人間裁定後に pilot-pm（spec モード）が仕様を修正する。仕様修正後、spec 側で `phase:coding` に戻されれば再び coding セッションが拾う。

### 7. blocked:human 付与時の Discord 通知

`blocked:human` を付与した直後に以下を実行する。`$ISSUE_URL` は `gh issue view N --json url -q .url` で取得する。

通常の ESCALATE 由来:

```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"<@448217636611031051> **[coding] 裁定待ち** Issue #N が blocked:human になりました。\\n$ISSUE_URL\"}")
```

バックフロー由来:

```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"<@448217636611031051> **[backflow] 仕様差し戻し要求** Issue #N が phase:wait_spec_fix に戻されました。\\n$ISSUE_URL\"}")
```

`$DISCORD_WEBHOOK_URL` が未設定の場合は通知をスキップし、cycle 終了報告に「Discord 通知スキップ（DISCORD_WEBHOOK_URL 未設定）」と記載する。`$HTTP_STATUS` が 2xx 以外の場合は通知失敗扱いとし、cycle 終了報告に「Discord 通知失敗（Issue #N, HTTP $HTTP_STATUS）」と記載する。`blocked:human` ラベル付与・phase 戻し自体は通知成否に関わらず維持する。

### 8. cycle 終了報告

呼び出し元（`pilot-coding` スキルを実行しているメインセッション）に、動かした Feature・遷移の概要・PR 作成した Feature・エスカレーション有無・バックフロー有無・`phase:done` 到達 Feature を数行で報告して終了する。報告は簡潔にすること（メインセッションのコンテキストに残るのはこの報告だけであり、ここで詳細を書くと長期運用時にメインの context window を消費する）。

## 制約

- 並列 attach は最大3体（裁定回収時の pilot-pm 起動も枠に含める。`phase:done` 処理は含めない）
- pilot-master は内容判断をしない。pilot-pm や pilot-reviewer の判断に介入したくなったら constitution の不備なので `blocked:human` でユーザに委ねる
- pilot-master は pilot-pm の長い出力を要約しない（pilot-pm 側で要約済みのものを受け取る）
- 共有リソース（ADR 連番・PR 作成・Discord 通知・`blocked:human` 付与・バックフロー時の phase 戻し）以外には触らない。phase ラベル遷移・pilot-log 投稿・チェックボックス更新は pilot-pm の責務である（裁定回収時の `blocked:human` 解除と裁定要約 pilot-log 投稿、バックフロー時の phase 戻しは例外的に pilot-master が行う）
- 未起票 Feature の起票・`docs/roadmap.md` の更新は行わない（spec セッションの責務）
- `phase:proposed` / `phase:wait_spec_*` の Issue には触らない（spec セッションの責務）
- エラーや想定外の状態（label の重複・worktree の残骸など）を検出したら、修復を試みる前に pilot-log コメントに記録する
