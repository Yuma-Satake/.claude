---
name: email
description: メールの文章を作成する。ユーザーが「メールを書いて」「メール文を作って」「メールの下書きを作成して」と依頼した場合に使用する。引数として宛先・目的・内容の概要を受け取る。
argument-hint: "<宛先> <目的・内容の概要>"
model: sonnet
---

# email

引数: $ARGUMENTS

## ユーザー情報

- 名前: 佐竹友真
- メール（個人）: satous.y@icloud.com
- メール（仕事）: satake.satake.y@gmail.com
- メール（TSKaigi運営）: yuma.satake@tskaigi.org

## 送信アカウントの選択

引数または会話の文脈から、どのアカウントで送るかを判断する:

- 個人的な連絡 → satous.y@icloud.com
- 仕事・業務委託関連 → satake.satake.y@gmail.com
- TSKaigi関連 → yuma.satake@tskaigi.org
- フロントエンドカンファレンス名古屋関連 → 文脈に応じて判断

## メール作成ルール

### 基本方針

- 簡潔・丁寧・言い切りの文体で書く
- 不要な前置きや過剰な敬語を避ける
- 目的が明確に伝わる構成にする

### 構成

```
件名: [内容が一目でわかる件名]

[宛先名] 様

[送信者の自己紹介（初回または文脈に応じて）]

[本文: 用件を簡潔に]

[必要に応じてアクション依頼や期日]

何卒よろしくお願いいたします。

ーーーーーーーーーーー
[メール上で適切な氏名]
[組織（optional）]
Mail：[該当するメールアドレス]
ーーーーーーーーーーー
```

### 件名のルール

- 用件が一目でわかる件名をつける
- イベント名・組織名が関係する場合は冒頭に `【イベント名】` を付ける
  - 例: `【TSKaigi 2026】参加登録のご案内`

### 本文のルール

- 冒頭で自分が誰か・何の件かを明示する
- 箇条書きで情報を整理する（複数の情報がある場合）
- 期日や締切がある場合は明記する
- 返信が必要かどうかを明示する

### トーン

- ビジネス丁寧語を基本とする（過剰な敬語は不要）
- コミュニティ・イベント向けは少しカジュアルな親しみやすさも可
- 初対面の相手には丁寧に、継続的なやり取りは簡潔に

## 出力形式

作成したメールは以下の形式で出力する:

```
**件名**
[件名]

**本文**
[本文]

**送信アカウント**
[使用するメールアドレス]
```

gws CLI でドラフト作成が必要な場合は、その後の手順も案内する。

## gws CLI でのドラフト作成手順

メール本文を作成したあと、以下の手順で Gmail ドラフトを作成する。

### エンコード方式

- 本文は **quoted-printable** でエンコードする（base64 本文埋め込みは文字化けが発生するため使用しない）
- メール全体は **base64url** でエンコードして `raw` に渡す

### Python スクリプト例

```python
import base64, json, email.header, quopri

body = "本文テキスト（UTF-8）"
subject = email.header.Header("件名（日本語）", "utf-8").encode()
body_qp = quopri.encodestring(body.encode("utf-8")).decode("ascii")

raw = (
    "From: 送信元@example.com\r\n"
    "To: 宛先@example.com\r\n"
    f"Subject: {subject}\r\n"
    # 返信の場合は以下を追加
    # "In-Reply-To: <元メッセージID>\r\n"
    # "References: <元メッセージID>\r\n"
    "Content-Type: text/plain; charset=utf-8\r\n"
    "Content-Transfer-Encoding: quoted-printable\r\n"
    "MIME-Version: 1.0\r\n"
    "\r\n"
    + body_qp
)

raw_encoded = base64.urlsafe_b64encode(raw.encode("utf-8")).decode()
payload = {"message": {"raw": raw_encoded}}
# 返信の場合: payload["message"]["threadId"] = "スレッドID"
print(json.dumps(payload))
```

### ドラフト作成コマンド

```bash
# ペイロードをファイルに出力してから渡す（シェル引数の長さ制限回避のため）
python3 script.py > /tmp/draft_payload.json
gws-{account} gmail users drafts create --params '{"userId": "me"}' --json "$(cat /tmp/draft_payload.json)"
```

### 返信元メッセージIDの取得

```bash
gws-{account} gmail users messages get --params '{"userId": "me", "id": "メッセージID", "format": "full"}' 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
headers = {h['name']: h['value'] for h in data['payload']['headers']}
print('Message-ID:', headers.get('Message-ID', ''))
print('Thread-ID:', data.get('threadId', ''))
"
```
