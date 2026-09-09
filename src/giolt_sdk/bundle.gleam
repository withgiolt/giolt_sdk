//// Bundling a Gleam app for the Giolt platform.
////
//// Call this from your own `build.gleam`:
////
//// ```gleam
//// import giolt_sdk/bundle
////
//// pub fn main() {
////   bundle.new()
////   |> bundle.entry("app")
////   |> bundle.static_dir("./public")
////   |> bundle.outdir("./dist")
////   |> bundle.run
//// }
//// ```
////
//// Run it with `gleam run -m build`, which compiles your project on the way in.
//// The SDK never builds anything for you — whatever your app needs before the
//// bundle is plain Gleam code in `main`, above the `bundle.new()` call.
////
//// There is nothing to configure about the bundle itself. Giolt produces one
//// shape of artifact — a minified, tree shaken ESM bundle wrapped in the
//// platform's worker entry — and having already run esbuild over your own code
//// is fine; it gets bundled again to adapt it to the platform.

import filepath
import giolt_sdk/internal/entry
import giolt_sdk/internal/env
import giolt_sdk/internal/esbuild
import giolt_sdk/internal/esbuild_bin
import giolt_sdk/internal/io
import giolt_sdk/internal/project
import giolt_sdk/internal/shim
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile

/// A configuration that has not been given an entry module yet.
pub type NoEntry

/// A configuration that is ready to run.
pub type HasEntry

/// A bundle configuration.
///
/// The type parameter tracks whether an entry module has been set. `run` only
/// accepts a configuration that has one, so forgetting `entry` is a compile
/// error rather than something you find out about at build time.
pub opaque type Config(has_entry) {
  Config(entry: String, static_dir: Option(String), outdir: String)
}

/// What a successful bundle produced. Hand it to `deploy.from` to ship it.
pub type Output {
  Output(outdir: String, entry: String, static_dir: Option(String))
}

pub type Error {
  /// `gleam.toml` could not be read.
  CannotLoadProject(reason: project.Error)
  /// The entry module has not been compiled to JavaScript.
  EntryNotCompiled(expected_path: String)
  /// The entry module is not a valid Giolt entry.
  InvalidEntry(reason: entry.InvalidEntry)
  CannotClearOutdir(reason: simplifile.FileError)
  CannotWriteShim(reason: simplifile.FileError)
  CannotCopyStatic(reason: simplifile.FileError)
  StaticDirNotFound(path: String)
  EsbuildFailed(reason: String)
  /// `outdir` was set to something the SDK refuses to delete, such as `.` or
  /// the project root.
  UnsafeOutdir(path: String)
}

/// The default output directory, used unless `outdir` is called.
pub const default_outdir = "./dist"

/// Start a new bundle configuration.
pub fn new() -> Config(NoEntry) {
  Config(entry: "", static_dir: None, outdir: default_outdir)
}

/// The module holding your `handler` function.
///
/// Required. Any of `"app"`, `"app.gleam"` or `"src/app.gleam"` work, as do
/// nested modules such as `"app/server"`.
pub fn entry(config: Config(has_entry), module: String) -> Config(HasEntry) {
  let Config(static_dir:, outdir:, ..) = config
  Config(entry: module, static_dir:, outdir:)
}

/// A directory of files to serve as-is, copied to `{outdir}/static`.
pub fn static_dir(
  config: Config(has_entry),
  path: String,
) -> Config(has_entry) {
  let Config(entry:, outdir:, ..) = config
  Config(entry:, static_dir: Some(path), outdir:)
}

/// Where to write the bundle. Defaults to `./dist`.
pub fn outdir(config: Config(has_entry), path: String) -> Config(has_entry) {
  let Config(entry:, static_dir:, ..) = config
  Config(entry:, static_dir:, outdir: path)
}

/// Bundle the app.
///
/// Only compiles if `entry` has been set — `bundle.new() |> bundle.run` is a
/// type error.
pub fn run(config: Config(HasEntry)) -> Result(Output, Error) {
  let result = pipeline(config)

  case result {
    Ok(output) -> io.println_success("Bundled to " <> output.outdir)
    Error(error) -> io.println_error(describe_error(error))
  }

  result
}

fn pipeline(config: Config(HasEntry)) -> Result(Output, Error) {
  use project <- result.try(
    project.load() |> result.map_error(CannotLoadProject),
  )

  let module = entry.normalise(config.entry)
  use _ <- result.try(check_entry(project, module))

  use _ <- result.try(check_outdir(config.outdir))
  use _ <- result.try(clear_outdir(config.outdir))
  use _ <- result.try(write_shim(project.name, module))
  use _ <- result.try(run_esbuild(config.outdir))
  use _ <- result.try(copy_static(config.static_dir, config.outdir))

  Ok(Output(outdir: config.outdir, entry: module, static_dir: config.static_dir))
}

/// Check the entry module exists and looks like a Giolt entry before spending
/// time on a bundle that could never work.
fn check_entry(project: project.Project, module: String) -> Result(Nil, Error) {
  let path = entry.compiled_path(project: project.name, module: module)

  use source <- result.try(
    simplifile.read(path) |> result.replace_error(EntryNotCompiled(path)),
  )

  entry.validate(
    target: project.target,
    module: module,
    exports: entry.scan_exports(source),
  )
  |> result.map_error(InvalidEntry)
}

/// A short denylist of paths `outdir` must not be, since `clear_outdir` is
/// about to delete it outright. Catches the obvious typo —
/// `bundle.outdir(".")` deleting the whole project — not every way to point a
/// path at something it shouldn't touch.
const unsafe_outdirs = [".", "./", "", "..", "/"]

/// Would `outdir` be unsafe to pass to `clear_outdir`? Exposed so the
/// denylist can be unit tested directly.
pub fn is_unsafe_outdir(outdir: String) -> Bool {
  list.contains(unsafe_outdirs, string.trim(outdir))
}

fn check_outdir(outdir: String) -> Result(Nil, Error) {
  case is_unsafe_outdir(outdir) {
    True -> Error(UnsafeOutdir(outdir))
    False -> Ok(Nil)
  }
}

fn clear_outdir(outdir: String) -> Result(Nil, Error) {
  case simplifile.is_directory(outdir) {
    Ok(True) -> simplifile.delete(outdir) |> result.map_error(CannotClearOutdir)
    Ok(False) | Error(_) -> Ok(Nil)
  }
}

fn write_shim(project_name: String, module: String) -> Result(Nil, Error) {
  let specifier = entry.shim_specifier(project: project_name, module: module)

  use _ <- result.try(
    simplifile.create_directory_all(shim.build_dir)
    |> result.map_error(CannotWriteShim),
  )

  simplifile.write(shim.path, shim.render(specifier))
  |> result.map_error(CannotWriteShim)
}

fn run_esbuild(outdir: String) -> Result(Nil, Error) {
  io.println_info("Bundling...")

  use exe <- result.try(
    esbuild_bin.ensure_installed() |> result.map_error(EsbuildFailed),
  )

  let plan =
    esbuild.Plan(
      entry: shim.path,
      outfile: filepath.join(outdir, "index.mjs"),
      defines: env.defines(env.load()),
    )

  esbuild_bin.run(exe, esbuild.flags(plan))
  |> result.map_error(EsbuildFailed)
}

fn copy_static(
  static_dir: Option(String),
  outdir: String,
) -> Result(Nil, Error) {
  case static_dir {
    None -> Ok(Nil)
    Some(path) ->
      case simplifile.is_directory(path) {
        Ok(True) ->
          simplifile.copy_directory(path, filepath.join(outdir, "static"))
          |> result.map_error(CannotCopyStatic)
        Ok(False) | Error(_) -> Error(StaticDirNotFound(path))
      }
  }
}

/// A message suitable for showing to the user.
pub fn describe_error(error: Error) -> String {
  case error {
    CannotLoadProject(reason) -> project.describe_error(reason)

    EntryNotCompiled(path) ->
      "Could not find the compiled entry module at "
      <> path
      <> ".\n"
      <> "  Check the module name passed to `bundle.entry`, and that the "
      <> "project compiles for the javascript target."

    InvalidEntry(reason) -> entry.describe_invalid(reason)

    CannotClearOutdir(reason) ->
      "Could not clear the output directory: " <> string.inspect(reason)

    CannotWriteShim(reason) ->
      "Could not write the worker entry: " <> string.inspect(reason)

    CannotCopyStatic(reason) ->
      "Could not copy the static directory: " <> string.inspect(reason)

    StaticDirNotFound(path) -> "No such static directory: " <> path

    EsbuildFailed(reason) -> "Bundling failed: " <> reason

    UnsafeOutdir(path) ->
      "Refusing to use `"
      <> path
      <> "` as the output directory — it gets deleted before every bundle. "
      <> "Pick something more specific, like `./dist`."
  }
}

/// Turn a bundle result into the shape `dev.build` expects.
///
/// ```gleam
/// |> dev.build(fn(_change) {
///   bundle.new()
///   |> bundle.entry("app")
///   |> bundle.run
///   |> bundle.discard_output
/// })
/// ```
pub fn discard_output(result: Result(Output, Error)) -> Result(Nil, String) {
  case result {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(describe_error(error))
  }
}
