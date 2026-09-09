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
  // Anything you need before the bundle is plain Gleam code — Giolt does not
  // build anything for you:
  //
  //   let assert Ok(_) = tailwind.run("./src/app.css", "./public/app.css")

  bundle.new()
  |> bundle.entry("app")
  |> bundle.static_dir("./public")
  |> bundle.outdir("./dist")
  |> bundle.run
}
```

Run with `gleam run -m build`. There is nothing to configure about the bundle
itself — Giolt produces one shape of artifact: a minified, tree shaken ESM
bundle wrapped in the platform's worker entry. Your entry module needs to
export a single function:

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
  |> dev.ignore("**/*_dev.gleam")
  |> dev.prebuild(fn() { Ok(Nil) })
  |> dev.build(fn(_change) {
    // `bundle.run` only ever bundles what's already in `./build`, so
    // recompile Gleam to JavaScript first.
    use _ <- result.try(dev.compile())

    bundle.new()
    |> bundle.entry("app")
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

Run with `gleam run -m {project}_dev`.

## Where each of these builders come from

All three are opaque, phantom typed configurations, in the style of
[`lustre_ssg`](https://hexdocs.pm/lustre_ssg/): required fields flip a type
parameter when set, so `bundle.new() |> bundle.run` (an entry was never given)
is a compile error, not something you discover at build time.

Documentation can be found at [docs.giolt.com](https://docs.giolt.com).
