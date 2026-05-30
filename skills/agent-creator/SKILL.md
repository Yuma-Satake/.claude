---
name: agent-creator
description: .claude/agents/ 配下にagentファイルを新規作成・編集する際の仕様とベストプラクティスを提供する。agentを作る、agentを追加したい、agentを修正したいと言われた場合に使用する。
---

# agent-creator

## agentファイルの配置

`~/.claude/agents/<name>.md` または プロジェクトの `.claude/agents/<name>.md` に配置する。

## frontmatterフィールド一覧

| フィールド | 必須 | 説明 |
|---|---|---|
| `name` | 必須 | 一意識別子。小文字とハイフンで記述する |
| `description` | 必須 | Claudeがいつこのagentを使うべきかを示すテキスト |
| `tools` | 任意 | 使用可能なツール一覧。省略時は全ツール継承 |
| `disallowedTools` | 任意 | 継承ツールから除外するツール |
| `model` | 任意 | `sonnet`/`opus`/`haiku`/full model ID。省略時は`inherit` |
| `permissionMode` | 任意 | `default`/`acceptEdits`/`auto`/`bypassPermissions` など |
| `maxTurns` | 任意 | agentic turnsの上限 |
| `skills` | 任意 | preloadするskill名。内容全体がcontextに注入される |
| `background` | 任意 | `true`でbackground taskとして動作 |
| `color` | 任意 | `red`/`blue`/`green`/`yellow`/`purple`/`orange`/`pink`/`cyan` |

## サブagentで使用できないツール

以下のツールはサブagentのtoolsに指定しても動作しない。

- `AskUserQuestion`
- `Agent`
- `EnterPlanMode` / `ExitPlanMode`
- `ScheduleWakeup`
- `WaitForMcpServers`

ユーザーへの確認が必要な場合は、テキスト出力として質問を記述する。

## agentとskillの使い分け

| | Agent | Skill |
|---|---|---|
| contextの独立性 | 独立（結果要約のみ親に返る） | 親sessionと共有 |
| 向いている用途 | レビュー・探索・並行実行 | 繰り返し手順・規約参照 |
| context消費 | 少ない（要約のみ） | 多い（全内容がcontextに含まれる） |

## descriptionの書き方

- 何をするagentかを1文で説明する
- 使用タイミング（「〜する場合に使用」「〜後に起動」）を明示する
- 起動してほしい条件を具体的に書く

悪い例: `コードをレビューするagent`
良い例: `テストカバレッジを分析し、テスト観点の漏れを指摘するQAエキスパート。テストファイルが存在するリポジトリでのみ使用する。`

## agentの設計原則

- ペルソナ（キャラクター・行動原則）はagentに持たせる
- 技術知識・規約はskillに持たせ、agentからSkillツールでロードする
- agentに具体的なskill名をハードコードしない（skill追加・変更のたびに更新が必要になる）
- 強調表現（「必ず」「絶対に」等）は使わない。Sonnet 4.6系ではオーバートリガーの原因になる
- `model` は原則省略する（`inherit`がデフォルト）
