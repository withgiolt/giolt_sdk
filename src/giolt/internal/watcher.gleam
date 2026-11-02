@external(javascript, "./ffi_watcher.mjs", "watch")
pub fn watch(
  paths paths: List(String),
  on_change on_change: fn(String, String) -> Nil,
) -> fn() -> Nil
