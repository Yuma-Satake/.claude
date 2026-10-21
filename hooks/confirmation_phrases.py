# Stopフックで、確認・承認待ちの言い回しの検出とafkモードの判定を共有する
import os
import re
import subprocess

REQUEST_FORM = re.compile(
    r"させてください|ですか|ますか|確認したい|してみる？|教えてください|決めてください|指示をください"
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
