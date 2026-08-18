---
name: coding-react-next
description: React / Next.js のコーディング規約を提供する。Reactコンポーネント・hooksを使う際、Next.jsのApp Routerを使う際に必ず参照すること。useEffect/useRefなどのhooks使用、コンポーネント設計、コロケーション、Next.jsのバージョン確認、clientコンポーネントでのparams取得方法、appディレクトリの共通化ファイル配置など固有の落とし穴を含む規約が含まれる。
user-invocable: false
---

> 対象プロジェクトがNext.jsを使っていない（素のReact/Vite等）場合、後半の「Next.js固有」セクションはスキップしてよい。それ以外は本skill全体を適用する。

# React / Next.js コーディング規約

## React共通

### Hooks

- hooksの引数としてミュータブルな値やオブジェクトを渡しても、引数の値が変更されてもその変更がhooksの中では反映されないことを理解した上で実装すること
- `useEffect` の第2引数の依存配列には、本当にそのhooksを再実行するために監視が必要な値のみを含めること
- `useRef` はそれを使わないと実現不可能な場合を除き使用しないこと
- 非同期処理の進行中フラグ (「送信中」「保存中」など) を `useState<boolean>` + `setPending(true)` / `try { ... await ... } finally { setPending(false) }` の手動制御で扱わないこと。代わりに `useTransition` を使い、`startTransition` を使用すること

### コンポーネント

- ReactコンポーネントはJSDocの記載対象とする
- `React.Component` のように、Reactのパッケージをインポートする際には、`React.` で使用せず、直接importして使用すること
- `import('react').ReactElement` のようなインラインimport型は使用せず、`import type { ReactElement } from 'react'` のようにファイル先頭でimportすること

### コンポーネント設計

- クラスコンポーネントではなく関数コンポーネントを使用すること
- 状態と副作用の管理にはhooksを活用すること
- 不要な再レンダリングを防ぐために `React.memo`・`useCallback` を適切に活用すること
- 横断的な状態管理にはContext API or 導入されている状態管理ライブラリを使用すること
- コンポーネント間で共有するロジックはカスタムhooksに切り出すこと
- コンポーネントは小さく、単一責務を保つこと
- リストのレンダリングには `index` ではなく `id` など一意な値を `key` に設定すること

### 共通化 / コロケーション

コロケーションの概念に従い、全てを共通化するのではなく以下を意識すること

- そのfeatureでのみ使用されるものはプロジェクト全体の `/components` などに置くのではなく、そのfeatureのディレクトリ内に配置すること
- 全体で汎用的に使用するcomponentやhookなどはプロジェクト全体の `/components` や `/hooks` などのディレクトリに配置すること

feature内のディレクトリ構成:

| ディレクトリ | 用途 |
|---|---|
| `/components` | そのfeature内でのみ使用されるUIコンポーネント |
| `/hooks` | そのfeature内でのみ使用されるhook |
| `/utils` | そのfeature内でのみ使用されるutil関数 |
| `/types` | そのfeature内でのみ使用されるtype定義 |
| `/const` | そのfeature内でのみ使用される定数 |
| `/services` | そのfeature内でのみ使用されるAPI通信などのサービス関数 |

## Next.js固有

- Next.jsはバージョンによって大きく破壊的変更があるため、現在のバージョンを確認してから作業に取り組むこと
- clientコンポーネントでのparamsの取得には `use` ではなく、`useParams` を使用すること
- サーバーとクライアントでレンダリング結果が異なる実装（window参照・Math.random()・Date.now()・localStorage へのSSR時アクセスなど）はハイドレーションエラーを引き起こすため避けること
- App Router使用時のappディレクトリの中で共通化のためにファイルを置くときは、直接ファイルをおかずに `_xxx` というディレクトリを作成して、その中にファイルを置くこと
