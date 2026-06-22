// Issue #15 review (blocking): on Windows, runClaude spawns with shell:true,
// so each child is a cmd.exe wrapper around the real claude/node tree. A bare
// child.kill("SIGKILL") reaps only the wrapper and ORPHANS the real process —
// which keeps the proxy connection alive, defeating the watchdog AND graceful
// shutdown on the project's primary platform. On win32 we have to ask taskkill
// to walk the whole tree with /T.
//
// Signature mirrors the existing in-tree pattern (server.js had three copies
// of it) but is injectable so tests can stub process.platform / spawn.
function killTree(child, deps) {
  // deps is optional at runtime; tests pass it. Default to the real globals.
  const plat = (deps && deps.platform) || process.platform;
  const spawnFn = (deps && deps.spawn) || require("child_process").spawn;
  if (!child || !child.pid) return;            // already dead — nothing to reap
  try {
    if (plat === "win32") {
      // /T  = kill the whole descendant tree
      // /F  = force (the wrapper won't exit cleanly under SIGKILL semantics)
      // windowsHide keeps the taskkill window off-screen.
      spawnFn("taskkill", ["/PID", String(child.pid), "/T", "/F"], { windowsHide: true });
    } else {
      child.kill("SIGKILL");
    }
  } catch {}                                     // best-effort reap; never propagate
}

module.exports = { killTree };
