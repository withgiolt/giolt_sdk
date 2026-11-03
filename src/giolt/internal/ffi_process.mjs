import { spawn, spawnSync } from "node:child_process";
import { default as process } from "node:process";
import { createInterface } from "node:readline";
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

export function is_interactive() {
  return Boolean(process.stdin.isTTY);
}

// Ctrl-C or Ctrl-D resolves with an empty line, so a pending confirmation
// reads as declined instead of leaving the prompt hanging.
export function read_line(prompt) {
  const prompter = createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    prompter.on("SIGINT", () => prompter.close());
    prompter.on("close", () => resolve(""));
    prompter.question(prompt, (answer) => {
      resolve(answer);
      prompter.close();
    });
  });
}

export function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

// Best effort: the caller has already printed the URL, so a machine with no
// browser (SSH, CI, a container) only loses the convenience. cmd treats & and
// friends as operators, so they are escaped for `start`.
export function open_url(url) {
  const [command, args] =
    process.platform === "darwin"
      ? ["open", [url]]
      : process.platform === "win32"
        ? ["cmd", ["/c", "start", "", url.replace(/[&^|<>]/g, "^$&")]]
        : ["xdg-open", [url]];

  try {
    const child = spawn(command, args, { stdio: "ignore", detached: true });
    child.on("error", () => {});
    child.unref();
  } catch {}
}
