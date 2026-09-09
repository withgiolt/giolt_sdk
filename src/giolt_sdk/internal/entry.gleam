//// Everything the SDK needs to decide about a user's entry module.
////
//// All of the functions in here are pure: they take strings and lists and
//// return values. Reading the compiled module off disk happens in
//// `giolt_sdk/bundle`, so this module is directly unit testable.

import gleam/int
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string

/// The compilation target of the user's project, read from `gleam.toml`.
pub type Target {
  Javascript
  Erlang
}

/// A function exported by a compiled module.
pub type Export {
  Export(name: String, arity: Int)
}

/// Why an entry module is not a usable Giolt entry.
pub type InvalidEntry {
  /// The module does not export a `handler` function at all.
  MissingHandler(module: String)
  /// The module exports `handler`, but it does not take a single request.
  HandlerWrongArity(module: String, found: Int)
  /// We do not know how to check entries for this target yet.
  CheckUnsupported(target: String)
}

/// The name a Giolt entry module must export.
pub const handler_name = "handler"

/// Turn any of the spellings a user might reasonably write into a module path.
///
/// ```gleam
/// normalise("src/app.gleam")  // -> "app"
/// normalise("app.gleam")      // -> "app"
/// normalise("./app")          // -> "app"
/// normalise("app/server")     // -> "app/server"
/// ```
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

/// Where the Gleam compiler puts the JavaScript for a module.
pub fn compiled_path(project project: String, module module: String) -> String {
  "./build/dev/javascript/" <> project <> "/" <> module <> ".mjs"
}

/// The specifier the generated worker shim uses to import the entry module.
///
/// The shim lives in `build/dev/javascript/_giolt_build/`, one directory up
/// from the package directories, so entries are reached as `../{project}/…`.
pub fn shim_specifier(
  project project: String,
  module module: String,
) -> String {
  "../" <> project <> "/" <> module <> ".mjs"
}

/// Read the exported functions out of a compiled JavaScript module.
///
/// Gleam's JavaScript codegen emits top level `export function name(a, b) {`
/// declarations, so a source scan is enough and — unlike a dynamic `import()`
/// — it keeps `bundle.run` synchronous.
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

/// Decide whether a module's exports make it a valid entry for the target.
///
/// On JavaScript an entry must export `handler` taking exactly one argument,
/// the request. Whether it returns a `Response` or a `Promise(Response)` is not
/// visible in the compiled JavaScript, and the worker shim awaits the result
/// either way, so that half is deliberately not checked.
pub fn validate(
  target target: Target,
  module module: String,
  exports exports: List(Export),
) -> Result(Nil, InvalidEntry) {
  case target {
    Javascript -> validate_javascript(module, exports)

    // TODO: the Erlang target is not supported yet. When it is, an entry will
    // need a different shape check here (an exported `handler/1` in the
    // generated `.erl`, most likely) rather than the JavaScript one.
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

/// A message suitable for showing to the user.
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

/// Parse the `target` key of a `gleam.toml`. Absent means JavaScript, which is
/// what Giolt deploys.
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

/// Convenience for callers holding an optional target.
pub fn target_or_default(target: Result(Target, a)) -> Target {
  result.unwrap(target, Javascript)
}
