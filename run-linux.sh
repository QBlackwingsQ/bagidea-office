#!/usr/bin/env bash
# BagIdea Office — Linux Tier-1 launcher. Starts the Node daemon (if not already
# up) and launches the native shell (which spawns the Godot office + overlay/orb).
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
SHELL_BIN="$ROOT/shell/target/release/bagidea-office-shell"

if [ ! -x "$SHELL_BIN" ]; then
  echo "Shell not built at $SHELL_BIN — run ./build-linux.sh first." >&2
  exit 1
fi

# Start the daemon if port 8787 is free.
if ! curl -s -m2 http://127.0.0.1:8787/ -o /dev/null; then
  echo "[run-linux] starting daemon…"
  node "$ROOT/daemon/server.js" > /tmp/bagidea-daemon.log 2>&1 &
  sleep 2
else
  echo "[run-linux] daemon already running on :8787"
fi

echo "[run-linux] launching office…"
exec "$SHELL_BIN" "$@"
