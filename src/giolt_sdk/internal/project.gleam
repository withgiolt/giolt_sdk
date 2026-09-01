import filepath
import gleam/dict
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import simplifile
import tom

pub type Error {
  CannotReadGleamToml(reason: simplifile.FileError)
  CannotParseGleamToml
  CannotReadGleamTomlProperty(reason: tom.GetError)
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
    config: GioltConfig,
  )
}

pub type GioltConfig {
  GioltConfig(
    outdir: String,
    static_dir: option.Option(String),
    entry: option.Option(String),
    bundle_aliases: List(String),
  )
}

pub const default_config = GioltConfig(
  outdir: "./dist",
  static_dir: option.None,
  entry: option.None,
  bundle_aliases: [],
)

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
    |> result.map_error(CannotReadGleamTomlProperty),
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

  let config = load_config(gleam_toml)

  Ok(Project(name:, target:, root_directory:, config:))
}

fn load_config(gleam_toml: dict.Dict(String, tom.Toml)) {
  let outdir =
    tom.get_string(gleam_toml, ["tools", "giolt", "outdir"])
    |> result.unwrap("./dist")

  let static_dir =
    tom.get_string(gleam_toml, ["tools", "giolt", "static_dir"])
    |> option.from_result

  let entry =
    tom.get_string(gleam_toml, ["tools", "giolt", "entry"])
    |> option.from_result

  let bundle_aliases =
    tom.get_array(gleam_toml, ["tools", "giolt", "bundle_aliases"])
    |> result.unwrap([])
    |> list.map(fn(alias) {
      tom.as_string(alias)
      |> result.unwrap("")
    })

  GioltConfig(outdir:, static_dir:, entry:, bundle_aliases:)
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
