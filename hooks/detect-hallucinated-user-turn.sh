#!/bin/bash
# Stopフック: 直前の応答に "user[" が含まれる場合、偽のuserターンを自作した可能性があるとして警告をコンテキストへ注入する
# last_assistant_messageにはアシスタント自身の発言だけが入るため、本物のユーザ発言は判定対象にならない
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
