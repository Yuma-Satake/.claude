#!/bin/bash
# WorktreeRemoveフック: WorktreeCreateでworktrunk(wt)経由に差し替えたworktreeの後始末
set -euo pipefail

input=$(cat)
worktree_path=$(echo "$input" | jq -r '.worktree_path')

mise exec worktrunk -- wt remove "$worktree_path" -y --force >&2
