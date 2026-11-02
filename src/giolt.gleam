import argv
import giolt_sdk/bundle
import giolt_sdk/internal/cli
import giolt_sdk/internal/config.{type Config, Erlang, Javascript}
import giolt_sdk/internal/io
import giolt_sdk/internal/process
import giolt_sdk/internal/signature
import gleam/io as stdio
import gleam/result
import simplifile

const javascript_steps = 3

const interface_path = "./build/.giolt-interface.json"

pub fn main() -> Nil {
  case cli.parse(argv.load().arguments) {
    cli.Usage(text) -> stdio.println(text)
    cli.Invalid(text) -> {
      stdio.println_error(text)
      process.exit(2)
    }
    cli.Run(command) ->
      case run(command) {
        Ok(Nil) -> Nil
        Error(message) -> {
          io.println_error(message)
          process.exit(1)
        }
      }
  }
}

fn run(command: cli.Command) -> Result(Nil, String) {
  case command {
    cli.Build -> build()
    cli.Dev | cli.Deploy ->
      Error("This command is not available in the giolt CLI yet.")
  }
}

fn build() -> Result(Nil, String) {
  use config <- result.try(read_config())
  use _ <- result.try(check_handle(config))

  case config.target {
    Javascript -> {
      io.println_progress(1, javascript_steps, "Checked handle")
      bundle_javascript(config)
    }
    Erlang -> {
      io.println_progress(1, 1, "Checked handle")
      Error(
        "`handle` in `"
        <> config.entry
        <> "` is valid, but building for the Erlang target (GlowVM) is not supported yet.",
      )
    }
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

  bundle.new()
  |> bundle.entry(config.compiled_entry(config))
  |> bundle.run
  |> result.replace_error("Build failed.")
  |> result.map(fn(_) { io.println_progress(3, javascript_steps, "Bundled") })
}
