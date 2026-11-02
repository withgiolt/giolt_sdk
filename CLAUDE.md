# giolt_sdk

Giolt's tooling for building, deploying and locally developing Gleam apps on
the Giolt platform: today the `giolt_sdk` library (retired after 3.0.0),
becoming the `giolt` CLI (withgiolt/issues#1). `target = "javascript"` only —
there is no Erlang support yet, it's stubbed throughout.

## Settings

- Tracker: GitHub issues in withgiolt/issues
- Tests: when a cheap test seam exists
- Commits: only when the maintainer says
- Pushes and pull requests: ask before pushing
- Closing issues: allowed
- Subagents: only when the maintainer asks

## Working here

GitHub issues hold intent, usually one issue per plan with a heading and checklist per feature; the code and the maintainer decide what is true.
Check off items the code already does. Ask before adding an entry for a request that isn't listed. Problems you notice outside the task get an entry too, asked the same way, rather than a fix in passing, so every diff stays reviewable. Order is a suggestion: if a request seems to depend on unfinished work, say so in one line and continue.

Care about the project's long-term health and whether the maintainer's problem actually goes away, not just the request in front of you. Suggest what they haven't asked for but will need. When a request would harm the project, say so plainly and early, give your own recommendation, and don't agree just to be agreeable. Hold your position if the pushback brings no new information. Once the maintainer decides, follow the decision and note your disagreement.

Ask the maintainer about product direction, scope, anything irreversible or outward-facing, such as pushing, deleting data, adding a dependency or closing issues, unless the settings above allow it, and any choice where different readings of the request would lead to materially different work. Ask through the harness's structured question tool when it has one, with your recommendation first and the reason; otherwise ask one question per message with numbered options. Make every other call yourself and name it in the report. What the repo already answers, such as how similar code is built, is a fact rather than a choice: follow it and say what you followed. Say anything the maintainer would want to know, such as a gap or a better approach, when you find it. Finishing a change is not a question: report it and stop, and leave committing and pushing to the settings or the maintainer's word.

The maintainer can override any setting for a single request, for example "go autonomous, commit and push everything" or "ask before each commit"; the override lasts until that request is done.

When a task finishes, say once what changed, what you skipped or couldn't check, and any risk. Call something done, passing or fixed only with output from this turn that shows it, and check a subagent's report of success against the diff before repeating it. After that, follow the maintainer's current topic: raise finished work again only when the current topic affects it or they ask, and keep options about it out of questions on other subjects.

In chat with the maintainer, be direct, honest and brief: lead with the answer or the result, cut filler, and drop grammar where the meaning survives without it. Brevity never cuts what they need to know, such as a failure, a risk, a skipped step, a gap you found or your disagreement. When something needs explaining, such as a design tradeoff, a root cause or why you disagree, take the space it needs.

When the m4 skills are installed, route requests through them even when phrased casually, because they carry the steps that keep work consistent: a bug or error goes through m4:fix, building or changing behavior through m4:do, cleaning up a diff or working through review findings through m4:tidy, hunting bugs in a diff through Claude Code's `/code-review`, planning through m4:shape, explaining code through m4:explore, and a repeated correction through m4:harden. One-line edits are made directly. Before writing prose that lands somewhere, such as docs, a README, comments, commit or pull request text, tracker entries, or a message to another person, run m4:unslop on the draft. In chat replies, follow its rules without invoking it, except that chat may drop grammar for brevity, which rule 33 forbids in prose that lands somewhere.

Work inline; spawn subagents only as the settings allow, except the plan review in m4:shape, because they spend tokens the maintainer wants to spend deliberately.

## Code

Aim for code that is obviously correct to a newcomer, since the next reader won't have this session's context.
Rank choices by correctness, then how easily the code reads and tests, then size; a one-liner that needs decoding is not simple.

Build only what was asked: features, options and configuration nobody requested wait until someone needs them. New code of a kind listed under Golden files takes that file's shape: its file layout, naming, error handling, state, UI and tests, and its helpers rather than new ones. Other new code takes the shape of the closest code that does something similar. When neither fits, ask before inventing a new shape. Before writing new code, look for it in this repo, then the standard library and platform, then installed dependencies.

Before editing, find every place the change must reach (callers, tests, fixtures, config, exports, and paths that must stay in step, such as a mock or sandbox mode beside production, each platform, and both sides of a feature flag) and finish all of them. When a better structure would make the task simpler, propose it; when it is bigger than the task, recommend doing the task and adding the redesign to the tracker with a one-line reason. Keep validation of untrusted input, error handling that prevents data loss, security and accessibility, including in code you move.

Comments explain why something non-obvious is true, such as a known limit and when it will matter. When code needs a comment to say what it does, rename or restructure it instead. Leave existing comments in code you don't change. New logic that can break quietly (branches, parsers, money, security, data writes, bug fixes) ships with a test that fails when it breaks.

Leave nothing behind but the change: no summary files, commented-out code, debug logs or session scripts. When a test fails, fix the code, or ask if the test's expectation looks wrong. Update the README in the same commit when user-visible behavior changes.

## Golden files

One file per kind of code that shows how this repo does it. Copy its shape when adding another of that kind, so the same job is always done the same way. When a new kind lands or a golden file moves, update its row in the same commit.

| To add | Copy |
|---|---|
| a public builder module | src/giolt_sdk/bundle.gleam |
| a pure internal function with its test | src/giolt_sdk/internal/esbuild.gleam, test/esbuild_test.gleam |
| an FFI file | src/giolt_sdk/internal/ffi_esbuild.mjs |

## Enforced rules

| Rule | Enforced by |
|---|---|
| Formatting | `gleam format --check` in .github/workflows/test.yml |
| Tests pass | `gleam test` in .github/workflows/test.yml |

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
| `internal/esbuild.gleam` | The esbuild argument list (`Plan -> List(String)`) — no process spawned |
| `internal/esbuild_bin.gleam` | Installing/running the actual esbuild binary (effectful) |
| `internal/shim.gleam` | The worker entry template esbuild bundles |
| `internal/templates.gleam` | The three scaffolded file bodies |
| `internal/project.gleam` | Reading `name` out of the consumer's `gleam.toml` |
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
- **`bundle` never runs `gleam build`.** `bundle.entry` takes a plain path to
  a JS file (usually compiled Gleam output, but not necessarily) — `bundle.run`
  only ever reads whatever that path points at, it does not compile the
  user's Gleam. Don't quietly make `bundle.run` shell out to `gleam build` —
  that was a deliberate call. `dev` is the one module that compiles, and it
  does so in its supervisor (see below), not in `bundle`.

- **`dev.run` supervises and restarts; there is no `dev.compile`.** The first
  process is a supervisor: it runs `gleam build --target javascript`, then
  spawns itself again with a `--giolt-dev-child` argv flag. The child runs
  `prebuild`, the `build` closure, the watcher and the server. On a watched
  change the child writes the change to `build/.giolt-dev-change` and exits
  with status 75; the supervisor recompiles and spawns a fresh child, which
  reads that file back so the closure still receives a real `Change`.
  This exists because a long-lived process freezes its imported modules at
  startup: a `build` closure that generates output **in-process** (lustre_ssg,
  codegen, templating) would keep rendering from the code loaded when the
  process began, even though `gleam build` had just written fresh JS to disk.
  Subprocess steps (esbuild via `esbuild_bin`) never had this problem, which
  is why it presented as "static pages stale, worker routes fine". Don't
  reintroduce an in-process rebuild loop, and don't add a public `compile`
  back — the supervisor compiling before every child is what makes the
  closure correct.

- **Nothing in `dev` may read `process.env`.** Under Deno (a supported way to
  run this — `gleam run --runtime deno`) `process.env` requires `--allow-env`,
  while `process.argv` needs no permission at all. That is why the child
  marker is an argv flag and the change handoff is a file. Verified against a
  real `deno run`, not assumed.
- **`bundle.entry` is a path, not a module name.** It used to take a Gleam
  module name and resolve it under `./build/dev/javascript/...` itself; it no
  longer does that resolution. The scaffolded templates bake the default
  compiled path in as a literal string
  (`./build/dev/javascript/{name}/{name}.mjs`) at scaffold time. This is what
  lets `dev.gleam`'s `build` closure point `bundle.entry` at any JS file, not
  just the project's own default Gleam entry module — including a file the
  user already ran their own esbuild over.
- **`bundle.run` only checks that the entry file exists, not its contents.**
  There used to be a regex-based static check (`internal/entry.gleam`, since
  deleted) that scanned the compiled JS for a handler export and its arity.
  It only ever matched Gleam's own `export function ...` codegen —
  esbuild's own bundling (which the SDK explicitly allows: "run your own
  esbuild, we bundle it again") commonly hoists exports into a trailing
  `export { x as handle };`, arrow functions, minified/renamed bindings,
  etc., all of which a regex can't reliably keep up with. The check for a
  working `handle` export (renamed from `handler`, no
  fallback) now happens where it can't be fooled by the entry file's
  shape: at request time, inside the generated worker shim
  (`internal/shim.gleam`) — `typeof app.handle !== "function"` returns a
  clear 500 instead of crashing. Don't reintroduce static export-shape
  parsing in `bundle.run`.
- **The bundle has almost no configuration surface.** No env-file loading,
  no aliases. It is always minified, tree-shaken ESM, node platform by
  default. The one escape hatch is `bundle.additional_args`, a raw
  `List(String)` of esbuild flags appended after the fixed ones
  (`internal/esbuild.gleam`'s `flags`) — later flags win, so it's what lets a
  consumer override a fixed default (`--minify=false`) or mark something
  `--external` instead of having it bundled again. Don't turn this into
  named/typed options (a `minify: Bool` field, a `platform` enum, etc.) —
  it's deliberately one plain pass-through list, not a re-implementation of
  esbuild's own flag surface.
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
- **Erlang is stubbed, not supported.** `esbuild_bin`'s `@target(erlang)`
  branches return a plain "not supported" error (Gleam's own conditional
  compilation, not a runtime check on the consumer's project). Leave these as
  stubs unless explicitly asked to implement real Erlang support.

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
