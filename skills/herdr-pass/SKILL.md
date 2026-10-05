---
name: herdr-pass
description: Herdr環境で、与えられた指示を別のclaudeセッションに引き渡して作業させる。新しいworkspaceを作成してclaudeを起動し、指示を送る。-wなしなら作業が正常に始まっていることを確認した時点で終える。-wありなら子セッションの作業完了まで見守り、その結果を使って親側の作業を再開する。「herdr-passで」「別セッションに投げて」「新しいclaudeにやらせて」「herdrで別セッションを立てて作業させて」と依頼された場合に使用する。Herdr環境でない場合は何もしない。
---

# herdr-pass

引数: `[-w] <指示>`。指示は子セッションのclaudeにそのまま渡す作業内容である。

子セッションは会話履歴を持たない。指示に必要な背景（対象リポジトリ・ブランチ・関連issue/PR・制約）は、会話から補って自己完結した文にする。

## 1. 準備

- 作業ディレクトリ`--cwd`は、指示の対象リポジトリのルートを会話から特定して渡す。不明なら現在のディレクトリを使う。
- agent名は指示内容を表す`[a-z][a-z0-9_-]{0,31}`の名前にする（例: `fix-login-bug`）。既存のagent名と重複させない（`herdr agent list`で確認）。
- 起動コマンド`--launcher`は既定で`cc`とする。ユーザーが`ccaws`（AWS Bedrock経由）での起動を指示した場合のみ`ccaws`を指定する。
- 指示文をscratchpadのファイルに書き出す。`-w`ありの場合は末尾に次の内容を追記する。
  - 作業完了時に、結果（実施内容・変更ファイル・未解決事項）をMarkdownで`<scratchpad>/<agent名>-result.md`に書き出すこと

## 2. 起動

```bash
bash ~/.claude/skills/herdr-pass/scripts/herdr_pass.sh --name <agent名> --cwd <dir> --prompt-file <指示ファイル> [--launcher ccaws]
```

`cc`・`ccaws`は`~/.zshrc`のシェル関数で、`.env.1password`の注入（ccawsはさらにBedrock用の環境変数）を行ってから`claude`を起動する。スクリプトは新しいペインでこの関数を実行し、agentとして検出されて`idle`になるのを待つ（最大約3分）。

標準出力が`herdr-pass: failed (...)`または`skipped`の場合は、その行をそのまま報告して終える。成功時は`workspace`・`pane`・`agent`を控える。

## 3. -wなし: 正常に作業中であることの確認

1. `herdr agent get <agent名>`の`agent_status`を確認する。指示送信直後は`working`になる。`idle`のままなら指示が受理されていないため、`herdr agent read <agent名> --source visible --lines 40`で画面を確認する。
2. `blocked`なら権限確認などで止まっている。`visible`で内容を読み、ユーザーに報告する（子セッションは追加の権限オプションなしで起動しているため、書き込みや実行の承認待ちで止まりうる）。承認・拒否の入力はユーザーの判断なしに送らない。
3. `working`を確認できた時点で終える。ユーザーには、agent名・workspace ID・`working`であることを報告する。完了は待たない。

## 4. -wあり: 完了まで見守り、結果で作業を再開

1. 完了待ちはBashの`run_in_background`で実行し、完了通知が来るまで待機以外のことをしない。

   ```bash
   herdr agent wait <agent名> --timeout 1800000
   ```

2. 通知後、応答の`agent_status`で分岐する。
   - `idle`または`done`: 5へ進む。
   - `blocked`: `herdr agent read <agent名> --source visible --lines 40`で内容を読み、ユーザーに報告して判断を仰ぐ。ユーザーの判断で`herdr agent send-keys`や`herdr agent prompt`で入力を送り、再度1の待機に戻る。
   - `unknown`や待機のタイムアウト: 完了とみなさず、`agent read`で画面を確認して状況を報告する。
3. 結果は`<scratchpad>/<agent名>-result.md`を優先して読む。存在しない場合は`herdr agent read <agent名> --source visible --lines 80`で読む。`recent-unwrapped`はclaudeの画面がalternate screenの間は空になることがあるため、`visible`を使う。
4. 読み取った結果を要約して報告し、その内容を前提に、親セッションで本来続けるはずだった作業を再開する。

## 共通の注意

- `--no-focus`で作るため、ユーザーの画面は切り替わらない。
- 子セッションのworkspaceは、ユーザーが明示的に依頼しない限り閉じない。
- 子セッションの作業内容の検証は、結果を鵜呑みにせず、必要に応じて差分や成果物を親側で確認する。
- 起動失敗・スキップ時の1行報告は、グローバル言語ルールの例外としてスクリプトの出力をそのまま伝える。
