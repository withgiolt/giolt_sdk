//// The dev server: static files first, then the bundled worker.
////
//// `Option(String)` is converted to a plain string at the boundary (`""`
//// meaning "no static dir") so that `ffi_server.mjs` never needs to know how
//// Gleam represents `Option`.

import gleam/option.{type Option}

/// Start the dev server. Never returns.
pub fn serve(
  port port: Int,
  static_dir static_dir: Option(String),
  worker_path worker_path: String,
  live_reload live_reload: Bool,
) -> Nil {
  do_serve(port, option.unwrap(static_dir, ""), worker_path, live_reload)
}

@external(javascript, "./ffi_server.mjs", "serve")
fn do_serve(
  port: Int,
  static_dir: String,
  worker_path: String,
  live_reload: Bool,
) -> Nil

/// Tell the running server the worker has been rebuilt: the next request
/// re-imports it, and connected browsers are told to reload.
@external(javascript, "./ffi_server.mjs", "notify_reload")
pub fn notify_reload() -> Nil
