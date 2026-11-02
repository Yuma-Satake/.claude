# 公式ベストプラクティスのスナップショット

rules・skillsの定期レビューで判断基準に使う公式ドキュメントの要点を記録する。各ページの本文はMarkdown版（URL末尾に`.md`）をcurlで取得し、そのsha256を記録する。ハッシュが一致するページは本ファイルの要点をそのまま基準に使い、異なるページだけ読み直して更新する。

## Agent Skillsのベストプラクティス

- ソースURL: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md
- 取得日: 2026-11-02
- sha256: cb3f49125d6716342b369145655ec8a129a2baeaff3dd56b3087758f9674bd54
- 備考: docs.claude.com のURLは platform.claude.com へリダイレクトされる

要点

- SKILL.mdは簡潔に保つ。起動時に読み込まれるのはname・descriptionのみで、SKILL.md本文はskillが関連すると判断された時点で読み込まれ、以降は会話履歴と同じくコンテキストを消費する。各段落について「このトークンコストに見合うか」を問う
- SKILL.md本文は500行未満に保つ。超える場合はプログレッシブ開示のパターンで別ファイルに分割する
- SKILL.mdは目次として機能させ、詳細は必要時に読む別ファイルへ置く。参照はSKILL.mdから1階層までに留める（参照先からさらに別ファイルを参照させない）
- 100行を超える参照ファイルは冒頭に目次を置く。部分的に読まれた場合でも全体の範囲が分かるようにするため
- 時間とともに古くなる情報（日付付きの経緯、特定時点の状態）は書かない。必要なら「旧パターン」として分けて書く
- 用語は全体で統一する
- 自由度は作業の性質に合わせる。壊れやすい操作は具体的な手順・スクリプトで固定し、判断を要する作業は方針で示す
- 複雑な作業はチェックリスト付きのワークフローにし、検証して修正するフィードバックループを組み込む
- 決定的な処理はスクリプト化する。スクリプトは内容を読み込まずに実行でき、出力だけがコンテキストを消費する
- descriptionは三人称で、何をするかと、いつ使うかの両方を書く。nameは64文字以内、descriptionは1024文字以内

## Claude Codeのメモリ・rules

- ソースURL: https://code.claude.com/docs/en/memory.md
- 取得日: 2026-11-02
- sha256: f19bb5aa909fe5588d523cf302a0e15ed5950ca689fbb73bd932c315ec764a49

要点

- CLAUDE.mdとrulesは強制される設定ではなくコンテキストとして扱われる。判断に関わらず必ず阻止したい操作はPreToolUseフックを使う
- 指示は検証できる程度に具体的に書く。具体的で簡潔なほど一貫して守られる
- CLAUDE.mdは1ファイル200行未満を目安にする。長いほどコンテキストを消費し、遵守率が下がる。`@`インポートは整理には使えるが起動時に読み込まれるためコストは減らない
- 関連する指示は見出しと箇条書きでまとめる
- 矛盾する指示があるとClaudeはどちらかを任意に選ぶ。古い指示や矛盾する指示を定期的に取り除く。`/doctor prompt-audit`で古い指示・実在しないファイルやコマンドへの参照・ファイル間の矛盾を検出できる
- CLAUDE.mdには毎セッション必要な事実（ビルドコマンド、規約、構成、常に守ること）だけを置く。複数ステップの手順や一部の作業でしか使わない内容はskillかパス限定のruleへ移す
- `.claude/rules/`の各ファイルは1トピックにする。`paths`の無いruleは起動時に`.claude/CLAUDE.md`と同じ優先度で読み込まれる。ruleのfrontmatterで読まれるフィールドは`paths`のみで、他のフィールドはエラーなく無視される
- `paths`付きのruleは、一致するファイルをRead・Write・Editで扱ったときに加え、Bashの`cat`・`head`のように単一ファイルを読むコマンドで扱ったときにも読み込まれる
- 特定の作業でしか使わない指示は、常時コンテキストに載るruleではなく、呼び出し時や関連時にだけ読み込まれるskillに置く
- `~/.claude/rules/`のユーザーレベルruleはプロジェクトruleより先に読み込まれる。どちらも他方を上書きしないため、矛盾しないよう保つ
- `.claude/rules/`内のシンボリックリンクがworking directory外を指す場合は外部インポートと同じ扱いになり、プロジェクトごとの承認後に`paths`の無いものだけが読み込まれる。承認なしで共有したいruleは`~/.claude/rules/`に置く
- `paths`付きのruleやサブディレクトリのCLAUDE.mdのように必要時に読み込まれるファイルは、1ファイルあたりの文字数上限（コンテキストウィンドウの大きさとモデルで変わる）を超えると先頭部分だけが読み込まれ、残りはClaudeがReadで読むまでコンテキストに入らない。超える場合はファイルを削るか、一部を別のruleに分ける
- `/compact`後、プロジェクトルートのCLAUDE.mdはディスクから読み直されて再注入される。サブディレクトリのCLAUDE.mdと`paths`付きのruleは、必要になった時点で読み込み直される
- 作業ディレクトリとその上位に`CLAUDE.md`・`.claude/CLAUDE.md`・`CLAUDE.local.md`が無いリポジトリでは、代わりに`AGENTS.md`をプロジェクトの指示として読む。`~/.claude/CLAUDE.md`・組織のmanaged `CLAUDE.md`・`.claude/rules/`はこの判定に数えられず、`AGENTS.md`と併せて読み込まれる。読み込む組み合わせは`/config`の「Project instructions」で変えられる

## Claude Codeのskills

- ソースURL: https://code.claude.com/docs/en/skills.md
- 取得日: 2026-11-02
- sha256: d2a5d07c0d1cef1d1edcf30f38f6b2712ff70ac050e3d50601cd3dadb42f9097

要点

- frontmatterのフィールドは全て任意で、`description`のみ推奨。未知のフィールドはエラーなく無視される
- 利用できる主なフィールドは`name`・`description`・`when_to_use`・`argument-hint`・`arguments`・`disable-model-invocation`・`user-invocable`・`allowed-tools`・`disallowed-tools`・`model`・`effort`・`context`・`agent`・`background`・`hooks`・`paths`・`shell`。Agent Skills仕様由来の`metadata`・`license`・`compatibility`も受け付けるが、Claude Codeは内容に基づく動作をしない
- `allowed-tools`による許可と`disallowed-tools`による除外は、呼び出したターンに限られ、次のメッセージを送ると解除される。`allowed-tools`は許可するだけで、列挙していないツールの使用を制限しない
- `disable-model-invocation: true`のskillは、descriptionがコンテキストに載らず、自動読み込みに加えてサブエージェントへのプリロードとセッションスコープのscheduled taskのプロンプトとしての実行も行われない
- SKILL.mdを編集せずにskillの表示を変えるには、settingsの`skillOverrides`を使う。値は`on`・`name-only`・`user-invocable-only`・`off`で、未指定のskillは`on`として扱われる。プラグインのskillには効かない
- `model`はskillが有効な間のモデルを指定する。上書きは呼び出したターンの残りにだけ適用され、次のプロンプトでセッションのモデルに戻る。`context: fork`と併用した場合はフォークされるサブエージェントのモデルを指定する
- `description`と`when_to_use`は合計1,536文字で切り詰められる（`skillListingMaxDescChars`で変更可）。主要な用途を先頭に書く
- 補助ファイルはSKILL.mdから参照し、各ファイルの内容といつ読むかをSKILL.mdに書く
- 呼び出されたSKILL.mdの内容は1つのメッセージとして会話に残り、後のターンでファイルは読み直されない。タスク全体に適用したい指示は、一度きりの手順ではなく常に有効な指示として書く
- 自動コンパクション後は各skillの直近の呼び出しが先頭5,000トークンまで再添付される（全skill合計25,000トークン）。重要な指示はSKILL.mdの先頭近くに置く
- 毎回必ず守らせたいルールはhookへ移す。skillに紐づけたい場合はskillの`hooks` frontmatterで定義できる
- Cowork・クラウドセッション（クラウドのscheduled taskを含む）は、手元のマシンの`~/.claude/skills/`を読まない。これらのセッションではclaude.aiアカウントで有効にしたskillが読み込まれる
- `` !`command` ``とコードブロック` ```! `は、skill内容がClaudeへ渡される前にコマンドを実行して出力で置き換える

## Claude Codeのhooks

- ソースURL: https://code.claude.com/docs/en/hooks.md
- 取得日: 2026-11-02
- sha256: 8e4d5d8c03b5a4cd0e6fe15cc8d71d782a5acc29cf738c584337d024ff1e4ca1

要点

- 主なイベントは`SessionStart`・`UserPromptSubmit`・`PreToolUse`・`PostToolUse`・`Stop`・`WorktreeCreate`・`WorktreeRemove`など。`PreModelSwitch`・`PostModelSwitch`・`MessageDisplay`のようにモデル切り替えや表示に関わるイベントもある
- exit code 2はブロックを意味し、JSONのブロック理由が無ければstderrがブロック理由として使われる。JSONで`permissionDecision: "allow"`を返してもexit code 2のブロックは覆らない。構造化した制御を行う場合はexit code 0でJSONを出力する。exit code 1は有効なJSONが無ければブロックしないエラーとして扱われる（`onFailure: "block"`のhookを除く）ため、ポリシーを強制するhookはexit code 2を使う
- PreToolUseは`hookSpecificOutput.permissionDecision`（`allow`・`deny`・`ask`・`defer`。`defer`は`-p`の非対話モードでのみ有効）と`permissionDecisionReason`でツール呼び出しを制御できる
- `additionalContext`でClaudeにコンテキストを追加できる。`additionalContext`・`systemMessage`・プレーンなstdoutは10,000文字が上限で、超えるとファイルに保存され、先頭2,000文字のプレビューとファイルパスが渡される
- 同じhandlerを複数のsettingsファイルに定義した場合は1回だけ実行される。プラグインやskillが持つ同じhandlerは別扱いになる
- プラグインに同梱されたMCPサーバーのツール名は`mcp__plugin_<plugin名>_<サーバー名>__<ツール名>`になり、サーバー名だけのmatcherは一致しない
- `if`フィールドはpermission rule構文で1つだけ指定でき、ツールイベント（`PreToolUse`・`PostToolUse`・`PostToolUseFailure`・`PermissionRequest`・`PermissionDenied`）でのみ評価され、それ以外のイベントで`if`を指定したhookは実行されない。Bashの場合は先頭の`VAR=value`を除いたうえでサブコマンドごとに判定され、`&&`で連結された後続コマンドや`$()`・バッククォート内のコマンドも判定対象になる。コマンドを解析できない場合はパターンに関わらずhookを実行する。`if`はbest-effortであり、確実な許可・拒否にはpermissionsを使う
- `timeout`の既定値は`command`・`http`・`mcp_tool`で600秒、`prompt`で30秒、`agent`で60秒。`UserPromptSubmit`・`PreModelSwitch`・`PostModelSwitch`では30秒、`MessageDisplay`では10秒に下がる。`SessionEnd`のhookは全体で1.5秒の予算を共有し、個別の`timeout`を長く設定すると最大60秒まで予算が引き上げられる
- `once`はskill frontmatterで宣言したhookでのみ有効。最初に成功した実行の後に削除され、失敗・exit code 2によるブロック・タイムアウトの場合は残る
- hookはskillやagentのfrontmatterでも定義できる
- `PreToolUse`の`command`・`http`・`mcp_tool` hookがタイムアウトや失敗で終わってもツール呼び出しはブロックされず、通常の権限フローに進む。失敗時にブロックさせるには`command`・`http` hookに`"onFailure": "block"`を指定する（async hookには効かない。Git Bashの無いWindowsでは未指定でもブロックされることがある）
- hookがバックグラウンドプロセスを起動する場合は、判定結果を先に出力し、バックグラウンドプロセスの標準出力・標準エラーをリダイレクトする。allowを出力した後にリダイレクトせず起動するとツール呼び出しがブロックされ、バックグラウンドで後から出したdenyは無視される
