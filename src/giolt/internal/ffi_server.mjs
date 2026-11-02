import { createServer } from "node:http";
import { copyFile, readFile, rm, stat } from "node:fs/promises";
import { dirname, extname, join, normalize } from "node:path";
import { pathToFileURL } from "node:url";

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".htm": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
  ".wasm": "application/wasm",
};

const LIVE_RELOAD_SNIPPET = `
<script>
  (function () {
    var seen = false;
    var source = new EventSource("/__giolt_dev/events");
    source.onmessage = function () { location.reload(); };
    source.onopen = function () {
      if (seen) { location.reload(); }
      seen = true;
    };
  })();
</script>`;

let reloadVersion = 0;
let liveReloadEnabled = false;
const sseClients = new Set();

export function notify_reload() {
  reloadVersion += 1;
  for (const res of sseClients) {
    res.write("data: reload\n\n");
  }
}

function injectLiveReload(html) {
  if (!liveReloadEnabled) return html;
  return html.includes("</body>")
    ? html.replace("</body>", `${LIVE_RELOAD_SNIPPET}</body>`)
    : html + LIVE_RELOAD_SNIPPET;
}

async function statFile(path) {
  try {
    const info = await stat(path);
    return info.isFile() ? path : null;
  } catch {
    return null;
  }
}

async function serveStatic(staticDir, method, urlPath, res) {
  const cleanPath = normalize(urlPath.split("?")[0]).replace(
    /^(\.\.[/\\])+/,
    "",
  );
  const routePath = cleanPath.replace(/[/\\]+$/, "");
  const isRoot = routePath === "" || routePath === ".";

  let filePath = await statFile(join(staticDir, cleanPath));
  if (!filePath && !isRoot && (method === "GET" || method === "HEAD")) {
    filePath = await statFile(join(staticDir, `${routePath}.html`));
  }
  if (!filePath && isRoot) {
    filePath = await statFile(join(staticDir, "index.html"));
  }
  if (!filePath) return false;

  const contentType = MIME_TYPES[extname(filePath)] ?? "application/octet-stream";
  const body = await readFile(filePath);

  res.writeHead(200, { "content-type": contentType });
  res.end(
    contentType.startsWith("text/html")
      ? injectLiveReload(body.toString("utf-8"))
      : body,
  );
  return true;
}

async function readRequestBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return chunks.length > 0 ? Buffer.concat(chunks) : undefined;
}

let loadedWorker = { version: -1, worker: null };

// Bun ignores the query string when caching ES modules, so each version is
// imported from its own temporary copy next to the bundle.
async function loadWorker(workerPath) {
  if (loadedWorker.version === reloadVersion) return loadedWorker.worker;

  const copy = join(dirname(workerPath), `.giolt-dev-${reloadVersion}.mjs`);
  await copyFile(workerPath, copy);
  try {
    const worker = (await import(pathToFileURL(copy).href)).default;
    loadedWorker = { version: reloadVersion, worker };
    return worker;
  } finally {
    await rm(copy, { force: true });
  }
}

async function serveWorker(workerPath, req, res) {
  if (!workerPath) {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    res.end("Not found");
    return;
  }

  let worker;
  try {
    worker = await loadWorker(workerPath);
  } catch (error) {
    res.writeHead(500, { "content-type": "text/plain; charset=utf-8" });
    res.end(
      `[Giolt] Could not load ${workerPath}.\n` +
        `Run your build first (gleam run -m giolt build).\n\n${error?.stack ?? error}`,
    );
    return;
  }

  if (!worker || typeof worker.fetch !== "function") {
    res.writeHead(500, { "content-type": "text/plain; charset=utf-8" });
    res.end(
      `[Giolt] ${workerPath} has no default export with a fetch function.`,
    );
    return;
  }

  const body =
    req.method === "GET" || req.method === "HEAD"
      ? undefined
      : await readRequestBody(req);

  const request = new Request(`http://localhost${req.url}`, {
    method: req.method,
    headers: req.headers,
    body,
  });

  const response = await worker.fetch(request, {}, {});
  const headers = {};
  response.headers.forEach((value, key) => {
    headers[key] = value;
  });

  const contentType = response.headers.get("content-type") ?? "";
  if (contentType.startsWith("text/html")) {
    const text = await response.text();
    res.writeHead(response.status, headers);
    res.end(injectLiveReload(text));
  } else {
    res.writeHead(response.status, headers);
    res.end(Buffer.from(await response.arrayBuffer()));
  }
}

export function serve(port, staticDir, workerPath, liveReload) {
  liveReloadEnabled = liveReload;

  const server = createServer(async (req, res) => {
    try {
      if (liveReloadEnabled && req.url === "/__giolt_dev/events") {
        res.writeHead(200, {
          "content-type": "text/event-stream",
          "cache-control": "no-cache",
          connection: "keep-alive",
        });
        res.write(":\n\n");
        sseClients.add(res);
        req.on("close", () => sseClients.delete(res));
        return;
      }

      if (
        staticDir &&
        (await serveStatic(staticDir, req.method ?? "GET", req.url ?? "/", res))
      ) {
        return;
      }

      await serveWorker(workerPath, req, res);
    } catch (error) {
      res.writeHead(500, { "content-type": "text/plain; charset=utf-8" });
      res.end(`[Giolt] ${error?.stack ?? error}`);
    }
  });

  server.listen(port, () => {
    console.log(`[Giolt] Dev server listening on http://localhost:${port}`);
  });
}
