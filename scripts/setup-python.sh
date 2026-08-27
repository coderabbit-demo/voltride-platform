#!/usr/bin/env bash
# Creates a virtualenv and installs dependencies for each Python service repo.
set -euo pipefail

PARENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for repo in voltride-pricing voltride-notifications; do
  dir="$PARENT_DIR/$repo"
  echo "==> Setting up Python env for $repo"
  if command -v uv >/dev/null 2>&1; then
    (cd "$dir" && uv venv --allow-existing .venv && uv pip install -p .venv/bin/python -r requirements.txt)
  else
    if [ ! -d "$dir/.venv" ]; then
      python3 -m venv "$dir/.venv"
    fi
    "$dir/.venv/bin/pip" install --quiet --upgrade pip
    "$dir/.venv/bin/pip" install --quiet -r "$dir/requirements.txt"
  fi
done

echo "Python services ready."
