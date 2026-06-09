---
name: coding-go
description: Goのコーディング規約を提供する。Goファイルを新規作成・編集する際に必ず参照すること。エラーハンドリング、命名規則、コンテキスト、インタフェース設計、DBアクセス、並行処理など、イディオマティックなGo実装のための規約が含まれる。
---

> Echoを使ったHTTPハンドラー・ミドルウェアを実装する場合は `coding-echo` も必ず合わせて参照すること。

# Go コーディング規約

## エラーハンドリング

- 返されたエラーは必ず確認し、`_` で捨てることを禁止する
- エラーはコンテキストを付与してwrapする: `fmt.Errorf("操作名: %w", err)`
- エラーの検査は `errors.Is` / `errors.As` を使用し、直接型アサーションや値比較は行わない
- エラーはログに記録するか呼び出し元に返すかのどちらか一方のみ（両方行うとログが重複する）
- エラーメッセージは小文字で始め、末尾に句読点をつけない（例: `"user not found"` ○、`"User not found."` ✗）
- 期待されるケース（Not Found等）はsentinel errorを使用し、付加情報が必要な場合はカスタムエラー型を定義する
- `panic` は真に回復不能な状態のみに限定し、通常のエラー処理には使わない

## 命名規則

- パッケージ名は小文字・単数形にする（例: `user` ○、`users` / `userService` ✗）
- エラー変数は `Err` プレフィックスを付ける（例: `ErrNotFound`, `ErrUnauthorized`）
- インタフェース名は `Doer` / `Reader` のように動詞+`er` が慣例
- レシーバー名は型名の頭文字1〜2文字を使い、全メソッドで統一する（例: `u *User`）
- ブール変数・関数名は `is` / `has` / `can` プレフィックスを付ける（例: `isActive`, `hasPermission`）

## コンテキスト

- DBクエリ・外部API呼び出しなど全てのI/Oに `context.Context` を第一引数として渡す
- `context.Background()` はプログラムのエントリポイントのみで使用する
- `context.WithValue` でコンテキストに値を詰める際は unexported な型をキーに使い、基本型（`string` 等）をキーにしない

## インタフェース設計

- インタフェースは実装側ではなく利用側のパッケージで定義する
- 1〜3メソッドの小さなインタフェースを優先し、大きなインタフェースを避ける
- 具体型を直接参照できる場合はインタフェースを定義しない（過度な抽象化を避ける）

## DBアクセス

- SQLインジェクション防止のため、ユーザー入力は必ずプレースホルダー（`?` / `$1`）を使用し、文字列結合は禁止
- クエリ実行後は `defer rows.Close()` を忘れない
- `errors.Is(err, sql.ErrNoRows)` で「レコードなし」と実際のエラーを区別する
- `SetMaxOpenConns` / `SetMaxIdleConns` / `SetConnMaxLifetime` でコネクションプールを必ず設定する
- トランザクションが必要な処理はトランザクション内にまとめ、更新後に読み取る場合は `SELECT FOR UPDATE` を使う

## 並行処理

- goroutineを起動する際は必ずリークしないことを保証する（チャンネルのcloseもしくはcontextのキャンセルで終了させる）
- 複数goroutineの管理には `sync.WaitGroup` または `golang.org/x/sync/errgroup` を使用する
- チャンネルの所有権（送信責任・closeする責任）を明確にし、受信側でcloseしない
- `sync.Mutex` のロックは取得直後に `defer mu.Unlock()` を記述する

## テスト

- テーブル駆動テスト（`[]struct{ name, input, want }`）を基本形とする
- テスト関数名は `TestXxx_シナリオ名` の形式にする（例: `TestGetUser_NotFound`）
- `go test -race ./...` でレースコンディションを必ず確認する
- 外部依存（DB・HTTP）はインタフェース経由でモックに差し替えてユニットテストを書く
