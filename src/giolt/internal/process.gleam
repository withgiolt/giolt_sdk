import gleam/javascript/promise.{type Promise}

pub fn run(
  command: String,
  args: List(String),
) -> Promise(Result(Nil, String)) {
  run_in(".", command, args)
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "run")
pub fn run_in(
  directory: String,
  command: String,
  args: List(String),
) -> Promise(Result(Nil, String))

@target(erlang)
pub fn run_in(
  _directory: String,
  _command: String,
  _args: List(String),
) -> Promise(Result(Nil, String)) {
  promise.resolve(Error("Giolt only supports the `javascript` target."))
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "shell")
pub fn shell(command: String) -> Promise(Result(Nil, String))

@target(erlang)
pub fn shell(_command: String) -> Promise(Result(Nil, String)) {
  promise.resolve(Error("Giolt only supports the `javascript` target."))
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "forever")
pub fn forever() -> Promise(Nil)

@target(erlang)
pub fn forever() -> Promise(Nil) {
  promise.resolve(Nil)
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "available")
pub fn available(command: String, args: List(String)) -> Bool

@target(erlang)
pub fn available(_command: String, _args: List(String)) -> Bool {
  False
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "exit")
pub fn exit(code: Int) -> Nil

@target(erlang)
pub fn exit(_code: Int) -> Nil {
  Nil
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "is_interactive")
pub fn is_interactive() -> Bool

@target(erlang)
pub fn is_interactive() -> Bool {
  False
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "read_line")
pub fn read_line(prompt: String) -> Promise(String)

@target(erlang)
pub fn read_line(_prompt: String) -> Promise(String) {
  promise.resolve("")
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "sleep")
pub fn sleep(milliseconds: Int) -> Promise(Nil)

@target(erlang)
pub fn sleep(_milliseconds: Int) -> Promise(Nil) {
  promise.resolve(Nil)
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "open_url")
pub fn open_url(url: String) -> Nil

@target(erlang)
pub fn open_url(_url: String) -> Nil {
  Nil
}
