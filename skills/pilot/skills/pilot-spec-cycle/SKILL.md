---
name: pilot-spec-cycle
description: pilot kit の spec セッション 1cycle アルゴリズムを実行する。pilot-master agent が spec モードで起動された際にロードする内部skill。要件定義フェーズ（proposed・wait_spec_review・wait_spec_fix）に絞った裁定回収・Feature選定・起票・pilot-pm並列起動・共有リソース管理・Discord通知の全手順を含む。pilot kit 以外では使用しない。
---

# pilot-spec-cycle

pilot kit の **spec セッション** 1cycle アルゴリズムを実行する。**pilot-master agent 専用**（spec モードで起動された際にロードする）であり、メインセッション・他 agent からはロードしない（メインセッションは `pilot-spec` skill 経由で pilot-master を起動する）。

共通規約は `${CLAUDE_PLUGIN_ROOT}/CONVENTIONS.md` を参照すること。

## このセッションが扱う phase

spec セッションは以下の phase のみを対象とする:

- `phase:proposed`
- `phase:wait_spec_review`
- `phase:wait_spec_fix`

`phase:coding` 以降は coding セッション（`pilot-coding` skill 経由）の責務である。

## 前提条件

cycle 開始時に確認し、欠けていたら `/pilot:pilot-setup` の実行が必要である旨を報告して終了する。/loop 実行中はユーザがループを止めるまで同じ報告を繰り返すだけになるため、修復を試みない。

- `docs/constitution.md`・`docs/vision.md`・`docs/roadmap.md` が存在すること
- `phase:*` ラベルがリポジトリに存在すること（`gh label list`）

## cycle アルゴリズム

### 1. 裁定の回収

`gh issue list --label "blocked:human" --state open --limit 200` でブロック中の Issue を取得し、**spec セッションが担当する phase のものだけ**を対象とする:

- phase が `phase:proposed` / `phase:wait_spec_review` / `phase:wait_spec_fix` のもの

該当しない phase（`phase:coding` 以降）の `blocked:human` Issue は coding セッションが回収するため、spec セッションでは何もしない。

各対象 Issue について `gh issue view N --json comments` で全コメントを取得し、`[pilot-master]` または `[pilot-pm]` で始まるコメントのうち最後のもの（ブロック時の質問）を内容でフィルタリングして特定する。それより後に `[pilot-master]` / `[pilot-pm]` で始まらず、かつ bot アカウント（login 末尾が `[bot]`）でないもの（= 人間の裁定）があるか確認する。

- 裁定があれば `blocked:human` を外し、裁定の要約を pilot-log コメント（`[pilot-master]` プレフィックス）として投稿する。このコメントを境にレビューサイクルの往復回数は0から数え直す
- ブロックの原因がレビューサイクル上限だった場合: `phase:wait_spec_review → phase:wait_spec_fix` に遷移させる
- ブロックの原因が coding セッションからの仕様差し戻し（バックフロー）だった場合: 当該 Issue は既に `phase:wait_spec_fix` のはず。裁定を反映して通常の選定対象に戻す
- ブロックの原因が pilot-pm の ESCALATE だった場合: 裁定内容に従い phase はそのままにして選定対象に戻す
- 裁定がプロダクト判断（仕様・優先順位・スコープ）の場合: ADR起案が必要かを判断する。必要な場合は対象 Issue の pilot-pm を起動して ADR 本文の起案を依頼する（プロンプトに「ADR起案を依頼」と明記、テンプレート: `${CLAUDE_PLUGIN_ROOT}/skills/pilot-setup/templates/adr.md.tmpl`、番号は既存ADRの連番）。pilot-pm が返した本文を pilot-master が `docs/adr/NNNN-<slug>.md` としてデフォルトブランチに直接コミットして push する。ADR 起案後、当該 Issue の phase はそのままとし選定対象に戻す

### 2. ボード取得と選定

```
gh issue list --state open --limit 200 --json number,title,labels,body
```

以下の条件で attach 対象を最大3件選ぶ。

- `blocked:human` が付いていない
- phase が `phase:proposed` / `phase:wait_spec_review` / `phase:wait_spec_fix` のいずれか
- 本文「依存」に記載された Issue がすべて closed である（`open` の Issue は phase:done であっても PR マージ前と扱い未完了とみなす。close は PR の `Closes #N` 経由で自動的に行われる）
- Issue 番号昇順。ただし依存関係が順序を上書きする（分割で後から起票された Feature も依存に従う）
- 同一 Issue への attach は 1 cycle に1回まで

**起票トリガー**: spec セッションが担当する phase の open issue 総数（`blocked:human` 付きを含む）が3件未満で、かつ `docs/roadmap.md` に未起票 Feature（Issue 列が `-`）が残っている場合のみ、（3 − 該当 phase の open issue 総数）件を起票する。3件以上あれば起票しない。

計測は phase ラベル別に行う。`coding` 以降の phase の Issue 数は含めない。例:

```bash
SPEC_OPEN=$(gh issue list --state open --limit 200 --json labels \
  --jq '[.[] | select(.labels[].name | test("^phase:(proposed|wait_spec_(review|fix))$"))] | length')
```

`$SPEC_OPEN` が3未満かつ未起票 Feature が残っている場合のみ起票する。詳細は次項を参照。

対象が0件で未起票 Feature もない場合、spec 側で動かす Feature がないことを1行で報告して cycle を終了する。

### 2.5. 未起票 Feature の逐次起票（spec セッション専属の責務）

`docs/roadmap.md` を読み、Issue 列が `-` の Feature のうち「順序」が最も小さいものから順に、不足枠の数だけ選定する。依存列に書かれた順序番号が未起票 Feature を指す場合は、その先行 Feature を先に起票する（順序昇順に処理すれば自然に満たされる）。

選定した各 Feature に対し、pilot-pm サブエージェントを起動して `pilot:pilot-create-feature` を実行させる。

attach 指示の骨子:

> 「Skill ツールで `pilot:pilot-create-feature` をロードし、自律実行モードで Feature『<名前>』を起票せよ。Outcome 案: <roadmap の Outcome 文>。依存（roadmap 順序）: <数字またはなし>。依存先の Issue 番号: <`#NN` または なし>（本文の依存セクションにこの番号で記載すること）。`docs/constitution.md` と `docs/vision.md` および最新の `docs/adr/` 配下を参照し、起票時点の前提を反映すること。判断できない事項は結果先頭に `ESCALATE:` で報告すること。起票した Issue 番号を報告すること。起票後は Feature owner 業務には入らず、Issue 番号の報告のみで終了せよ」

報告を受けた後、pilot-master は `docs/roadmap.md` の該当行の Issue 列を `#NN` に書き換え、デフォルトブランチへ直接コミット & push する（roadmap 更新は共有リソースであり pilot-master に集約する）。push 前に `git fetch origin` で `origin` 上の最新 roadmap.md を取得し、書き換え対象行が既に `#NN` 等で埋まっていないか確認する（埋まっていれば pilot-pm 起動側の判定漏れであり、ESCALATE 扱いで pilot-log に記録）。push が non-fast-forward で失敗した場合は `git fetch origin --prune` → ローカル変更を再 apply → 再コミット & push をリトライする（最大3回）。それでも失敗する場合は ESCALATE で報告し当該 Feature は未起票のまま残す。`ESCALATE:` を pilot-pm から受けた場合は起票せず、Feature 名・質問内容を cycle 終了報告に含めてユーザに mention する。当該 Feature は未起票のまま残り、裁定後の次 cycle で再試行する。

### 3. pilot-pm への attach（並列実行）

選定した各 Issue に対し、pilot-pm サブエージェントを起動する。独立した Issue 同士は同一メッセージ内で並列起動する（最大3体）。pilot-pm は隔離不要（spec フェーズでは pilot-worker を起動しないためファイル変更が発生しない）。

attach プロンプトの骨子:

> 「自律実行モードで Feature #N『<タイトル>』の spec owner として担当せよ。Skill ツールで `pilot:pilot-drive-feature-spec` をロードし、その手順に従うこと。最初に `gh issue view N --json number,title,body,labels,comments` で Issue の現在状態を完全に取得し、phase ラベル（`phase:proposed` / `phase:wait_spec_review` / `phase:wait_spec_fix` のいずれか）から現在の工程を判断して動作せよ。pilot-log コメント（`[pilot-master]` / `[pilot-pm]` で始まるもの）から前回までの cycle 境界をまたぐ判断と指示のみを読み取り、文脈を復元せよ。
>
> このcycle内で動かせるだけphaseを連鎖駆動してよい（例: `phase:proposed` なら 仕様記入 → `wait_spec_review` → pilot-reviewer 起動 → 必須修正0件なら `phase:coding` 遷移まで、必須修正ありなら `wait_spec_fix` で連鎖修正）。レビュー指摘は pilot-pm 自身のコンテキスト内に保持し、issue コメントには転記しないこと。
>
> 実装規約: `docs/constitution.md`・`docs/vision.md`・`docs/roadmap.md` を参照すること。起動してよいサブエージェントは pilot-reviewer・Explore のみ（spec フェーズでは pilot-worker は起動しない）。
>
> 判断できない事項、または指示に対する反論がある場合は作業を中断し、結果の先頭に `ESCALATE:` と質問・主張を書いて報告せよ。pilot-master はその内容を見て `blocked:human` 付与と Discord 通知を行う。
>
> ADR 起案が必要なプロダクト判断・スコープ判断に遭遇した場合は、ADR 本文を起案し報告に含めよ（pilot-master が `docs/adr/` にコミットする）。
>
> cycle 完了時の報告は簡潔に: 担当 Issue 番号、実行した phase 遷移の列、ESCALATE 有無、ADR 起案有無、`phase:coding` 到達有無を数行で返すこと。pilot-reviewer レポートの長文は含めないこと」

### 4. pilot-pm からの報告検収と共有リソース更新

各 pilot-pm の完了報告を回収し、以下を処理する。

| 報告内容 | pilot-master の処理 |
|---|---|
| `ESCALATE:` を含む | 該当 Issue に `blocked:human` を付与し、質問・主張を pilot-log コメント（`[pilot-master]` プレフィックス）として投稿する。phase は変更しない。Discord 通知（後述） |
| ADR 起案あり | pilot-pm が返した ADR 本文を `docs/adr/NNNN-<slug>.md` としてデフォルトブランチに直接コミット & push する。番号は既存 ADR の連番。push 前に `git fetch origin` して `origin` 上の ADR と番号が重複していないか確認し、重複していれば振り直す。push が non-fast-forward で失敗した場合（coding cycle が同時刻に ADR を push したケース）は再度 `git fetch origin --prune` → 番号を取り直し → ファイル名変更 → 再コミット & push をリトライする（最大3回） |
| `phase:coding` 到達報告 | pilot-master は何もしない。coding セッション側で次 cycle に拾われる |
| 通常の phase 遷移完了（`wait_spec_review` 等で終了） | pilot-master は何もしない。次 cycle で新 pilot-pm が引き継ぐ |

pilot-master は pilot-pm が投稿した pilot-log コメントの内容を再投稿しない。pilot-pm が既に Issue に記録している。

### 5. blocked:human 付与時の Discord 通知

`blocked:human` を付与した直後に以下を実行する。`$ISSUE_URL` は `gh issue view N --json url -q .url` で取得する。

```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"<@448217636611031051> **[spec] 裁定待ち** Issue #N が blocked:human になりました。\\n$ISSUE_URL\"}")
```

`$DISCORD_WEBHOOK_URL` が未設定の場合は通知をスキップし、cycle 終了報告に「Discord 通知スキップ（DISCORD_WEBHOOK_URL 未設定）」と記載する。`$HTTP_STATUS` が 2xx 以外の場合は通知失敗扱いとし、cycle 終了報告に「Discord 通知失敗（Issue #N, HTTP $HTTP_STATUS）」と記載する。`blocked:human` ラベル付与自体は通知成否に関わらず維持する。

### 6. cycle 終了報告

呼び出し元（`pilot-spec` スキルを実行しているメインセッション）に、動かした Feature・遷移の概要・新規起票した Feature・エスカレーション有無・`phase:coding` 到達 Feature を数行で報告して終了する。報告は簡潔にすること（メインセッションのコンテキストに残るのはこの報告だけであり、ここで詳細を書くと長期運用時にメインの context window を消費する）。

## 制約

- 並列 attach は最大3体（裁定回収時の pilot-pm 起動・未起票 Feature 起票の pilot-pm 起動も枠に含める）
- pilot-master は内容判断をしない。pilot-pm や pilot-reviewer の判断に介入したくなったら constitution の不備なので `blocked:human` でユーザに委ねる
- pilot-master は pilot-pm の長い出力を要約しない（pilot-pm 側で要約済みのものを受け取る）
- 共有リソース（roadmap.md・ADR 連番・Discord 通知・`blocked:human` 付与）以外には触らない。phase ラベル遷移・pilot-log 投稿・チェックボックス更新は pilot-pm の責務である（裁定回収時の `blocked:human` 解除と裁定要約 pilot-log 投稿は例外的に pilot-master が行う）
- `phase:coding` 以降の Issue には触らない（coding セッションの責務）
- エラーや想定外の状態（label の重複・依存 Issue が closed でない等）を検出したら、修復を試みる前に pilot-log コメントに記録する
