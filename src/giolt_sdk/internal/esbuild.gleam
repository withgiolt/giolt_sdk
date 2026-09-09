//// Constructing the esbuild invocation.
////
//// Giolt bundles every app the same way, so there is nothing to configure
//// here — the only thing that varies between projects is the entry, the
//// output path and the inlined environment variables. `flags/1` is pure, so
//// the exact argument list is unit testable without ever spawning esbuild.

import gleam/list

/// Where the esbuild binary is downloaded to.
pub const install_dir = "./build/dev/bin/package/bin"

/// Everything that varies between one bundle and the next.
pub type Plan {
  Plan(
    /// Entry point handed to esbuild — the generated worker shim.
    entry: String,
    /// Single file esbuild writes.
    outfile: String,
    /// `--define:` flags, from `giolt_sdk/internal/env`.
    defines: List(String),
  )
}

/// The full esbuild argument list for a plan.
///
/// The fixed flags are what the Giolt runtime expects: a single minified ESM
/// bundle with tree shaking, targeting the node platform.
pub fn flags(plan: Plan) -> List(String) {
  list.flatten([
    [plan.entry],
    [
      "--bundle",
      "--format=esm",
      "--platform=node",
      "--minify",
      "--tree-shaking=true",
      "--outfile=" <> plan.outfile,
    ],
    plan.defines,
  ])
}

/// Path of the esbuild executable, given the platform's executable name.
pub fn exe_path(exe_name: String) -> String {
  install_dir <> "/" <> exe_name
}

/// The npm tarball holding the esbuild binary for a platform, for example
/// `linux-x64`.
pub fn tarball_url(package: String) -> String {
  "https://registry.npmjs.org/@esbuild/"
  <> package
  <> "/-/"
  <> package
  <> "-"
  <> version
  <> ".tgz"
}

/// The esbuild version Giolt bundles with.
pub const version = "0.28.2"
