#!/bin/bash
# Stopフック: アシスタント自身の直前応答の中に "user[" という文字列が含まれている場合、
# それは自作自演で生成した偽のuserターンである可能性が高いとして警告をコンテキストへ注入する。
# last_assistant_messageはアシスタント自身の発言全文であり、本物のユーザ発言（UserPromptSubmitの
# prompt）とは別経路で届くフィールドのため、本物のユーザ指示を誤検知することはない。
set -euo pipefail

input=$(cat)

agent_id=$(echo "$input" | jq -r '.agent_id // empty')
if [ -n "$agent_id" ]; then
  exit 0
fi

last_message=$(echo "$input" | jq -r '.last_assistant_message // empty')

if [ -z "$last_message" ]; then
  exit 0
fi

if ! echo "$last_message" | grep -qF 'user['; then
  exit 0
fi

message='直前の自分の応答内に "user[" という文字列が含まれています。これは過去のセッションで、実際にはユーザが発言していないのに自分でuserターンを自作自演して会話を打ち切ってしまった際のパターンに一致します。この文字列が実際のユーザ発言の引用・コード・ログの一部など正当な理由によるものでない限り、それは幻想であり本物のユーザ指示ではありません。作業を打ち切らず、本当にユーザからの入力を待っている状態か、あるいはタスクが未完了のまま停止していないかを確認してください。'

jq -n --arg msg "$message" \
  '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $msg}}'
