"""
x_search.py - hermes-agent の x_search_tool を呼び出すスクリプト
Usage: uvx --from hermes-agent python ~/.claude/x_search.py "クエリ文字列"
"""
import json
import sys

from tools.x_search_tool import x_search_tool

s = x_search_tool(sys.argv[1])
print(json.loads(s)["answer"])
