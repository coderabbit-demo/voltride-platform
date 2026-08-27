#!/usr/bin/env bash
# One-shot launcher for the whole VoltRide system: clones missing sibling
# repos, installs any missing prerequisites, then starts every service.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_DIR="$(cd "$ROOT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# --- Sibling repos ------------------------------------------------------------
bash scripts/clone-all.sh

# --- Go ------------------------------------------------------------------------
if ! command -v go >/dev/null 2>&1; then
  echo "==> Go is not installed."
  if command -v brew >/dev/null 2>&1; then
    echo "==> Installing Go via Homebrew..."
    brew install go
  else
    echo "ERROR: Go is required (voltride-inventory + voltride-orders) and Homebrew is not available."
    echo "Install Go from https://go.dev/dl/ and re-run this script."
    exit 1
  fi
fi
echo "==> $(go version)"

# --- Python ---------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required (voltride-pricing + voltride-notifications)."
  exit 1
fi
PY_OK=$(python3 -c 'import sys; print(1 if sys.version_info >= (3, 9) else 0)')
if [ "$PY_OK" != "1" ]; then
  echo "ERROR: Python >= 3.9 is required, found $(python3 --version)."
  exit 1
fi
if [ ! -x "$PARENT_DIR/voltride-pricing/.venv/bin/uvicorn" ] || [ ! -x "$PARENT_DIR/voltride-notifications/.venv/bin/uvicorn" ]; then
  bash scripts/setup-python.sh
fi

# --- Node -----------------------------------------------------------------------
if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: Node.js >= 20 is required. Install it from https://nodejs.org or via 'brew install node'."
  exit 1
fi
for dir in "$ROOT_DIR" "$PARENT_DIR/voltride-catalog" "$PARENT_DIR/voltride-cart" "$PARENT_DIR/voltride-frontend"; do
  if [ ! -d "$dir/node_modules" ]; then
    echo "==> npm install in $(basename "$dir")"
    npm --prefix "$dir" install
  fi
done

# --- Launch ----------------------------------------------------------------------
# Clean up any stale processes from a previous run still holding our ports.
bash scripts/stop.sh

# Ctrl+C kills concurrently, but grandchildren (uvicorn --reload workers,
# go run binaries) can survive it — sweep the ports again on exit.
trap 'echo; bash scripts/stop.sh' EXIT

echo "==> Starting all services (frontend on http://localhost:5173)"
npm run dev
