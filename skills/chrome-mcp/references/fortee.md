# fortee 操作ナレッジ

fortee（https://fortee.jp）の organizer 画面を Chrome MCP で操作する場合の固有ナレッジ。

## 確認ダイアログ（`confirm()`）の罠

fortee の削除ボタンや一部のアクションは JavaScript の `confirm()` ダイアログを使っている。

- ダイアログが開くと後続の MCP コマンドが **Detached while handling command** で止まる
- `requestSubmit()` で送信してもブロックされる

### 回避策: fetch で直接 POST

各フォームのデータを収集し、`fetch` で POST する:

```javascript
// ページネーションを含む一括処理の例
(async () => {
  const pageLinks = document.querySelectorAll('.pagination .page-link');
  const pages = Array.from(pageLinks).map(l => l.textContent.trim()).filter(t => !isNaN(t));

  // 他ページのフォームデータを fetch で取得
  for (const page of pages.slice(1)) {
    const res = await fetch(`/path?page=${page}`, { credentials: 'include' });
    const html = await res.text();
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const forms = doc.querySelectorAll('form[name^="post_"]');
    for (const form of forms) {
      const body = new URLSearchParams();
      form.querySelectorAll('input').forEach(i => body.append(i.name, i.value));
      await fetch(form.action, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString(),
        credentials: 'include'
      });
    }
  }
})()
```

## デプロイボタンのクリック

fortee のデプロイページでは、各コンタクト行に以下のボタンが並ぶ:

- アイコンボタン群（左から）: シェブロン(dropdown), 詳細(info), 編集(edit), **削除(trash/赤)**
- デプロイボタン: アイコン群の **下** に配置された青い `<span>` 要素

### 重要: find / read_page でデプロイボタンを探さない

デプロイボタンは `<span class="action-mail btn btn-sm btn-light-primary">` で実装されており、`<a>` や `<button>` ではないため **アクセシビリティツリーに出ない**。

- `find` が返す結果は **削除ボタン（`fa-trash`）を指している可能性が高い**
- 誤クリックすると削除確認ダイアログが表示され、ブラウザ操作がブロックされる
- **削除ボタンは絶対にクリックしない**

### 正しい手順

`javascript_tool` で対象コンタクトのデプロイボタンを検証してからクリックする:

```javascript
const target = [...document.querySelectorAll('a')]
  .find(a => a.textContent.trim() === '学生支援-{氏名}');
let container = target;
for (let i = 0; i < 5; i++) container = container.parentElement;
const deployBtn = container.querySelector('.action-mail.btn-light-primary');
const firstLink = container.querySelector('a');

// 正しいコンタクトのコンテナであることを検証
if (!firstLink || firstLink.textContent.trim() !== '学生支援-{氏名}') {
  JSON.stringify({ error: 'wrong container', firstLink: firstLink?.textContent.trim() });
} else {
  deployBtn.click();
  'deployed: 学生支援-{氏名}';
}
```

- **parentElement の回数（例では5回）が正しいか必ず検証する**
- DOM 構造が変わっている場合は、1〜12 回の範囲で正しいレベルを探索する
- 検証に失敗した場合（`firstLink` が対象コンタクト名と一致しない場合）は、クリックせずにエラーを返す

## メール送信一覧の確認

デプロイ成功後は、送信メール一覧ページで宛先が正しく作成されているかを確認する。メール作成されていない場合はユーザーに報告して判断を仰ぐ。

## タイムアウト対策（シリアル fetch）

大量のデータを扱う場合は **並列ではなくシリアル（for ループ）で fetch する**。並列実行は 45 秒でタイムアウトする。

```javascript
// 60件ずつなど、適切に分割してシリアル処理する
for (const url of urls.slice(0, 60)) {
  const res = await fetch(url, { credentials: 'include' });
  // ...
}
```

## テンプレート操作

- テンプレート編集ページ: `/{event-slug}/organizer/email-templates/edit/{id}`
- テンプレート一覧からIDを取得:
  ```javascript
  Array.from(document.querySelectorAll('a[href*="email-templates/view"]'))
    .map(a => ({ text: a.textContent.trim(), href: a.href }))
    .filter(a => a.text)
  ```
- フォーム入力後のサブミット: `document.querySelector('button[type="submit"]').click()`

## フォーム入力のコツ

- combobox（タイプ選択など）は `form_input` が効かない場合がある → `ref` 指定で `left_click` + `type` + `key("Enter")`
- テキスト・textarea は `form_input` が効く
- 一括入力できるフィールドは同じ `form_input` 呼び出しでまとめる

## よくあるミス

- **削除ボタン（ゴミ箱アイコン）を誤クリックする**: find / read_page が `<span>` のデプロイボタンを見つけられないため、代わりに削除ボタンを返すことがある。必ず `javascript_tool` + 検証を使う
- **確認ダイアログでブラウザ操作が止まる**: `fetch` による POST で回避する
- **並列 fetch で 45 秒タイムアウト**: シリアル処理する
