import gleam/javascript/promise.{type Promise}

@external(javascript, "./ffi_watcher.mjs", "watch")
pub fn watch(
  paths paths: List(String),
  on_change on_change: fn(List(String)) -> Promise(Nil),
) -> fn() -> Nil
