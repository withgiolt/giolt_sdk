import { homedir, platform } from "node:os";

export function is_windows() {
  return platform() === "win32";
}

export function home_directory() {
  return homedir();
}
