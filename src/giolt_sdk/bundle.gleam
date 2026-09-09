import filepath
import giolt_sdk/internal/entry
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

pub type NoEntry

pub type HasEntry

pub opaque type Config(has_entry) {
  Config(entry: String, static_dir: Option(String), outdir: String)
}

pub type Output {
  Output(outdir: String, entry: String, static_dir: Option(String))
}

pub type Error {
  CannotLoadProject(reason: project.Error)
  EntryNotCompiled(expected_path: String)
  InvalidEntry(reason: entry.InvalidEntry)
  CannotClearOutdir(reason: simplifile.FileError)
  CannotWriteShim(reason: simplifile.FileError)
  CannotCopyStatic(reason: simplifile.FileError)
  StaticDirNotFound(path: String)
  EsbuildFailed(reason: String)
  UnsafeOutdir(path: String)
}

pub const default_outdir = "./dist"

pub fn new() -> Config(NoEntry) {
  Config(entry: "", static_dir: None, outdir: default_outdir)
}

pub fn entry(config: Config(has_entry), module: String) -> Config(HasEntry) {
  let Config(static_dir:, outdir:, ..) = config
  Config(entry: module, static_dir:, outdir:)
}

pub fn static_dir(
  config: Config(has_entry),
  path: String,
) -> Config(has_entry) {
  let Config(entry:, outdir:, ..) = config
  Config(entry:, static_dir: Some(path), outdir:)
}

pub fn outdir(config: Config(has_entry), path: String) -> Config(has_entry) {
  let Config(entry:, static_dir:, ..) = config
  Config(entry:, static_dir:, outdir: path)
}

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

const unsafe_outdirs = [".", "./", "", "..", "/"]

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
    esbuild.Plan(entry: shim.path, outfile: filepath.join(outdir, "index.mjs"))

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

pub fn discard_output(result: Result(Output, Error)) -> Result(Nil, String) {
  case result {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(describe_error(error))
  }
}
