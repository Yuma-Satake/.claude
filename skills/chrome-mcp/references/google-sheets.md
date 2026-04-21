# Google Sheets 操作ナレッジ

Google スプレッドシートで Chrome MCP からセル操作・値取得を行う場合の固有ナレッジ。

## セル移動

- セル移動には `ArrowRight` / `ArrowLeft` / `ArrowUp` / `ArrowDown` キーを使う
- **Name Box（セル参照欄）を使ったセル移動は行わないこと**
  - アクセシビリティツリー上で **Rename（ファイル名変更）テキストボックス** と区別がつかない
  - セル移動のつもりで入力すると、スプレッドシートのタイトルを誤って上書きする事故になる

## 長文セルの読み取り

画面上で切れて見えるセルの全文を取得するには:

1. 対象セルをクリックして選択する
2. スクリーンショットを撮り、画面下部の **数式バー** から全文を読み取る
3. セル内容をそのまま `read_page` で取得しようとしても見切れる

## 絵文字の入力（✅ など）

`type` アクションでは絵文字が Google Sheets に入力できない。以下の手順で入力する:

1. 対象セルを **ダブルクリック** して編集モードに入る
2. `javascript_tool` で `execCommand` を使って入力:
   ```js
   document.execCommand('selectAll', false, null);
   document.execCommand('insertText', false, '✅');
   document.activeElement.textContent  // ✅ が返れば成功
   ```
3. `key` アクションで `Return` を押して確定する
4. 対象セルをクリックし直し、数式バーに ✅ が表示されていることを確認する

## 一般的な注意点

- Google Sheets は SPA で、要素の `ref_id` が再描画ごとに変わる場合がある。都度 `read_page(filter="interactive")` で取り直す
- 同一 URL への `navigate` 再実行は避ける（ログインセッションが切れる・編集が巻き戻る可能性）
- 複数シートがあるファイルでは、シート切り替え後に次の操作まで `wait` を挟む

## よくあるミス

- **Name Box 経由でセル移動してファイル名を上書きする**: 必ず Arrow キーで移動する
- **絵文字が入力できない**: `type` ではなく `execCommand('insertText', ...)` を使う
- **長文セルが切れて見える**: 数式バーから読むか、セル展開（Alt+Enter 等）で表示する
