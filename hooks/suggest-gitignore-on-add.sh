#!/bin/bash
# PostToolUseフック: git add後も未追跡のまま残っているパスを注入し、
# .gitignoreに追加すべき実行時生成物・キャッシュ・状態ファイルがあれば提案を促す
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

pattern='(^|[;&|(`[:space:]])git([[:space:]]+-[A-Za-z-]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+add([[:space:]]|$)'

if [[ ! "$command" =~ $pattern ]]; then
  exit 0
fi

if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
  exit 0
fi

untracked=$(git -C "$cwd" status --porcelain --untracked-files=normal 2>/dev/null | sed -n 's/^?? //p' | head -100) || exit 0

if [ -z "$untracked" ]; then
  exit 0
fi

jq -n --arg untracked "$untracked" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("git add後も未追跡のまま残っているパスの一覧である（ディレクトリは末尾が/）。このリポジトリはClaude Code本体が生成する実行時データ（キャッシュ・履歴・状態・ログ・一時ファイル・認証情報など）が同じディレクトリに置かれる。意図してaddしなかったファイルではなく、管理対象にならない生成物が含まれていれば、AskUserQuestionで「.gitignoreに追加する」「追加しない」等の選択肢を提示してユーザに提案すること。追加する場合は、既存の.gitignoreの区分に沿い、個別ファイルではなくディレクトリやパターンで記述する。今回のaddで意図的に外したファイルや、これからコミットするファイルは提案の対象にしない。.gitignoreに追加すべきものがなければ何も言わず作業を続けること。\n\n" + $untracked)
  }
}'
