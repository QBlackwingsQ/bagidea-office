# Regenerate the Claude Code hook settings so they point at THIS install.
#
# The committed .claude/settings.json files carry the dev machine's ABSOLUTE
# paths (e.g. E:\Projects\...). On a user's machine those paths don't exist, so
# the PreToolUse permission hook (Security Center) and the task hooks (Mission
# Control feed) silently never fire. install.ps1 calls this after the clone and
# update.ps1 calls it after every git pull, so the hooks always resolve to the
# real install directory. Mirrors what build-mac.sh does for macOS/Linux.
param([Parameter(Mandatory = $true)][string]$App)

$ErrorActionPreference = "Stop"

$hookScript = Join-Path $App "daemon\hook.ps1"
$permScript = Join-Path $App "daemon\perm.ps1"

function HookCmd([string]$script, [string]$arg) {
  $c = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$script`""
  if ($arg) { $c += " -Type $arg" }
  return $c
}

$rootCfg = [ordered]@{
  hooks = [ordered]@{
    UserPromptSubmit = @(@{ hooks = @(@{ type = "command"; command = (HookCmd $hookScript "task.started") }) })
    PostToolUse      = @(@{ hooks = @(@{ type = "command"; command = (HookCmd $hookScript "task.progress") }) })
    Stop             = @(@{ hooks = @(@{ type = "command"; command = (HookCmd $hookScript "task.completed") }) })
  }
}

$wsCfg = [ordered]@{
  hooks = [ordered]@{
    PreToolUse = @(@{ hooks = @(@{ type = "command"; command = (HookCmd $permScript $null); timeout = 60 }) })
  }
}

function Write-JsonNoBom([string]$path, $obj) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  $json = $obj | ConvertTo-Json -Depth 8
  [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

Write-JsonNoBom (Join-Path $App ".claude\settings.json") $rootCfg
Write-JsonNoBom (Join-Path $App "workspace\.claude\settings.json") $wsCfg
