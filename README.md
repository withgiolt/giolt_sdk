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
  |> bundle.run
}
```

Run with `gleam run -m build`. There is nothing to configure about the bundle
itself — Giolt produces one shape of artifact: a minified, tree shaken ESM
bundle wrapped in the platform's worker entry. `bundle.entry` takes a path to
a JavaScript file — usually your compiled Gleam module, but it can be any
file, including one your own build already produced — that exports a single
function:

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
import gleam/result

pub fn main() {
  dev.new()
  |> dev.watch("./src")
  |> dev.watch("./public")
  |> dev.prebuild(fn() { Ok(Nil) })
  |> dev.build(fn(_change) {
    use _ <- result.try(dev.compile())

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

Documentation can be found at [docs.giolt.com](https://docs.giolt.com).
