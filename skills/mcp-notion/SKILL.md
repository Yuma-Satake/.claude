---
name: mcp-notion
description: Notion MCPツール（mcp__notion__*）のベストプラクティスを提供する。Notionページの検索・取得・更新・コメント操作を行う場合に使用する。
user-invocable: false
---

# Notion MCP

Notion MCPツールを使用する際に参照するナレッジ集。運用しながら知見をここに追記していく。

このプロジェクトのNotion MCPサーバー（`@notionhq/notion-mcp-server`）が公開するツールは `notion-fetch` のような名前ではなく、`API-post-search`、`API-patch-block-children` のような `API-` プレフィックスのOpenAPIラッパー形式である。

## 投稿・更新時の注意

- Notionのコメントは編集できないので、記録は原則コメントではなく本文への追記にする
- 本文への**追記**（既存内容を残したい場合）には `API-patch-block-children`（ブロック子要素の末尾追加）を使う。`API-update-page-markdown` は使わない。`type: replace_content` はページ全体を置換してしまい、`type: insert_content` はdeprecated扱いのため、追記の手段として安全ではない
  - これは追記に限った注意であり、既存内容を意図的に別の内容へ**完全に書き換える**場合は `type: replace_content` が本来の用途に合っている（ページの目的そのものを変える場合など）
- `API-update-page-markdown` の `replace_content` / `update_content` パラメータは、JSON Schema上 `anyOf: [object, string]` と書かれていて素の文字列でも通りそうに見えるが、実際に文字列を渡すと `should be an object` で検証エラーになる。`replace_content: {"new_str": "..."}`、`update_content: {"content_updates": [{"old_str": "...", "new_str": "..."}]}` のようにオブジェクト形式で渡す
- `API-patch-block-children` の `block_id` にはページIDを直接渡せる（ブロックIDを事前に調べる必要はない）。`after` を省略すると本文の末尾に追加される
- `children` は文字列やmarkdownではなく、Notionのブロックオブジェクトの配列で渡す。段落を1つ追加する場合の最小形は次の通り。

```json
{
  "block_id": "<ページIDまたはブロックID>",
  "children": [
    {
      "object": "block",
      "type": "paragraph",
      "paragraph": { "rich_text": [{ "type": "text", "text": { "content": "<追記するテキスト>" } }] }
    }
  ]
}
```

- 箇条書きとして追記する場合は、項目ごとに `bulleted_list_item` タイプのブロックを `children` 配列へ並べる（1つの `paragraph` に箇条書き記号を含めても箇条書きブロックにはならない）。

```json
{
  "type": "bulleted_list_item",
  "bulleted_list_item": { "rich_text": [{ "type": "text", "text": { "content": "<項目のテキスト>" } }] }
}
```

- 既存ブロックの内容を修正する場合、`API-update-a-block` は `type` パラメータをオブジェクト・JSON文字列いずれの形式で渡しても `body.paragraph should be defined` 等のvalidation_errorになり使用できない。代わりに `API-delete-a-block` で対象ブロックを削除し、`API-patch-block-children` で修正後の内容を再追加する

## ページ作成時の注意

- ページ作成は `API-post-page`。`parent` と `properties` が必須
- データソース配下にページを作る際の `parent` の形式は決め打ちしない。OpenAPIスキーマ上はデータソース向けの定義（`dataSourceIdParentRequest`）であってもキー名が `database_id` になっており、Notion-Versionによって参照キーが変わる。対象データソース内の既存ページを1件 `API-retrieve-a-page` で取得し、返ってきた `parent` と同じ形式で渡す。既存ページが1件も無い場合は `API-retrieve-a-data-source` のレスポンスから組み立て、`API-post-page` が `parent` の検証エラーを返した場合は推測で再試行せず失敗を報告する
- 同じ親ページ配下の兄弟ページを列挙する場合、親子関係を表すrelation型プロパティの値（`API-retrieve-a-page` で取得できる）か、`API-query-data-source` を親ページへのrelationでフィルタして特定する。データソースのプロパティスキーマにrelationが無い場合は、親ページ自体のサブアイテム/子ページ一覧（`API-retrieve-a-page` や `API-retrieve-a-block`）から辿る
- `properties` のキーは対象データソースに実在するプロパティ名（またはID）のみ使える。select/multi-selectの値もスキーマ上の選択肢に限られるため、事前に `API-retrieve-a-data-source` でプロパティ名・型・選択肢を取得してから組み立てる。推測した名前や値を渡すと検証エラーになる
- 本文は `API-post-page` の `children` に載せず、ページ作成後に `API-patch-block-children` で追記する。`children` はOpenAPIスキーマ上 `items: {type: string}` と定義されているが実際に必要なのはブロックオブジェクトであり、`API-patch-block-children` 側と同じ型の食い違いを含んでいる
- テンプレートは `API-list-data-source-templates` で取得できる。データソースにテンプレートが定義されている場合は本文の項目構成をそこに合わせる
