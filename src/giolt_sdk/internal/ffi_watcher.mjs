// @ts-check
//
// Recursive `fs.watch` over a list of directories, coalesced onto a short
// fixed window so that one save does not fire a burst of rebuilds. The
// coalescing window is an implementation detail, not something projects
// configure, so it lives here rather than as a `dev.debounce` knob.
import { watch as fsWatch, existsSync } from "node:fs";
import { relative, resolve, sep } from "node:path";

const COALESCE_MS = 100;

/**
 * @param {{ toArray: () => string[] }} paths
 * @param {(path: string, kind: string) => void} on_change
 */
export function watch(paths, on_change) {
  const directories = paths.toArray();
  const watchers = [];
  const pending = new Map();
  let timer = null;

  function flush() {
    for (const [path, kind] of pending) {
      on_change(path, kind);
    }
    pending.clear();
    timer = null;
  }

  function schedule(fullPath, eventType) {
    const relativePath = relative(".", fullPath).split(sep).join("/");
    const kind = eventType === "change"
      ? "modified"
      : existsSync(fullPath)
        ? "created"
        : "deleted";

    pending.set(relativePath, kind);
    if (timer) clearTimeout(timer);
    timer = setTimeout(flush, COALESCE_MS);
  }

  for (const directory of directories) {
    try {
      const watcher = fsWatch(
        directory,
        { recursive: true },
        (eventType, filename) => {
          if (!filename) return;
          schedule(resolve(directory, filename.toString()), eventType);
        },
      );
      watchers.push(watcher);
    } catch (error) {
      console.error(
        `[Giolt SDK] Could not watch ${directory}: ${error?.message ?? error}`,
      );
    }
  }

  return () => {
    if (timer) clearTimeout(timer);
    for (const watcher of watchers) watcher.close();
  };
}
