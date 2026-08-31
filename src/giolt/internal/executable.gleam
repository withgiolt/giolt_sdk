@external(erlang, "erlang", "binary")
@external(javascript, "javascript", "string")
pub type ExecutablePath

@external(erlang, "executable_ffi", "run_executable")
@external(javascript, "./executable_ffi.mjs", "runExecutable")
pub fn run(
  executable_path path: ExecutablePath,
  working_directory directory: String,
  command_line_arguments arguments: List(String),
) -> Result(Int, Nil)

@external(erlang, "executable_ffi", "find_executable")
@external(javascript, "./executable_ffi.mjs", "findExecutable")
pub fn find(name: String) -> Result(ExecutablePath, Nil)
