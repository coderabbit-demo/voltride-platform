#!/usr/bin/env bash
# Stops every VoltRide process by killing listeners on the demo ports.
# Only touches processes whose working directory is under the parent folder
# holding the VoltRide repos, or whose command line matches a VoltRide
# service signature — so a different project that happens to use one of
# these ports is left alone. Safe to run any time; also used by start.sh to
# clean up stale runs.
set -uo pipefail

PARENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORTS=(4001 4002 4003 4004 4005 4006 5173)

# Recognizable command lines of VoltRide services, so stale processes from a
# different checkout of these repos are cleaned up too. Deliberately excludes
# generic commands (vite, node) that other projects might run on these ports.
SIGNATURES='uvicorn main:app --app-dir .*voltride-(pricing|notifications)|go-build/.*/(inventory|orders)$|tsx/dist/loader.mjs src/index.ts'

owned_pids_on_port() {
  local port="$1" pid cwd cmd
  for pid in $(lsof -ti tcp:"$port" 2>/dev/null || true); do
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
    cmd=$(ps -o command= -p "$pid" 2>/dev/null)
    if [[ "$cwd" == "$PARENT_DIR"* ]] || echo "$cmd" | grep -qE "$SIGNATURES"; then
      echo "$pid"
    else
      echo "==> Skipping PID $pid on port $port (not a VoltRide service from this checkout)" >&2
    fi
  done
}

stopped=0
for port in "${PORTS[@]}"; do
  pids=$(owned_pids_on_port "$port")
  if [ -n "$pids" ]; then
    echo "==> Stopping process(es) on port $port: $pids"
    # shellcheck disable=SC2086
    kill $pids 2>/dev/null || true
    stopped=1
  fi
done

if [ "$stopped" = "1" ]; then
  sleep 1
  # Escalate for anything that ignored SIGTERM (e.g. wedged reload workers).
  for port in "${PORTS[@]}"; do
    pids=$(owned_pids_on_port "$port")
    if [ -n "$pids" ]; then
      echo "==> Force-killing stubborn process(es) on port $port: $pids"
      # shellcheck disable=SC2086
      kill -9 $pids 2>/dev/null || true
    fi
  done
  echo "All VoltRide services stopped."
else
  echo "Nothing running on the VoltRide ports."
fi
