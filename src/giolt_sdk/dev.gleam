//// The local dev loop: watch, rebuild, serve.
////
//// Call this from your own `{project}_dev.gleam`:
////
//// ```gleam
//// import giolt_sdk/bundle
//// import giolt_sdk/dev
////
//// pub fn main() {
////   dev.new()
////   |> dev.watch("./src")
////   |> dev.watch("./public")
////   |> dev.ignore("**/*_dev.gleam")
////   |> dev.prebuild(fn() { Ok(Nil) })
////   |> dev.build(fn(_change) {
////     // Recompile Gleam to JavaScript, then bundle it — `bundle.run` only
////     // ever reads what is already in `./build`, so this is what makes an
////     // edited .gleam file actually show up.
////     use _ <- result.try(dev.compile())
////
////     bundle.new()
////     |> bundle.entry("app")
////     |> bundle.static_dir("./public")
////     |> bundle.run
////     |> bundle.discard_output
////   })
////   |> dev.serve(port: 3000)
////   |> dev.worker("./dist/index.mjs")
////   |> dev.static_dir("./public")
////   |> dev.live_reload(True)
////   |> dev.run
//// }
//// ```
////
//// Run it with `gleam run -m {project}_dev`. `dev.run` watches, rebuilds and
//// serves until you stop it — it does not return under normal operation.

import giolt_sdk/internal/glob
import giolt_sdk/internal/io
import giolt_sdk/internal/server
import giolt_sdk/internal/watcher
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}

/// A configuration that has not been given a path to watch yet.
pub type NoWatch

/// A configuration that has at least one watched path.
pub type HasWatch

/// A configuration that has not been given a build step yet.
pub type NoBuild

/// A configuration that has a build step.
pub type HasBuild

/// What changed on disk.
pub type ChangeKind {
  Created
  Modified
  Deleted
}

/// A single change reported by the watcher.
pub type Change {
  Change(path: String, kind: ChangeKind)
}

/// A dev loop configuration.
///
/// The type parameters track whether at least one path to watch, and a build
/// step, have been set. `run` only accepts a configuration that has both, so
/// forgetting either is a compile error rather than something you find out
/// about by running it.
pub opaque type Config(has_watch, has_build) {
  Config(
    watch_paths: List(String),
    ignore_patterns: List(String),
    prebuild: Option(fn() -> Result(Nil, String)),
    build: Option(fn(Change) -> Result(Nil, String)),
    serve_port: Option(Int),
    worker_path: String,
    static_dir: Option(String),
    live_reload: Bool,
  )
}

const default_worker_path = "./dist/index.mjs"

/// The change passed to your `build` closure for the very first build, before
/// anything has actually changed on disk.
pub const initial_change = Change(path: "", kind: Modified)

/// Start a new dev configuration.
pub fn new() -> Config(NoWatch, NoBuild) {
  Config(
    watch_paths: [],
    ignore_patterns: [],
    prebuild: None,
    build: None,
    serve_port: None,
    worker_path: default_worker_path,
    static_dir: None,
    live_reload: True,
  )
}

/// A directory to watch for changes. Required, and can be used more than
/// once.
pub fn watch(
  config: Config(has_watch, has_build),
  path: String,
) -> Config(HasWatch, has_build) {
  let Config(
    ignore_patterns:,
    prebuild:,
    build:,
    serve_port:,
    worker_path:,
    static_dir:,
    live_reload:,
    watch_paths:,
  ) = config

  Config(
    watch_paths: [path, ..watch_paths],
    ignore_patterns:,
    prebuild:,
    build:,
    serve_port:,
    worker_path:,
    static_dir:,
    live_reload:,
  )
}

/// A glob to exclude from the watch — for example `"**/*_dev.gleam"`, so
/// editing this very file does not trigger a rebuild. Can be used more than
/// once.
pub fn ignore(
  config: Config(has_watch, has_build),
  pattern: String,
) -> Config(has_watch, has_build) {
  Config(..config, ignore_patterns: [pattern, ..config.ignore_patterns])
}

/// Run once, before the first build.
pub fn prebuild(
  config: Config(has_watch, has_build),
  action: fn() -> Result(Nil, String),
) -> Config(has_watch, has_build) {
  Config(..config, prebuild: Some(action))
}

/// Run on the first build and again on every change to a watched path.
/// Required.
pub fn build(
  config: Config(has_watch, has_build),
  action: fn(Change) -> Result(Nil, String),
) -> Config(has_watch, HasBuild) {
  let Config(
    watch_paths:,
    ignore_patterns:,
    prebuild:,
    serve_port:,
    worker_path:,
    static_dir:,
    live_reload:,
    ..,
  ) = config

  Config(
    watch_paths:,
    ignore_patterns:,
    prebuild:,
    build: Some(action),
    serve_port:,
    worker_path:,
    static_dir:,
    live_reload:,
  )
}

/// Serve the bundle on this port. Optional — omit it to watch and rebuild
/// without a dev server.
pub fn serve(
  config: Config(has_watch, has_build),
  port port: Int,
) -> Config(has_watch, has_build) {
  Config(..config, serve_port: Some(port))
}

/// Where `build` writes the worker bundle. Defaults to `./dist/index.mjs`.
pub fn worker(
  config: Config(has_watch, has_build),
  path: String,
) -> Config(has_watch, has_build) {
  Config(..config, worker_path: path)
}

/// A directory of static files to serve ahead of the worker.
pub fn static_dir(
  config: Config(has_watch, has_build),
  path: String,
) -> Config(has_watch, has_build) {
  Config(..config, static_dir: Some(path))
}

/// Whether an open browser tab should refresh itself after a rebuild.
/// Defaults to `True`. The worker is reloaded either way — this only
/// controls whether the browser is told to reload itself.
pub fn live_reload(
  config: Config(has_watch, has_build),
  enabled: Bool,
) -> Config(has_watch, has_build) {
  Config(..config, live_reload: enabled)
}

/// Watch, rebuild and serve. Does not return under normal operation.
///
/// Only compiles once both `watch` and `build` have been set —
/// `dev.new() |> dev.run` is a type error.
pub fn run(config: Config(HasWatch, HasBuild)) -> Promise(Nil) {
  let assert Some(build_step) = config.build

  case run_prebuild(config.prebuild) {
    Error(message) -> {
      io.println_error(message)
      promise.resolve(Nil)
    }
    Ok(_) -> {
      run_build(build_step, initial_change)

      let stop_watching =
        watcher.watch(config.watch_paths, fn(path, kind) {
          handle_change(config, build_step, path, kind)
        })

      case config.serve_port {
        Some(port) ->
          server.serve(
            port: port,
            static_dir: config.static_dir,
            worker_path: config.worker_path,
            live_reload: config.live_reload,
          )
        None -> Nil
      }

      // No signal handling yet — `stop_watching` is here for a future
      // Ctrl-C hook to call.
      let _ = stop_watching
      forever()
    }
  }
}

fn handle_change(
  config: Config(has_watch, has_build),
  build_step: fn(Change) -> Result(Nil, String),
  path: String,
  kind: String,
) -> Nil {
  case glob.matches_any(config.ignore_patterns, path) {
    True -> Nil
    False -> run_build(build_step, Change(path: path, kind: change_kind(kind)))
  }
}

fn run_build(
  build_step: fn(Change) -> Result(Nil, String),
  change: Change,
) -> Nil {
  case build_step(change) {
    Ok(_) -> {
      io.println_success("Rebuilt")
      server.notify_reload()
    }
    Error(message) -> io.println_error(message)
  }
}

fn run_prebuild(
  prebuild: Option(fn() -> Result(Nil, String)),
) -> Result(Nil, String) {
  case prebuild {
    None -> Ok(Nil)
    Some(action) -> action()
  }
}

/// Turn a raw kind string from `giolt_sdk/internal/watcher` into a
/// `ChangeKind`. Exposed so the mapping can be unit tested directly.
pub fn change_kind(raw: String) -> ChangeKind {
  case raw {
    "created" -> Created
    "deleted" -> Deleted
    _ -> Modified
  }
}

/// Recompile the project's Gleam source to JavaScript.
///
/// The SDK does not build anything for you, and `bundle.run` only ever
/// bundles what is already sitting in `./build` — it never invokes the Gleam
/// compiler. So a `.gleam` change has nothing to make it visible to the next
/// bundle unless something calls the compiler first. Make this the first
/// line of your `build` closure:
///
/// ```gleam
/// |> dev.build(fn(_change) {
///   use _ <- result.try(dev.compile())
///   bundle.new() |> bundle.entry("app") |> bundle.run |> bundle.discard_output
/// })
/// ```
pub fn compile() -> Result(Nil, String) {
  do_compile()
}

@external(javascript, "./internal/ffi_dev.mjs", "forever")
fn forever() -> Promise(Nil)

@external(javascript, "./internal/ffi_dev.mjs", "compile")
fn do_compile() -> Result(Nil, String)
