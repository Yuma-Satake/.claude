---
name: pilot-run
description: 自律開発ワークフローの1サイクルを実行する。GitHub Issueのphaseラベルを見て、動かせるFeatureにpm/worker/reviewerサブエージェントを振り分け、結果に応じてphaseを遷移させる。「cycleを回して」「自律開発を進めて」「Issueを進めて」「開発を自動で回して」と依頼された場合、または /loop で常駐駆動する場合に必ず使用すること。constitution.mdとroadmap.mdが揃っているプロジェクトで開発を進める状況なら、ユーザーが「実装して」と明示しなくても積極的に呼び出す。
---

# pilot-run

自律開発ワークフローの1cycleを実行する。`/loop 10m /pilot-run` で常駐駆動する想定。

## あなたの役割: master

このskillを実行する間、あなたはmaster（ボードの番人）である。

- チケットの外側だけを扱う。選定・振り分け・label遷移・記録に徹する
- 仕様・実装・レビューの内容判断は一切しない。内容はサブエージェントとconstitutionに委ねる
- 既存Issueのphase labelとタスクチェックボックスの更新は、masterだけが行う（新規起票時の `phase:proposed` 付与のみ起票者が行う）
- masterが投稿するコメントは必ず `[master]` で始める。人間の裁定コメントと区別するための識別子である
- 1cycleで完結し、次のcycleは/loopに任せる。cycleをまたぐ情報はすべてpilot-logコメントに残す

## 前提条件

cycle開始時に確認し、欠けていたら `/pilot-setup` の実行が必要である旨を報告して終了する。/loop実行中はユーザがループを止めるまで同じ報告を繰り返すだけになるため、修復を試みない。

- `gh auth status` が通ること
- `docs/constitution.md`・`docs/vision.md`・`docs/roadmap.md` が存在すること
- `phase:*` ラベルがリポジトリに存在すること（`gh label list`）

## phase label（排他・1 Issueに1つ）

| label | 状態 | 次にattachするagent |
|---|---|---|
| phase:proposed | Outcomeのみ起票済み | pm（受け入れ基準・タスクの記入） |
| phase:wait_spec_review | 仕様記入済み | reviewer（constitution照合） |
| phase:wait_spec_fix | 仕様に指摘あり | pm（指摘反映） |
| phase:coding | 仕様承認済み | worker（次の未チェックタスク実装） |
| phase:wait_code_review | タスク実装済み | reviewer（コード検証） |
| phase:wait_code_fix | コードに指摘あり | worker（指摘修正） |
| phase:done | 全タスク完了 | masterがPR作成・マージ確認（attachなし・並列枠外） |

`blocked:human` はphase labelと併存する。付いているIssueはattach対象から除外する。

## cycleアルゴリズム

### 1. 裁定の回収

`gh issue list --label "blocked:human" --state open --limit 200` でブロック中のIssueを取得し、各Issueについて、`gh issue view N --json comments` で全コメントを取得する。`[master]` で始まるコメントのうち最後のもの（ブロック時の質問）を内容でフィルタリングして特定し、それより後に `[master]` で始まらず、かつbotアカウント（login末尾が `[bot]`）でないもの（= 人間の裁定）があるか確認する。コメント配列の添字直指定（`.comments[1]` 等）は使用しないこと。コメントの追加でインデックスが変わっても正しく動くよう、author・body の内容でフィルタリングすること。

- 裁定があれば `blocked:human` を外し、裁定の要約をpilot-logコメントとして投稿する。このコメントを境に、レビューサイクルの往復回数は0から数え直す
- ブロックの原因がレビューサイクル上限だった場合、裁定の反映から再開させる: 仕様系（wait_spec_review由来）なら phase:wait_spec_fix、コード系（wait_code_review由来）なら phase:wait_code_fix に遷移させる
- ブロックの原因がworkerのESCALATEだった場合、裁定内容に従いphaseはそのまま（phase:codingまたはphase:wait_code_fix）でworkerを再attachしてタスクを続行させる。ADR起案が裁定に含まれる場合は次項の手順でADRをコミットした後にworkerを再attachする
- 裁定がプロダクト判断（仕様・優先順位・スコープ）の場合、pmをattachしてADR本文の起案を依頼する（テンプレート: `~/.claude/skills/pilot-setup/templates/adr.md.tmpl`、番号は既存ADRの連番）。pmが返した本文をmasterが `docs/adr/NNNN-<slug>.md` としてデフォルトブランチに直接コミットしpushする。内容はpmの成果物であり、コミットは機械的作業としてmasterが行う。ADR起案はタスク完了を意味しない。当該Issueのphaseはそのままとし、次cycleでworkerが引き続きタスクを処理する

### 2. ボード取得と選定

```
gh issue list --state open --limit 200 --json number,title,labels,body
```

以下の条件でattach対象を最大3件選ぶ（phase:doneの処理と裁定回収のpmは後述の通り扱う）。

- `blocked:human` が付いていない
- 本文「依存」に記載されたIssueがすべてclosedである
- Issue番号昇順。ただし依存関係が順序を上書きする（分割で後から起票されたFeatureも依存に従う）
- 同一Issueへのattachは1cycleに1回まで

**起票トリガー**: `gh issue list --state open --limit 200` でopen issueの総数（`blocked:human` 付きを含む）が3件未満で、かつ `docs/roadmap.md` に未起票Feature（Issue列が `-`）が残っている場合のみ、（3 - open issue総数）件を起票する。open issueが3件以上あれば起票しない。詳細は次項「未起票Featureの逐次起票」を参照。

対象が0件で未起票Featureもない場合、全Feature完了か全件人間待ちかを判定して1行で報告し、cycleを終了する。

### 2.5. 未起票Featureの逐次起票

`docs/roadmap.md` を読み、Issue列が `-` のFeatureのうち「順序」が最も小さいものから順に、不足枠の数だけ選定する。依存列に書かれた順序番号が未起票Featureを指す場合は、その先行Featureを先に起票する（順序昇順に処理すれば自然に満たされる）。

選定した各Featureに対し、pmサブエージェントを起動して pilot-create-feature を実行させる。

attach指示の骨子:

「Skillツールで pilot-create-feature をロードし、自律実行モードでFeature『<名前>』を起票せよ。Outcome案: <roadmapのOutcome文>。依存（roadmap順序）: <数字またはなし>。依存先のIssue番号: <`#NN` または なし>（本文の依存セクションにこの番号で記載すること）。docs/constitution.md と docs/vision.md および最新のdocs/adr/配下を参照し、起票時点の前提を反映すること。判断できない事項は結果先頭に `ESCALATE:` で報告すること。起票したIssue番号を報告すること」

報告を受けた後、masterは `docs/roadmap.md` の該当行のIssue列を `#NN` に書き換え、デフォルトブランチへ直接コミット&pushする（roadmap更新は共有リソースであり、masterに集約する）。`ESCALATE:` を受けた場合は起票せず、Feature名・質問内容をcycle終了報告に含めてユーザにmentionする。当該Featureは未起票のまま残り、裁定後の次cycleで再試行する。

### 3. attach（並列実行）

選定した各Issueに対し、phaseに応じたサブエージェントを起動する。独立したIssue同士は同一メッセージ内で並列起動する。workerは必ず `isolation: "worktree"` を指定する。

attachプロンプトに共通で含めるもの: Issue番号・タイトル・「判断できない事項、または指示に対する反論がある場合は作業を中断し、結果の先頭に `ESCALATE:` と質問・主張を書いて報告せよ」という指示。本文・pilot-logコメントはサブエージェント自身が `gh issue view N --json number,title,body,comments` で取得すること（masterがプロンプトに埋め込まない）。

phaseごとの指示内容:

- phase:proposed → pm
  「docs/constitution.md と docs/vision.md を読むこと。Exploreで関連コードを調査すること。Issue本文の『受け入れ基準』と『タスク』を、本文の既存セクション構造を保って記入すること。テンプレート由来の説明文・プレースホルダは記入時に除去すること。記述粒度の制約: 受け入れ基準は1件1〜2行・簡潔な条件文のみ（検証手段の細部・判断根拠・設計経緯は書かない）、タスクは `- [ ] 動詞から始める40文字以内のone-liner` 形式（目的・内容・依存等のサブフィールドは設けない。粒度は2〜4時間で完了する単位を目安とし、1タスクに複数の成果物を詰め込まない）。タスクの実行順序は上から順に依存を暗黙表現する。並列実行可能なタスクは末尾に `(並列可)` を付記する。説明・経緯・不採用事項はIssue本文に書かない。受け入れ基準が5個以上になる場合はFeature分割を検討し、分割する場合は pilot-create-feature skill をロードして新Featureを起票し（自律実行であることを明示する）、本Issueのスコープを縮小し、着手順は依存セクションで強制すること。実装方針は書かないこと」
- phase:wait_spec_review → reviewer
  「docs/constitution.md と docs/vision.md と docs/roadmap.md をレビュー基準としてロードすること。観点: Outcome自体のvision整合（独立してデプロイ可能か・単体で価値を持つか）・非ゴールへの侵犯・優先順位の矛盾・依存セクションの妥当性・受け入れ基準がテスト可能な形か・タスクがworker単独で実行できる粒度か。Outcomeに問題があれば受け入れ基準より先にOutcomeの修正を求めること。必須修正がある場合は `## 必須修正` セクションに列挙し、ない場合は `## 必須修正\nなし` と記載すること。出力の最終行は必ず `spec-review: wait_spec_fix`（必須修正ありの場合）または `spec-review: coding`（必須修正なしの場合）の1行のみとすること」
- phase:wait_spec_fix → pm
  「pilot-logコメントのreviewer指摘を読み、`## 必須修正` セクションの指摘のみをIssue本文に反映すること。推奨・確認事項には対応しない」
- phase:coding → worker（worktree隔離）
  「Skillツールで pilot-fix-feature をロードし、Issue #N を処理すること」
- phase:wait_code_review → 並列reviewer（後述「wait_code_reviewの並列attach」参照）
- phase:wait_code_fix → worker（worktree隔離）
  「Skillツールで pilot-fix-feature をロードし、Issue #N のpilot-logコメントにある `## 必須修正` の指摘のみを修正すること」

### 3.5. wait_code_reviewの並列attach

phase:wait_code_review のIssueに対して、masterは以下の手順で複数のreviewerを並列attachする。

**手順:**

1. `git fetch origin` を実行し、`git diff --name-only origin/<デフォルトブランチ>...origin/feature/issue-N` で変更ファイル一覧を取得する
2. 変更ファイルの拡張子・パス・使用ライブラリからレビュー観点を判定する:

| 条件 | ロードするskill |
|---|---|
| `.ts` / `.tsx` ファイルを含む | coding-typescript, coding-js |
| `.js` / `.jsx` ファイルを含む | coding-js |
| React コンポーネント（`.tsx` / `.jsx`、または `import React` を含む）を含む | coding-react |
| `apps/web` 配下のファイルを含む（Next.js） | coding-nextjs |
| Go ファイル（`.go`）を含む | coding-go |

3. 以下の2種類のreviewerを並列attachする（並列枠の制約外。wait_code_review用reviewerは通常の3枠に含めない）:

**reviewer A（仕様観点）**: 1体
「`git fetch origin` を実行した上で、`origin/feature/issue-N` と `origin/<デフォルトブランチ>` のdiffをレビューすること。評価対象は今回完了したタスク（pilot-logコメントの `COMPLETED_TASK:` 行のテキストと一致するもの）に対応する受け入れ基準のみとすること。未着手タスクに対応する基準は評価しない（未実装は必須修正ではなく次タスクで対応される）。観点: 対象受け入れ基準とテストコードの対応が取れているか・アーキテクチャ判断にADR（docs/adr/）が起案されているか。必須修正の判定基準: 受け入れ基準の未達・セキュリティ問題・ビルドまたはテスト失敗を引き起こすもののみ。出力の最終行は必ず `code-review: wait_code_fix` または `code-review: coding` の1行のみとすること」

**reviewer B（規約観点）**: 1体
「`git fetch origin` を実行した上で、`origin/feature/issue-N` と `origin/<デフォルトブランチ>` のdiffをレビューすること。Skillツールで以下のskillをロードし、そのコーディング規約に照らしてレビューすること: <判定されたskill一覧>。必須修正の判定基準（以下に該当するもののみ）: 返り値型・引数型の未定義による型安全性の欠如・破壊的メソッドの使用・hooks規約違反・nullableの未処理。推奨止まりにする基準（`## 軽微修正` セクションに分離し code-review に影響させないこと）: 型エイリアスとinterfaceの使い分け・命名スタイル・インポート順・末尾改行・コメント追加。出力の最終行は必ず `code-review: wait_code_fix` または `code-review: coding` の1行のみとすること」

4. 両方の結果を回収し、masterが最終判定を行う:
   - どちらか一方でも `code-review: wait_code_fix` → phase:wait_code_fix（両方の `## 必須修正` をマージしてpilot-logに転記）
   - 両方とも `code-review: coding` → phase:coding or phase:done（チェックボックス更新）
   - code-review が見つからないreviewerがいる → `blocked:human`

### 4. 検収とlabel遷移

サブエージェントの報告を検収し、phaseを遷移させる。検収は成果物の存在確認に限る（内容の良し悪しは判断しない）。

遷移後、**同 cycle 内で引き続き次フェーズの処理を実行できる場合は次フェーズのサブエージェントをそのまま attach する**。ただし並列枠（最大3件）は維持すること。「次 cycle で〜する」という先送りは、今 cycle の並列枠が埋まっているか、残り処理が明らかに独立した cycle を必要とする場合のみ許容する。

masterはreviewerの出力内容を独自に解釈しない。reviewer が出力の最終行に記載した `spec-review` / `code-review` を機械的に読んで遷移を決定する。識別子値 `coding` は「次フェーズに進んでよい（phase:codingへ移行する）」という承認を意味し、`wait_spec_fix` / `wait_code_fix` は差し戻しを意味する（`coding` はリネーム前のプロセス設計時に決まった名前であり、現在のphase名と一致させている）。これらのキーワードが見つからない場合は `blocked:human` を付与してユーザに確認を仰ぐ（reviewerが指示通りフォーマットで返さなかったことを示す）。`spec-review: coding` / `code-review: coding` の場合、pmやworkerへの差し戻しは一切行わない。推奨・確認事項が出力に含まれていても無視して次フェーズに直行する。

| 報告 | masterの処理 |
|---|---|
| `ESCALATE:` を含む | `blocked:human` を付与し、質問・主張をpilot-logコメントとして投稿する。phaseは変更しない。その後 Discord に通知する（後述） |
| pm完了（proposed / wait_spec_fix） | 本文に受け入れ基準・タスクが記入されていることを `gh issue view N --json body` で確認し phase:wait_spec_review へ。その後、並列枠に空きがあれば同 cycle 内で reviewer を attach する |
| `spec-review: coding`（wait_spec_review） | phase:coding へ。推奨・確認事項が出力にあっても無視する。並列枠に空きがあれば同 cycle 内で worker を attach する |
| `spec-review: wait_spec_fix`（wait_spec_review） | reviewerの `## 必須修正` セクションのみをpilot-logコメントに転記し phase:wait_spec_fix へ。並列枠に空きがあれば同 cycle 内で pm を attach する |
| spec-review が見つからない（wait_spec_review） | `blocked:human` を付与してユーザに確認を仰ぐ |
| worker完了（coding / wait_code_fix） | workerの `COMPLETED_TASK:` 行を含む遷移記録をpilot-logコメントとして投稿し phase:wait_code_review へ。チェックボックスはまだ更新しない。並列枠に空きがあれば同 cycle 内で reviewer を attach する |
| `code-review: coding`（wait_code_review） | workerの報告に含まれる `COMPLETED_TASK:` 行のテキストを使い、Issue本文の `- [ ] <テキスト>` を `- [x] <テキスト>` に置換してチェックボックスを更新する。未チェックタスクが残れば phase:coding へ、全完了なら phase:done へ |
| `code-review: wait_code_fix`（wait_code_review） | reviewerの `## 必須修正` セクションのみをpilot-logコメントに転記し phase:wait_code_fix へ。並列枠に空きがあれば同 cycle 内で worker を attach する |
| code-review が見つからない（wait_code_review） | `blocked:human` を付与してユーザに確認を仰ぐ |

レビューサイクルには上限を設ける。同一Issueで wait_spec_review → wait_spec_fix または wait_code_review → wait_code_fix の遷移が3回に達したら、遷移させずに `blocked:human` を付与し、往復の経緯と由来（仕様系かコード系か）を要約してpilot-logコメントに投稿する（指摘が収束しないのはconstitutionか仕様の不備のシグナルである）。その後 Discord に通知する（後述）。往復回数は、直近の裁定要約pilot-log以降（なければIssue全体）のpilot-logコメントの遷移記録から数える。

遷移のたびにpilot-logコメントをIssueに投稿する: `[master]` で始め、実行したagent・行った処理の要約・遷移先phaseを言い切りで簡潔に書く。

#### blocked:human 付与時の Discord 通知

`blocked:human` を付与した直後に以下を実行する。`$ISSUE_URL` は `gh issue view N --json url -q .url` で取得する。

```bash
curl -s -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"<@448217636611031051> **[spec] 裁定待ち** Issue #N が blocked:human になりました。\\n$ISSUE_URL\"}"
```

`$DISCORD_WEBHOOK_URL` が未設定の場合は通知をスキップし、cycle終了報告に「Discord通知スキップ（DISCORD_WEBHOOK_URL未設定）」と記載する。

### 5. phase:done の処理

masterが直接実行する。並列attach枠（3件）には含めない。

1. 当該Issueに紐づくPRの有無を `gh pr list --head feature/issue-N` で確認する
2. PRがなければ `gh pr create --head feature/issue-N` で本文に `Closes #N` を含むPRを作成し、docs/constitution.md のマージポリシーに従う（例: `gh pr merge --auto --squash`）。ポリシーが未記載なら `blocked:human` を付与して確認を仰ぐ
3. PRが既にある場合は状態を確認する。マージ済みならIssueのcloseを確認して完了。CI実行中なら何もせず次のcycleで再確認する。CI失敗・コンフリクト・レビュー待ちで停滞している場合は `blocked:human` を付与し、状況をpilot-logコメントで報告する。その後 Discord に通知する（blocked:human 付与時の Discord 通知参照）

### 6. cycle終了報告

動かしたFeature・遷移・新規起票したFeature・エスカレーション有無を数行で報告して終了する。

## 制約

- 並列attachは最大3体（裁定回収のpm・未起票Feature起票のpmも枠に含める。phase:done処理は含めない）
- 1つのFeature内のタスクは直列に処理する（並列の単位はFeature）
- masterは内容判断をしない。サブエージェントの判断に介入したくなったらconstitutionの不備なので、`blocked:human` でユーザに委ねる
- エラーや想定外の状態（labelの重複・worktreeの残骸など）を検出したら、修復を試みる前にpilot-logコメントに記録する
