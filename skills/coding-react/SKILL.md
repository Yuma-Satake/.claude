---
name: coding-react
description: Reactのコーディング規約を提供する。Reactコンポーネント・hooksを使う際に必ず参照すること。useEffect/useRefなどのhooks使用、コンポーネント設計、コロケーションに関する規約が含まれる。
---

> Next.jsファイルを編集する場合は coding-nextjs も必ず合わせて参照すること。

# React / Next.js コーディング規約

## Hooks

- hooksの引数としてミュータブルな値やオブジェクトを渡しても、引数の値が変更されてもその変更がhooksの中では反映されないことを理解した上で実装すること
- `useEffect` の第2引数の依存配列には、本当にそのhooksを再実行するために監視が必要な値のみを含めること
- `useRef` はそれを使わないと実現不可能な場合を除き使用しないこと

## コンポーネント

- 共通コンポーネントを使用する際、該当箇所のニーズを満たすために、無理に共通コンポーネントを拡張して使用することは避ける（例: `!important` でスタイルを当てる/共通コンポーネント自体を安易に拡張する）
- ReactコンポーネントはJSDocの記載対象とする
- `React.Component` のように、Reactのパッケージをインポートする際には、`React.` で使用せず、直接importして使用すること

## 共通化 / コロケーション

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

