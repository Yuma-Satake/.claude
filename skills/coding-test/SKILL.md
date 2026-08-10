---
name: coding-test
description: テストコードに関するコーディング規約を提供する。テストコードを新規作成・編集・レビューする際に必ず参照すること。
user-invocable: false
---

# テスト コーディング規約

## 適用範囲

- テストコードの新規作成・編集・レビュー時に使用する

## タイマーとグローバルAPIのスタブ

- `IntersectionObserver` 等のグローバルなブラウザAPIを `vi.stubGlobal` でスタブするテストでは、実タイマー（`setTimeout` 等）に依存せず `vi.useFakeTimers()` を使うこと。実タイマー＋`findByText`/`waitFor` のポーリングを併用すると、単体実行では成功してもフルテストスイートの並列実行下でスレッド競合によりタイミングが乱れ、まれに失敗する（flaky）ことがある
