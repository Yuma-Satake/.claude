# miseレジストリ登録確認手順

## 1. ショートハンド検索

```sh
mise registry <name>
```

登録されていれば `asdf:mise-plugins/mise-poetry` のようにバックエンド接頭辞つきのフルネームがstdoutに返る。未登録の場合は `tool not found in registry: <name>` がstderrに出力され、非ゼロ終了コードで終わる。

部分一致で探したいときは全件を出力してフィルタする。

```sh
mise registry | grep -i <keyword>
```

複数バックエンドで登録されているツールもある。優先順位は SKILL.md の「バックエンド選定の優先順位」に従う。

## 2. バックエンド別の絞り込み

特定バックエンドで登録されているか調べたいとき。

```sh
mise registry -b aqua
mise registry -b github
mise registry -b core
```

## 3. JSON出力による厳密判定

スクリプトから登録有無を判定したい場合。

```sh
mise registry --json <name>
```

登録があればJSONが返る。未登録時はJSONを一切返さず、stderrにエラーを出して非ゼロ終了する。CIやhookからは終了コードで判定する。

```sh
if mise registry <name> >/dev/null 2>&1; then
  echo "registered"
else
  echo "not registered"
fi
```

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
