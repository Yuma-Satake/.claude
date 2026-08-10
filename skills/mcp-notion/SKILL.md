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
- 本文への追記には `API-patch-block-children`（ブロック子要素の末尾追加）を使う。`API-update-page-markdown` は使わない。`type: replace_content` はページ全体を置換してしまい、`type: insert_content` はdeprecated扱いのため、追記の手段として安全ではない
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
