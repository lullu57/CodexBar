#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

branch="${1:-main}"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Refusing to sync with uncommitted changes. Commit or stash them first." >&2
    exit 1
fi

git fetch upstream --prune
git switch "$branch"
git merge --no-edit upstream/main

echo "Synced $branch with upstream/main."
