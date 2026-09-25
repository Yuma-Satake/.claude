#!/usr/bin/env python3
import json
import re
import sys

REQUEST_FORM = re.compile(
    r"させてください|ですか|ますか|確認したい|してみる？|教えてください"
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
        "確認・質問を求める言い回し（「〜してよいですか」「教えてください」等）を使っているが、"
        "AskUserQuestionが呼ばれていない。ユーザへの質問は、複数項目でも地の文にせず項目ごとにAskUserQuestionで聞く"
        "（自由入力の項目も候補を2つ以上並べ、Otherに任せる。1回最大4問）。"
        "質問ではなく決定事項で、選択肢が実質1つの場合に限り、地の文で述べ直して進める。"
    )
    print(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False))


if __name__ == "__main__":
    main()
