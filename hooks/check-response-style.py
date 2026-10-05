#!/usr/bin/env python3
import json
import re
import sys

CODE_BLOCK = re.compile(r"```.*?```", re.DOTALL)
QUOTED_SPAN = re.compile(r"「[^」]*」|`[^`]*`")
# Markdownリンクと山括弧で囲んだURLは、閉じ記号がリンク構文の一部である
LINK_SYNTAX = re.compile(r"\]\(https?://[^)\s]*\)|<https?://[^>\s]*>")
URL = re.compile(r"https?://[\x21-\x7e]+")
TRAILING_PUNCTUATION = ".,;:!?)]}'\""

# rules/communication.mdの言い換え辞書のうち、他の語に含まれて誤検知しにくい語
DISCOURAGED_TERMS = (
    "赤くする",
    "完走",
    "不正値",
    "するべき",
    "落ちる",
    "挙動変更",
    "散っている",
    "窓長",
    "購読",
    "安定ソート",
)


def strip_exempt_spans(text):
    text = CODE_BLOCK.sub("", text)
    text = LINK_SYNTAX.sub("", text)
    return QUOTED_SPAN.sub("", text)


def find_glued_urls(text):
    glued = []
    for match in URL.finditer(text):
        url = match.group()
        next_char = text[match.end() : match.end() + 1]
        if url[-1] in TRAILING_PUNCTUATION or (next_char and not next_char.isspace()):
            glued.append(url)
    return glued


def main():
    data = json.load(sys.stdin)

    if data.get("agent_id"):
        return
    if data.get("stop_hook_active"):
        return

    text = strip_exempt_spans(data.get("last_assistant_message", ""))

    problems = []
    glued_urls = find_glued_urls(text)
    if glued_urls:
        problems.append(
            "URLの直後に文字が続いている（"
            + "、".join(glued_urls[:3])
            + "）。URLの後に補足を書く場合は改行して別の行にする"
        )
    terms = [term for term in DISCOURAGED_TERMS if term in text]
    if terms:
        problems.append(
            "言い換え辞書の変更前の語を使っている（"
            + "、".join(terms)
            + "）。rules/communication.mdの辞書に従って言い換える"
        )

    if not problems:
        return

    reason = "応答の書式がrules/communication.mdに反している。" + "。".join(problems) + "。直した内容で応答し直す"
    print(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False))


if __name__ == "__main__":
    main()
