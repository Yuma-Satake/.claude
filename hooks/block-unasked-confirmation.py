#!/usr/bin/env python3
import json
import re
import sys

REQUEST_FORM = re.compile(
    r"させてください|してよいですか|してもよいですか|してもいいですか|"
    r"よろしいですか|どちらにしますか|どうしますか|進めてよいですか|確認したい|してみる？"
)
QUOTED_SPAN = re.compile(r"「[^」]*」|`[^`]*`")


def strip_quotes(text):
    return QUOTED_SPAN.sub("", text)


def main():
    data = json.load(sys.stdin)

    if data.get("agent_id"):
        return
    if data.get("stop_hook_active"):
        return

    last_message = data.get("last_assistant_message", "")
    if not REQUEST_FORM.search(strip_quotes(last_message)):
        return

    reason = (
        "直前の応答内で許可・確認を求める言い回し（「〜させてください」「〜してよいですか」等）を"
        "使っているが、AskUserQuestionツールは呼ばれていない。実質的に2つ以上の選択肢があるなら"
        "AskUserQuestionツールで確認する。選択肢が実質1つしかない場合は、AskUserQuestionは使わず、"
        "地の文で決定事項として述べ直して進める。"
    )
    print(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False))


if __name__ == "__main__":
    main()
