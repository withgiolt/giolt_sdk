import { spawnSync } from "node:child_process";
import { Ok, Error as GleamError } from "../../gleam.mjs";

export function forever() {
  return new Promise(() => {});
}

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
