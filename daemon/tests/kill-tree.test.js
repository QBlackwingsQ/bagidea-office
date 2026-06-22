// Issue #15 review (blocking): on Windows, runClaude spawns with shell:true,
// so each child is a cmd.exe wrapper around the real claude/node tree. A bare
// child.kill("SIGKILL") reaps only the wrapper and orphans the real process —
// which keeps the proxy connection alive, defeating the watchdog AND graceful
// shutdown on the project's primary platform. killTree must use taskkill /T
// /F on win32 to walk the whole tree.
const { test } = require("node:test");
const assert = require("node:assert");
const { killTree } = require("../kill-tree");

test("killTree on non-win32 sends SIGKILL to the child directly", () => {
  let killed = null;
  const fakeChild = { pid: 12345, kill: (sig) => { killed = sig; } };
  let spawnCalls = [];
  killTree(fakeChild, {
    platform: "darwin",
    spawn: (...a) => { spawnCalls.push(a); },
  });
  assert.strictEqual(killed, "SIGKILL");
  assert.strictEqual(spawnCalls.length, 0, "must not spawn taskkill off-windows");
});

test("killTree on win32 spawns taskkill /PID /T /F (kills the whole tree)", () => {
  let killed = null;
  const fakeChild = { pid: 999, kill: (sig) => { killed = sig; } };
  let spawnCalls = [];
  killTree(fakeChild, {
    platform: "win32",
    spawn: (...a) => { spawnCalls.push(a); return { on() {}, unref() {} }; },
  });
  assert.strictEqual(killed, null, "must NOT call child.kill on win32 — that orphans");
  assert.strictEqual(spawnCalls.length, 1);
  const [exe, args] = spawnCalls[0];
  assert.strictEqual(exe, "taskkill");
  assert.ok(args.includes("/PID"), "must target the child PID");
  assert.ok(args.includes("999"), "must pass the actual pid");
  assert.ok(args.includes("/T"), "/T walks the whole process tree (the whole point)");
  assert.ok(args.includes("/F"), "/F forces kill");
});

test("killTree is a no-op on a child with no pid (already dead)", () => {
  let killed = null;
  const fakeChild = { kill: (sig) => { killed = sig; } };
  let spawnCalls = [];
  killTree(fakeChild, {
    platform: "darwin",
    spawn: (...a) => { spawnCalls.push(a); },
  });
  assert.strictEqual(killed, null);
  assert.strictEqual(spawnCalls.length, 0);
});

test("killTree swallows errors from kill/spawn (best-effort reap)", () => {
  // A throw inside kill must not propagate — callers wrap nothing.
  const fakeChild = { pid: 1, kill: () => { throw new Error("ESRCH"); } };
  assert.doesNotThrow(() =>
    killTree(fakeChild, { platform: "darwin", spawn: () => {} })
  );
  // And a throwing spawn on win32 likewise.
  const fakeChild2 = { pid: 1, kill: () => {} };
  assert.doesNotThrow(() =>
    killTree(fakeChild2, { platform: "win32", spawn: () => { throw new Error("no taskkill"); } })
  );
});
