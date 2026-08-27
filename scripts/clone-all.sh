#!/usr/bin/env bash
# Clones any missing VoltRide sibling repo next to this checkout.
set -euo pipefail

ORG_URL="https://github.com/coderabbit-demo"
REPOS=(voltride-frontend voltride-catalog voltride-cart voltride-inventory voltride-orders voltride-pricing voltride-notifications)

PARENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for repo in "${REPOS[@]}"; do
  if [ -d "$PARENT_DIR/$repo" ]; then
    echo "==> $repo already present"
  else
    echo "==> Cloning $repo"
    git clone "$ORG_URL/$repo.git" "$PARENT_DIR/$repo"
  fi
done
