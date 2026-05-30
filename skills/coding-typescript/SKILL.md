---
name: coding-typescript
description: TypeScriptのコーディング規約を提供する。型定義を書く際、enumやclassを使おうとする際、関数の型を定義する際に必ず参照すること。type alias/interface の使い分け、as const、型安全性、classの禁止などの規約が含まれる。TSファイルを編集する場合は coding-js も必ず合わせて参照すること。
---

# TypeScript コーディング規約

## 型定義

- 型の定義においては、`interface` より `type alias` を使用すること（既存のプロジェクトで `interface` が多く使用されている場合は `interface` を使用）
- `enum` は使用せず、`as const` オブジェクト + union型を使用すること

```ts
const Status = { Active: "active", Inactive: "inactive" } as const;
type Status = typeof Status[keyof typeof Status];
// 値一覧が必要な場合は Object.values(Status) で取得
```

- `as const` オブジェクトの値を使用する際は、文字列リテラルを直接書かず、必ずオブジェクトのプロパティを参照すること（例: `"active"` ではなく `Status.Active`）

## 関数の型

- 関数の型定義は引数と返り値共に必ず型定義を行うこと
- 返り値の型定義は共通化の必要がない場合インラインで定義すること（例: `const fun = (): { id: string } => ...`）

## その他

- classの使用を禁止する。代わりに関数とオブジェクトを使用すること
- `any`/`as`/`unknown` など、型の安全性を損なうような記述の使用を禁止する
