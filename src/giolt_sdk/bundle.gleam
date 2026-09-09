import filepath
import giolt_sdk/internal/esbuild
import giolt_sdk/internal/esbuild_bin
import giolt_sdk/internal/io
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
  EntryFileNotFound(path: String)
  CannotClearOutdir(reason: simplifile.FileError)
  CannotWriteShim(reason: simplifile.FileError)
  CannotCopyStatic(reason: simplifile.FileError)
  StaticDirNotFound(path: String)
  EsbuildFailed(reason: String)
  UnsafeOutdir(path: String)
  EntryInsideOutdir(entry: String, outdir: String)
}

pub const default_outdir = "./dist"

pub fn new() -> Config(NoEntry) {
  Config(entry: "", static_dir: None, outdir: default_outdir)
}

pub fn entry(config: Config(has_entry), path: String) -> Config(HasEntry) {
  let Config(static_dir:, outdir:, ..) = config
  Config(entry: path, static_dir:, outdir:)
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
  use _ <- result.try(check_entry(config.entry))
  use _ <- result.try(check_outdir(config.outdir, config.entry))
  use _ <- result.try(clear_outdir(config.outdir))
  use _ <- result.try(write_shim(config.entry))
  use _ <- result.try(run_esbuild(config.outdir))
  use _ <- result.try(copy_static(config.static_dir, config.outdir))

  Ok(Output(
    outdir: config.outdir,
    entry: config.entry,
    static_dir: config.static_dir,
  ))
}

fn check_entry(entry_path: String) -> Result(Nil, Error) {
  case simplifile.is_file(entry_path) {
    Ok(True) -> Ok(Nil)
    Ok(False) | Error(_) -> Error(EntryFileNotFound(entry_path))
  }
}

const unsafe_outdirs = [".", "./", "", "..", "/"]

pub fn is_unsafe_outdir(outdir: String) -> Bool {
  list.contains(unsafe_outdirs, string.trim(outdir))
}

pub fn outdir_contains_entry(
  outdir outdir: String,
  entry entry: String,
) -> Bool {
  let outdir_norm = normalise_path(outdir)
  let entry_norm = normalise_path(entry)
  string.starts_with(entry_norm, outdir_norm <> "/")
}

fn normalise_path(path: String) -> String {
  let trimmed = string.trim(path)
  let without_prefix = case string.starts_with(trimmed, "./") {
    True -> string.drop_start(trimmed, 2)
    False -> trimmed
  }

  case string.ends_with(without_prefix, "/") {
    True -> string.drop_end(without_prefix, 1)
    False -> without_prefix
  }
}

fn check_outdir(outdir: String, entry_path: String) -> Result(Nil, Error) {
  case is_unsafe_outdir(outdir) {
    True -> Error(UnsafeOutdir(outdir))
    False ->
      case outdir_contains_entry(outdir: outdir, entry: entry_path) {
        True -> Error(EntryInsideOutdir(entry: entry_path, outdir: outdir))
        False -> Ok(Nil)
      }
  }
}

fn clear_outdir(outdir: String) -> Result(Nil, Error) {
  case simplifile.is_directory(outdir) {
    Ok(True) -> simplifile.delete(outdir) |> result.map_error(CannotClearOutdir)
    Ok(False) | Error(_) -> Ok(Nil)
  }
}

fn write_shim(entry_path: String) -> Result(Nil, Error) {
  let specifier = resolve_absolute(entry_path)

  use _ <- result.try(
    simplifile.create_directory_all(shim.build_dir)
    |> result.map_error(CannotWriteShim),
  )

  simplifile.write(shim.path, shim.render(specifier))
  |> result.map_error(CannotWriteShim)
}

@external(javascript, "./internal/ffi_paths.mjs", "resolve_absolute")
fn resolve_absolute(path: String) -> String

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
    EntryFileNotFound(path) ->
      "Could not find the entry file at "
      <> path
      <> ".\n"
      <> "  Check the path passed to `bundle.entry`. If it points at "
      <> "compiled Gleam output, make sure the project has been built for "
      <> "the javascript target first (`gleam build --target javascript`, "
      <> "or `dev.compile()`)."

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

    EntryInsideOutdir(entry, outdir) ->
      "`bundle.entry(\""
      <> entry
      <> "\")` points inside `bundle.outdir(\""
      <> outdir
      <> "\")`, which gets deleted before every bundle.\n"
      <> "  Point entry at your compiled Gleam module (e.g. under "
      <> "./build/dev/javascript/...), not at the bundle's own output."
  }
}

pub fn discard_output(result: Result(Output, Error)) -> Result(Nil, String) {
  case result {
    Ok(_) -> Ok(Nil)
    Error(error) -> Error(describe_error(error))
  }
}
