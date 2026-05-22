#!/bin/bash
# ~/.claude の設定を ~/.copilot に同期する
set -euo pipefail

RULES_DIR="$HOME/.claude/rules"
OUTPUT_DIR="$HOME/.copilot/instructions"

if [ ! -d "$RULES_DIR" ]; then
  echo "Error: $RULES_DIR not found" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 既存の自動生成ファイルをクリア
rm -f "$OUTPUT_DIR"/*.instructions.md

count=0
for file in "$RULES_DIR"/*.md; do
  [ -f "$file" ] || continue
  name="$(basename "$file" .md)"
  cp "$file" "$OUTPUT_DIR/${name}.instructions.md"
  count=$((count + 1))
done

echo "Synced $count rules -> $OUTPUT_DIR/"

# シンボリックリンクの作成（既存の場合はスキップ）
for target in skills agents; do
  link="$HOME/.copilot/$target"
  source="$HOME/.claude/$target"
  if [ -L "$link" ]; then
    echo "Skip: $link (already exists)"
  else
    ln -s "$source" "$link"
    echo "Created: $link -> $source"
  fi
done
