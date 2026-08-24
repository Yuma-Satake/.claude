# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (cuts up to 90% of bash output)

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

## Installation Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
rtk gain              # Should work (not "command not found")
which rtk             # Verify correct binary
```

⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

⚠️ **`find`との複合条件非対応**: rtkフックが自動リライトする`find`は、`-not`・`-exec`などの複合的な条件・アクションを受け付けず失敗する（例: `find . -iname "*.sh" -not -path "*/node_modules/*"`）。この場合は条件を分けて複数回の単純な`find`呼び出しに分割するか、`rtk proxy find <args>`でフィルタリングをバイパスして直接実行する。

## Hook-Based Usage

All other commands are automatically rewritten by the Claude Code hook.
Example: `git status` → `rtk git status` (transparent, 0 tokens overhead)

Refer to CLAUDE.md for full command reference.
