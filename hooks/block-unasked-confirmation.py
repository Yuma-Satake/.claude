#!/usr/bin/env python3
import json
import re
import sys

REQUEST_FORM = re.compile(
    r"させてください|してよいですか|してもよいですか|してもいいですか|"
    r"よろしいですか|どちらにしますか|どうしますか|進めてよいですか"
)
QUOTED_SPAN = re.compile(r"「[^」]*」|`[^`]*`")


def strip_quotes(text):
    return QUOTED_SPAN.sub("", text)


def is_real_user_turn(rec):
    if rec.get("type") != "user":
        return False
    content = rec.get("message", {}).get("content")
    if isinstance(content, str):
        return content.strip() != ""
    if isinstance(content, list):
        return any(block.get("type") != "tool_result" for block in content)
    return False


def load_records(transcript_path):
    records = []
    with open(transcript_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except ValueError:
                continue
    return records


def current_turn_records(records):
    start_idx = 0
    for i in range(len(records) - 1, -1, -1):
        if is_real_user_turn(records[i]):
            start_idx = i + 1
            break
    return records[start_idx:]


def main():
    data = json.load(sys.stdin)

    if data.get("agent_id"):
        return
    if data.get("stop_hook_active"):
        return

    transcript_path = data.get("transcript_path")
    if not transcript_path:
        return

    try:
        records = load_records(transcript_path)
    except OSError:
        return

    assistant_texts = []
    ask_used = False
    for rec in current_turn_records(records):
        if rec.get("type") != "assistant":
            continue
        for block in rec.get("message", {}).get("content", []):
            if block.get("type") == "text":
                assistant_texts.append(block.get("text", ""))
            elif block.get("type") == "tool_use" and block.get("name") == "AskUserQuestion":
                ask_used = True

    if ask_used:
        return
    if not any(REQUEST_FORM.search(strip_quotes(txt)) for txt in assistant_texts):
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
