// @ts-check
//
// Downloading and running the esbuild binary.
//
// The download runs in a synchronous child process so that `bundle.run` stays
// synchronous: fetching and un-tarring are async, but a user's build.gleam
// reads much better as a plain `Result` pipeline than as a promise chain.
import { spawnSync } from "node:child_process";
import { default as process } from "node:process";
// @ts-expect-error
import { Ok, Error as GleamError } from "../../gleam.mjs";

/**
 * Run the esbuild binary, streaming its output to the terminal.
 *
 * @param {string} command
 * @param {{ toArray: () => string[] }} args
 */
export function exec(command, args) {
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

  return new GleamError(`esbuild exited with status ${result.status}`);
}

/**
 * Download the esbuild binary for this platform and make it executable.
 *
 * @param {string} url tarball to fetch
 * @param {string} directory to write the binary into
 * @param {string} exe_name file name to give the binary
 */
export function install(url, directory, exe_name) {
  const tar = new URL("./esgleam/streaming_tar.mjs", import.meta.url).href;

  const script = `
import { mkdir, writeFile, chmod } from "node:fs/promises";
import { Buffer } from "node:buffer";
import { entries } from ${JSON.stringify(tar)};

const url = ${JSON.stringify(url)};
const directory = ${JSON.stringify(directory)};
const exe = ${JSON.stringify(exe_name)};

const response = await fetch(url);
if (!response.ok) {
  console.error("Failed to download esbuild: HTTP " + response.status);
  process.exit(1);
}

const stream = response.body.pipeThrough(new DecompressionStream("gzip"));
await mkdir(directory, { recursive: true });

let installed = false;
for await (const entry of entries(stream)) {
  if (/(^|\\/)esbuild(\\.exe)?$/.test(entry.name)) {
    const path = directory + "/" + exe;
    await writeFile(path, Buffer.from(await entry.arrayBuffer()));
    await chmod(path, 0o755);
    installed = true;
    break;
  }
}

if (!installed) {
  console.error("The esbuild tarball did not contain an esbuild binary");
  process.exit(1);
}
`;

  const result = spawnSync(
    process.execPath,
    ["--input-type=module", "-e", script],
    { cwd: ".", stdio: "inherit" },
  );

  if (result.error) {
    return new GleamError(result.error.message);
  }

  if (result.status === 0) {
    return new Ok(undefined);
  }

  return new GleamError(`Installing esbuild exited with status ${result.status}`);
}
