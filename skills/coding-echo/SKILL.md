---
name: coding-echo
description: Echo v4のコーディング規約を提供する。EchoでHTTPエンドポイント・ミドルウェア・ルーティングを実装する際に必ず参照すること。ルート設計、ミドルウェアの書き方、データバインディング、エラーレスポンスのパターンが含まれる。
---

> Echo関連ファイルを編集する場合は `coding-go` も必ず合わせて参照すること。

# Echo v4 コーディング規約

## アーキテクチャ概要

- ルートやミドルウェアの登録は `e.Start()` 呼び出し前にすべて完了させる（登録処理はgoroutine-safeでない）
- `echo.Context` はリクエスト・レスポンスを扱う中心的なインタフェース
- ルーターはHTTPメソッドごとにRadix treeを持ち、静的・パラメータ・ワイルドカードルートを優先度順に解決する

## ルーティング

- 共通プレフィックスや共通ミドルウェアを持つルートはGroupでまとめる

```go
api := e.Group("/api/v1")
api.Use(authMiddleware)
api.GET("/users/:id", getUser)
api.POST("/users", createUser)
```

- パスパラメータは `:name`、ワイルドカードは `*` で定義し、取得は `c.Param("name")` で行う
- クエリパラメータの取得は `c.QueryParam("key")`、フォーム値は `c.FormValue("key")` を使う

## ミドルウェア

- ミドルウェアのシグネチャ: `func(next echo.HandlerFunc) echo.HandlerFunc`
- 適用スコープは Echo全体 / Group / 個別ルートの3段階で使い分ける
- Pre-middlewareはルーティング前に実行されるため、ルート情報が必要な処理には使わない

```go
e.Use(middleware.Logger())   // Echo全体
g.Use(authMiddleware)        // Group
e.GET("/path", h, rateLimit) // 個別ルート
```

## ハンドラー

- ハンドラーのシグネチャ: `func(c echo.Context) error`
- HTTPエラーは `echo.NewHTTPError` で返し、ハンドラー内で `c.JSON` を直接書いてエラーを返さない

```go
func getUser(c echo.Context) error {
    id := c.Param("id")
    user, err := svc.GetUser(c.Request().Context(), id)
    if errors.Is(err, ErrNotFound) {
        return echo.NewHTTPError(http.StatusNotFound, "user not found")
    }
    if err != nil {
        return err // EchoのデフォルトHTTPErrorHandlerが500を返す
    }
    return c.JSON(http.StatusOK, user)
}
```

- パニックは `middleware.Recover()` でキャッチされるが、エラーハンドリングはpanicに依存せず `error` を返す形で実装する

## データバインディング

- `c.Bind(&req)` はContent-Type（JSON / XML / フォーム）を自動判別してリクエストをバインドする。バインド後に必ずバリデーションを実行する
- `c.Validate` を使うには事前に `e.Validator` にバリデーター実装（例: `go-playground/validator`）を設定すること。未設定の場合は `ErrValidatorNotRegistered` エラーが返される

```go
var req CreateUserRequest
if err := c.Bind(&req); err != nil {
    return echo.NewHTTPError(http.StatusBadRequest, err.Error())
}
if err := c.Validate(&req); err != nil {
    return echo.NewHTTPError(http.StatusBadRequest, err.Error())
}
```

- カスタムバインダーが必要な場合は `echo.Binder` インタフェースを実装し `e.Binder` に設定する

## エラーハンドリング

- 集中エラーハンドラーは `e.HTTPErrorHandler` に設定し、ハンドラーごとに個別のエラーフォーマットを実装しない
- `*echo.HTTPError` でラップされていないエラーはデフォルトで500を返す
- エラーレスポンスのフォーマット（`{"error": "message"}` 等）はカスタムHTTPErrorHandlerで統一する

## テスト

- `go test -race ./...` でレースコンディションを確認する
- ハンドラーのテストは `httptest.NewRecorder()` と `httptest.NewRequest()` を使い、HTTPサーバーを起動せずに単体でテストできる

```go
req := httptest.NewRequest(http.MethodGet, "/users/1", nil)
rec := httptest.NewRecorder()
c := e.NewContext(req, rec)
c.SetParamNames("id")
c.SetParamValues("1")
assert.NoError(t, getUser(c))
assert.Equal(t, http.StatusOK, rec.Code)
```
