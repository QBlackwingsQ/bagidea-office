#!/usr/bin/env bash
# BagIdea Office — Linux updater (called by `bagidea update`).
#   git pull → rebuild the shell only if shell/ changed → relaunch.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source "$HOME/.cargo/env" 2>/dev/null || true

echo "  ===== BagIdea Office - UPDATE (Linux) ====="

# 1) Stop the running suite (shell + daemon + Godot).
echo "  [1/4] Stopping the app..."
pkill -f "shell/target/release/bagidea-office-shell" 2>/dev/null || true
pkill -f "daemon/server.js" 2>/dev/null || true
pkill -f "godot/bin-linux/godot" 2>/dev/null || true
pkill -f "godot .*--wallpaper" 2>/dev/null || true
sleep 1

# 2) Pull latest.
#    settings.json is tracked but rewritten per-machine (hook paths); discard
#    those local edits so --ff-only won't abort, then re-wire after the pull.
echo "  [2/4] Pulling latest code..."
git checkout -- .claude/settings.json workspace/.claude/settings.json 2>/dev/null || true
before="$(git rev-parse HEAD)"
git pull --ff-only || true
after="$(git rev-parse HEAD)"
[ "$before" = "$after" ] && echo "  - Already up to date"

# Re-point the Claude hooks at this install (the pull restored the dev paths).
bash "$ROOT/installer/wire-hooks.sh" "$ROOT"

# 3) Rebuild the shell only if its source changed.
if [ "$before" != "$after" ] && ! git diff --quiet "$before" "$after" -- shell/; then
  echo "  [3/4] Rebuilding the shell (shell/ changed)..."
  ( cd "$ROOT/shell" && cargo build --release )
else
  echo "  [3/4] shell unchanged — skipping the build"
fi

# 4) Relaunch.
echo "  [4/4] Relaunching..."
SHELL_BIN="$ROOT/shell/target/release/bagidea-office-shell"
if [ -x "$SHELL_BIN" ]; then
  nohup "$SHELL_BIN" > /tmp/bagidea-shell.log 2>&1 &
  echo "  Updated → $(git rev-parse --short HEAD)"
else
  echo "  ! shell binary not found — run ./build-linux.sh"
fi
