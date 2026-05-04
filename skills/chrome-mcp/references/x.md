# X（Twitter）操作ナレッジ

## フォロー操作

### フォローボタンのクリック

プロフィールページのフォローボタンは `data-testid="<userId>-follow"` の形式。
`aria-label="Follow @<handle>"` での検索はページ内のおすすめユーザー欄もヒットするため、誤操作の原因になる。

**確実な方法**: `[data-testid$="-follow"]` でページ内最初の `-follow` 要素をクリックする。

```javascript
const btn = document.querySelector('[data-testid$="-follow"]');
btn ? (btn.click(), 'clicked: ' + btn.getAttribute('data-testid')) : 'not found';
```

### フォロー完了の確認

フォロー後はボタンの `data-testid` が `-follow` から `-unfollow` に変わる。

```javascript
const userId = '1234567890'; // クリック時に取得したID
const btn = document.querySelector(`[data-testid="${userId}-unfollow"]`);
btn ? 'Following confirmed' : 'not yet';
```

### アンフォロー

アンフォローボタンをクリックすると確認ダイアログが出る。`Unfollow` テキストのボタンで確定する。

```javascript
// ① Following ボタンをクリック（ダイアログを開く）
const followingBtn = document.querySelector('[data-testid$="-unfollow"]');
followingBtn && followingBtn.click();

// ② 確認ダイアログの Unfollow ボタンをクリック
const confirmBtn = Array.from(document.querySelectorAll('[role="button"]'))
  .find(b => b.innerText.trim() === 'Unfollow');
confirmBtn && confirmBtn.click();
```

## ログインアカウントの確認

```javascript
const btn = document.querySelector('[data-testid="SideNav_AccountSwitcher_Button"]');
btn ? btn.innerText : 'not found';
// → "Yuma Satake＠フロカン名古屋\n@yuma_satake22" のように返る
```

## 前提条件

- XにChromeでログイン済みであること
- X操作の検索・調査（アカウント発掘など）にはGrokスキルを使うこと（`~/.claude/skills/chrome-mcp/references/x.md` はUI操作専用）
