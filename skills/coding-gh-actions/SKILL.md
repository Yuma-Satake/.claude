---
name: coding-gh-actions
description: GitHub Actionsのワークフローファイルのコーディング規約を提供する。`.github/workflows/` 配下のYAMLファイルを新規作成・編集する際に必ず参照すること。トリガー設定、権限管理、シークレット・環境変数の扱い、ジョブ・ステップ設計、再利用可能ワークフロー、サードパーティActionのバージョン固定など、GitHub Actions実装のための規約が含まれる。
user-invocable: false
---

# GitHub Actions コーディング規約

## スクリプト実行

- ワークフロー内でコマンドやスクリプトを実行する場合、`actions/github-script` などJavaScriptベースの実装ではなく、シェルスクリプト（`run:` ステップ）を原則使用すること

## ツールセットアップ（mise）

- 対象プロジェクトで mise（``mise.toml`など）が使用されている場合、`actions/setup-node` や `actions/setup-go`のような言語別セットアップActionを個別に使わず、`jdx/mise-action` を使ってツールのセットアップを行うこと

## GraphQL APIレスポンスのjq処理

- `gh api graphql` のレスポンスをjqでパースする場合、対象データが存在しない・フィールドがnullになるケースを想定しないと、`set -euo pipefail` 環境下でjqがエラー終了しスクリプトが意図せず中断する
- 詳細な対処パターン（`[]?` による配列のnull安全な反復、`// empty` によるスカラー値のnull安全な取得）は `references/jq-null-safety.md` を参照すること

## ローカル静的検証（actionlint / shellcheck）

- `.github/workflows/` 配下のYAMLファイルを変更した場合、`actionlint <file>` で静的検証すること。actionlintはPATH上に`shellcheck`があれば`run:`ステップのシェルスクリプトも自動でshellcheck解析する
- `.github/actions/` 配下のcomposite action定義（`action.yml`）はワークフロー用スキーマ（`jobs`/`on`必須）と異なるため、actionlintの対象外。`runs.steps[].run` のシェルスクリプト部分を抜き出し、`shellcheck` 単体に渡して検証すること
- actionlint・shellcheckはmiseでグローバル導入済み（`~/.config/mise/config.toml`）。Bashツール経由の実行では`mise activate`のPATH注入が効かないことがあるため、`command not found`になる場合は `mise exec actionlint shellcheck -- <command>` の形で実行すること

## 再利用可能ワークフロー（workflow_call）内でのイベント判定

- `workflow_call`経由で呼び出されたジョブの中でも、`github.event_name`は呼び出し元のトップレベルイベント名（`push`・`workflow_dispatch`等）を継承する。`workflow_call`という値を取ることは無いため、`github.event_name != 'workflow_call'`のような式で「直接実行か呼び出し経由か」を判定することはできない
- 直接実行と呼び出し経由を区別する必要がある場合（例: `environment:`による承認ゲートを呼び出し経由だけ外す）は、`github.event_name == 'workflow_dispatch'`のように直接実行時のイベント名を正の条件として判定するか、呼び出し元が渡す専用のboolean inputを使うこと

## 動作確認（CI実行によるチェック）

- ワークフローファイルの変更はローカルで完全には検証できず、実際にCIを動かして初めて動作確認できる場合が多い
- PRを出すことでCIによる動作確認ができる変更の場合、まずユーザにPRを発行してよいか確認を取ること
- 承認が得られた場合、PRを発行した後は該当ワークフローのCI実行が正しく完了する（成功する、またはエラーがない）まで結果をチェックすること
