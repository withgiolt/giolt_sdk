//// Watching files for changes.
////
//// The FFI side (`ffi_watcher.mjs`) only ever hands back a bare path and a
//// raw kind string — it does not know about `giolt_sdk/dev`'s `ChangeKind`
//// type, so there is nothing there for it to construct. Turning that string
//// into a typed value, and deciding whether a change should be ignored, is
//// ordinary — and testable — Gleam code.

/// The three kinds of change `ffi_watcher.mjs` reports.
pub const created = "created"

pub const modified = "modified"

pub const deleted = "deleted"

/// Start watching a list of directories, recursively.
///
/// `on_change` is called with a path (relative to the working directory, `/`
/// separated) and a raw kind string — one of `created`, `modified` or
/// `deleted`. Returns a function that stops every watcher.
@external(javascript, "./ffi_watcher.mjs", "watch")
pub fn watch(
  paths paths: List(String),
  on_change on_change: fn(String, String) -> Nil,
) -> fn() -> Nil
