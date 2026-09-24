# 共通セットアップ方針

## バージョンの原則

全てのツール・ライブラリは、特別な理由がない限り可能な限り新しいバージョンを使用する。バージョン指定には `latest` やレンジ指定ではなく、具体的なバージョン番号を記載すること（例: `"20.19.0"`, `"5.7.3"`）。指定する前にその時点での最新安定版を確認する。

LTS（Long Term Support）の概念を持つツール・ランタイム（Node.jsなど）については、「最新」はLTS版の中での最新を指す。LTS化前の最新版（Node.jsのCurrentリリース等）は長期サポートが保証されないため、特別な理由がない限り採用しない。

## ツール選定

### 言語・ランタイム・パッケージ管理

| 用途 | 採用ツール | 不採用の代替 |
| --- | --- | --- |
| 言語 | TypeScript | JavaScript |
| Node.js/パッケージマネージャーなどのバージョン管理 | mise（mise.toml） | nvm, volta, asdf |
| パッケージマネージャ | pnpm | npm, yarn, bun |
| モジュールシステム | ES Modules | CommonJS |

### コード品質

| 用途 | 採用ツール | 不採用の代替 |
| --- | --- | --- |
| リンター | oxlint | Biome, ESLint |
| フォーマッター | oxfmt（2026年時点でv0.x・実験的。安定版が出るまで挙動変更に注意し、定期的に見直す） | Biome, Prettier |
| Gitフック | Lefthook | husky + lint-staged |
| テスト | Vitest | Jest |

oxfmtは.astroファイルのフォーマットに未対応（2026年時点）。oxlintは.astroファイル内のスクリプト部分もlint対象になる。

## pnpm利用時の注意事項

- pnpm v10以降はセキュリティ上、依存パッケージの`postinstall`等のビルドスクリプト（lefthookのバイナリダウンロードなど）をデフォルトでブロックする。`pnpm install`実行後に`[ERR_PNPM_IGNORED_BUILDS]`が出た場合は、`pnpm approve-builds --all`（または対象パッケージを指定して`pnpm approve-builds <pkg>`）を実行して承認する。承認結果は`pnpm-workspace.yaml`の`allowBuilds`に記録されるため、これもコミット対象に含める。

## miseの初回セットアップ時の注意事項

- 新規に`mise.toml`を配置したプロジェクトで`mise install`等を実行すると、`mise ERROR Config files in ... are not trusted`というエラーになる場合がある。先に`mise trust`を実行して設定ファイルを信頼させる必要がある。

## セットアップ時に必ず導入するもの

- Lefthookによるpre-commitフック（oxlint・oxfmtのチェックを走らせる）
- GitHub ActionsによるCIワークフロー（lint, test, build）
- GitHub Actionsは可能な場合、実際にcommit/push/PR作成/mergeを行ってCIが正しく動作するか確認すること

## セットアップ時の注意事項

### AIにセットアップを依頼した後の確認ポイント

AIがプロジェクトを初期セットアップした場合、以下の点を手動で確認・調整する必要がある。AIは「とりあえず動く」構成を作るが、不要な設定や過剰な依存を含みやすい。

- 不要な依存パッケージが入っていないか（使わないライブラリ、重複する機能を持つパッケージ）
- 設定ファイルの中身が意図通りか（oxlint、oxfmt、Lefthook、TypeScript等の設定が過剰でないか）
- ディレクトリ構造が既存プロジェクトと整合しているか
- .gitignoreに必要な項目が含まれているか（.env、node_modules、ビルド出力等）