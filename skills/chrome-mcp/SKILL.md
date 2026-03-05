---
name: chrome-mcp
description: ブラウザ自動化のベストプラクティスを提供します。Claude in Chrome（mcp__claude-in-chrome__*）ツールでWebページを操作する場合、フォーム入力、要素の検索、値の取得、スクリーンショット撮影を行う場合に使用します。
user-invocable: false
---

# Browser Automation (Claude in Chrome)

## フォーム操作

- テキスト入力の上書きには `triple_click` で全選択してから `type` で入力すること
- ボタンクリックが反応しない場合は `find` でボタン要素を特定し、`ref` 指定でクリックすること

## 値の取得

- 画面上で切れている値は `read_page` で `ref_id` を指定し、DOM内の要素から全文を取得できる
- クリップボードAPIはセキュリティ制約で使えない場合がある。`read_page` による DOM 直接参照を優先すること
- コピーボタンのクリック + `navigator.clipboard.readText()` は信頼性が低い

## テキスト入力の注意点

- `type` アクションは絵文字（✅など）を入力できない場合がある。絵文字入力が必要な場合は、セルをダブルクリックして編集モードに入った上で `javascript_tool` の `document.execCommand('insertText', false, '絵文字')` を使用すること

## JavaScript による DOM 操作

- `javascript_tool` で要素を検索して `.click()` を実行する場合、DOM ツリーの親要素をたどる回数（`parentElement` の繰り返し）が正しいか慎重に確認すること。ページのDOM構造が想定と異なると、意図しない要素がクリックされるリスクがある
- `.click()` を実行する前に、対象要素のテキストやクラス名をログ出力して正しい要素であることを確認すること（例: `JSON.stringify({ text: deployBtn.textContent, class: deployBtn.className })`）
- `scrollIntoView()` はページのスクロールコンテナが `window` 以外（例: 固定レイアウトの内部コンテナ）の場合に機能しないことがある。スクリーンショットで要素が画面に表示されていることを確認してからクリックすること

## スクリーンショット座標とビューポート座標の変換

- ビューポートサイズとスクリーンショットサイズは異なる場合がある（例: viewport 2042x1124, screenshot 1476x812）
- `javascript_tool` で取得した `getBoundingClientRect()` の座標はビューポート座標なので、`computer` ツールでクリックする場合はスクリーンショット座標に変換が必要: `ss_x = vp_x * ss_width / vp_width`
- 変換後の座標が画面外（スクリーンショットの幅/高さを超える）の場合、要素がビューポート外にあるため、先にスクロールが必要

## 一般的なブラウザ操作

- 操作開始時は必ず `tabs_context_mcp` でタブ情報を取得すること
- 新しいセッションでは既存タブのIDを再利用しないこと
- ページの読み込みが完了したかは、タブのタイトル変化で判断できる
- 小さいUI要素は `zoom` で拡大して確認してから操作すること
- `find` は自然言語でのUI要素検索が可能で、座標指定より信頼性が高い
- ページ遷移が遅いサイトでは、操作後に `wait` で数秒待機してから `screenshot` を撮ること
