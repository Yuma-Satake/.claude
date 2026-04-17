# AI Design アンチパターン詳細カタログ

AIが生成するWebフロントエンドに頻出するアンチパターンの網羅的なリスト。Impeccableプロジェクト、100サイト分析、各種デザインレビュー記事から収集・整理したもの。

## 目次

1. [カラーとコントラスト](#カラーとコントラスト)
2. [タイポグラフィ](#タイポグラフィ)
3. [レイアウトとスペーシング](#レイアウトとスペーシング)
4. [コンポーネント](#コンポーネント)
5. [ビジュアルディテール](#ビジュアルディテール)
6. [モーション](#モーション)
7. [コンテンツ](#コンテンツ)
8. [技術的品質](#技術的品質)
9. [推奨フォント・カラーパレット例](#推奨フォントカラーパレット例)

---

## カラーとコントラスト

### AI color palette（深刻度: 高）
紫/バイオレットのグラデーションとダーク背景にシアンアクセント。AI生成UIの最も認識しやすい視覚的特徴。

原因: Tailwind UIの初期デフォルトが`bg-indigo-500`で、膨大なチュートリアルやOSSプロジェクトがこの色を使用。学習データに過剰に含まれた結果、AIが「標準的なWebデザインの色」として学習した。

避けるべき具体的な値:
- `bg-indigo-*`, `bg-violet-*`, `bg-purple-*` をプライマリカラーとして使用
- `from-indigo-500 to-purple-500` 系のグラデーション
- `text-indigo-600` のリンク/ボタン色

### Dark mode with glowing accents（深刻度: 高）
暗い背景にカラーのbox-shadowグローを組み合わせるパターン。

避けるべき具体的なCSS:
```css
box-shadow: 0 0 20px rgba(99, 102, 241, 0.3);  /* indigo glow */
box-shadow: 0 0 15px rgba(168, 85, 247, 0.4);   /* purple glow */
```

### Gradient text（深刻度: 中）
見出しや数値にグラデーションテキストを適用する装飾。機能的な意味がなく、AIの特徴。

避けるべきパターン:
```css
background: linear-gradient(to right, #6366f1, #a855f7);
-webkit-background-clip: text;
-webkit-text-fill-color: transparent;
```

### Defaulting to dark mode（深刻度: 中）
デザイン上の判断ではなく「かっこよく見えるから」という理由でダークモードをデフォルトにする。

### Pure black background（深刻度: 低）
`#000000`はスクリーン上で不自然に見える。ブランドカラー方向にわずかにティントした暗色を使う。

例: `#0a0a0b`（ニュートラル）、`#0c1015`（青寄り）、`#100d09`（暖色寄り）

### Gray text on colored background（深刻度: 低）
色付き背景にグレーテキストを置くと洗い出されて見える。背景色の暗いシェードを使う。

---

## タイポグラフィ

### Overused font（深刻度: 高）
以下のフォントは数百万サイトで使用されており、AI出力の最大の視覚的特徴:
- Inter
- Roboto
- Open Sans
- Lato
- Montserrat
- Arial
- system-ui（フォールバックとしてのみ可）

### Single font family（深刻度: 高）
ページ全体で1フォントファミリーのみを使用。見出し用（display）と本文用で最低2種類をペアリングする。

### Flat type hierarchy（深刻度: 中）
フォントサイズの隣接ステップの比率が1.25未満。大胆なサイズジャンプが必要。

悪い例: 14px → 16px → 18px → 20px → 24px（差が小さすぎる）
良い例: 14px → 18px → 28px → 48px → 72px（明確な階層）

### Everything centered（深刻度: 中）
すべてのテキストがtext-align: center。左揃えベースに切り替え、センター揃えはhero見出しとCTAボタン周辺のみに限定する。

### Icon tile stacked above heading（深刻度: 中）
角丸の小さなアイコンコンテナが見出しの上に配置されるパターン。AI featureカードテンプレートの普遍的な特徴。

代替案: アイコンと見出しを横並びにする、アイコンをコンテナなしで配置する、アイコン自体を大きくして主役にする。

### Monospace as "technical" shorthand（深刻度: 低）
コードブロック以外でmonospaceフォントを使い「技術っぽさ」を演出する。意味のある場面でのみ使用する。

### All-caps body text（深刻度: 低）
長い文章を全大文字にすると可読性が著しく落ちる。大文字は短いラベルやナビゲーションのみ。

---

## レイアウトとスペーシング

### Identical card grids（深刻度: 高）
同サイズのカードにアイコン+見出し+テキストを繰り返す、AIホームページの定型レイアウト。

代替案:
- ジグザグ（左右交互）レイアウト
- メインカード1つ+サブカード複数の非均等グリッド
- カードを使わずタイポグラフィと余白だけで構成
- リスト形式
- 画像/ビジュアルとテキストの2カラム交互配置

### Monotonous spacing（深刻度: 中）
全セクションで同じpadding/margin値（典型的に`py-16`や`py-20`）。

修正: 関連要素はタイトに（16〜24px）、セクション間は大きく（64〜120px）、意図的にリズムをつける。

### Nested cards（深刻度: 中）
カードの中にカードを入れると視覚的ノイズと過剰な深度が生まれる。

### Wrapping everything in cards（深刻度: 中）
すべてのコンテンツにボーダー付きコンテナを使う。余白と文字組みだけでグルーピングを表現する方が洗練される。

### Hero metric layout（深刻度: 中）
大きな数字+小さなラベル+3つの支持統計+グラデーションアクセント。頻出しすぎて信頼性がない。

### Line length too long（深刻度: 低）
テキストが80文字を超えると可読性が落ちる。`max-width: 65ch`〜`75ch`を設定する。

### Predictable section ordering（深刻度: 中）
hero → features → testimonials → pricing → CTA → footer の予測可能な順序。コンテンツの優先度に基づいて順序を決める。

---

## コンポーネント

### Unstyled shadcn/ui（深刻度: 高）
shadcn/uiのデフォルトテーマをカスタマイズせずに使用。CSS変数（`--radius`, `--primary`, `--secondary`等）を必ずプロジェクトに合わせて変更する。

### Every button is primary（深刻度: 中）
すべてのボタンが同じ視覚的重要度。primary/secondary/ghost/linkの階層を明確にする。

### Side-tab accent border（深刻度: 高）
カード片側の太い色付きボーダー。AI生成UIの最も認識しやすい特徴の1つ。

```tsx
{/* 絶対にやらない */}
<div className="rounded-lg border-l-4 border-indigo-500 bg-white p-4 shadow">
```

### Rounded rectangles with generic drop shadows（深刻度: 中）
`rounded-xl shadow-md`の組み合わせ。最も安全で最も忘れられやすい形状。

代替案: シャドウなしでボーダーのみ、薄い背景色で区切り、色付きシャドウ、またはシャドウを使わない。

### Generic CTA text（深刻度: 低）
"Get Started", "Learn More", "Sign Up Now"。そのプロダクトの行動に合った具体的なテキストにする。

---

## ビジュアルディテール

### Glassmorphism everywhere（深刻度: 中）
ブラー効果、ガラスカード、グローボーダーを装飾として使用。レイヤリングの問題を解決する場合にのみ使う。

### Sparklines as decoration（深刻度: 低）
意味のある情報を伝えない小さなチャートを装飾として配置する。

### Border accent on rounded element（深刻度: 低）
角丸カードに太いアクセントボーダー。角丸とボーダーが視覚的に衝突する。

### Stock photography（深刻度: 中）
Unsplashのストック写真をheroやfeatureセクションに使用。「見たことある」感が信頼を下げる。

代替案: プロダクトの実際のスクリーンショット、CSSパターン/グラデーション、カスタムイラスト、または画像なし。

---

## モーション

### Bounce or elastic easing（深刻度: 低）
bounceやelasticイージングは古臭い印象。`ease-out`やカスタムの`cubic-bezier`を使う。

### Layout property animation（深刻度: 低）
width/height/padding/marginのアニメーションはレイアウトスラッシュを起こす。`transform`と`opacity`を使う。

---

## コンテンツ

### Generic hero copy（深刻度: 中）
- "We help teams collaborate better"
- "The future of [noun]"
- "Built for developers, by developers"
- "Supercharge your workflow"

これらはAIが生成する最頻出のキャッチコピー。そのプロダクトにしか言えない、具体的で正直なコピーに置き換える。

### Fake testimonials（深刻度: 高）
架空の人名と肩書きの推薦文。テスティモニアルを入れるなら本物のデータがあることが前提。プロトタイプ段階ではセクション自体を省略する。

---

## 技術的品質

以下はデザインではなく技術的な品質の問題だが、AI生成サイトに頻出するため含める:

- OpenGraphメタデータの欠落
- 画像のalt属性なし
- 見出しレベルの飛び（h1 → h3）
- デフォルトのfavicon放置
- viewport metaタグの欠落
- 未圧縮のhero画像
- WCAG AAコントラスト比（4.5:1）の未達

---

## 推奨フォント・カラーパレット例

### フォントペアリング例

| 用途 | 見出し | 本文 |
|------|--------|------|
| エディトリアル | Playfair Display | Source Serif 4 |
| モダンテック | Space Grotesk | IBM Plex Sans |
| クリーン | DM Serif Display | DM Sans |
| 個性派 | Bricolage Grotesque | Outfit |
| クラフト | Fraunces | Crimson Pro |
| ミニマル | Newsreader | Source Sans 3 |

### カラーパレット例（indigo/purpleを使わない）

**Forest（自然・エコ系）**
```
primary: #2d6a4f    accent: #95d5b2    surface: #f0f7f4    text: #1b1b1b
```

**Terracotta（温かみ・クラフト系）**
```
primary: #bc6c25    accent: #dda15e    surface: #fefae0    text: #283618
```

**Ocean（信頼・プロフェッショナル系）**
```
primary: #0077b6    accent: #90e0ef    surface: #f8f9fa    text: #212529
```

**Slate（ミニマル・ビジネス系）**
```
primary: #475569    accent: #f59e0b    surface: #f8fafc    text: #0f172a
```

**Rose（柔らか・ヘルスケア系）**
```
primary: #9f1239    accent: #fda4af    surface: #fff1f2    text: #1c1917
```

### 背景色のバリエーション（純白 #ffffff の代替）

| トーン | 値 | 用途 |
|--------|-----|------|
| ウォームホワイト | #fafaf9 | 温かみのあるサイト |
| クールホワイト | #f8fafc | テック系・クリーン |
| クリーム | #fefae0 | オーガニック・ナチュラル |
| ペールグレー | #f9fafb | ニュートラル |
| ペールブルー | #f0f9ff | SaaS・プロフェッショナル |
