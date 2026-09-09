# giolt_sdk

The Giolt SDK: a Gleam **library** (no CLI) for building, deploying and
locally developing Gleam apps for the Giolt platform. `target = "javascript"`
only — there is no Erlang support yet, it's stubbed throughout.

## Shape of the thing

Consumers don't run a CLI. They call `gleam run -m giolt_sdk/init`
(`src/giolt_sdk/init.gleam`) once, which scaffolds three files into their own
`src/` from templates in `src/giolt_sdk/internal/templates.gleam`:

- `build.gleam` → calls `giolt_sdk/bundle`
- `deploy.gleam` → calls `giolt_sdk/deploy`
- `{project}_dev.gleam` → calls `giolt_sdk/dev`

Those three public modules (`src/giolt_sdk/bundle.gleam`,
`src/giolt_sdk/deploy.gleam`, `src/giolt_sdk/dev.gleam`) are the entire public
API. Each is an opaque, phantom-typed builder in the `lustre_ssg` style:

```gleam
pub opaque type Config(has_entry) { Config(...) }
pub fn new() -> Config(NoEntry)
pub fn entry(Config(a), String) -> Config(HasEntry)   // flips the phantom
pub fn run(Config(HasEntry)) -> Result(Output, Error)  // only typechecks once set
```

A required field missing is a compile error at the call site, not a runtime
one — `bundle.new() |> bundle.run` does not typecheck. When adding a new
required setter, follow this pattern rather than adding a runtime check.

## Where the logic actually lives

Every public module is a thin effectful shell. Decisions are pure functions in
`src/giolt_sdk/internal/`, each with a matching `test/*_test.gleam`:

| Module | Owns |
| --- | --- |
| `internal/entry.gleam` | Entry name normalisation, compiled-path resolution, scanning compiled JS for exports, validating a `handler` export |
| `internal/esbuild.gleam` | The esbuild argument list (`Plan -> List(String)`) — no process spawned |
| `internal/esbuild_bin.gleam` | Installing/running the actual esbuild binary (effectful) |
| `internal/shim.gleam` | The worker entry template esbuild bundles |
| `internal/templates.gleam` | The three scaffolded file bodies |
| `internal/project.gleam` | Reading `name`/`target` out of the consumer's `gleam.toml` |
| `internal/watcher.gleam` + `ffi_watcher.mjs` | Recursive file watching |
| `internal/server.gleam` + `ffi_server.mjs` | The dev HTTP server (static dir, worker hot-reload, live-reload SSE) |
| `internal/esgleam/` | Vendored (Apache-2.0, forked) esbuild platform-detection + tarball extraction only — do not add unrelated code here |

When changing behavior, change the pure `internal/` function and its test
first; the public module's job is just to read/write the filesystem and call
that function.

## Non-negotiables from how this got built

- **No CLI, ever.** Nothing is invoked by `gleam run -m giolt_sdk` (top
  level) or by any `argv`/`clip`-style flag parsing. The only module-name
  invocation is `giolt_sdk/init`.
- **The SDK never runs `gleam build`.** `bundle.run` only ever reads
  `./build/dev/javascript/...` — it does not compile the user's Gleam. The
  dev loop recompiles explicitly via `dev.compile()`, which the user calls
  themselves as the first line of their `build` closure. Don't quietly make
  `bundle.run` shell out to `gleam build` — that was a deliberate call.
- **The bundle has no configuration surface.** No env-file loading, no
  aliases, no minify/sourcemap/platform flags on `bundle.Config`. It is
  always minified, tree-shaken ESM, node platform. If someone wants
  something different, they run their own esbuild before calling `bundle.run`
  — the SDK bundles it again to adapt it to the platform.
- **No env-var handling in the SDK.** There is no `.env` loading, no
  `PUBLIC_`/`PRIVATE_` inlining. `deploy.token_from_env` is the one place the
  SDK reads a real environment variable (via `internal/ffi_env.mjs`, a bare
  `process.env[name]` lookup) — that's authentication, not app config, and is
  not up for expansion into general env handling.
- **No glob/ignore matching in `dev`.** `dev.watch` takes directories; there
  is no `dev.ignore`. Don't reintroduce pattern-based filtering.
- **Comments are minimal, deliberately.** Almost no doc comments (`///`,
  `////`) anywhere in `src/`. Keep new code the same way — let names and
  types carry the meaning. The few comments that do exist are load-bearing
  (a `TODO` marking real unfinished work, or the one-line note in
  `internal/project.gleam` explaining why the regex hand-rolls a multi-line
  anchor). Don't add narrative "why" comments or usage-example doc blocks
  back in without being asked.
- **`giolt_sdk/deploy` doesn't talk to the Giolt API yet.** `deploy.run`
  validates everything it can locally (project id, artifact present, token
  resolved) and then returns `Error(NotImplemented(...))` at the one seam
  marked `// TODO` in `deploy.gleam`'s `submit` function. That's intentional,
  not a bug.
- **Erlang is stubbed, not supported.** `entry.validate` on the `Erlang`
  target returns `Error(CheckUnsupported("erlang"))`; `esbuild_bin`'s
  `@target(erlang)` branches return a plain "not supported" error. Leave
  these as stubs unless explicitly asked to implement real Erlang support.

## Vendored code

`src/giolt_sdk/internal/esgleam/` is a trimmed fork of
[Enderchief/esgleam](https://github.com/Enderchief/esgleam) (Apache-2.0, see
`NOTICE`/`LICENSE` in that directory) — just enough left for esbuild platform
detection (`esgleam/mod/platform.gleam`) and tarball extraction
(`streaming_tar.mjs`). Keep the `// Modified from Enderchief/esgleam...`
attribution line at the top of files taken from there. The rest of the
original esgleam (its own CLI/bundler wrapper) was deleted — `bundle.gleam`
builds and runs the esbuild invocation itself now
(`internal/esbuild.gleam` + `internal/esbuild_bin.gleam`).

## FFI conventions

All `.mjs` files live beside the Gleam module that declares their
`@external`. To import the generated prelude (`Ok`/`Error`) from a file at
`src/giolt_sdk/internal/X.mjs`, use `"../../gleam.mjs"` — Gleam compiles this
package's modules to `build/dev/javascript/giolt_sdk/giolt_sdk/...`, so a
file two segments below `src/` needs two `../` to reach the package-root
`gleam.mjs`. A file one segment deeper (like `internal/esgleam/X.mjs`) needs
three. If you add a new nested FFI file, count the depth — this was verified
against a real `gleam build --target javascript` output, not assumed.

## Testing

`gleam test --target javascript`, or `just test`. Tests live in `test/` and
target the pure `internal/` functions directly — see the table above for
which module owns which decision. There's no live-fixture/integration test
today; if you need one, build it against a scratch Gleam project the way the
history of this file's authoring did (a project with an empty
`[dependencies]` table needs no hex fetch and is enough to check compiled
output shape).

CI (`.github/workflows/test.yml`) runs `gleam format --check` and
`gleam test` on every push and PR — including feature branches, not just
`main`. Keep it that way.
