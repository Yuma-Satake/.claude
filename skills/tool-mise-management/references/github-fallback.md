# レジストリ未登録ツールの導入手順

`mise registry <name>` で見つからなかったツールをどう導入するかの判断フロー。

## 判断フロー

1. aquaレジストリに存在するか確認する
2. 無ければGitHubリリースの構成を調べ、`github:` バックエンドで解決可能か判断する
3. どちらも不可の場合はユーザに報告し、mise以外の導入手段を提案する（勝手に代替手段を選ばない）

## aquaレジストリの確認

以下のいずれかで確認する。

- Web検索: https://github.com/aquaproj/aqua-registry の `pkgs/<owner>/<name>/registry.yaml` があるか
- ローカル調査: aquaのregistry.yamlを検索する

存在すればそのまま指定する。

```toml
[tools]
"aqua:<owner>/<name>" = "<version>"
```

aquaに登録があればgithubより優先する。ただし署名検証・SLSA検証が自動で走るのは、aquaレジストリの当該エントリに `github_artifact_attestations` / `cosign` / `slsa_provenance` の設定が入っているツールに限られる。全ツールで自動的に検証されるわけではない。

## GitHubバックエンドで解決可能かのチェック

以下の条件を全て満たす場合、`github:owner/repo` で導入可能な可能性が高い。

- リポジトリのReleasesページに対象OS・アーキテクチャ向けのバイナリアセット（`.tar.gz` `.zip` `.tar.xz` など）がアップロードされている
- アセット名にOS（`linux` `darwin` `windows` など）とアーキテクチャ（`x86_64` `amd64` `arm64` など）が含まれる、または一意に判定できる命名になっている
- タグが `v` 接頭辞または一般的な semver 形式である

確認コマンド例。

```sh
gh release list --repo <owner>/<repo> --limit 5
gh release view <tag> --repo <owner>/<repo>
```

アセット構造が確認できたら以下のように追加する。

```sh
mise use <backend>:<owner>/<repo>@<version>
```

## github: バックエンドの追加オプションが必要なケース

素の `github:owner/repo` で解決できないとき、次のオプションを検討する。設定は `mise.toml` の tools セクションに書く。

| 状況 | 使うオプション |
| --- | --- |
| リリースタグが `release-` などv以外の接頭辞 | `version_prefix` |
| アセット名の自動判定に失敗する | `matching` または `matching_regex` |
| バイナリ名がリポジトリ名と異なる | `bin` または `rename_exe` |
| アーカイブ内のサブディレクトリにバイナリがある | `bin_path`, `strip_components` |
| macOSで `.app` を避けたい | `no_app = true` |

記載例。

```toml
[tools]
"github:oxc-project/oxc" = { version = "0.34.0", matching = "oxlint" }
```

## 一つのリリースから複数バイナリを取り出すケース

一つのGitHubリリースが複数のバイナリを含む場合、`tool_alias` で別名を分け、それぞれに異なる `matching` を指定する。

```toml
[tool_alias]
oxlint = "github:oxc-project/oxc"
oxfmt = "github:oxc-project/oxc"

[tools]
oxlint = { version = "0.34.0", matching = "oxlint" }
oxfmt = { version = "0.34.0", matching = "oxfmt" }
```

## 判断できないケース

以下は自己判断せず、ユーザに確認する。

- アセットが `.deb` `.rpm` のみでtar/zipアーカイブが無い
- アセット名にOS・アーキテクチャ情報が無くビルド判別できない
- 独自のインストーラスクリプト（`install.sh`）経由のみ配布されている
- 対象ツールが実行時に別ランタイム（JVMなど）を要求する

## ubi: バックエンドの取り扱い

`ubi:` は非推奨。既存プロジェクトで `ubi:owner/repo` を見つけた場合は、動作確認の上で `github:owner/repo` へ置換を提案する。勝手に書き換えず、置換案と理由を提示してから実施する。
