---
name: anti-ai-design
description: React/Next.js + Tailwind CSSでWebフロントエンドのUI/デザインを実装する際に、AIが生成しがちな汎用的・没個性的なデザインを回避し、人間が作ったような個性あるUIを生成するためのガイドライン。個人プロジェクト、MVP、サイドプロジェクト、ランディングページ、小規模チーム開発など、専任デザイナーが不在のプロジェクトでUI実装を行う場合に使用する。「ランディングページを作って」「UIを作って」「画面を作って」「コンポーネントを作って」「トップページを実装して」「フォームを作って」などフロントエンドの見た目に関わるコード生成時に積極的にトリガーすること。デザインシステムが確立済み、またはデザイナーが関与している大規模プロダクトでは使用しない。
---

# Anti AI Design

AIが生成するWebフロントエンドには共通した視覚的特徴があり、見る人に「これAIが作ったな」と即座に見抜かれる。この現象は"AI slop"と呼ばれ、AIの学習データに含まれる最頻出パターンへの収束（distributional convergence）が原因で起きる。

このスキルは、AIが陥りやすいデザインの定型パターンを理解し、意図的に回避することで、人間のデザイナーが手がけたような個性と温かみのあるUIを生成することを目的とする。

詳細なアンチパターンのカタログは `references/anti-patterns.md` を参照すること。

## 基本原則

AIっぽさの根本原因は「最も安全で平均的な選択の繰り返し」にある。以下の3つの原則でこれを打破する。

1. **デフォルトを疑う**: Tailwindのデフォルトカラー、shadcn/uiの素のスタイル、Lucideアイコンのそのまま使用 — これらはAI生成の最大の特徴。必ずカスタマイズしてから使う
2. **非対称性を取り入れる**: 完全な対称・センター揃え・均等配置はAIの安全圏。意図的な非対称やリズムの変化で人間味を出す
3. **制約から個性を生む**: 「なんでもあり」ではなく、プロジェクト固有のカラーパレット・フォント・スペーシングルールを最初に決め、それに従う

## カラー

### 避けるべきパターン

- 紫/インディゴ系のグラデーション（Tailwindの`indigo-500`～`violet-500`圏）  
  Tailwind UIのデフォルトが`bg-indigo-500`だったため、AIの学習データに最も多く含まれている色
- 暗い背景にネオンカラーのbox-shadowグロー
- グラデーションテキスト（特に見出しや数値）
- 意味なく「かっこいい」からとダークモードをデフォルトにする
- 純粋な`#000000`の背景

### 代わりにやること

- プロジェクト開始時に、用途に合った3〜5色のカラーパレットをCSS変数で定義する
- Tailwindの`theme.extend.colors`で独自のブランドカラーを設定し、`indigo`や`violet`をプライマリカラーに使わない
- ダークモードが必要な場合、純黒ではなくブランドカラーの極めて暗いトーン（例: `hsl(220, 15%, 8%)`）を使う
- グラデーションを使うなら、装飾ではなく機能的な理由（進捗バー、ステータス表示など）で使う
- 彩度の低い自然な色味（warm gray, slate, stone）をベースにし、アクセントカラーは1色に絞る

```css
/* 悪い例: AIデフォルト */
--primary: theme('colors.indigo.500');
--gradient: linear-gradient(to right, #6366f1, #a855f7);

/* 良い例: プロジェクト固有のパレット */
--primary: #2d6a4f;      /* 深い緑 */
--accent: #d4a373;        /* 温かみのあるアンバー */
--surface: #fefae0;       /* 柔らかいクリーム */
--text: #1b1b1b;          /* ほぼ黒（純黒ではない） */
```

## タイポグラフィ

### 避けるべきパターン

- Inter, Roboto, Open Sans, Lato, Montserrat, Arial をメインフォントとして使用  
  これらは数百万のサイトで使われており、AI出力の最大の視覚的特徴
- ページ全体で1フォントファミリーのみ
- フォントサイズの差が小さい平坦な文字階層（隣接ステップの比率が1.25未満）
- 全テキストのセンター揃え
- 「技術っぽさ」を出すためだけのmonospaceフォント使用

### 代わりにやること

- 見出し用（display）と本文用（body）で2つのフォントファミリーを使い分ける
- 見出しには個性的なフォントを選ぶ。推奨例：
  - エディトリアル系: Playfair Display, Crimson Pro, Fraunces, Newsreader
  - テック系: Space Grotesk, IBM Plex Sans, JetBrains Mono
  - 個性派: Bricolage Grotesque, DM Serif Display, Outfit
- フォントサイズは大胆な差をつける（見出しは本文の2.5〜3倍以上）
- ウェイトも極端に使い分ける（本文 400, 見出し 700〜900）
- テキストは基本的に左揃え。センター揃えはheroセクションの主見出しとCTAのみ

```tsx
{/* 悪い例 */}
<h1 className="text-2xl font-bold text-center">タイトル</h1>
<p className="text-lg text-center">説明文</p>

{/* 良い例 */}
<h1 className="font-display text-5xl font-black tracking-tight">タイトル</h1>
<p className="font-body text-base text-gray-700 max-w-prose">説明文</p>
```

## レイアウト

### 避けるべきパターン

- hero → 3カラムfeatureカード → testimonials → CTA → footer の定型構成
- 同サイズのカードグリッドにアイコン+見出し+テキストの繰り返し
- 角丸の小さなアイコンコンテナが見出しの上に載る構造
- 全セクション均一のpadding/margin
- すべてをカードで囲む
- カードの中にカードをネストする

### 代わりにやること

- セクションの順序と構成を、そのプロジェクトのコンテンツに合わせて変える
- featureの紹介は3カラム均等グリッドではなく、ジグザグ配置、1カラム縦積み、2カラム非対称などバリエーションを持たせる
- カードを使うなら、サイズや形を意図的に変える（1つだけ大きくする、横長と縦長を混ぜる）
- すべてのコンテンツをカードに入れない — 余白とタイポグラフィだけでグルーピングを表現できる
- セクション間のスペーシングにリズムをつける（例: 64px → 96px → 48px → 80px）

```tsx
{/* 悪い例: AI定型パターン */}
<div className="grid grid-cols-3 gap-6">
  {features.map((f) => (
    <div key={f.id} className="rounded-xl border p-6 text-center">
      <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-lg bg-indigo-100">
        <f.icon className="h-6 w-6 text-indigo-600" />
      </div>
      <h3 className="text-lg font-semibold">{f.title}</h3>
      <p className="text-gray-500">{f.description}</p>
    </div>
  ))}
</div>

{/* 良い例: 非定型レイアウト */}
<div className="space-y-16">
  {features.map((f, i) => (
    <div key={f.id} className={`flex items-start gap-8 ${i % 2 !== 0 ? "flex-row-reverse" : ""}`}>
      <div className="flex-1">
        <span className="text-sm font-medium uppercase tracking-widest text-emerald-700">
          {f.label}
        </span>
        <h3 className="mt-2 text-2xl font-bold">{f.title}</h3>
        <p className="mt-3 leading-relaxed text-gray-600">{f.description}</p>
      </div>
      <div className="w-80 shrink-0">
        {f.visual}
      </div>
    </div>
  ))}
</div>
```

## コンポーネントスタイリング

### 避けるべきパターン

- shadcn/uiのデフォルトテーマをそのまま使用
- すべてのボタンが同じ重要度に見える（全部primaryスタイル）
- 太い色付きボーダーが片側だけにあるカード（AI UI最大の特徴の1つ）
- 角丸+汎用ドロップシャドウの組み合わせ（例: `rounded-xl shadow-md`）
- Lucide/Heroiconsをデフォルトサイズ・色でそのまま使用

### 代わりにやること

- shadcn/uiを使う場合、CSS変数でテーマをカスタマイズする（`--radius`, `--primary`等）
- ボタンの視覚的重要度を明確に分ける（primary 1つ、secondary、ghost/link）
- シャドウを使うなら控えめに、かつ色付きシャドウ（ブランドカラーの薄いトーン）で個性を出す
- border-radiusは全体で統一し、プロジェクトの性格に合わせる（シャープ: 4px / 柔らか: 12px / 丸い: 9999px）
- アイコンを使う場合、サイズ・ストローク幅・色をコンテキストに合わせて調整する

## スペーシングとリズム

### 避けるべきパターン

- 全セクションで同じpadding値（例: すべて`py-16`）
- コンテンツと容器の端が近すぎる（padding 8px未満）
- テキストの行長が長すぎる（80文字超）

### 代わりにやること

- スペーシングにリズムをつけ、関連する要素はタイトに、セクション間は大きく開ける
- 本文テキストの最大幅を`max-w-prose`（65ch）または`max-w-2xl`程度に制限する
- コンポーネント内のpaddingは最低12〜16px確保する
- line-heightは本文で1.6〜1.75を確保する

## Heroセクション

heroセクションはAIっぽさが最も出やすい箇所。特に注意する。

### 避けるべきパターン

- センター揃えの見出し + 説明 + グラデーションボタン + 右側にモックアップ画像
- 「We help teams [動詞]」のような汎用的なコピー
- 紫系グラデーションの背景
- 大きな数字 + 小さなラベル + 3つの統計値の並び

### 代わりにやること

- 左揃えレイアウトや、フルブリードの画像/イラストを検討する
- heroのビジュアルはストック写真ではなく、実際のプロダクトのスクリーンショット、パターン、イラスト、またはCSSアートを検討する
- コピーは具体的で、そのプロダクトにしか言えないことを書く

## テクスチャと温かみ

完全にフラットで均一な表面はAIの特徴。微細な質感で人間味を加える。

- 背景に薄いノイズテクスチャ（SVGフィルタで`opacity: 0.03`〜`0.05`程度）
- 純粋な白(`#ffffff`)の代わりに、かすかに色味のある白を使う（例: `#fafaf9`, `#f8fafc`）
- ボーダーの色は灰色のデフォルトではなく、背景色に合わせた暖色/寒色を選ぶ

## 実装時のチェックリスト

UIコンポーネントやページを生成した後、以下を確認する：

1. カラーパレットにindigo/violet/purpleがプライマリとして使われていないか
2. フォントがInter/Roboto/Open Sans/Montserrat/Arialだけになっていないか
3. 3カラム均等カードグリッド+アイコン+見出し+説明の定型パターンになっていないか
4. すべてのテキストがセンター揃えになっていないか
5. スペーシングが全セクションで均一になっていないか
6. グラデーションテキストやネオングローが装飾として使われていないか
7. ボタンの視覚的階層が区別されているか
8. shadcn/uiのデフォルトテーマをそのまま使っていないか
9. heroセクションが定型パターン（見出し+説明+CTA+右側画像）になっていないか
10. カードの片側に太い色付きボーダーがないか
