import envie
import esgleam
import giolt/internal/project
import gleam/io
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

pub type BuildTarget {
  Javascript
  Erlang
}

pub fn build_target_to_string(target: BuildTarget) {
  case target {
    Javascript -> "javascript"
    Erlang -> "erlang"
  }
}

pub fn build(target: BuildTarget) {
  let res = do_build(target)

  case res {
    Ok(_) -> io.println("[GioltSDK Bundle] JavaScript bundled successfully")
    Error(err) ->
      case err {
        FailedToBuildProjectWithTarget ->
          io.println("[GioltSDK Bundle] Failed to build project for target")
        CannotBuild ->
          io.println("[GioltSDK Bundle] Failed to build bundle with esbuild")
        CannotLoadProject(_) ->
          io.println("[GioltSDK Bundle] Failed to load project properties")
        CannotCreateBuildFolder(_) ->
          io.println(
            "[GioltSDK Bundle] Failed to create temporary build assets",
          )
      }
  }
}

fn do_build(target: BuildTarget) -> Result(Nil, Error) {
  let is_dev = envie.get_string("NODE_ENV", "production") == "development"

  use _ <- result.try(
    shellout.command(
      "gleam",
      ["build", "--target", build_target_to_string(target)],
      ".",
      [shellout.LetBeStdout, shellout.LetBeStderr],
    )
    |> result.replace_error(FailedToBuildProjectWithTarget),
  )

  use project <- result.try(
    project.load() |> result.map_error(CannotLoadProject),
  )

  use _ <- result.try(
    simplifile.create_directory_all("./build/dev/javascript/.giolt-build")
    |> result.map_error(CannotCreateBuildFolder),
  )

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

  let res =
    esgleam.new("./build/prod/javascript")
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

  use _ <- result.try(result.flatten(res) |> result.replace_error(CannotBuild))

  Ok(Nil)
}
