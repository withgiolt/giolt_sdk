//// The files `gleam run -m giolt_sdk/init` scaffolds.
////
//// Pure string rendering, so what init would write can be asserted in tests
//// without touching the filesystem.

import gleam/string

/// Path of the scaffolded build script.
pub const build_path = "src/build.gleam"

/// Path of the scaffolded deploy script.
pub const deploy_path = "src/deploy.gleam"

/// Path of the scaffolded dev script, which is named after the project so it
/// sits next to the app module it drives.
pub fn dev_path(project: String) -> String {
  "src/" <> project <> "_dev.gleam"
}

/// The module name `gleam run -m ...` takes for the dev script.
pub fn dev_module(project: String) -> String {
  project <> "_dev"
}

const build_template = "import giolt_sdk/bundle

pub fn main() {
  // Your build steps go here. The SDK does not build anything for you, so this
  // is where you compile CSS, bundle client side code, run codegen, and so on:
  //
  //   let assert Ok(_) = tailwind.run(\"./src/app.css\", \"./public/app.css\")

  bundle.new()
  |> bundle.entry(\"{name}\")
  |> bundle.static_dir(\"./public\")
  |> bundle.outdir(\"./dist\")
  |> bundle.run
}
"

const deploy_template = "import build
import giolt_sdk/deploy
import gleam/javascript/promise

pub fn main() {
  // Build first, then ship exactly what the build produced. If you would
  // rather deploy a directory that is already there, drop these two lines and
  // use `deploy.artifact(\"./dist\")` instead of `deploy.from(output)`.
  let assert Ok(output) = build.main()

  deploy.new()
  |> deploy.project_id(\"prj_replace_me\")
  |> deploy.from(output)
  |> deploy.preview(True)
  |> deploy.token_from_env(\"GIOLT_TOKEN\")
  |> deploy.run
  |> promise.map(deploy.print_result)
}
"

const dev_template = "import giolt_sdk/bundle
import giolt_sdk/dev
import gleam/result

pub fn main() {
  dev.new()
  |> dev.watch(\"./src\")
  |> dev.watch(\"./public\")
  |> dev.ignore(\"**/*_dev.gleam\")
  |> dev.prebuild(fn() {
    // Runs once, before the first build.
    Ok(Nil)
  })
  |> dev.build(fn(_change) {
    // Runs on every change to a watched path. Recompile Gleam to JavaScript
    // first — `bundle.run` only ever bundles what is already in `./build`.
    use _ <- result.try(dev.compile())

    bundle.new()
    |> bundle.entry(\"{name}\")
    |> bundle.static_dir(\"./public\")
    |> bundle.run
    |> bundle.discard_output
  })
  |> dev.serve(port: 3000)
  |> dev.worker(\"./dist/index.mjs\")
  |> dev.static_dir(\"./public\")
  |> dev.live_reload(True)
  |> dev.run
}
"

pub fn render_build(project: String) -> String {
  render(build_template, project)
}

pub fn render_deploy(project: String) -> String {
  render(deploy_template, project)
}

pub fn render_dev(project: String) -> String {
  render(dev_template, project)
}

fn render(template: String, project: String) -> String {
  string.replace(template, "{name}", project)
}
