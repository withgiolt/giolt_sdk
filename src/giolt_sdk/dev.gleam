import giolt_sdk/internal/io
import giolt_sdk/internal/server
import giolt_sdk/internal/watcher
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}

pub type NoWatch

pub type HasWatch

pub type NoBuild

pub type HasBuild

pub type ChangeKind {
  Created
  Modified
  Deleted
}

pub type Change {
  Change(path: String, kind: ChangeKind)
}

pub opaque type Config(has_watch, has_build) {
  Config(
    watch_paths: List(String),
    prebuild: Option(fn() -> Result(Nil, String)),
    build: Option(fn(Change) -> Result(Nil, String)),
    serve_port: Option(Int),
    worker_path: String,
    static_dir: Option(String),
    live_reload: Bool,
  )
}

const default_worker_path = "./dist/index.mjs"

pub const initial_change = Change(path: "", kind: Modified)

pub fn new() -> Config(NoWatch, NoBuild) {
  Config(
    watch_paths: [],
    prebuild: None,
    build: None,
    serve_port: None,
    worker_path: default_worker_path,
    static_dir: None,
    live_reload: True,
  )
}

pub fn watch(
  config: Config(has_watch, has_build),
  path: String,
) -> Config(HasWatch, has_build) {
  let Config(
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
    prebuild:,
    build:,
    serve_port:,
    worker_path:,
    static_dir:,
    live_reload:,
  )
}

pub fn prebuild(
  config: Config(has_watch, has_build),
  action: fn() -> Result(Nil, String),
) -> Config(has_watch, has_build) {
  Config(..config, prebuild: Some(action))
}

pub fn build(
  config: Config(has_watch, has_build),
  action: fn(Change) -> Result(Nil, String),
) -> Config(has_watch, HasBuild) {
  let Config(
    watch_paths:,
    prebuild:,
    serve_port:,
    worker_path:,
    static_dir:,
    live_reload:,
    ..,
  ) = config

  Config(
    watch_paths:,
    prebuild:,
    build: Some(action),
    serve_port:,
    worker_path:,
    static_dir:,
    live_reload:,
  )
}

pub fn serve(
  config: Config(has_watch, has_build),
  port port: Int,
) -> Config(has_watch, has_build) {
  Config(..config, serve_port: Some(port))
}

pub fn worker(
  config: Config(has_watch, has_build),
  path: String,
) -> Config(has_watch, has_build) {
  Config(..config, worker_path: path)
}

pub fn static_dir(
  config: Config(has_watch, has_build),
  path: String,
) -> Config(has_watch, has_build) {
  Config(..config, static_dir: Some(path))
}

pub fn live_reload(
  config: Config(has_watch, has_build),
  enabled: Bool,
) -> Config(has_watch, has_build) {
  Config(..config, live_reload: enabled)
}

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
          run_build(build_step, Change(path: path, kind: change_kind(kind)))
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

      let _ = stop_watching
      forever()
    }
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

pub fn change_kind(raw: String) -> ChangeKind {
  case raw {
    "created" -> Created
    "deleted" -> Deleted
    _ -> Modified
  }
}

pub fn compile() -> Result(Nil, String) {
  do_compile()
}

@external(javascript, "./internal/ffi_dev.mjs", "forever")
fn forever() -> Promise(Nil)

@external(javascript, "./internal/ffi_dev.mjs", "compile")
fn do_compile() -> Result(Nil, String)
