# GitHub Actions

## 基本方針

- シークレットはGitHub Secretsで管理し、ワークフロー内にハードコードしない
- CIワークフローにはプロジェクトで使用しているツールに応じたチェック（lint, test, build等）を含める

## pnpmのセットアップ

GitHub Actionsでpnpmを使う場合は `pnpm/action-setup` を使用する。バージョンはpackage.jsonの `packageManager` フィールドから自動検出させる構成が望ましい。

```yaml
- uses: pnpm/action-setup@v4
- uses: actions/setup-node@v4
  with:
    node-version-file: "mise.toml"
    cache: "pnpm"
- run: pnpm install --frozen-lockfile
```

`--frozen-lockfile` でlockファイルの更新を防ぎ、CI上での再現性を担保する。

## miseとの連携

Node.jsのバージョンをmise.tomlで管理している場合、`setup-node` の `node-version-file` に `mise.toml` を指定できる。ただし、mise.tomlのフォーマットによっては読み取れない場合があるため、その場合は `.node-version` ファイルを併用するか、バージョンを直接指定する。

## ワークフローのデバッグ

- `act` を使ってローカルでワークフローを試す方法がある
- `workflow_dispatch` トリガーを追加しておくと、手動実行でデバッグしやすい
