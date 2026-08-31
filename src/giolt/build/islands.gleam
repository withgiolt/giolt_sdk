import envie
import esgleam
import filepath
import giolt/internal/executable
import gleam/io
import gleam/result
import simplifile

pub type Error {
  CannotGetCurrentDir
  CannotFindExecutable
  CannotRunExecutable
}

pub fn build(islands_project_path project_path: String) {
  let res = do_build(project_path)

  case res {
    Ok(_) -> io.println("[GioltSDK Islands] Islands compiled successfully")
    Error(err) ->
      case err {
        CannotGetCurrentDir ->
          io.println(
            "[GioltSDK Islands] Failed to get the current directory for islands",
          )
        CannotFindExecutable ->
          io.println("[GioltSDK Islands] Failed to find the Gleam executable")
        CannotRunExecutable ->
          io.println(
            "[GioltSDK Islands] Failed to execute build in islands project folder",
          )
      }
  }
}

fn do_build(project_path: String) {
  use current_dir <- result.try(
    simplifile.current_directory() |> result.replace_error(CannotGetCurrentDir),
  )
  use gleam_exec <- result.try(
    executable.find("gleam") |> result.replace_error(CannotFindExecutable),
  )

  use _ <- result.try(
    executable.run(gleam_exec, filepath.join(current_dir, project_path), [
      "run",
      "-m",
      "build",
    ])
    |> result.replace_error(CannotRunExecutable),
  )

  Ok(Nil)
}

fn add_islands_entries(config: esgleam.Config, entries: List(String)) {
  case entries {
    [] -> config
    [entry, ..rest] -> {
      esgleam.entry(config, "./islands/" <> entry)
      |> add_islands_entries(rest)
    }
  }
}

pub fn island_project() {
  let is_dev = envie.get_string("NODE_ENV", "production") == "development"

  let assert Ok(current_dir) = simplifile.current_directory()
    as "Failed to get current directory"
  let assert Ok(gleam_exec) = executable.find("gleam")
    as "Failed to find Gleam executable"
  let assert Ok(_) =
    executable.run(gleam_exec, current_dir, ["run", "-m", "build"])
    as "Failed to run Gleam executable"

  let assert Ok(islands) =
    simplifile.read_directory(
      filepath.join(current_dir, "src")
      |> filepath.join("islands"),
    )
    as "Failed to get islands directory"

  let res =
    esgleam.new("../dist/_islands")
    |> esgleam.platform(esgleam.Browser)
    |> esgleam.autoinstall(True)
    |> esgleam.minify(is_dev)
    |> add_islands_entries(islands)
    |> esgleam.raw(
      "--tree-shaking --splitting"
      <> case is_dev {
        True -> " --sourcemap"
        False -> ""
      },
    )
    |> esgleam.bundle

  case res {
    Ok(_) -> io.println("Islands build successfully")
    Error(_) -> {
      panic as "Failed to build islands"
    }
  }
  Nil
}
