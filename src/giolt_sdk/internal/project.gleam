//// Reading the two things the SDK still needs from the consumer's
//// `gleam.toml`: the project name and the compilation target.
////
//// There is no `[tools.giolt]` section any more — everything that used to
//// live there is now an argument to `bundle`, `deploy` or `dev`.

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

/// Load the project the SDK is running inside.
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

/// Read `name = "..."` out of a `gleam.toml`.
pub fn parse_name(source: String) -> Result(String, Nil) {
  first_match(source, "name")
}

/// Read `target = "..."` out of a `gleam.toml`. Gleam's own default is Erlang,
/// but every Giolt project is a JavaScript one, and the scaffolded `gleam.toml`
/// says so — so an absent or unrecognised target is read as JavaScript and the
/// entry check will speak up if the project really is not.
pub fn parse_target(source: String) -> entry.Target {
  first_match(source, "target")
  |> result.try(entry.target_from_string)
  |> result.unwrap(entry.Javascript)
}

/// Read `{key} = "..."` out of a TOML source, anchored to the start of a
/// line so that, say, a `description` mentioning the word `name` is not
/// mistaken for the `name` key.
///
/// `gleam/regexp` compiles to JavaScript's `RegExp` without a multi-line flag
/// available here, so the anchor is spelled out by hand as "start of string,
/// or right after a newline" rather than relying on one.
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
