import { watch as fsWatch, existsSync } from "node:fs";
import { relative, resolve, sep } from "node:path";

const COALESCE_MS = 100;

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
