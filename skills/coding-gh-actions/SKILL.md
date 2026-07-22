---
name: coding-gh-actions
description: GitHub Actionsのワークフローファイルのコーディング規約を提供する。`.github/workflows/` 配下のYAMLファイルを新規作成・編集する際に必ず参照すること。トリガー設定、権限管理、シークレット・環境変数の扱い、ジョブ・ステップ設計、再利用可能ワークフロー、サードパーティActionのバージョン固定など、GitHub Actions実装のための規約が含まれる。
---

# GitHub Actions コーディング規約

## スクリプト実行

- ワークフロー内でコマンドやスクリプトを実行する場合、`actions/github-script` などJavaScriptベースの実装ではなく、シェルスクリプト（`run:` ステップ）を原則使用すること

## ツールセットアップ（mise）

- 対象プロジェクトで mise（``mise.toml`など）が使用されている場合、`actions/setup-node` や `actions/setup-go`のような言語別セットアップActionを個別に使わず、`jdx/mise-action` を使ってツールのセットアップを行うこと

## GraphQL APIレスポンスのjq処理

- `gh api graphql` のレスポンスをjqでパースする場合、対象データが存在しない・フィールドがnullになるケースを想定しないと、`set -euo pipefail` 環境下でjqがエラー終了しスクリプトが意図せず中断する
- 詳細な対処パターン（`[]?` による配列のnull安全な反復、`// empty` によるスカラー値のnull安全な取得）は `references/jq-null-safety.md` を参照すること

## 動作確認（CI実行によるチェック）

- ワークフローファイルの変更はローカルで完全には検証できず、実際にCIを動かして初めて動作確認できる場合が多い
- PRを出すことでCIによる動作確認ができる変更の場合、まずユーザにPRを発行してよいか確認を取ること
- 承認が得られた場合、PRを発行した後は該当ワークフローのCI実行が正しく完了する（成功する、またはエラーがない）まで結果をチェックすること
