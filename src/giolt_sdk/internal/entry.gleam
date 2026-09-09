import gleam/int
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string

pub type Target {
  Javascript
  Erlang
}

pub type Export {
  Export(name: String, arity: Int)
}

pub type InvalidEntry {
  MissingHandler(module: String)
  HandlerWrongArity(module: String, found: Int)
  CheckUnsupported(target: String)
}

pub const handler_name = "handler"

pub fn normalise(entry: String) -> String {
  entry
  |> string.trim
  |> string.replace("\\", "/")
  |> drop_prefix("./")
  |> drop_prefix("src/")
  |> drop_suffix(".gleam")
  |> drop_suffix(".mjs")
  |> trim_slashes
}

pub fn compiled_path(project project: String, module module: String) -> String {
  "./build/dev/javascript/" <> project <> "/" <> module <> ".mjs"
}

pub fn shim_specifier(
  project project: String,
  module module: String,
) -> String {
  "../" <> project <> "/" <> module <> ".mjs"
}

pub fn scan_exports(source: String) -> List(Export) {
  let assert Ok(re) =
    regexp.from_string(
      "export\\s+(?:async\\s+)?function\\s+(\\w+)\\s*\\(([^)]*)\\)",
    )

  regexp.scan(re, source)
  |> list.filter_map(fn(match) {
    case match.submatches {
      [option.Some(name), params] ->
        Ok(Export(name: name, arity: count_params(params)))
      [option.Some(name)] -> Ok(Export(name: name, arity: 0))
      _ -> Error(Nil)
    }
  })
}

pub fn validate(
  target target: Target,
  module module: String,
  exports exports: List(Export),
) -> Result(Nil, InvalidEntry) {
  case target {
    Javascript -> validate_javascript(module, exports)
    // TODO: Erlang entries are not checked yet.
    Erlang -> Error(CheckUnsupported("erlang"))
  }
}

fn validate_javascript(
  module: String,
  exports: List(Export),
) -> Result(Nil, InvalidEntry) {
  case list.find(exports, fn(export) { export.name == handler_name }) {
    Error(_) -> Error(MissingHandler(module))
    Ok(Export(arity: 1, ..)) -> Ok(Nil)
    Ok(Export(arity: arity, ..)) -> Error(HandlerWrongArity(module, arity))
  }
}

pub fn describe_invalid(error: InvalidEntry) -> String {
  case error {
    MissingHandler(module) ->
      "`"
      <> module
      <> "` does not export a `handler` function.\n"
      <> "  A Giolt entry module needs:\n"
      <> "    pub fn handler(request: Request(Body)) -> Response(Body)"

    HandlerWrongArity(module, found) ->
      "`"
      <> module
      <> "` exports `handler`, but it takes "
      <> int.to_string(found)
      <> " arguments.\n"
      <> "  A Giolt entry module needs `handler` to take a single request."

    CheckUnsupported(target) ->
      "Entry checking for the `"
      <> target
      <> "` target is not implemented yet. Giolt currently supports the "
      <> "`javascript` target only."
  }
}

fn count_params(params: option.Option(String)) -> Int {
  case string.trim(option.unwrap(params, "")) {
    "" -> 0
    text ->
      string.split(text, ",")
      |> list.filter(fn(param) { string.trim(param) != "" })
      |> list.length
  }
}

fn drop_prefix(value: String, prefix: String) -> String {
  case string.starts_with(value, prefix) {
    True -> string.drop_start(value, string.length(prefix))
    False -> value
  }
}

fn drop_suffix(value: String, suffix: String) -> String {
  case string.ends_with(value, suffix) {
    True -> string.drop_end(value, string.length(suffix))
    False -> value
  }
}

fn trim_slashes(value: String) -> String {
  value
  |> string.split("/")
  |> list.filter(fn(segment) { segment != "" })
  |> string.join("/")
}

pub fn target_from_string(value: String) -> Result(Target, Nil) {
  case string.trim(value) {
    "javascript" -> Ok(Javascript)
    "erlang" -> Ok(Erlang)
    _ -> Error(Nil)
  }
}

pub fn target_to_string(target: Target) -> String {
  case target {
    Javascript -> "javascript"
    Erlang -> "erlang"
  }
}

pub fn target_or_default(target: Result(Target, a)) -> Target {
  result.unwrap(target, Javascript)
}
