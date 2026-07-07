# Grok（x.com/i/grok）操作ナレッジ

## 送信

`form_input` でテキストボックスに入力後、**EnterキーのKeyboardEventは効かない**。

送信には `[aria-label="Grok something"]` ボタンをJavaScriptでクリックする:

```javascript
const btn = document.querySelector('[aria-label="Grok something"]');
btn ? (btn.click(), 'clicked') : 'not found';
```

- このボタンはテキスト入力後に現れる（入力前は存在しない）
- `querySelectorAll('button')` のテキスト検索では見つからない（aria-label属性で検索すること）
- 送信成功するとURLが `https://x.com/i/grok?conversation=<ID>` に変わる

## 回答完了の検知

`get_page_text` でポーリングしてフェーズを判断する:

| テキストの内容 | 状態 |
|---|---|
| `Thinking about your request ...` | 思考・X検索中（待機が必要） |
| `Thought for Xm Xs` | 思考完了、本文生成中 |
| 末尾に `Expert` や `X posts` が出現 | 回答完了 |

- Expertモードは複数回X検索を実施するため、完了まで1〜2分かかる
- `get_page_text` の返却テキストにはUIボタン名（"History" "Private" "Expert" など）が混在する。Grokの実際の回答部分だけを抽出してユーザーに提示すること

## エラー対処: "Grok was unable to reply"

Expert modeでタイムアウトするとエラー画面になる。Retryボタンをjsクリックで再試行する:

```javascript
const buttons = Array.from(document.querySelectorAll('button'));
const retryBtn = buttons.find(b => b.textContent.trim() === 'Retry');
retryBtn ? (retryBtn.click(), 'clicked Retry') : 'Retry not found';
```

- `document.querySelector('button')` ではボタンを特定できないため `Array.from + find` でテキスト検索する
- Retry後は再度ポーリングしてフェーズを確認する

## 前提条件

- XにChromeでログイン済みであること
- X Premiumに加入していること
