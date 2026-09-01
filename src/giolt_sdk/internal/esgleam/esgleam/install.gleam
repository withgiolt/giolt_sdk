// Modified from Enderchief/esgleam - see https://github.com/withgiolt/esgleam
import giolt_sdk/internal/esgleam/esgleam/mod/install

/// Installs `esbuild` (required to be run before building)
/// Run with `gleam run -m esgleam/install`
pub fn main() {
  install.internal_fetch()
}
