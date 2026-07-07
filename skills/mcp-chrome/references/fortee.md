# fortee 操作ナレッジ

fortee（https://fortee.jp）の organizer 画面を Chrome MCP で操作する場合の固有ナレッジ。

イベント固有の情報（イベントスラッグ・テンプレート件名ルール・署名など）は各プロジェクトの `knowledge/` に置き、本ファイルには fortee 全般のブラウザ操作ノウハウのみを載せる。

## URL 構造

- テンプレート一覧: `/{event-slug}/organizer/email-templates`
- テンプレート新規作成: `/{event-slug}/organizer/email-templates/add`
- テンプレート編集: `/{event-slug}/organizer/email-templates/edit/{id}`
- テンプレートデプロイ: `/{event-slug}/organizer/email-templates/deploy/{id}`
- コンタクト詳細: `/{event-slug}/organizer/contacts/view/{id}`
- 参加者一覧（未発券含む）: `/{event-slug}/organizer/attendees/index?u=1`
- 参加者詳細: `/{event-slug}/organizer/attendees/view/{id}`
- ツイート候補一覧: `/{event-slug}/organizer/tweets`
- 送信メール一覧: `/{event-slug}/organizer/emails/index`

## テンプレート操作

### 新規作成

1. `/{event-slug}/organizer/email-templates/add` に移動
2. 以下フィールドを `mcp__claude-in-chrome__form_input` で入力:
   - タイプ (combobox)
   - テンプレート名 (textbox)
   - From (textbox)
   - 件名 (textbox)
   - 本文 (textarea)
3. `javascript_tool` で `document.querySelector('button[type="submit"]').click()` を実行
4. 成功すると view ページにリダイレクトされ「メールテンプレートを保存しました」と表示される

### 編集

1. `/{event-slug}/organizer/email-templates/edit/{id}` に移動
2. 該当フィールドを `form_input` で更新
3. 新規作成と同様の方法でサブミット

### テンプレートIDの取得

テンプレート一覧ページでリンク一覧を取得:

```javascript
Array.from(document.querySelectorAll('a[href*="email-templates/view"]'))
  .map(a => ({ text: a.textContent.trim(), href: a.href }))
  .filter(a => a.text)
```

## デプロイ操作

### 個別コンタクトへのデプロイボタン

デプロイページでは各コンタクト行に以下のボタンが並ぶ:

- アイコンボタン群（左から）: シェブロン(dropdown), 詳細(info), 編集(edit), **削除(trash/赤)**
- デプロイボタン: アイコン群の **下** に配置された青い `<span>` 要素

#### 重要: find / read_page でデプロイボタンを探さない

デプロイボタンは `<span class="action-mail btn btn-sm btn-light-primary">` で実装されており、`<a>` や `<button>` ではないため **アクセシビリティツリーに出ない**。

- `find` が返す結果は **削除ボタン（`fa-trash`）を指している可能性が高い**
- 誤クリックすると削除確認ダイアログが表示され、ブラウザ操作がブロックされる
- **削除ボタンは絶対にクリックしない**

#### 正しい手順

`javascript_tool` で対象コンタクトのデプロイボタンを検証してからクリックする:

```javascript
const target = [...document.querySelectorAll('a')]
  .find(a => a.textContent.trim() === '{対象コンタクト名}');
let container = target;
for (let i = 0; i < 5; i++) container = container.parentElement;
const deployBtn = container.querySelector('.action-mail.btn-light-primary');
const firstLink = container.querySelector('a');

// 正しいコンタクトのコンテナであることを検証
if (!firstLink || firstLink.textContent.trim() !== '{対象コンタクト名}') {
  JSON.stringify({ error: 'wrong container', firstLink: firstLink?.textContent.trim() });
} else {
  deployBtn.click();
  'deployed: {対象コンタクト名}';
}
```

- **parentElement の回数（例では5回）が正しいか必ず検証する**
- DOM 構造が変わっている場合は、1〜12 回の範囲で正しいレベルを探索する
- 検証に失敗した場合（`firstLink` が対象コンタクト名と一致しない場合）は、クリックせずにエラーを返す

### 「全てデプロイ」ボタン

テンプレートデプロイページにある一括デプロイ用のボタン。

1. `/{event-slug}/organizer/email-templates/deploy/{id}` に移動
2. 「全てデプロイ」ボタンを `mcp__claude-in-chrome__computer` の `left_click` でクリック
3. **ブラウザのネイティブ確認ダイアログが出る** → computer use では直接クリックできないため、ユーザーに手動で OK をクリックしてもらうよう案内する
   - Chrome は tier "read" のため `mcp__computer-use__request_access` でアクセス許可を取得しても直接操作できない

### デプロイ後のメール送信一覧確認

デプロイ成功後は送信メール一覧ページ（`/{event-slug}/organizer/emails/index`）で宛先が正しく作成されているかを確認する。メールが作成されていない場合はユーザーに報告して判断を仰ぐ。

### デプロイとメール送信の違い

- **デプロイはメールを送信しない**（送信対象としてセットするだけ）
- 実送信はバルクメール機能から別途行う

## 確認ダイアログ（`confirm()`）の罠

fortee の削除ボタンや一部のアクションは JavaScript の `confirm()` ダイアログを使っている。

- ダイアログが開くと後続の MCP コマンドが **Detached while handling command** で止まる
- `requestSubmit()` で送信してもブロックされる

### 回避策: fetch で直接 POST

各フォームのデータを収集し、`fetch` で POST する。

例: ツイート候補一覧の一括削除（ページネーション + 現在ページの両方を処理）

```javascript
(async () => {
  // ページ数を確認
  const pageLinks = document.querySelectorAll('.pagination .page-link');
  const pages = Array.from(pageLinks).map(l => l.textContent.trim()).filter(t => !isNaN(t));

  // 他ページのフォームデータを fetch で取得して POST
  for (const page of pages.slice(1)) {
    const res = await fetch(`/{event-slug}/organizer/tweets?page=${page}`, { credentials: 'include' });
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

  // 現在ページのフォームを削除
  const deleteBtns = document.querySelectorAll('a.btn-light-danger[data-confirm-message]');
  for (const btn of deleteBtns) {
    const match = btn.getAttribute('onclick').match(/document\.(\w+)\.requestSubmit/);
    if (!match) continue;
    const form = document[match[1]];
    const body = new URLSearchParams();
    form.querySelectorAll('input').forEach(i => body.append(i.name, i.value));
    await fetch(form.action, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
      credentials: 'include'
    });
  }
})()
```

削除後はページをリロードして件数が 0 件になっていることを確認する。

## タイムアウト対策（シリアル fetch）

大量のデータを扱う場合は **並列ではなくシリアル（for ループ）で fetch する**。並列実行は 45 秒でタイムアウトする。

```javascript
// 60件ずつなど、適切に分割してシリアル処理する
for (const url of urls.slice(0, 60)) {
  const res = await fetch(url, { credentials: 'include' });
  // ...
}
```

## 参加者のチケット購入状況確認

コンタクトのメールアドレスと参加者リストを照合して、チケット購入済みかどうかを確認する手順。

### 前提

- 参加者リストは fortee ハンドル名で表示されるため、実名での検索は効かない
- 参加者詳細ページにはメールアドレスが含まれるので、コンタクトのメールアドレスと照合することで購入状況を特定できる

### 手順

1. コンタクトページからメールアドレスを取得する

```javascript
// シリアルfetchでコンタクトのメールアドレスを取得
const contacts = [{ name: '...', id: 'UUID' }, ...];
const results = [];
for (const c of contacts) {
  const res = await fetch(`/{event-slug}/organizer/contacts/view/${c.id}`, { credentials: 'include' });
  const html = await res.text();
  const match = html.match(/メールアドレス[\s\S]*?([\w.\-+]+@[\w.\-]+\.[a-z]{2,})/);
  results.push({ name: c.name, email: match ? match[1] : null });
}
window._contactEmails = results;
```

2. 参加者リストページで全 URL を取得する（`?u=1` で未発券者も含める）

```javascript
// /{event-slug}/organizer/attendees/index?u=1 にアクセスした状態で実行
const urls = [...new Set(
  Array.from(document.querySelectorAll('a[href*="/organizer/attendees/view/"]')).map(a => a.href)
)];
window._attendeeUrls = urls;
```

3. 参加者詳細ページをシリアル fetch してメールアドレスと照合する（タイムアウト防止のため 60 件ずつ処理）

```javascript
// 1〜60件目
(async () => {
  const targetEmails = new Set(window._contactEmails.map(s => s.email?.toLowerCase()).filter(Boolean));
  const urls = window._attendeeUrls.slice(0, 60);
  const matched = [];
  for (const url of urls) {
    const res = await fetch(url, { credentials: 'include' });
    const html = await res.text();
    const emails = (html.match(/[\w.\-+]+@[\w.\-]+\.[a-z]{2,}/g) || []).map(e => e.toLowerCase());
    const hit = emails.find(e => targetEmails.has(e));
    if (hit) matched.push({ url, email: hit });
  }
  window._matched1 = matched;
  return JSON.stringify(matched);
})()
// → 同様に slice(60, 120)、slice(120) と繰り返す
```

4. 結果を集計する

```javascript
const allMatched = [...(window._matched1 || []), ...(window._matched2 || []), ...(window._matched3 || [])];
const purchasedEmails = new Set(allMatched.map(m => m.email));

window._contactEmails.map(s => ({
  name: s.name,
  email: s.email,
  purchased: s.email ? purchasedEmails.has(s.email.toLowerCase()) : false
}))
```

### 注意事項（照合）

- 参加者 URL の総数 ÷ 3 ≒ 実参加者数（各参加者に 3 つのリンクが存在するため）
- 並列 fetch は 45 秒でタイムアウトするため、必ずシリアル（for ループ）で処理する
- 同じメールアドレスが複数コンタクトに登録されている場合は手動確認が必要

## フォーム入力のコツ

- combobox（タイプ選択など）は `form_input` が効かない場合がある → `ref` 指定で `left_click` + `type` + `key("Enter")`
- テキスト・textarea は `form_input` が効く
- 一括入力できるフィールドは同じ `form_input` 呼び出しでまとめる
- フォームサブミットは `form_input` でフィールドを埋めた後、`javascript_tool` で `document.querySelector('button[type="submit"]').click()` を実行

## よくあるミス

- **削除ボタン（ゴミ箱アイコン）を誤クリックする**: find / read_page が `<span>` のデプロイボタンを見つけられないため、代わりに削除ボタンを返すことがある。必ず `javascript_tool` + 検証を使う
- **確認ダイアログでブラウザ操作が止まる**: `fetch` による POST で回避する
- **並列 fetch で 45 秒タイムアウト**: シリアル処理する
- **「全てデプロイ」のネイティブ確認ダイアログを自動で通そうとする**: computer use では通せないので、ユーザーに手動対応を依頼する
