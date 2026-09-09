// @ts-check
//
// `dev.run` watches, rebuilds and serves until the process is interrupted —
// there is nothing in Gleam's Promise API to build a promise that simply
// never settles, so it is one line of FFI.
import { spawnSync } from "node:child_process";
// @ts-expect-error
import { Ok, Error as GleamError } from "../../gleam.mjs";

export function forever() {
  return new Promise(() => {});
}

/**
 * Recompile the project's Gleam source to JavaScript, streaming the
 * compiler's output to the terminal.
 */
export function compile() {
  const result = spawnSync("gleam", ["build", "--target", "javascript"], {
    cwd: ".",
    stdio: "inherit",
  });

  if (result.error) {
    return new GleamError(result.error.message);
  }

  if (result.status === 0) {
    return new Ok(undefined);
  }

  return new GleamError(`gleam build exited with status ${result.status}`);
}
