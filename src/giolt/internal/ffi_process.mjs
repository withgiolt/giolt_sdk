import { spawn, spawnSync } from "node:child_process";
import { default as process } from "node:process";
import { Ok, Error as GleamError } from "../../gleam.mjs";

function finish(child, describe) {
  return new Promise((resolve) => {
    child.on("error", (error) => resolve(new GleamError(error.message)));
    child.on("close", (status, signal) => {
      resolve(
        status === 0
          ? new Ok(undefined)
          : new GleamError(describe(status ?? `signal ${signal}`)),
      );
    });
  });
}

export function run(directory, command, args) {
  const child = spawn(command, args.toArray(), {
    cwd: directory,
    stdio: "inherit",
  });

  return finish(child, (status) => `${command} exited with status ${status}`);
}

export function shell(command) {
  const child = spawn(command, { cwd: ".", stdio: "inherit", shell: true });

  return finish(child, (status) => `\`${command}\` exited with status ${status}`);
}

export function forever() {
  return new Promise(() => {});
}

export function available(command, args) {
  const result = spawnSync(command, args.toArray(), { stdio: "ignore" });
  return !result.error && result.status === 0;
}

export function exit(code) {
  process.exit(code);
}
