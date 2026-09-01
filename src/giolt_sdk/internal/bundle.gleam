import envie
import esgleam
import giolt_sdk/internal/io
import giolt_sdk/internal/project
import gleam/result
import gleam/string
import shellout
import simplifile

pub type Error {
  FailedToBuildProjectWithTarget
  CannotLoadProject(reason: project.Error)
  CannotCreateBuildFolder(reason: simplifile.FileError)
  CannotBuild
}

pub fn build_target_to_string(target: project.BuildTarget) {
  case target {
    project.Javascript -> "javascript"
    project.Erlang -> "erlang"
  }
}

pub fn build(target: project.BuildTarget) {
  let res = do_build(target)

  case res {
    Ok(_) -> io.println_success("JavaScript bundled successfully")
    Error(err) ->
      case err {
        FailedToBuildProjectWithTarget ->
          io.println_error("Failed to build project for target")
        CannotBuild -> io.println_error("Failed to build bundle with esbuild")
        CannotLoadProject(_) ->
          io.println_error("Failed to load project properties")
        CannotCreateBuildFolder(_) ->
          io.println_error("Failed to create temporary build assets")
      }
  }
}

fn do_build(target: project.BuildTarget) -> Result(Nil, Error) {
  let is_dev = envie.get_string("NODE_ENV", "production") == "development"

  io.println_info(
    "Compiling project for " <> build_target_to_string(target) <> " target...",
  )
  use _ <- result.try(
    shellout.command(
      "gleam",
      ["build", "--target", build_target_to_string(target)],
      ".",
      [shellout.LetBeStdout, shellout.LetBeStderr],
    )
    |> result.replace_error(FailedToBuildProjectWithTarget),
  )

  io.println_info("Loading project...")
  use project <- result.try(
    project.load() |> result.map_error(CannotLoadProject),
  )

  io.println_info("Creating temporary build folder...")
  use _ <- result.try(
    simplifile.create_directory_all(
      "./build/dev/" <> build_target_to_string(target) <> "/.giolt-build",
    )
    |> result.map_error(CannotCreateBuildFolder),
  )

  let _ = case target {
    project.Javascript -> {
      io.println_info("Generating Javascript files...")
      use _ <- result.try(
        simplifile.copy_file(
          "./build/dev/javascript/giolt_sdk/priv/bundle_assets/javascript/index.mjs",
          "./build/dev/javascript/.giolt-build/index.mjs",
        )
        |> result.map_error(CannotCreateBuildFolder),
      )

      use index_file_text <- result.try(
        simplifile.read("./build/dev/javascript/.giolt-build/index.mjs")
        |> result.map_error(CannotCreateBuildFolder),
      )

      let index_file_text =
        index_file_text
        |> string.replace("{project}", project.name)

      use _ <- result.try(
        simplifile.write(
          "./build/dev/javascript/.giolt-build/index.mjs",
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
    esgleam.new("./build/prod/" <> build_target_to_string(target))
    |> esgleam.platform(esgleam.Node)
    |> esgleam.autoinstall(True)
    |> esgleam.minify(!is_dev)
    |> esgleam.entry("../.giolt-build/index.mjs")
    |> esgleam.raw(
      "--tree-shaking --splitting"
      <> case is_dev {
        True -> ""
        False -> " --sourcemap"
      },
    )
    |> esgleam.bundle

  use res <- result.try(res |> result.replace_error(CannotBuild))
  use _ <- result.try(res |> result.replace_error(CannotBuild))

  Ok(Nil)
}
