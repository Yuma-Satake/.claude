# freee 操作ナレッジ

freee会計・freee請求書（invoice.secure.freee.co.jp）を Chrome MCP で操作する場合の固有ナレッジ。

## URL 構造

- 取引先一覧: `https://settings.secure.freee.co.jp/partners?service_name=accounting&is_disable=false`
- 取引先CSVインポート: `https://settings.secure.freee.co.jp/partners/import`
- 請求書一覧: `https://invoice.secure.freee.co.jp/reports/invoices?filter_view_id=-1&cancel_status=uncanceled`
- 請求書の新規作成: `https://invoice.secure.freee.co.jp/reports/invoices/new`

## 取引先CSVインポート

- 一覧右上の「…」メニューから「CSVインポート」を開く
- ファイル選択ボタンは押さず、`find` で `input[type=file]` の ref を取得して `file_upload` で渡す
- 「プレビュー画面へ」の時点では登録されない。プレビューでエラーなしを確認してから「インポートの実行」を押す
- 実行後は取り込みが非同期で進むため、数秒待って一覧を再読み込みして件数を確認する

## 請求書の新規作成

- 日付・摘要・単価は `read_page` で ref を取得して `form_input` で入力できる。ページ遷移ごとに ref を取り直す必要があるため、`navigate` 後に `read_page` を一度呼ぶ
- `form_input` で入れた単価は、入力欄の外（空白部分）をクリックするまで金額・合計に反映されない
- 取引先のドロップダウンは入力による絞り込みが効かない。`type` で文字を打っても候補は全件のままで、Enter は先頭項目を選ぶ
  - 候補を開いたら `screenshot` で並びを確認し、対象項目を座標で直接クリックする
  - 一覧の末尾に「新規登録」があり、誤クリックすると取引先登録ダイアログが開く。開いた場合は「キャンセル」で閉じる
- 取引先の入力欄のクリックは、直前に別の欄を操作していると1回目で開かないことがある。`screenshot` で開いたことを確認してから項目をクリックする
- 「保存」は下書き保存に相当し、送付はされない。保存後は送付ステータスが「送付待ち」になる
- 宛名は取引先マスタの会社名と敬称（御中・様）、部署、担当者から組み立てられる。取引先CSVには担当者名の列がないため、担当者宛にする場合は請求書側または取引先側で個別に設定する
