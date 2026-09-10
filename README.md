# giolt_sdk

[![Package Version](https://img.shields.io/hexpm/v/giolt_sdk)](https://hex.pm/packages/giolt_sdk)

The Giolt SDK for building, developing and deploying Gleam apps on the edge.

There is no CLI. `giolt_sdk` is a library — you write plain Gleam scripts that
call into it, and you own your own build. The only thing invoked by module
name is a one-shot scaffolder.

## Install

```sh
gleam add giolt_sdk
```

## Get started

```sh
gleam run -m giolt_sdk/init
```

This reads your project name out of `gleam.toml` and writes three files into
`src/`, skipping any that already exist:

- **`build.gleam`** — bundles your app for the Giolt platform.
- **`deploy.gleam`** — ships a bundle.
- **`{project}_dev.gleam`** — watches, rebuilds and serves your app locally.

### `build.gleam`

```gleam
import giolt_sdk/bundle

pub fn main() {
  bundle.new()
  |> bundle.entry("./build/dev/javascript/app/app.mjs")
  |> bundle.static_dir("./public")
  |> bundle.outdir("./dist")
  |> bundle.additional_args(["--external:node:crypto"])
  |> bundle.run
}
```

Run with `gleam run -m build`. Giolt produces one shape of artifact by
default: a minified, tree shaken ESM bundle wrapped in the platform's worker
entry. `bundle.additional_args` takes a raw list of esbuild flags appended
after the SDK's own — later flags win, so it's how you override a default
(`--minify=false`) or mark something `--external` so esbuild doesn't bundle
it a second time. `bundle.entry` takes a path to a JavaScript file — usually
your compiled Gleam module, but it can be any file, including one your own
build already produced — that exports a single function:

```gleam
pub fn handler(request: Request(Body)) -> Response(Body) {
  // or: -> Promise(Response(Body))
}
```

### `deploy.gleam`

```gleam
import build
import giolt_sdk/deploy
import gleam/javascript/promise

pub fn main() {
  let assert Ok(output) = build.main()

  deploy.new()
  |> deploy.project_id("prj_replace_me")
  |> deploy.from(output)
  |> deploy.preview(True)
  |> deploy.token_from_env("GIOLT_TOKEN")
  |> deploy.run
  |> promise.map(deploy.print_result)
}
```

Run with `gleam run -m deploy`.

### `{project}_dev.gleam`

```gleam
import giolt_sdk/bundle
import giolt_sdk/dev

pub fn main() {
  dev.new()
  |> dev.watch("./src")
  |> dev.watch("./public")
  |> dev.prebuild(fn() { Ok(Nil) })
  |> dev.build(fn(_change) {
    bundle.new()
    |> bundle.entry("./build/dev/javascript/app/app.mjs")
    |> bundle.static_dir("./public")
    |> bundle.run
    |> bundle.discard_output
  })
  |> dev.serve(port: 3000)
  |> dev.worker("./dist/index.mjs")
  |> dev.static_dir("./public")
  |> dev.live_reload(True)
  |> dev.run
}
```

Run with `gleam dev`.

`dev.run` supervises itself: the first process compiles the project and then
spawns a child that runs your `build` closure, watches and serves. On a file
change the child exits, the parent recompiles and starts a fresh child. That
restart is what makes the `build` closure see newly compiled code — a
long-lived process holds its imported modules in memory, so anything that
generates output in-process (a static site generator, codegen, templating)
would otherwise keep rendering from the code that was loaded at startup.

Because the supervisor compiles before every child, your `build` closure does
not need to compile the project itself.

Documentation can be found at [docs.giolt.com](https://docs.giolt.com).
