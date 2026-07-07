# note.com エディタ操作ナレッジ

note（note.com）のエディタで記事作成・編集を Chrome MCP で行う場合の固有ナレッジ。

## エディタの基本仕様

- note のエディタは **ProseMirror** ベース
- `table` ノードはスキーマに存在しない → HTML テーブルの挿入は不可（貼り付けても無視される）
- テーブルが必要な場合はプレーンテキストで代替するか、ローカルの Markdown ファイルにのみ記録する

## ログイン

- X（Twitter）OAuth はポップアップ制限で失敗することがある（`references/oauth.md` 参照）
- 個人アカウントでログイン中の場合は X OAuth をキャンセルし、note ID/パスワードでのログインに切り替え、パスワードはユーザーが手入力する
- note ID は `input[type="text"]` に `javascript_tool` で直接セット可能:
  ```js
  const input = document.querySelector('input[type="text"]');
  input.value = 'xxx';
  input.dispatchEvent(new Event('input', { bubbles: true }));
  ```

## 改行・段落

### Enter の挙動

- note エディタ内で Enter キーを押すと、コンテキストによって **hardbreak（`<br>`）** が挿入される場合がある
- 真の段落分割（`</p><p>`）を作るには `document.execCommand('insertParagraph')` を使う:
  ```js
  document.execCommand('insertParagraph');
  ```

### BR を段落分割に変換

```js
const para = /* 対象の <p> 要素 */;
const brs = para.querySelectorAll('br');
brs.forEach(br => {
  const range = document.createRange();
  range.setStartBefore(br);
  range.setEndAfter(br);
  const sel = window.getSelection();
  sel.removeAllRanges();
  sel.addRange(range);
  document.execCommand('insertParagraph');
});
```

## 区切り線（Divider / HR）

- `---` と入力して Enter キーを押すと ProseMirror の inputRule が発火し、HR 要素（区切り線）に変換される
- Chrome MCP での操作:
  ```
  type: "---"
  key: "Enter"
  ```
- 区切り線の前後に余分な空行が入る場合は `forwardDelete` execCommand で削除する:
  ```js
  document.execCommand('forwardDelete');
  ```

## 箇条書き（Bullet List）

### 入力方法

- 行頭で `- `（ハイフン + スペース）を入力すると bulletList に変換される（inputRule）
- 変換後、複数アイテムを一括入力するには `\n` 区切りで一度に `type` アクションを呼ぶ:
  ```
  type: "アイテム1\nアイテム2\nアイテム3"
  ```
  各 `\n` が新しいリストアイテムになる

### 手順

1. 対象の段落にカーソルを移動
2. `type: "- "` で箇条書きモードに入る
3. `type: "アイテム1\nアイテム2\n..."` で一括入力

### 注意

- note の UL 要素（箇条書き）と見た目は似ている `・` 記号をそのまま使わないこと。`- ` inputRule で本来の箇条書きを使う

## リンクの挿入

1. リンクテキストを選択（`find` または `ref` 指定でクリックして選択）
2. `Cmd+K` でリンク入力ダイアログを開く
3. URL を入力して Enter

## 絵文字の入力

- `type` アクションは絵文字（🎉 など）を入力できない場合がある
- 絵文字入力が必要な場合:
  ```js
  document.execCommand('insertText', false, '🎉');
  ```

## 下書き保存

- エディタ内で操作後、自動保存が走ることが多い
- 明示的に保存する場合は `Cmd+S` または保存ボタンをクリック

## よくあるミス

- **テーブルを貼り付けても何も起きない**: ProseMirror に table ノードがないため。ローカルファイルに Markdown テーブルで記録する
- **Enter が段落分割でなく BR になる**: `execCommand('insertParagraph')` を使う
- **`---` が区切り線にならない**: Enter キーを押す前に別のキーを押してしまっている。`type: "---"` の直後に `key: "Enter"` を実行する
- **箇条書きの `・` 記号をそのまま使わない**: note の UL 要素（箇条書き）と見た目は似ているが別物
