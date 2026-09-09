import gleam/option.{type Option}

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

@external(javascript, "./ffi_server.mjs", "notify_reload")
pub fn notify_reload() -> Nil
