import giolt_sdk/internal/esbuild
import gleam/list

pub fn flags_contains_entry_test() {
  let plan =
    esbuild.Plan(entry: "./shim.mjs", outfile: "./dist/index.mjs", defines: [])

  assert list.first(esbuild.flags(plan)) == Ok("./shim.mjs")
}

pub fn flags_contains_fixed_options_test() {
  let plan =
    esbuild.Plan(entry: "./shim.mjs", outfile: "./dist/index.mjs", defines: [])
  let flags = esbuild.flags(plan)

  assert list.contains(flags, "--bundle")
  assert list.contains(flags, "--format=esm")
  assert list.contains(flags, "--platform=node")
  assert list.contains(flags, "--minify")
  assert list.contains(flags, "--outfile=./dist/index.mjs")
}

pub fn flags_appends_defines_test() {
  let plan =
    esbuild.Plan(entry: "./shim.mjs", outfile: "./dist/index.mjs", defines: [
      "--define:process.env.PUBLIC_URL=\"x\"",
    ])

  assert list.contains(
    esbuild.flags(plan),
    "--define:process.env.PUBLIC_URL=\"x\"",
  )
}

pub fn exe_path_test() {
  assert esbuild.exe_path("esbuild") == "./build/dev/bin/package/bin/esbuild"
}

pub fn tarball_url_test() {
  assert esbuild.tarball_url("linux-x64")
    == "https://registry.npmjs.org/@esbuild/linux-x64/-/linux-x64-"
    <> esbuild.version
    <> ".tgz"
}
