#!/usr/bin/env python3
# Stopフック: afkモード中に確認・承認待ちの言い回しで応答が終わった場合、
# ユーザーは離席中で応答が返らないことを伝え、自律的な作業継続を促す
import json
import os
import re
import subprocess
import sys

REQUEST_FORM = re.compile(
    r"させてください|ですか|ますか|確認したい|してみる？|教えてください"
)
QUOTED_SPAN = re.compile(r"「[^」]*」|`[^`]*`")

AFK_FLAG_SCRIPT = os.path.expanduser("~/.claude/hooks/afk-flag.sh")


def strip_quotes(text):
    return QUOTED_SPAN.sub("", text)


def is_afk_active(session_id):
    if not session_id:
        return False
    result = subprocess.run(
        [AFK_FLAG_SCRIPT, "status", session_id],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() == "active"


def main():
    data = json.load(sys.stdin)

    if data.get("agent_id"):
        return
    if data.get("stop_hook_active"):
        return
    if not is_afk_active(data.get("session_id", "")):
        return

    last_message = data.get("last_assistant_message", "")
    if not REQUEST_FORM.search(strip_quotes(last_message)):
        return

    reason = (
        "ユーザーは現在離席中(afkモード)であり、質問しても応答は返ってこない。"
        "破壊的操作・依頼スコープ外の新規作業など、afkスキル(~/.claude/skills/afk/SKILL.md)が定める"
        "『確認を省略しない対象』に該当する場合は、そのまま停止してユーザーの復帰を待ってよい。"
        "該当しない場合は、選択肢の中から最も妥当な既定解を自分で選び、判断の理由を記録した上で"
        "確認を待たずに作業を続ける必要がある。"
    )
    print(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False))


if __name__ == "__main__":
    main()
