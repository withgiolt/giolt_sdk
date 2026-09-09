import filepath
import giolt_sdk/internal/entry
import gleam/option
import gleam/regexp
import gleam/result
import simplifile

pub type Error {
  CannotReadGleamToml(reason: simplifile.FileError)
  CannotReadProjectName
}

pub type Project {
  Project(name: String, target: entry.Target, root_directory: String)
}

pub fn load() -> Result(Project, Error) {
  let root_directory = find_root_directory(".")

  use source <- result.try(
    filepath.join(root_directory, "gleam.toml")
    |> simplifile.read
    |> result.map_error(CannotReadGleamToml),
  )

  use name <- result.try(
    parse_name(source) |> result.replace_error(CannotReadProjectName),
  )

  Ok(Project(name:, target: parse_target(source), root_directory:))
}

pub fn parse_name(source: String) -> Result(String, Nil) {
  first_match(source, "name")
}

pub fn parse_target(source: String) -> entry.Target {
  first_match(source, "target")
  |> result.try(entry.target_from_string)
  |> result.unwrap(entry.Javascript)
}

// No multi-line regex flag on this target, so `^` is spelled out by hand.
fn first_match(source: String, key: String) -> Result(String, Nil) {
  use re <- result.try(
    regexp.from_string("(?:^|\\n)\\s*" <> key <> "\\s*=\\s*\"([^\"]+)\"")
    |> result.replace_error(Nil),
  )

  case regexp.scan(re, source) {
    [match, ..] ->
      case match.submatches {
        [option.Some(value), ..] -> Ok(value)
        _ -> Error(Nil)
      }
    [] -> Error(Nil)
  }
}

pub fn describe_error(error: Error) -> String {
  case error {
    CannotReadGleamToml(_) ->
      "Could not read gleam.toml. Run this from inside a Gleam project."
    CannotReadProjectName -> "Could not read `name` from gleam.toml."
  }
}

fn find_root_directory(current_path: String) -> String {
  do_find_root_directory(current_path, 32)
}

fn do_find_root_directory(current_path: String, remaining: Int) -> String {
  let gleam_toml = filepath.join(current_path, "gleam.toml")

  case simplifile.is_file(gleam_toml), remaining {
    Ok(True), _ -> current_path
    _, 0 -> "."
    _, _ ->
      do_find_root_directory(filepath.join(current_path, ".."), remaining - 1)
  }
}
