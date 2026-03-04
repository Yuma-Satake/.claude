# React / Next.jsを編集する場合に守るべきルール

## Hooks

- hooks の引数としてミュータブルな値やオブジェクトを渡しても、引数の値が変更されてもその変更が hooks の中では反映されないことを理解し、実装を進めて下さい
- useEffect の第2引数の依存配列には、本当にその値がそのhooksを再実行するために監視が必要な値のみを含めること
- useRef はそれを使わないと実現不可能な場合を除き使用しないで下さい

## コンポーネント

- 共通コンポーネントを使用する際、該当箇所のニーズを満たすために、無理に共通コンポーネントを拡張して使用することは避ける（ex: importantでスタイルを当てる/共通コンポーネント自体を安易に拡張する）
- ReactコンポーネントはJSDocの記載対象とする
- React.Componentのように、Reactのパッケージをインポートする際には、React.で使用せず、直接importして使用すること

## 共通化 / コロケーション

コロケーションの概念に従い、全てを共通化するのではなく、以下の内容を意識して共通化を行うこと

- そのfeatureでのみ使用されるものはプロジェクト全体"/components"などに置くのではなく、そのfeatureのディレクトリ内に"/utils"・"/components"・"/hooks"などのディレクトリを作成して配置すること
- 全体で汎用的に使用するcomponentやhookなどはプロジェクト全体の"/components"や"/hooks"などのディレクトリに配置すること
- features内で共通化を行うためのディレクトリとしては以下のようなものがあります
  - /components: そのfeature内でのみ使用されるui component
  - /hooks: そのfeature内でのみ使用されるhook
  - /utils: そのfeature内でのみ使用されるutil関数
  - /types: そのfeature内でのみ使用されるtype定義
  - /const: そのfeature内でのみ使用される定数
  - /services: そのfeature内でのみ使用されるapi通信などのサービス関数
