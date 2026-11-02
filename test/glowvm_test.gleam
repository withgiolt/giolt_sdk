import giolt/internal/glowvm
import gleam/string

pub fn start_calls_handle_through_a_lambda_test() {
  let source = glowvm.start_source("hello")

  assert string.contains(source, "glowvm.serve(fn(req) { user.handle(req) })")
  assert !string.contains(source, "glowvm.serve(user.handle)")
}

pub fn start_is_a_zero_argument_function_test() {
  assert string.contains(glowvm.start_source("hello"), "pub fn start() {")
}

pub fn start_imports_the_entry_module_under_a_fixed_alias_test() {
  assert string.contains(glowvm.start_source("hello"), "import hello as user\n")
  assert string.contains(
    glowvm.start_source("my_app/server"),
    "import my_app/server as user\n",
  )
}

pub fn build_package_depends_on_the_project_and_the_runtime_test() {
  let toml = glowvm.gleam_toml(package: "hello", project_path: "../../..")

  assert string.contains(toml, "name = \"giolt_glowvm_build\"\n")
  assert string.contains(toml, "target = \"erlang\"\n")
  assert string.contains(toml, "hello = { path = \"../../..\" }\n")
  assert string.contains(toml, "glowvm = \">= 0.2.0 and < 1.0.0\"\n")
  assert string.contains(toml, "orbital = ")
}

pub fn pack_source_packs_the_start_module_into_the_archive_test() {
  let source = glowvm.pack_source()

  assert string.contains(
    source,
    "packbeam_create(\"build/app.avm\", \"giolt_glowvm_start\",",
  )
  assert !string.contains(source, "{archive}")
  assert !string.contains(source, "{start_module}")
}

pub fn pack_source_skips_priv_directories_test() {
  assert string.contains(glowvm.pack_source(), "\"priv\"")
}

pub fn runtime_files_are_what_the_platform_loads_test() {
  assert glowvm.runtime_files() == ["glowvm.wasm", "index.js", "index.min.js"]
}
