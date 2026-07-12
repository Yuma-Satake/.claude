---
name: mise-tool-management
description: miseで開発ツール（CLI・ランタイム）を追加・更新・削除する際に参照するスキル。ツールがmiseレジストリに登録されているかの確認手順、未登録ツールをGitHubリリースやaquaレジストリ経由で導入する判断フローを含む。「miseでツールを追加して」「mise.tomlに入れて」「このCLIをmiseで管理したい」「miseで入るか調べて」「バージョン管理どうする」といった依頼で必ず使用すること。
---

# mise ツール管理方針

miseで新しいツールを導入・更新するときは、必ず以下のフローで進める。

## 導入フロー

1. レジストリ確認: `mise registry <name>` でショートハンドが引けるか確認する。詳細は `references/registry-check.md` を参照する
2. 未登録の場合の代替バックエンド判断: aqua もしくは github バックエンドで導入可能か調査する。詳細は `references/github-fallback.md` を参照する
3. バージョン固定: `latest` を書かず、必ず具体的なバージョン番号を `mise.toml` に記載する
4. 反映確認: `mise install` と `mise doctor` で解決状況を確認する

## 基本ルール

- `mise.toml` はプロジェクトルートに配置し、コミット対象に含める
- 新規に `mise.toml` を配置した直後は `mise trust` を実行してから `mise install` を実行する
- グローバル導入（`~/.config/mise/config.toml`）はユーザの明示指示がある場合のみ行い、プロジェクト用ツールは常にプロジェクトの `mise.toml` に書く
- `mise use <name>@<version>` で追加すると `mise.toml` に自動追記される。手書きで足す場合はセクション（`[tools]`）とキーの重複に注意する
- 削除は `mise use --rm <name>` を用い、`mise.toml` を直接編集する場合も対応するインストール済みバージョンを `mise uninstall` で消す

## バックエンド選定の優先順位

1. コアバックエンド（`core:`）で提供されるランタイム（node, python, go, ruby など）は素の名前で指定する
2. aquaレジストリで提供されるツールは `aqua:owner/name` を優先する（署名検証やSLSA検証を持つため）
3. aquaに無くGitHubリリースにバイナリがある場合は `github:owner/name` を使う
4. `ubi:` は非推奨のため新規採用しない。既存の `ubi:` 記述を見つけたら `github:` への置換を提案する
5. `asdf:` `vfox:` はサプライチェーン上のリスクがあるため新規採用しない

## 禁止事項

- `mise.toml` に `latest` や範囲指定（`^1.2.3` など）を書かない
- レジストリに存在するのに `github:` を明示的に指定して上書きしない。ユーザに理由がある場合のみ許容する
- ユーザに確認せず勝手にツールをインストールしない。導入するツール名・バージョン・バックエンドを提示し合意を得てから実行する
