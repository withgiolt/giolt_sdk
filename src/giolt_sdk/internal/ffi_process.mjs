import { spawnSync } from "node:child_process";
import { default as process } from "node:process";
import { Ok, Error as GleamError } from "../../gleam.mjs";

export function run(command, args) {
  const result = spawnSync(command, args.toArray(), {
    cwd: ".",
    stdio: "inherit",
  });

  if (result.error) {
    return new GleamError(result.error.message);
  }

  if (result.status === 0) {
    return new Ok(undefined);
  }

  return new GleamError(`${command} exited with status ${result.status}`);
}

export function exit(code) {
  process.exit(code);
}
