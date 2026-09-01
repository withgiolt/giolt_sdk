import filepath
import gleam/option
import gleam/result
import simplifile
import tom

pub type Error {
  CannotReadGleamToml(reason: simplifile.FileError)
  CannotParseGleamToml
  CannotReadProjectName(reason: tom.GetError)
  InvalidProjectBuildTarget
}

pub type BuildTarget {
  Javascript
  Erlang
}

pub type Project {
  Project(
    name: String,
    target: option.Option(BuildTarget),
    root_directory: String,
  )
}

pub fn load() -> Result(Project, Error) {
  let root_directory = find_root_directory(".")
  use gleam_toml <- result.try(
    filepath.join(root_directory, "gleam.toml")
    |> simplifile.read
    |> result.map_error(CannotReadGleamToml),
  )
  use gleam_toml <- result.try(
    tom.parse(gleam_toml)
    |> result.replace_error(CannotParseGleamToml),
  )
  use name <- result.try(
    tom.get_string(gleam_toml, ["name"])
    |> result.map_error(CannotReadProjectName),
  )

  use target <- result.try(
    case tom.get_string(gleam_toml, ["target"]) {
      Ok(target) ->
        case target {
          "javascript" -> Ok(option.Some(Javascript))
          "erlang" -> Ok(option.Some(Erlang))
          _ -> Error(option.None)
        }
      Error(_) -> Ok(option.None)
    }
    |> result.replace_error(InvalidProjectBuildTarget),
  )

  Ok(Project(name:, target:, root_directory:))
}

fn find_root_directory(current_path: String) -> _ {
  let gleam_toml = filepath.join(current_path, "gleam.toml")
  case simplifile.is_file(gleam_toml) {
    Ok(True) -> current_path
    Ok(False) | Error(_) -> {
      let path = filepath.join(current_path, "..")
      find_root_directory(path)
    }
  }
}
