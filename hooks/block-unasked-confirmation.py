#!/usr/bin/env python3
import json
import sys

from confirmation_phrases import REQUEST_FORM, is_afk_active, strip_quotes


def main():
    data = json.load(sys.stdin)

    if data.get("agent_id"):
        return
    if data.get("stop_hook_active"):
        return
    # afkモード中はAskUserQuestionの利用を強制しない(afk-stop-guard.pyに委ねる)
    if is_afk_active(data.get("session_id", "")):
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
