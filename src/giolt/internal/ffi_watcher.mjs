import { watch as fsWatch, mkdirSync } from "node:fs";
import { relative, resolve, sep } from "node:path";
import { toList } from "../../gleam.mjs";

const COALESCE_MS = 50;

// One call per burst of changes, never two at once: changes that land mid-run
// become exactly one follow-up call.
export function watch(paths, on_change) {
  const directories = paths.toArray();
  const watchers = [];
  const pending = new Set();
  let timer = null;
  let running = false;
  let stopped = false;

  async function flush() {
    timer = null;
    if (stopped || running || pending.size === 0) return;

    const changed = [...pending].sort();
    pending.clear();
    running = true;
    try {
      await on_change(toList(changed));
    } catch (error) {
      console.error(`[Giolt] Rebuild failed: ${error?.message ?? error}`);
    } finally {
      running = false;
      if (pending.size > 0) schedule();
    }
  }

  function schedule() {
    if (stopped) return;
    if (timer) clearTimeout(timer);
    timer = setTimeout(flush, COALESCE_MS);
  }

  function record(fullPath) {
    pending.add(relative(".", fullPath).split(sep).join("/"));
    schedule();
  }

  for (const directory of directories) {
    try {
      mkdirSync(directory, { recursive: true });
      const watcher = fsWatch(
        directory,
        { recursive: true },
        (eventType, filename) => {
          if (!filename) return;
          record(resolve(directory, filename.toString()));
        },
      );
      watchers.push(watcher);
    } catch (error) {
      console.error(
        `[Giolt] Could not watch ${directory}: ${error?.message ?? error}`,
      );
    }
  }

  return () => {
    stopped = true;
    if (timer) clearTimeout(timer);
    for (const watcher of watchers) watcher.close();
  };
}
