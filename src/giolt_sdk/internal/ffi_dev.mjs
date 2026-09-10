import { spawnSync } from "node:child_process";
import { readFileSync, rmSync, writeFileSync } from "node:fs";
import { default as process } from "node:process";

const CHILD_FLAG = "--giolt-dev-child";
const HANDOFF = "build/.giolt-dev-change";
const RESTART_STATUS = 75;

export function forever() {
  return new Promise(() => {});
}

export function is_child() {
  return process.argv.includes(CHILD_FLAG);
}

export function pending_change() {
  try {
    const [kind, ...rest] = readFileSync(HANDOFF, "utf-8").split("\n");
    rmSync(HANDOFF, { force: true });
    return [rest.join("\n"), kind];
  } catch {
    return ["", ""];
  }
}

export function request_restart(path, kind) {
  try {
    writeFileSync(HANDOFF, `${kind}\n${path}`);
  } catch {
    // The next build just starts from a blank change.
  }
  process.exit(RESTART_STATUS);
}

export function supervise() {
  for (;;) {
    spawnSync("gleam", ["build", "--target", "javascript"], {
      cwd: ".",
      stdio: "inherit",
    });

    const child = spawnSync(
      process.argv[0],
      [...process.argv.slice(1), CHILD_FLAG],
      { cwd: ".", stdio: "inherit" },
    );

    if (child.status !== RESTART_STATUS) {
      process.exit(child.status ?? 0);
    }
  }
}
