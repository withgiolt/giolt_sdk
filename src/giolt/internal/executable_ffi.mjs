import { Error, Ok } from "../../gleam.mjs";
import * as path from "node:path";
import * as fs from "node:fs";
import { spawnSync } from "node:child_process";

export function runExecutable(executable, cwd, args) {
  try {
    const result = spawnSync(executable, args, {
      cwd,
      shell: false,
      stdio: "ignore",
    });

    if (result.error || result.status === null) {
      return Error(null);
    }

    return new Ok(result.status);
  } catch {
    return new Error(null);
  }
}

export function findExecutable(executableName) {
  const paths = process.env.PATH.split(path.delimiter);
  for (const dir of paths) {
    const fullPath = path.join(dir, executableName);
    if (fs.existsSync(fullPath)) {
      return new Ok(fullPath);
    }
  }
  return new Error(null);
}
