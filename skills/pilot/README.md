# pilot

自律開発ワークフロー「pilot kit」の Claude Code plugin。skills-directory plugin（`@skills-dir`）として配置することで、追加の marketplace・install なしに自動ロードされる。

## 構成

```
pilot/
├── .claude-plugin/plugin.json
├── CONVENTIONS.md                       # 共通規約（phase ラベル・pilot-log・ESCALATE 等）
├── skills/
│   ├── pilot-spec/                      # メインセッション用（spec）: pilot-master を spec モードで起動する薄いラッパー
│   ├── pilot-coding/                    # メインセッション用（coding）: pilot-master を coding モードで起動する薄いラッパー
│   ├── pilot-spec-cycle/                # pilot-master 内部用（spec）: 1cycle のアルゴリズム
│   ├── pilot-coding-cycle/              # pilot-master 内部用（coding）: 1cycle のアルゴリズム
│   ├── pilot-drive-feature-spec/        # pilot-pm 内部用（spec）: 1 Feature の仕様策定駆動
│   ├── pilot-drive-feature-coding/      # pilot-pm 内部用（coding）: 1 Feature の実装駆動
│   ├── pilot-setup/                     # 初回セットアップ（対話的）
│   │   ├── SKILL.md
│   │   └── templates/                   # constitution/vision/roadmap/adr/spec-feature-issue
│   ├── pilot-create-feature/            # Feature Issue 起票（自律実行・spec 側で使用）
│   └── pilot-fix-feature/               # 1タスク実装（pilot-worker 用・coding 側で使用）
└── agents/
    ├── pilot-master.md                  # 役割: cycle のボード番人（モードに応じた cycle skill をロード）
    ├── pilot-pm.md                      # 役割: Feature owner（モードに応じた drive-feature skill をロード）
    ├── pilot-worker.md                  # 役割: 実装担当
    └── pilot-reviewer.md                # 役割: レビュー担当（指摘は呼び出し元への戻り値のみ、issue には書き込まない）
```

## agent と skill の責務分離

- **agent**: 役割としての性格・判断スタンスのみを定義する。具体的な作業手順は持たない
- **skill**: 役割に与えられる作業手順・注意点を定義する。agent が起動時にロードして実行する
- agent は spec/coding のモード違いを保持しない。モードは起動プロンプトとロードされる skill によって注入される

| agent | spec モードでロードする skill | coding モードでロードする skill |
|---|---|---|
| pilot-master | `pilot:pilot-spec-cycle` | `pilot:pilot-coding-cycle` |
| pilot-pm | `pilot:pilot-drive-feature-spec` | `pilot:pilot-drive-feature-coding` |
| pilot-worker | （spec では起動されない） | pilot-pm から `pilot:pilot-fix-feature` を指示される |
| pilot-reviewer | 仕様観点のみ（skill 指定なし） | 仕様観点（skill 指定なし）に加え、変更ファイルから判定された規約観点 skill（`coding-typescript` / `coding-js` / `coding-react` / `coding-nextjs` / `coding-go` のいずれか）を並列起動した複数 pilot-reviewer がそれぞれ1つずつロードする |

共通規約（phase ラベル一覧・pilot-log 形式・記載粒度ルール・ESCALATE 規約・worktree 隔離・レビューサイクル上限・サブエージェント起動の制約・バックフロー）は `CONVENTIONS.md` に集約されている。各 agent / skill はここを参照する。

## 呼び出し方

エントリ skill: `/pilot:pilot-setup`、`/pilot:pilot-spec`、`/pilot:pilot-coding`、`/pilot:pilot-create-feature`、`/pilot:pilot-fix-feature`

agent: `pilot-master`、`pilot-pm`、`pilot-worker`、`pilot-reviewer`

`pilot-spec-cycle` / `pilot-coding-cycle` / `pilot-drive-feature-spec` / `pilot-drive-feature-coding` は agent 内部用の skill。メインセッションや他 agent から直接呼ばない。

## 初回セットアップ

```
/pilot:pilot-setup
```

`docs/constitution.md`・`docs/vision.md`・`docs/roadmap.md` と phase ラベル・`docs/adr/` を準備する。

## 自律駆動

spec セッションと coding セッションを別々のメインセッションで並走させる。phase 集合が排他なので同一 Issue を両セッションが同時に触ることはない。

```
# セッション A（要件定義側）
/loop 30m /pilot:pilot-spec

# セッション B（実装側）
/loop 30m /pilot:pilot-coding
```

30分間隔で各セッションが1cycle回す。ユーザの関与は `blocked:human` ラベル付き Issue へのコメント裁定のみ。

## 設計思想

- **spec/coding の責務分離**: 要件定義（仕様策定・仕様レビュー・起票）と実装（タスク実装・コードレビュー・PR 作成）を別セッションで並走させる。phase 集合（`proposed` / `wait_spec_*` は spec、`coding` / `wait_code_*` / `done` は coding）で排他制御される
- **pilot-master が cycle 全体を司り、最大3体の pilot-pm を並列起動する**: spec モードでは仕様策定の pm を、coding モードでは実装の pm を起動する
- **各 pilot-pm は1 Feature を担当**: spec モードなら仕様記入 → pilot-reviewer 起動 → 連鎖駆動、coding モードなら pilot-worker / pilot-reviewer を起動して実装 → review → 修正 → 再 review を1セッション内で完結
- **レビュー指摘は pilot-pm のコンテキスト内に保持**: pilot-reviewer は issue に書き込まず、指摘リストを pilot-pm に戻すだけ。pilot-pm が必要最小限の情報のみを pilot-log として残す（issue コメント肥大化の根治）
- **状態は GitHub Issue に集約**: phase ラベル・タスクチェックボックス・cycle 境界をまたぐ pilot-log コメントのみで状態を表現し、cycle 間で全 agent を破棄しても復元できる
- **バックフロー**: coding セッションが仕様矛盾を検出した場合、pilot-master が `phase:wait_spec_fix` に戻して `blocked:human` 付与。次の spec cycle が自動回収して仕様修正に入る
- **メインセッションのコンテキスト保護**: メインセッションには「pilot-master 起動 + 数行の cycle 終了報告」しか積まれない

## 関連ファイル

- `${CLAUDE_PLUGIN_ROOT}/CONVENTIONS.md`: 共通規約
- `${CLAUDE_PLUGIN_ROOT}/skills/pilot-setup/templates/`: テンプレート群（agent / skill から参照される）
- `~/.claude/agents/worker.md`・`reviewer.md`: 汎用版。pilot kit とは別物で、他の skill から利用される
