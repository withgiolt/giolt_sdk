//// Inlining environment variables into the bundle.
////
//// Giolt exposes `PUBLIC_*` and `PRIVATE_*` variables to the deployed worker
//// as `process.env.*`. esbuild does that with `--define:`, which needs the
//// value baked in as a JavaScript literal.
////
//// `defines/1` is pure — it takes variables that have already been read and
//// returns flags — so the escaping rules are unit testable without touching a
//// real environment. `load/1` is the thin effectful reader beside it.

import envie
import gleam/dict
import gleam/list
import gleam/string

/// Prefixes that are inlined into the bundle. Anything else stays out.
pub const exposed_prefixes = ["PUBLIC_", "PRIVATE_"]

/// The env file read from the project root.
pub const env_file = ".env"

/// Build the `--define:` flags for a set of environment variables.
///
/// Variables whose name does not start with an exposed prefix are dropped, and
/// values are escaped so that quotes and backslashes survive the round trip.
pub fn defines(vars: List(#(String, String))) -> List(String) {
  vars
  |> list.filter(fn(var) { is_exposed(var.0) })
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
  |> list.map(fn(var) {
    "--define:process.env." <> var.0 <> "=" <> quote(var.1)
  })
}

/// Whether a variable name is one Giolt inlines into the bundle.
pub fn is_exposed(name: String) -> Bool {
  list.any(exposed_prefixes, fn(prefix) { string.starts_with(name, prefix) })
}

/// Escape a value as a double quoted JavaScript string literal.
pub fn quote(value: String) -> String {
  let escaped =
    value
    |> string.replace("\\", "\\\\")
    |> string.replace("\"", "\\\"")
    |> string.replace("\n", "\\n")
    |> string.replace("\r", "\\r")

  "\"" <> escaped <> "\""
}

/// Read `.env` from the project root, overriding what is already in the
/// process environment, and return every variable that is set.
pub fn load() -> List(#(String, String)) {
  let _ = envie.load_override_from(env_file)

  envie.all()
  |> dict.to_list
}
