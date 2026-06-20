#!/usr/bin/env bash
# Regenerate the Claude Code hook settings so they point at THIS install.
#
# The committed .claude/settings.json carry the dev machine's absolute paths, so
# the permission hook (Security Center) and task hooks (Mission Control feed)
# would silently never fire elsewhere. The build scripts call this after a clone
# and update-linux.sh calls it after every git pull. macOS/Linux use the Node
# hooks (hook.js / perm.js); see wire-hooks.ps1 for the Windows (.ps1) variant.
set -e
ROOT="${1:?usage: wire-hooks.sh <app-root>}"

mkdir -p "$ROOT/.claude" "$ROOT/workspace/.claude"

cat > "$ROOT/.claude/settings.json" <<JSON
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "node \"$ROOT/daemon/hook.js\" task.started" } ] }
    ],
    "PostToolUse": [
      { "hooks": [ { "type": "command", "command": "node \"$ROOT/daemon/hook.js\" task.progress" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "node \"$ROOT/daemon/hook.js\" task.completed" } ] }
    ]
  }
}
JSON

cat > "$ROOT/workspace/.claude/settings.json" <<JSON
{
  "hooks": {
    "PreToolUse": [
      { "hooks": [ { "type": "command", "command": "node \"$ROOT/daemon/perm.js\"", "timeout": 60 } ] }
    ]
  }
}
JSON
