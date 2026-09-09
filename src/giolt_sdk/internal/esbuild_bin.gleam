import giolt_sdk/internal/esbuild
import giolt_sdk/internal/esgleam/esgleam/mod/platform
import giolt_sdk/internal/io
import simplifile

pub fn ensure_installed() -> Result(String, String) {
  let exe = esbuild.exe_path(platform.get_exe_name())

  case simplifile.is_file(exe) {
    Ok(True) -> Ok(exe)
    Ok(False) | Error(_) -> {
      io.println_info("Downloading esbuild " <> esbuild.version <> "...")

      let url = esbuild.tarball_url(platform.get_package_name())
      case install(url, esbuild.install_dir, platform.get_exe_name()) {
        Ok(_) -> Ok(exe)
        Error(reason) -> Error(reason)
      }
    }
  }
}

pub fn run(exe: String, args: List(String)) -> Result(Nil, String) {
  exec(exe, args)
}

@target(javascript)
@external(javascript, "./ffi_esbuild.mjs", "exec")
fn exec(command: String, args: List(String)) -> Result(Nil, String)

@target(erlang)
fn exec(_command: String, _args: List(String)) -> Result(Nil, String) {
  Error("Giolt only supports the `javascript` target.")
}

@target(javascript)
@external(javascript, "./ffi_esbuild.mjs", "install")
fn install(
  url: String,
  directory: String,
  exe_name: String,
) -> Result(Nil, String)

@target(erlang)
fn install(
  _url: String,
  _directory: String,
  _exe_name: String,
) -> Result(Nil, String) {
  Error("Giolt only supports the `javascript` target.")
}
