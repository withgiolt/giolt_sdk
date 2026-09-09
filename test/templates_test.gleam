import giolt_sdk/internal/templates
import gleam/string

pub fn dev_path_test() {
  assert templates.dev_path("app") == "src/app_dev.gleam"
}

pub fn dev_module_test() {
  assert templates.dev_module("app") == "app_dev"
}

pub fn render_build_mentions_entry_test() {
  let rendered = templates.render_build("app")

  assert string.contains(
    rendered,
    "bundle.entry(\"./build/dev/javascript/app/app.mjs\")",
  )
  assert string.contains(rendered, "import giolt_sdk/bundle")
}

pub fn render_deploy_imports_build_test() {
  let rendered = templates.render_deploy("app")

  assert string.contains(rendered, "import build")
  assert string.contains(rendered, "import giolt_sdk/deploy")
}

pub fn render_dev_mentions_entry_test() {
  let rendered = templates.render_dev("app")

  assert string.contains(
    rendered,
    "bundle.entry(\"./build/dev/javascript/app/app.mjs\")",
  )
  assert string.contains(rendered, "import giolt_sdk/dev")
}

pub fn render_dev_recompiles_gleam_test() {
  let rendered = templates.render_dev("app")

  assert string.contains(rendered, "dev.compile()")
}

pub fn templates_have_no_leftover_placeholder_test() {
  assert !string.contains(templates.render_build("app"), "{name}")
  assert !string.contains(templates.render_deploy("app"), "{name}")
  assert !string.contains(templates.render_dev("app"), "{name}")
}
