import envie
import filepath
import giolt_sdk/internal/esgleam/esgleam
import giolt_sdk/internal/io
import giolt_sdk/internal/project
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import shellout
import simplifile

pub type Error {
  FailedToBuildProjectWithTarget
  FailedToDeleteOutdir(reason: simplifile.FileError)
  CannotParsePrebuildCommand
  FailedToRunPrebuildCommand
  CannotLoadProject(reason: project.Error)
  CannotCreateBuildFolder(reason: simplifile.FileError)
  CannotCopyStaticDir(reason: simplifile.FileError)
  CannotBundle
}

pub fn build_target_to_string(target: project.BuildTarget) {
  case target {
    project.Javascript -> "javascript"
    project.Erlang -> "erlang"
  }
}

fn do_if(condition: Bool, action: fn() -> Result(Nil, Error)) {
  case condition {
    True -> action()
    False -> Ok(Nil)
  }
}

pub fn build(target: project.BuildTarget) {
  let res = run_pipeline(target)

  case res {
    Ok(_) -> io.println_success("JavaScript bundled successfully")
    Error(err) ->
      case err {
        FailedToDeleteOutdir(e) ->
          io.println_error(
            "Failed to build project for target. Reason: " <> string.inspect(e),
          )
        FailedToBuildProjectWithTarget ->
          io.println_error("Failed to build project for target")
        CannotParsePrebuildCommand ->
          io.println_error("Failed to build project for target")
        CannotBundle -> io.println_error("Failed to build bundle with esbuild")
        FailedToRunPrebuildCommand ->
          io.println_error("Failed to run prebuild command")
        CannotLoadProject(e) ->
          io.println_error(
            "Failed to load project properties. Reason: " <> string.inspect(e),
          )
        CannotCreateBuildFolder(e) ->
          io.println_error(
            "Failed to create temporary build assets. Reason: "
            <> string.inspect(e),
          )
        CannotCopyStaticDir(e) ->
          io.println_error(
            "Failed to copy static directory. Reason: " <> string.inspect(e),
          )
      }
  }
}

fn run_pipeline(target: project.BuildTarget) {
  io.println_info(
    "Compiling project for " <> build_target_to_string(target) <> " target...",
  )
  use _ <- result.try(gleam_build(target))

  io.println_info("Loading project...")
  use project <- result.try(
    project.load() |> result.map_error(CannotLoadProject),
  )

  io.println_info("Clearing " <> project.config.outdir <> " folder...")
  use _ <- result.try(
    simplifile.delete(project.config.outdir)
    |> result.map_error(FailedToDeleteOutdir),
  )

  use _ <- result.try(
    do_if(option.is_some(project.config.prebuild_command), fn() {
      do_prebuild(project)
    }),
  )

  use _ <- result.try(
    do_if(option.is_some(project.config.entry_module), fn() {
      do_bundle(target, project)
    }),
  )

  use _ <- result.try(
    do_if(option.is_some(project.config.static_dir), fn() { do_copy(project) }),
  )

  Ok(Nil)
}

fn gleam_build(target: project.BuildTarget) {
  use _ <- result.try(
    shellout.command(
      "gleam",
      ["build", "--target", build_target_to_string(target)],
      ".",
      [shellout.LetBeStdout, shellout.LetBeStderr],
    )
    |> result.replace_error(FailedToBuildProjectWithTarget),
  )

  Ok(Nil)
}

fn do_prebuild(project: project.Project) -> Result(Nil, Error) {
  use exec <- result.try(
    project.config.prebuild_command
    // We know for sure that prebuild_command is Some as we checked earlier
    |> option.unwrap("")
    |> string.split(" ")
    |> list.first
    |> result.replace_error(CannotParsePrebuildCommand),
  )

  let args =
    project.config.prebuild_command
    // We know for sure that prebuild_command is Some as we checked earlier
    |> option.unwrap("")
    |> string.split(" ")
    |> list.drop(1)

  use _ <- result.try(
    shellout.command(exec, args, ".", [
      shellout.LetBeStdout,
      shellout.LetBeStderr,
    ])
    |> result.replace_error(FailedToRunPrebuildCommand),
  )

  Ok(Nil)
}

fn do_copy(project: project.Project) -> Result(Nil, Error) {
  use _ <- result.try(
    simplifile.copy_directory(
      // We know for sure that static_dir is Some as we checked earlier
      project.config.static_dir |> option.unwrap(""),
      filepath.join(project.config.outdir, "static"),
    )
    |> result.map_error(CannotCopyStaticDir),
  )

  Ok(Nil)
}

fn do_bundle(
  target: project.BuildTarget,
  project: project.Project,
) -> Result(Nil, Error) {
  let is_dev = envie.get_string("NODE_ENV", "production") == "development"

  io.println_info("Creating temporary build folder...")
  use _ <- result.try(
    simplifile.create_directory_all(
      "./build/dev/" <> build_target_to_string(target) <> "/_giolt_build",
    )
    |> result.map_error(CannotCreateBuildFolder),
  )

  let _ = case target {
    project.Javascript -> {
      io.println_info("Generating Javascript files...")
      use _ <- result.try(
        simplifile.copy_file(
          "./build/dev/javascript/giolt_sdk/priv/bundle_assets/javascript/index.mjs",
          "./build/dev/javascript/_giolt_build/index.mjs",
        )
        |> result.map_error(CannotCreateBuildFolder),
      )

      use index_file_text <- result.try(
        simplifile.read("./build/dev/javascript/_giolt_build/index.mjs")
        |> result.map_error(CannotCreateBuildFolder),
      )

      let index_file_text =
        index_file_text
        |> string.replace("{project}", project.name)
        |> string.replace(
          "{module}",
          // We know for sure that static_dir is Some as we checked earlier
          option.unwrap(project.config.entry_module, ""),
        )

      use _ <- result.try(
        simplifile.write(
          "./build/dev/javascript/_giolt_build/index.mjs",
          index_file_text,
        )
        |> result.map_error(CannotCreateBuildFolder),
      )

      Ok(Nil)
    }
    project.Erlang -> {
      Error(FailedToBuildProjectWithTarget)
    }
  }

  io.println_info("Bundling...")
  let res =
    esgleam.new(project.config.outdir)
    |> esgleam.platform(esgleam.Node)
    |> esgleam.autoinstall(True)
    |> esgleam.minify(!is_dev)
    |> esgleam.entry("../_giolt_build/index.mjs")
    |> esgleam.raw(
      "--tree-shaking --splitting "
      <> case project.config.bundle_aliases {
        [] -> ""
        aliases -> {
          list.map(aliases, fn(alias) { "--alias:" <> alias })
          |> string.join(" ")
        }
      }
      <> case is_dev {
        True -> " --sourcemap"
        False -> ""
      },
    )
    |> esgleam.bundle

  use res <- result.try(res |> result.replace_error(CannotBundle))
  use _ <- result.try(res |> result.replace_error(CannotBundle))

  Ok(Nil)
}
