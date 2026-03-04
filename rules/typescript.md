# TypeScriptを編集する場合に守るべきルール

## 型定義

- 型の定義においては、interface より type alias を使用して下さい（既存で使用されている場合を除く）
- enumは使用せず、`as const` オブジェクト + union型を使用して下さい（ex: `const Status = { Active: "active", Inactive: "inactive" } as const; type Status = typeof Status[keyof typeof Status];`。値一覧が必要な場合は `Object.values(Status)` で取得可能）

## 関数の型

- 関数の型定義は引数と返り値共に絶対に型定義を行って下さい
- 関数の帰り値の型定義は共通化の必要がない場合"const fun = (): { ... } =>"のようにインラインで定義して下さい

## 型安全性

- any/as/unknown など、型の安全性を損なうような記述の使用を禁止します
