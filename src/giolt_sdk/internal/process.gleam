pub fn run(command: String, args: List(String)) -> Result(Nil, String) {
  run_in(".", command, args)
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "run")
pub fn run_in(
  directory: String,
  command: String,
  args: List(String),
) -> Result(Nil, String)

@target(erlang)
pub fn run_in(
  _directory: String,
  _command: String,
  _args: List(String),
) -> Result(Nil, String) {
  Error("Giolt only supports the `javascript` target.")
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
