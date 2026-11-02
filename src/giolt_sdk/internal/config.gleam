import gleam/regexp
import gleam/result
import tom

pub type Target {
  Javascript
  Erlang
}

pub type Config {
  Config(package: String, target: Target, entry: String)
}

pub type Error {
  InvalidToml
  MissingName
  UnknownTarget(String)
  InvalidEntry(String)
  TargetNotAString
  EntryNotAString
}

pub fn parse(source: String) -> Result(Config, Error) {
  use toml <- result.try(tom.parse(source) |> result.replace_error(InvalidToml))
  use package <- result.try(
    tom.get_string(toml, ["name"]) |> result.replace_error(MissingName),
  )
  use target <- result.try(read_target(toml))
  use entry <- result.try(read_entry(toml, package))

  Ok(Config(package:, target:, entry:))
}

fn read_target(toml) -> Result(Target, Error) {
  case tom.get_string(toml, ["target"]) {
    Ok("javascript") -> Ok(Javascript)
    Ok("erlang") -> Ok(Erlang)
    Ok(other) -> Error(UnknownTarget(other))
    Error(tom.NotFound(_)) -> Ok(Erlang)
    Error(tom.WrongType(..)) -> Error(TargetNotAString)
  }
}

fn read_entry(toml, package: String) -> Result(String, Error) {
  case tom.get_string(toml, ["tools", "giolt", "entry"]) {
    Ok(entry) -> validate_module_name(entry)
    Error(tom.NotFound(_)) -> Ok(package)
    Error(tom.WrongType(..)) -> Error(EntryNotAString)
  }
}

fn validate_module_name(name: String) -> Result(String, Error) {
  let assert Ok(pattern) =
    regexp.from_string("^[a-z][a-z0-9_]*(/[a-z][a-z0-9_]*)*$")

  case regexp.check(pattern, name) {
    True -> Ok(name)
    False -> Error(InvalidEntry(name))
  }
}

pub fn describe_error(error: Error) -> String {
  case error {
    InvalidToml -> "Could not parse gleam.toml: it is not valid TOML."
    MissingName -> "gleam.toml has no `name`."
    UnknownTarget(target) ->
      "Unknown target `"
      <> target
      <> "` in gleam.toml. Use \"erlang\" or \"javascript\"."
    TargetNotAString -> "`target` in gleam.toml must be a string."
    InvalidEntry(entry) ->
      "`entry` under [tools.giolt] must be a Gleam module name such as "
      <> "`my_app` or `my_app/server`, not `"
      <> entry
      <> "`."
    EntryNotAString -> "`entry` under [tools.giolt] must be a string."
  }
}

pub fn compiled_entry(config: Config) -> String {
  "./build/dev/javascript/" <> config.package <> "/" <> config.entry <> ".mjs"
}
