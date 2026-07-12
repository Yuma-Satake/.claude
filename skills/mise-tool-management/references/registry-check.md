# miseレジストリ登録確認手順

新しいツールを `mise.toml` に追加する前に、必ず登録状況を確認する。

## 1. ショートハンド検索

```sh
mise registry <name>
```

登録されていれば `asdf:mise-plugins/mise-poetry` のようにバックエンド接頭辞つきのフルネームが返る。何も返らない場合は未登録。

部分一致で探したいときは全件を出力してフィルタする。

```sh
mise registry | grep -i <keyword>
```

同名で複数バックエンドが登録されている場合もあるため、grep結果は複数行になり得る。優先順位は SKILL.md の「バックエンド選定の優先順位」に従う。

## 2. バックエンド別の絞り込み

特定バックエンドで登録されているか調べたいとき。

```sh
mise registry -b aqua
mise registry -b github
mise registry -b core
```

## 3. JSON出力による厳密判定

スクリプトから判定したい場合はJSONで取得する。

```sh
mise registry --json <name>
```

存在しない場合は空オブジェクトが返る。CIやhookから呼び出す場合はexit codeではなく出力内容で判定する。

## 4. 実際にインストール可能か確認

登録されていてもバージョン解決に失敗するケースがある。`mise ls-remote` で候補が返ることまで確認するのが望ましい。

```sh
mise ls-remote <name>
mise ls-remote <name> "<version-prefix>"
```

## 5. レジストリソースを直接見る

CLIで解決できない、あるいは詳細な設定（`asset_pattern` など）を知りたい場合は、GitHub上のレジストリソースを参照する。

- mise本体のレジストリ定義: https://github.com/jdx/mise/blob/main/registry.toml
- aquaレジストリ検索: https://github.com/aquaproj/aqua-registry の `pkgs/<owner>/<name>/registry.yaml`

aquaレジストリにあれば `aqua:owner/name` で導入できる。無ければ github バックエンドの検討に移る（`references/github-fallback.md`）。
