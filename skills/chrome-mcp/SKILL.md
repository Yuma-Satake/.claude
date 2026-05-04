---
name: chrome-mcp
description: Claude in Chrome（mcp__claude-in-chrome__* ツール）でブラウザ操作を行う際のベストプラクティスとサイト固有ナレッジを提供する。Webページのフォーム入力・要素検索・値取得・スクリーンショット撮影・OAuthログイン・SPAの操作・ブラウザ自動化を行う場合には必ず使用すること。note.com・Google Sheets・Google Docs・fortee・Amazon・GitHub・Slack・Google Cloud Console など特定サイトを操作するときは、固有の落とし穴回避ナレッジが含まれるため、ブラウザ操作を開始する前に必ず参照すること。ユーザーが「ブラウザで〜して」「〜を開いて操作して」「Webページから値を取って」と言った場合にも発動する。
user-invocable: false
---

# Browser Automation (Claude in Chrome)

このスキルは Claude in Chrome（`mcp__claude-in-chrome__*`）を使う際の汎用ベストプラクティスと、特定サイト固有のナレッジへのインデックスを提供する。

## サイト固有ナレッジの読み込み

操作対象のサイトに対応するファイルが `references/` 配下にある場合、**ブラウザ操作を始める前に必ず読むこと**。サイト固有の落とし穴やハマりどころが事前に回避できる。

| サイト / 領域 | ファイル | 読むべき場面 |
|---|---|---|
| note.com | `references/note.md` | note のエディタで記事作成・編集を行うとき |
| Google Sheets / スプレッドシート | `references/google-sheets.md` | Sheets でセル入力・値の取得を行うとき |
| Google Docs / ドキュメント | `references/google-docs.md` | Docs で見出しスタイル適用・コンテンツ貼り付けを行うとき |
| fortee | `references/fortee.md` | fortee の organizer 画面を操作するとき |
| Grok（x.com/i/grok） | `references/grok.md` | Grok でチャット送信・回答取得を行うとき |
| OAuth 認証（Google/X/Apple 等） | `references/oauth.md` | OAuth ボタン経由のログインが必要なとき |
| ブラウザ操作パターン（汎用） | `references/browser-patterns.md` | フォーム入力・値取得・DOM 操作・ダイアログ回避など具体的テクニックが必要なとき |

新しいサイトのナレッジが溜まったら、`references/{site-name}.md` を追加して上表に追記すること。

## 基本方針

### 使うべきツール

- **ブラウザ操作には Claude in Chrome（`mcp__claude-in-chrome__*`）を使う**
- **agent-browser / Playwright など独立ブラウザは使わない**: ユーザーが実際に使っている Chrome のログイン状態を共有できないため、Google・社内ツールなどで再認証が必要になり事故る
- 単に Web ページのテキストを取得するだけなら `WebFetch` や `WebSearch` の方が軽い

### セッション開始時

- 最初に `tabs_context_mcp` でタブ情報を取得する
- 既存タブの ID を前セッションから流用しない（無効なので再取得する）
- ユーザーが作業中のタブを奪わないよう、新しい作業は `tabs_create_mcp` で新規タブを開く

## フォーム操作

### 基本方針

- `read_page(filter="interactive")` でフォーム構造と `ref_id` を最初に把握する
- `form_input` で入力できるフィールドは一括で同時にセットする
- 座標クリックは使わず、すべて `ref` 指定で操作する
- スクリーンショットは最小限（入力確認時と完了確認時のみ）にする
- `form_input` が効かないフィールドや具体的な操作テクニックは `references/browser-patterns.md` を参照

## 一般的なブラウザ操作

- `find` は自然言語での UI 要素検索が可能で、座標指定より信頼性が高い
- **同一 URL への `navigate` 再実行はリロードを引き起こす**。ログインセッションが切れるサイトでは、サイト内のリンク・ボタン経由で遷移する
- 座標変換・ダイアログ回避・DOM 操作などの具体テクニックは `references/browser-patterns.md` を参照

## 操作終了時のナレッジ反映

ブラウザ操作を伴うタスクが一段落したら（最終報告を返す直前に）、**このスキルに反映すべき新しい知見がないかを必ず自己レビューすること**。これを怠ると、同じ落とし穴に次回もハマる。

チェック項目:

- **サイト固有のハマりどころ**: ボタンが `<span>` でアクセシビリティツリーに出ない、特定のキーが無視される、確認ダイアログで止まる等
- **有効だった回避策**: 特定のセレクタ、`execCommand` の使い方、URL パラメータ、`fetch` による POST 回避など
- **UI の前提条件**: ログイン状態、権限、設定により挙動が変わる場合
- **入力・出力のコツ**: form_input が効くフィールド／効かないフィールド、値取得の信頼できる経路

反映手順:

1. 既存の `SKILL.md` 本体と `references/` 配下に同等の記述があるか確認する
2. ない場合は、ユーザーに **「今回の操作で得た『〜』というナレッジをスキルに反映しますか？」と具体的に提案する**
3. ユーザーが承認した場合のみ、対応する `references/{site}.md` または `SKILL.md` に追記する
4. 新しいサイトのナレッジが一定量溜まったら `references/{site}.md` を新規作成し、`SKILL.md` のインデックス表にも追加する
