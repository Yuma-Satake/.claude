# 公式ベストプラクティスのスナップショット

rules・skillsの定期レビューで判断基準に使う公式ドキュメントの要点を記録する。各ページの本文はMarkdown版（URL末尾に`.md`）をcurlで取得し、そのsha256を記録する。ハッシュが一致するページは本ファイルの要点をそのまま基準に使い、異なるページだけ読み直して更新する。

## Agent Skillsのベストプラクティス

- ソースURL: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md
- 取得日: 2026-10-05
- sha256: 542eee1e150ff7e2853099dd9e24b94626817d5a50ba50af4a4c35101a355f13
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
- 取得日: 2026-10-05
- sha256: fe99e50e312feae327c1e16847bc5853c71aaf2755fa554f9014c9008850e2cb

要点

- CLAUDE.mdとrulesは強制される設定ではなくコンテキストとして扱われる。判断に関わらず必ず阻止したい操作はPreToolUseフックを使う
- 指示は検証できる程度に具体的に書く。具体的で簡潔なほど一貫して守られる
- CLAUDE.mdは1ファイル200行未満を目安にする。長いほどコンテキストを消費し、遵守率が下がる。`@`インポートは整理には使えるが起動時に読み込まれるためコストは減らない
- 関連する指示は見出しと箇条書きでまとめる
- 矛盾する指示があるとClaudeはどちらかを任意に選ぶ。古い指示や矛盾する指示を定期的に取り除く。`/doctor prompt-audit`で古い指示・実在しないファイルやコマンドへの参照・ファイル間の矛盾を検出できる
- CLAUDE.mdには毎セッション必要な事実（ビルドコマンド、規約、構成、常に守ること）だけを置く。複数ステップの手順や一部の作業でしか使わない内容はskillかパス限定のruleへ移す
- `.claude/rules/`の各ファイルは1トピックにする。`paths`の無いruleは起動時に`.claude/CLAUDE.md`と同じ優先度で読み込まれる。ruleのfrontmatterで読まれるフィールドは`paths`のみで、他のフィールドはエラーなく無視される
- 特定の作業でしか使わない指示は、常時コンテキストに載るruleではなく、呼び出し時や関連時にだけ読み込まれるskillに置く
- `~/.claude/rules/`のユーザーレベルruleはプロジェクトruleより先に読み込まれる。どちらも他方を上書きしないため、矛盾しないよう保つ

## Claude Codeのskills

- ソースURL: https://code.claude.com/docs/en/skills.md
- 取得日: 2026-10-05
- sha256: acdf96599200090206dd21327022aa58b21e23dfebdaffaa974b2fdb25077e00

要点

- frontmatterのフィールドは全て任意で、`description`のみ推奨。未知のフィールドはエラーなく無視される
- 利用できる主なフィールドは`name`・`description`・`when_to_use`・`argument-hint`・`arguments`・`disable-model-invocation`・`user-invocable`・`allowed-tools`・`disallowed-tools`・`model`・`effort`・`context`・`agent`・`background`・`hooks`・`paths`・`shell`
- `model`はskillが有効な間のモデルを指定する。`context: fork`と併用した場合はフォークされるサブエージェントのモデルを指定する
- `description`と`when_to_use`は合計1,536文字で切り詰められる。主要な用途を先頭に書く
- 補助ファイルはSKILL.mdから参照し、各ファイルの内容といつ読むかをSKILL.mdに書く
- 呼び出されたSKILL.mdの内容は1つのメッセージとして会話に残り、後のターンでファイルは読み直されない。タスク全体に適用したい指示は、一度きりの手順ではなく常に有効な指示として書く
- 自動コンパクション後は各skillの直近の呼び出しが先頭5,000トークンまで再添付される（全skill合計25,000トークン）。重要な指示はSKILL.mdの先頭近くに置く
- 毎回必ず守らせたいルールはhookへ移す。skillに紐づけたい場合はskillの`hooks` frontmatterで定義できる
- `` !`command` ``とコードブロック` ```! `は、skill内容がClaudeへ渡される前にコマンドを実行して出力で置き換える

## Claude Codeのhooks

- ソースURL: https://code.claude.com/docs/en/hooks.md
- 取得日: 2026-10-05
- sha256: 69c05a2c5eb2ec43f024375a11ffa2dc22fee2364236603fc9bd2e9368b73f24

要点

- 主なイベントは`SessionStart`・`UserPromptSubmit`・`PreToolUse`・`PostToolUse`・`Stop`・`WorktreeCreate`・`WorktreeRemove`など
- exit code 2はブロックを意味し、JSONのブロック理由が無ければstderrがブロック理由として使われる。JSONで`permissionDecision: "allow"`を返してもexit code 2のブロックは覆らない。構造化した制御を行う場合はexit code 0でJSONを出力する
- PreToolUseは`hookSpecificOutput.permissionDecision`（`allow`・`deny`・`ask`など）と`permissionDecisionReason`でツール呼び出しを制御できる
- `additionalContext`でClaudeにコンテキストを追加できる
- `if`フィールドはpermission rule構文で1つだけ指定でき、ツールイベントでのみ評価される。Bashの場合は先頭の`VAR=value`を除いたうえでサブコマンドごとに判定され、`&&`で連結された後続コマンドや`$()`・バッククォート内のコマンドも判定対象になる。コマンドを解析できない場合はパターンに関わらずhookを実行する。`if`はbest-effortであり、確実な許可・拒否にはpermissionsを使う
- `timeout`の既定値はcommandで600秒。`UserPromptSubmit`では30秒に下がる
- `once`はskill frontmatterで宣言したhookでのみ有効
- hookはskillやagentのfrontmatterでも定義できる
