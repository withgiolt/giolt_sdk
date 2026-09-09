//// A small glob matcher for `dev.ignore`.
////
//// Deliberately limited to what a watch list needs: `*` matches within one
//// path segment, `**` matches across segments, `?` matches one character.
//// Pure, so the matching rules are unit testable.

import gleam/list
import gleam/regexp
import gleam/string

/// Does a path match a glob pattern?
///
/// Paths are normalised first, so `./src/app.gleam`, `src/app.gleam` and
/// `src\\app.gleam` all match `src/*.gleam`. A bare pattern with no slash — say
/// `*.gleam` — is matched against the file name as well as the whole path, so
/// ignoring `*.css` does not require knowing which directory the file is in.
pub fn matches(pattern pattern: String, path path: String) -> Bool {
  let path = normalise(path)
  let pattern = normalise(pattern)

  case compile(pattern) {
    Error(_) -> False
    Ok(re) ->
      regexp.check(re, path)
      || { !string.contains(pattern, "/") && regexp.check(re, base_name(path)) }
  }
}

/// Does a path match any of the patterns?
pub fn matches_any(patterns patterns: List(String), path path: String) -> Bool {
  list.any(patterns, fn(pattern) { matches(pattern, path) })
}

/// Strip the `./` prefix and normalise separators so that patterns and paths
/// are compared in the same shape.
pub fn normalise(path: String) -> String {
  let path = string.replace(path, "\\", "/")

  case string.starts_with(path, "./") {
    True -> string.drop_start(path, 2)
    False -> path
  }
}

fn base_name(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(name) -> name
    Error(_) -> path
  }
}

fn compile(pattern: String) -> Result(regexp.Regexp, regexp.CompileError) {
  regexp.from_string("^" <> to_regexp_source(pattern) <> "$")
}

/// Translate a glob into a regular expression source string.
///
/// `**/` is allowed to match nothing at all, so `**/*.gleam` matches
/// `app.gleam` as well as `src/app.gleam`.
fn to_regexp_source(pattern: String) -> String {
  pattern
  |> string.to_graphemes
  |> consume("")
}

fn consume(graphemes: List(String), acc: String) -> String {
  case graphemes {
    [] -> acc

    ["*", "*", "/", ..rest] -> consume(rest, acc <> "(?:.*/)?")
    ["*", "*", ..rest] -> consume(rest, acc <> ".*")
    ["*", ..rest] -> consume(rest, acc <> "[^/]*")
    ["?", ..rest] -> consume(rest, acc <> "[^/]")

    [grapheme, ..rest] -> consume(rest, acc <> escape(grapheme))
  }
}

fn escape(grapheme: String) -> String {
  case grapheme {
    "." | "+" | "(" | ")" | "[" | "]" | "{" | "}" | "^" | "$" | "|" | "\\" ->
      "\\" <> grapheme
    grapheme -> grapheme
  }
}
