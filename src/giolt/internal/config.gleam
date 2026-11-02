import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import tom

pub type Target {
  Javascript
  Erlang
}

pub type Config {
  Config(
    package: String,
    target: Target,
    entry: String,
    assets: Option(String),
    outdir: String,
    esbuild_args: List(String),
    spa: Bool,
    watch: List(String),
    port: Int,
    live_reload: Bool,
    api_url: String,
    prebuild: Option(String),
    artifact: Option(String),
  )
}

pub type Error {
  InvalidToml
  MissingName
  UnknownTarget(String)
  InvalidEntry(String)
  InvalidPort(Int)
  InvalidValue(key: String, expected: String)
}

pub const default_outdir = "./dist"

pub fn default(package: String, target: Target) -> Config {
  Config(
    package:,
    target:,
    entry: package,
    assets: None,
    outdir: default_outdir,
    esbuild_args: [],
    spa: False,
    watch: ["src"],
    port: 3000,
    live_reload: True,
    api_url: "https://dash.giolt.com",
    prebuild: None,
    artifact: None,
  )
}

pub fn parse(source: String) -> Result(Config, Error) {
  use toml <- result.try(tom.parse(source) |> result.replace_error(InvalidToml))
  use package <- result.try(
    tom.get_string(toml, ["name"]) |> result.replace_error(MissingName),
  )
  use target <- result.try(read_target(toml))
  let defaults = default(package, target)

  use entry <- result.try(read_entry(toml, defaults.entry))
  use assets <- result.try(optional(toml, "assets", tom.as_string, "a string"))
  use outdir <- result.try(with_default(
    toml,
    "outdir",
    tom.as_string,
    "a string",
    defaults.outdir,
  ))
  use esbuild_args <- result.try(with_default(
    toml,
    "esbuild_args",
    strings,
    "a list of strings",
    defaults.esbuild_args,
  ))
  use spa <- result.try(with_default(
    toml,
    "spa",
    tom.as_bool,
    "true or false",
    defaults.spa,
  ))
  use port <- result.try(read_port(toml, defaults.port))
  use live_reload <- result.try(with_default(
    toml,
    "live_reload",
    tom.as_bool,
    "true or false",
    defaults.live_reload,
  ))
  use api_url <- result.try(with_default(
    toml,
    "api_url",
    tom.as_string,
    "a string",
    defaults.api_url,
  ))
  use prebuild <- result.try(optional(
    toml,
    "prebuild",
    tom.as_string,
    "a string",
  ))
  use artifact <- result.try(optional(
    toml,
    "artifact",
    tom.as_string,
    "a string",
  ))
  use watch <- result.try(with_default(
    toml,
    "watch",
    strings,
    "a list of strings",
    default_watch(defaults.watch, assets),
  ))

  Ok(Config(
    package:,
    target:,
    entry:,
    assets:,
    outdir:,
    esbuild_args:,
    spa:,
    watch:,
    port:,
    live_reload:,
    api_url:,
    prebuild:,
    artifact:,
  ))
}

fn default_watch(source: List(String), assets: Option(String)) -> List(String) {
  case assets {
    Some(path) -> list.append(source, [path])
    None -> source
  }
}

fn read_target(toml) -> Result(Target, Error) {
  case tom.get_string(toml, ["target"]) {
    Ok("javascript") -> Ok(Javascript)
    Ok("erlang") -> Ok(Erlang)
    Ok(other) -> Error(UnknownTarget(other))
    Error(tom.NotFound(_)) -> Ok(Erlang)
    Error(tom.WrongType(..)) ->
      Error(InvalidValue(key: "target", expected: "a string"))
  }
}

fn read_entry(toml, default: String) -> Result(String, Error) {
  use entry <- result.try(with_default(
    toml,
    "entry",
    tom.as_string,
    "a string",
    default,
  ))

  validate_module_name(entry)
}

fn read_port(toml, default: Int) -> Result(Int, Error) {
  use port <- result.try(with_default(
    toml,
    "port",
    tom.as_int,
    "a whole number",
    default,
  ))

  case port >= 1 && port <= 65_535 {
    True -> Ok(port)
    False -> Error(InvalidPort(port))
  }
}

fn optional(
  toml,
  key: String,
  convert: fn(tom.Toml) -> Result(a, tom.GetError),
  expected: String,
) -> Result(Option(a), Error) {
  case lookup(toml, key, convert) {
    Ok(value) -> Ok(Some(value))
    Error(tom.NotFound(_)) -> Ok(None)
    Error(tom.WrongType(..)) -> Error(InvalidValue(key:, expected:))
  }
}

fn with_default(
  toml,
  key: String,
  convert: fn(tom.Toml) -> Result(a, tom.GetError),
  expected: String,
  default: a,
) -> Result(a, Error) {
  optional(toml, key, convert, expected)
  |> result.map(option.unwrap(_, default))
}

fn lookup(
  toml,
  key: String,
  convert: fn(tom.Toml) -> Result(a, tom.GetError),
) -> Result(a, tom.GetError) {
  tom.get(toml, ["tools", "giolt", key]) |> result.try(convert)
}

fn strings(value: tom.Toml) -> Result(List(String), tom.GetError) {
  use items <- result.try(tom.as_array(value))
  list.try_map(items, tom.as_string)
}

fn validate_module_name(name: String) -> Result(String, Error) {
  let assert Ok(pattern) =
    regexp.from_string("^[a-z][a-z0-9_]*(/[a-z][a-z0-9_]*)*$")

  case regexp.check(pattern, name) {
    True -> Ok(name)
    False -> Error(InvalidEntry(name))
  }
}

pub fn compiled_entry(config: Config) -> String {
  "./build/dev/javascript/" <> config.package <> "/" <> config.entry <> ".mjs"
}

pub fn describe_error(error: Error) -> String {
  case error {
    InvalidToml -> "Could not parse gleam.toml: it is not valid TOML."
    MissingName -> "gleam.toml has no `name`."
    UnknownTarget(target) ->
      "Unknown target `"
      <> target
      <> "` in gleam.toml. Use \"erlang\" or \"javascript\"."
    InvalidEntry(entry) ->
      "`entry` under [tools.giolt] must be a Gleam module name such as "
      <> "`my_app` or `my_app/server`, not `"
      <> entry
      <> "`."
    InvalidPort(port) ->
      "`port` under [tools.giolt] must be between 1 and 65535, not "
      <> int.to_string(port)
      <> "."
    InvalidValue(key:, expected:) ->
      "`" <> key <> "` must be " <> expected <> "."
  }
}
