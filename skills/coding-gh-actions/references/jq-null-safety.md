# GraphQL APIレスポンスをjqで処理する際のnull安全化

`gh api graphql` のレスポンスをjqでパースする際、期待した値が存在しない（フィールドがnull、対象データが存在しない等）ケースを考慮しないと、jqがエラー終了しスクリプトが意図せず中断する。`set -euo pipefail` 環境下では特に致命的になる。

## 配列の反復: `.foo[]` ではなく `.foo[]?` を使う

`.foo` がnullの場合、`.foo[]` は `jq: error (at <stdin>:1): Cannot iterate over null (null)` でexit 5となり、後続の空値チェック（`if [ -z "$var" ]`）に到達する前にスクリプトが落ちる。

```bash
# NG: repository.issue が null（issue不存在等）だとクラッシュする
item_id=$(echo "$response" | jq -r \
  '.data.repository.issue.projectItems.nodes[] | select(.project.number == 659) | .id')

# OK: nodes が存在しない/null の場合は何も出力せず、item_id は空文字列になる
item_id=$(echo "$response" | jq -r \
  '.data.repository.issue.projectItems.nodes[]? | select(.project.number == 659) | .id')
```

## スカラー値の取得: `// empty` を付ける

`.foo.bar` が存在しない場合、`jq -r` は文字列 `"null"` を出力する。これは `[ -z "$var" ]` によるチェックをすり抜けてしまう（`$var` が空文字列ではなく `"null"` という4文字の文字列になるため）。

```bash
# NG: field が null の場合、field_id には文字列 "null" が入り -z チェックをすり抜ける
field_id=$(echo "$response" | jq -r '.data.organization.projectV2.field.id')

# OK: null/false の場合は空文字列を返す
field_id=$(echo "$response" | jq -r '.data.organization.projectV2.field.id // empty')
```

## チェックリスト

`gh api graphql` の結果をjqでパースするコードを書く/レビューする際は、以下を確認する。

- レスポンス中の各フィールドが「対象が存在しない」ケースでnullになり得るか洗い出す
- null配列を反復する箇所は全て `[]?` にしているか
- nullになり得るスカラー値の取得は全て `// empty` を付けているか（`-z` チェックと組み合わせる場合は必須）
- 実装後、実際に空レスポンス（対象なし）を模したJSONでjqコマンド単体を実行し、エラーにならず期待通り空文字列になることを確認する
