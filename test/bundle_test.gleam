import giolt_sdk/bundle
import giolt_sdk/internal/entry
import giolt_sdk/internal/project
import gleam/option
import gleam/string

pub fn default_outdir_test() {
  assert bundle.default_outdir == "./dist"
}

pub fn describe_error_entry_not_compiled_test() {
  let message =
    bundle.describe_error(bundle.EntryNotCompiled(
      "./build/dev/javascript/app/app.mjs",
    ))

  assert string.contains(message, "./build/dev/javascript/app/app.mjs")
}

pub fn describe_error_invalid_entry_test() {
  let message =
    bundle.describe_error(bundle.InvalidEntry(entry.MissingHandler("app")))

  assert string.contains(message, "handler")
}

pub fn describe_error_static_dir_not_found_test() {
  let message = bundle.describe_error(bundle.StaticDirNotFound("./public"))

  assert string.contains(message, "./public")
}

pub fn is_unsafe_outdir_current_dir_test() {
  assert bundle.is_unsafe_outdir(".")
  assert bundle.is_unsafe_outdir("./")
  assert bundle.is_unsafe_outdir("")
  assert bundle.is_unsafe_outdir("..")
  assert bundle.is_unsafe_outdir("/")
}

pub fn is_unsafe_outdir_trims_whitespace_test() {
  assert bundle.is_unsafe_outdir(" . ")
}

pub fn is_unsafe_outdir_allows_real_dirs_test() {
  assert !bundle.is_unsafe_outdir("./dist")
  assert !bundle.is_unsafe_outdir("dist")
  assert !bundle.is_unsafe_outdir("../dist")
}

pub fn describe_error_unsafe_outdir_test() {
  let message = bundle.describe_error(bundle.UnsafeOutdir("."))

  assert string.contains(message, "./dist")
}

pub fn describe_error_cannot_load_project_test() {
  let message =
    bundle.describe_error(bundle.CannotLoadProject(
      project.CannotReadProjectName,
    ))

  assert string.contains(message, "gleam.toml")
}

pub fn discard_output_ok_test() {
  let output =
    bundle.Output(outdir: "./dist", entry: "app", static_dir: option.None)

  assert bundle.discard_output(Ok(output)) == Ok(Nil)
}

pub fn discard_output_error_test() {
  let error = bundle.EntryNotCompiled("./build/dev/javascript/app/app.mjs")

  assert bundle.discard_output(Error(error))
    == Error(bundle.describe_error(error))
}
