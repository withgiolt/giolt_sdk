import filepath
import giolt/internal/bundle
import giolt/internal/config.{type Config, Erlang, Javascript}
import giolt/internal/deploy
import giolt/internal/glowvm_bin
import giolt/internal/io
import giolt/internal/process
import giolt/internal/server
import giolt/internal/signature
import giolt/internal/watcher
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import gleam/result
import simplifile

const javascript_steps = 3

const interface_path = "./build/.giolt-interface.json"

pub fn build() -> Result(Nil, String) {
  use config <- result.try(read_config())
  run_build(config)
}

pub fn deploy(
  preview preview: Bool,
  message message: Option(String),
) -> Promise(Result(Nil, String)) {
  case read_config() {
    Error(message) -> promise.resolve(Error(message))
    Ok(config) ->
      case config.target {
        Erlang ->
          promise.resolve(Error(
            "Deploying the Erlang target is not supported by the Giolt platform yet.",
          ))
        Javascript ->
          case run_build(config) {
            Error(message) -> promise.resolve(Error(message))
            Ok(Nil) -> submit(config, preview, message)
          }
      }
  }
}

pub fn dev() -> Promise(Result(Nil, String)) {
  case read_config() {
    Error(message) -> promise.resolve(Error(message))
    Ok(config) ->
      case config.target {
        Erlang ->
          promise.resolve(Error(
            "`giolt dev` supports the javascript target only for now.",
          ))
        Javascript -> {
          rebuild(config)

          let stop_watching =
            watcher.watch(config.watch, fn(path, _kind) {
              io.println_info("Changed " <> path <> ", rebuilding")
              rebuild(config)
            })

          server.serve(
            port: config.port,
            static_dir: config.assets,
            worker_path: filepath.join(config.outdir, "index.mjs"),
            live_reload: config.live_reload,
          )

          let _ = stop_watching
          process.forever() |> promise.map(fn(_) { Ok(Nil) })
        }
      }
  }
}

fn rebuild(config: Config) -> Nil {
  case run_build(config) {
    Ok(Nil) -> server.notify_reload()
    Error(message) -> io.println_error(message)
  }
}

fn read_config() -> Result(Config, String) {
  use source <- result.try(
    simplifile.read("gleam.toml")
    |> result.replace_error(
      "Could not read gleam.toml. Run this from the root of a Gleam project.",
    ),
  )

  config.parse(source) |> result.map_error(config.describe_error)
}

fn run_build(config: Config) -> Result(Nil, String) {
  use _ <- result.try(case config.target {
    Javascript -> Ok(Nil)
    Erlang -> glowvm_bin.check_tooling()
  })
  use _ <- result.try(run_prebuild(config.prebuild))
  use _ <- result.try(check_handle(config))

  case config.target {
    Javascript -> {
      io.println_progress(1, javascript_steps, "Checked handle")
      bundle_javascript(config)
    }
    Erlang -> {
      io.println_progress(1, glowvm_bin.steps, "Checked handle")
      warn_unused_assets(config)
      glowvm_bin.build(config, config.outdir)
    }
  }
}

fn run_prebuild(prebuild: Option(String)) -> Result(Nil, String) {
  case prebuild {
    None -> Ok(Nil)
    Some(command) -> {
      io.println_info("Running prebuild: " <> command)
      process.shell(command)
    }
  }
}

fn check_handle(config: Config) -> Result(Nil, String) {
  io.println_info("Checking `handle` in " <> config.entry <> "...")

  use _ <- result.try(
    simplifile.create_directory_all("./build")
    |> result.replace_error("Could not create the build directory."),
  )
  use _ <- result.try(
    process.run("gleam", [
      "export",
      "package-interface",
      "--out",
      interface_path,
    ]),
  )
  use interface <- result.try(
    simplifile.read(interface_path)
    |> result.replace_error("Could not read " <> interface_path <> "."),
  )

  signature.check(interface, config.entry, config.target)
  |> result.map_error(signature.describe_error)
}

fn bundle_javascript(config: Config) -> Result(Nil, String) {
  use _ <- result.try(process.run("gleam", ["build", "--target", "javascript"]))
  io.println_progress(2, javascript_steps, "Compiled")

  let base =
    bundle.new()
    |> bundle.entry(config.compiled_entry(config))
    |> bundle.outdir(config.outdir)
    |> bundle.additional_args(config.esbuild_args)
  let with_assets = case config.assets {
    Some(path) -> bundle.static_dir(base, path)
    None -> base
  }

  with_assets
  |> bundle.run
  |> result.replace_error("Build failed.")
  |> result.map(fn(_) { io.println_progress(3, javascript_steps, "Bundled") })
}

fn warn_unused_assets(config: Config) -> Nil {
  case config.assets {
    Some(_) ->
      io.println_warning(
        "`assets` is ignored for the Erlang target: GlowVM apps have no static directory yet.",
      )
    None -> Nil
  }
}

fn submit(
  config: Config,
  preview: Bool,
  message: Option(String),
) -> Promise(Result(Nil, String)) {
  let base =
    deploy.new()
    |> deploy.artifact(config.outdir)
    |> deploy.preview(preview)
    |> deploy.spa(config.spa)
    |> deploy.api_url(config.api_url)
  let with_message = case message {
    Some(text) -> deploy.message(base, text)
    None -> base
  }

  use result <- promise.map(deploy.run(with_message))
  case result {
    Ok(deployment) -> {
      deploy.print_result(Ok(deployment))
      Ok(Nil)
    }
    Error(_) -> Error("Deploy failed.")
  }
}
