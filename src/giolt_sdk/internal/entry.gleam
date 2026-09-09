import gleam/int
import gleam/list
import gleam/option
import gleam/regexp
import gleam/string

pub type Target {
  Javascript
  Erlang
}

pub type Export {
  Export(name: String, arity: Int)
}

pub type InvalidEntry {
  MissingHandler(path: String)
  HandlerWrongArity(path: String, found: Int)
  CheckUnsupported(target: String)
}

pub const handler_name = "handler"

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
  path path: String,
  exports exports: List(Export),
) -> Result(Nil, InvalidEntry) {
  case target {
    Javascript -> validate_javascript(path, exports)
    // TODO: Erlang entries are not checked yet.
    Erlang -> Error(CheckUnsupported("erlang"))
  }
}

fn validate_javascript(
  path: String,
  exports: List(Export),
) -> Result(Nil, InvalidEntry) {
  case list.find(exports, fn(export) { export.name == handler_name }) {
    Error(_) -> Error(MissingHandler(path))
    Ok(Export(arity: 1, ..)) -> Ok(Nil)
    Ok(Export(arity: arity, ..)) -> Error(HandlerWrongArity(path, arity))
  }
}

pub fn describe_invalid(error: InvalidEntry) -> String {
  case error {
    MissingHandler(path) ->
      "`"
      <> path
      <> "` does not export a `handler` function.\n"
      <> "  A Giolt entry file needs:\n"
      <> "    pub fn handler(request: Request(Body)) -> Response(Body)"

    HandlerWrongArity(path, found) ->
      "`"
      <> path
      <> "` exports `handler`, but it takes "
      <> int.to_string(found)
      <> " arguments.\n"
      <> "  A Giolt entry file needs `handler` to take a single request."

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
