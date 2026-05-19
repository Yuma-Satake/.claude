---
name: x-search
description: X（Twitter）の投稿をGrok経由でリアルタイム検索するスキル。hermes-agentのx_search_toolを直接呼び出してrawなデータを取得する。「x_searchで調べて」「Xで検索して」「x-searchで〜」「X上の反応を調べて」「ポストを検索して」のように言われた場合、またはXのリアルタイム情報・トレンド・口コミ調査が必要な場合に必ず使用すること。grokスキルよりもrawなデータが得られるため、他のエージェントとの連携にも適している。
---

# x-search

引数: $ARGUMENTS

## 概要

`uvx --from hermes-agent python` でスキル内の `scripts/x_search.py` を呼び出し、hermes-agent の `x_search_tool` を直接実行してGrokによるXのリアルタイム検索を行う。

通常の「Hermesにx_searchを使ってプロンプトする」方式と違い、モデルの解釈レイヤーを省いてrawな結果を直接取得できる。

## 実行手順

### 1. クエリの決定

引数（`$ARGUMENTS`）がある場合はそれをクエリとして使用する。なければ会話の文脈からクエリを英語または日本語で組み立てる。

### 2. x_search の実行

```bash
uvx --from hermes-agent python ~/.claude/skills/x-search/scripts/x_search.py "クエリ文字列"
```

- 実行は**バックグラウンドで行わず**、結果が返るまで待つ
- 30秒以上かかる場合があるため、ユーザーに待機を伝える
- エラーが出た場合は下記「トラブルシューティング」を参照

### 3. 結果の表示

出力された Markdown をそのままユーザーに提示する。必要に応じて要約や補足を加える。

## トラブルシューティング

### OAuth 認証エラーの場合

```bash
uvx --from hermes-agent hermes auth add xai-oauth
```

を実行し、表示された URL をブラウザで開いて認証する。

### `x_search_tool` が見つからないエラーの場合

hermes-agent のバージョンが古い可能性がある。以下でキャッシュをクリアして再実行：

```bash
uvx --from hermes-agent --refresh python ~/.claude/skills/x-search/scripts/x_search.py "クエリ"
```
