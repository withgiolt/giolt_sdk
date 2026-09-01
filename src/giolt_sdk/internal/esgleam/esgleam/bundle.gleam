// Modified from Enderchief/esgleam - see https://github.com/withgiolt/esgleam
import giolt_sdk/internal/esgleam/esgleam
import giolt_sdk/internal/esgleam/esgleam/internal
import gleam/io

/// Bundles {%project_name}.gleam as a library using ESM to the `./dist` directory.
pub fn main() {
  case
    esgleam.new(outdir: "./dist")
    |> esgleam.entry(internal.get_project_name() <> ".gleam")
    |> esgleam.bundle
  {
    Ok(_) -> io.println("Bundled")
    Error(msg) -> io.println_error(msg)
  }
}
