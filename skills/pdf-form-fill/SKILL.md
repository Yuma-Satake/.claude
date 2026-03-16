---
name: pdf-form-fill
description: スキャンされたPDFフォームにテキストを重ねて記入済みPDFを生成する。「PDFに記入して」「申請書を埋めて」「フォームに入力して」などのキーワードで発動する。
---

# PDF フォーム記入スキル

## 概要

スキャン画像ベースのPDFフォームに対して、ReportLab でテキストオーバーレイを生成し、PyPDF2 で合成して記入済みPDFを作成する。

## 環境・依存ライブラリ

```bash
uv add reportlab PyPDF2 PyMuPDF
```

- `reportlab`: テキストオーバーレイPDF生成
- `PyPDF2`: ベースPDFとオーバーレイの合成
- `PyMuPDF` (`fitz`): デバッグ用PDF→PNG変換（python3.9で動作確認済み）
- 日本語フォント: `HeiseiKakuGo-W5`（ReportLab CIDFont、追加インストール不要）

## 基本実装パターン

```python
import io
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from PyPDF2 import PdfReader, PdfWriter

pdfmetrics.registerFont(UnicodeCIDFont('HeiseiKakuGo-W5'))
FONT = 'HeiseiKakuGo-W5'
W, H = 595.68, 842.4  # A4サイズ（pt）

def text_width(text: str, size: int = 10) -> float:
    return pdfmetrics.stringWidth(text, FONT, size)

def make_overlay(data: dict) -> bytes:
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=(W, H))

    def t(x, y, text, size=10):
        c.setFont(FONT, size)
        c.setFillColorRGB(0, 0, 0)
        c.drawString(x, y, text)

    # ここにフィールドの描画処理を記述
    t(100, 700, data['field1'], 10)

    c.save()
    buf.seek(0)
    return buf.read()

def create_form(data: dict, base_pdf: str, out_path: str) -> None:
    overlay_bytes = make_overlay(data)
    reader = PdfReader(base_pdf)
    writer = PdfWriter()
    overlay_reader = PdfReader(io.BytesIO(overlay_bytes))
    base_page = reader.pages[0]
    base_page.merge_page(overlay_reader.pages[0])
    writer.add_page(base_page)
    with open(out_path, 'wb') as f:
        writer.write(f)
```

## 座標系

- PDF座標系: **原点は左下、y軸は上向き**
- A4: `W=595.68pt, H=842.4pt`
- ページ上端付近: y ≈ 800〜840
- ページ下端付近: y ≈ 0〜50
- 1文字分 ≈ フォントサイズ分のpt（size=10なら約10pt）

## 座標調整のコツ

- **右寄せ配置**（数字を「年/月/日」ラベルの直前に揃える）:
  ```python
  t(anchor_x - text_width("2026"), y, "2026", 10)
  ```
- **楕円で囲む**（チェックボックス代わりに項目を囲む）:
  ```python
  c.setLineWidth(1.2)
  c.setStrokeColorRGB(0, 0, 0)
  c.ellipse(x1, y1, x2, y2)  # 左下・右上の座標
  ```
- 微調整は「1文字分 = size pt」「半文字分 = size/2 pt」を目安に行う

## 座標確認（デバッグ）手順

フォームがスキャン画像の場合、テキスト抽出でフィールド座標は取得できないため、以下の手順で視覚的に確認する。

### ① グリッド付きデバッグPDF生成

```python
def make_debug_overlay() -> bytes:
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=(W, H))
    c.setFont('Helvetica', 6)
    c.setStrokeColorRGB(0.7, 0.7, 0.7)
    # 横線（50pt間隔）
    for y in range(0, int(H), 50):
        c.line(0, y, W, y)
        c.drawString(2, y + 1, str(y))
    # 縦線（50pt間隔）
    for x in range(0, int(W), 50):
        c.line(x, 0, x, H)
        c.drawString(x + 1, 2, str(x))
    c.save()
    buf.seek(0)
    return buf.read()
```

### ② PDF→PNG変換してブラウザ確認

```python
# python3.9 / PyMuPDF
import fitz
doc = fitz.open('debug.pdf')
page = doc[0]
mat = fitz.Matrix(3, 3)  # 3倍解像度
pix = page.get_pixmap(matrix=mat)
pix.save('debug.png')
```

```bash
# ローカルHTTPサーバーで確認
python3 -m http.server 8765
```

その後、Claude in Chrome で `http://localhost:8765/debug.png` を開いて座標を目視確認。

## 注意事項

- スキャンPDFはページサイズが標準A4と異なる場合がある → `PdfReader` でページサイズを確認してから `W, H` を設定
- `merge_page()` は既存ページにオーバーレイを重ねる（ベースページの内容は保持される）
- 複数ページのフォームは `reader.pages[n]` でページを指定する
- フォームデータが複数件ある場合は `dict` のリストを渡してループ処理するとよい
