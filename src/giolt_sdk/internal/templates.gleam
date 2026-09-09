import gleam/string

pub const build_path = "src/build.gleam"

pub const deploy_path = "src/deploy.gleam"

pub fn dev_path(project: String) -> String {
  "src/" <> project <> "_dev.gleam"
}

pub fn dev_module(project: String) -> String {
  project <> "_dev"
}

const build_template = "import giolt_sdk/bundle

pub fn main() {
  bundle.new()
  |> bundle.entry(\"./build/dev/javascript/{name}/{name}.mjs\")
  |> bundle.static_dir(\"./public\")
  |> bundle.outdir(\"./dist\")
  |> bundle.run
}
"

const deploy_template = "import build
import giolt_sdk/deploy
import gleam/javascript/promise

pub fn main() {
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
  |> dev.prebuild(fn() { Ok(Nil) })
  |> dev.build(fn(_change) {
    use _ <- result.try(dev.compile())

    bundle.new()
    |> bundle.entry(\"./build/dev/javascript/{name}/{name}.mjs\")
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
