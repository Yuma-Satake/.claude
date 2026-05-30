---
name: coding-nextjs
description: Next.jsのコーディング規約を提供する。Next.jsのApp Routerを使う際に必ず参照すること。バージョン確認、clientコンポーネントでのparamsの取得方法、appディレクトリの共通化ファイル配置など固有の落とし穴を含む規約が含まれる。
---

> Next.jsファイルを編集する場合は coding-react も必ず合わせて参照すること。

# Next.js コーディング規約

- Next.jsはバージョンによって大きく破壊的変更があるため、現在のバージョンを確認してから作業に取り組むこと
- clientコンポーネントでのparamsの取得には `use` ではなく、`useParams` を使用すること
- サーバーとクライアントでレンダリング結果が異なる実装（window参照・Math.random()・Date.now()・localStorage へのSSR時アクセスなど）はハイドレーションエラーを引き起こすため避けること
- App Router使用時のappディレクトリの中で共通化のためにファイルを置くときは、直接ファイルをおかずに `_xxx` というディレクトリを作成して、その中にファイルを置くこと
