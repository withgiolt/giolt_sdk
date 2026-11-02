@target(javascript)
@external(javascript, "./ffi_process.mjs", "run")
pub fn run(command: String, args: List(String)) -> Result(Nil, String)

@target(erlang)
pub fn run(_command: String, _args: List(String)) -> Result(Nil, String) {
  Error("Giolt only supports the `javascript` target.")
}

@target(javascript)
@external(javascript, "./ffi_process.mjs", "exit")
pub fn exit(code: Int) -> Nil

@target(erlang)
pub fn exit(_code: Int) -> Nil {
  Nil
}
