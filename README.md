# giolt

Build, run and deploy Gleam apps on [Giolt](https://giolt.com).

Add it as a dev dependency and run it with Bun:

```sh
gleam add --dev giolt
gleam run --runtime bun -m giolt build
```

Your entry module exports one function named `handle`:

```gleam
// JavaScript target
pub fn handle(req: Request(conversation.RequestBody)) -> Response(conversation.ResponseBody)

// Erlang target (GlowVM)
pub fn handle(req: wisp.Request) -> wisp.Response
```

`giolt build` checks this signature against `gleam export package-interface`
and fails with the expected and found types when it does not match.

## Commands

| Command | Does |
| --- | --- |
| `giolt build` | Checks `handle`, compiles and bundles into `outdir` |
| `giolt dev` | Builds, watches `watch`, serves on `port` and reloads on change (JavaScript target) |
| `giolt deploy [--preview] [--artifact DIR]` | Builds, then uploads `outdir` to Giolt (JavaScript target). With `artifact`, uploads that directory instead |

`deploy` reads the token from `GIOLT_TOKEN`. `GIOLT_API_URL` overrides `api_url`.

## Configuration

Everything is optional and lives under `[tools.giolt]` in your `gleam.toml`:

| Key | Default | Meaning |
| --- | --- | --- |
| `entry` | your package name | Module that exports `handle`, such as `my_app/server` |
| `assets` | none | Directory of static files, copied to `outdir/static` and served by `dev` |
| `outdir` | `"./dist"` | Where the bundle goes. It is deleted before every build |
| `esbuild_args` | `[]` | Extra esbuild flags, appended after the fixed ones so they win |
| `spa` | `false` | Serve `index.html` for paths that match no file (static-only apps) |
| `watch` | `["src"]`, plus `assets` | Directories `dev` watches |
| `port` | `3000` | `dev` server port |
| `live_reload` | `true` | Reload the browser after a rebuild |
| `api_url` | `"https://dash.giolt.com"` | Giolt API used by `deploy` |
| `prebuild` | none | Shell command run before every build, such as `gleam run -m docs/build` |
| `artifact` | none | Deploy this directory as a static site. Skips the `handle` check, the compile and the bundle |

## Erlang target

A project with `target = "erlang"` builds for GlowVM. You need Erlang/OTP and
rebar3 installed, and `giolt build` tells you which one is missing. The output
in `outdir` is `app.avm` plus the runtime files (`glowvm.wasm`, `index.js`,
`index.min.js`). `dev` and `deploy` do not support this target yet.

## Issues

Report bugs and requests at
[github.com/withgiolt/issues](https://github.com/withgiolt/issues).
