// Modified from Enderchief/esgleam - see https://github.com/withgiolt/esgleam
import giolt_sdk/internal/esgleam/esgleam.{Script}
import giolt_sdk/internal/esgleam/esgleam/internal

/// Bundles `gleam.main.mjs` as a script using ESM to the `./dist` directory.
/// Will run the main function in %{project_name}.gleam
pub fn main() {
  esgleam.new(outdir: "./dist")
  |> esgleam.entry(internal.get_project_name() <> ".gleam")
  |> esgleam.kind(Script)
  |> esgleam.bundle
}
