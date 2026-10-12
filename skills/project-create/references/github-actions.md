# GitHub Actions

## 基本方針

- シークレットはGitHub Secretsで管理し、ワークフロー内にハードコードしない
- CIワークフローにはプロジェクトで使用しているツールに応じたチェック（lint, test, build等）を含める

## ツールのセットアップ

Node.js・pnpmなどのツールは`mise.toml`で管理しているため、`actions/setup-node`や`pnpm/action-setup`のような言語別セットアップActionを個別に使わず、`jdx/mise-action`で`mise.toml`に記載したツールをまとめて導入する（`coding-gh-actions` skillの方針と同じ）。

```yaml
- uses: jdx/mise-action@v4
- run: pnpm install --frozen-lockfile
```

- pnpmも`mise.toml`の`[tools]`に記載し、ローカルとCIで同じバージョンを使う
- `--frozen-lockfile` でlockファイルの更新を防ぎ、CI上での再現性を担保する

## ワークフローのデバッグ

- `act` を使ってローカルでワークフローを試す方法がある
- `workflow_dispatch` トリガーを追加しておくと、手動実行でデバッグしやすい
