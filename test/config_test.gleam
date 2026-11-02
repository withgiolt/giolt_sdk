import giolt_sdk/internal/config.{Config, Erlang, Javascript}

pub fn entry_defaults_to_the_package_module_test() {
  let source = "name = \"my_app\"\nversion = \"1.0.0\"\n"

  assert config.parse(source)
    == Ok(Config(package: "my_app", target: Erlang, entry: "my_app"))
}

pub fn target_is_read_from_gleam_toml_test() {
  let source = "name = \"my_app\"\ntarget = \"javascript\"\n"

  assert config.parse(source)
    == Ok(Config(package: "my_app", target: Javascript, entry: "my_app"))
}

pub fn entry_is_read_from_tools_giolt_test() {
  let source =
    "name = \"my_app\"\ntarget = \"javascript\"\n\n[tools.giolt]\nentry = \"my_app/server\"\n"

  assert config.parse(source)
    == Ok(Config(package: "my_app", target: Javascript, entry: "my_app/server"))
}

pub fn other_tools_tables_are_ignored_test() {
  let source =
    "name = \"my_app\"\n\n[tools.other]\nentry = \"nope\"\n\n[tools.giolt]\n"

  assert config.parse(source)
    == Ok(Config(package: "my_app", target: Erlang, entry: "my_app"))
}

pub fn entry_that_is_not_a_module_name_is_rejected_test() {
  let build = fn(entry) {
    config.parse(
      "name = \"my_app\"\n[tools.giolt]\nentry = \"" <> entry <> "\"\n",
    )
  }

  assert build("src/my_app.gleam")
    == Error(config.InvalidEntry("src/my_app.gleam"))
  assert build("My_App") == Error(config.InvalidEntry("My_App"))
  assert build("") == Error(config.InvalidEntry(""))
  assert build("my_app/") == Error(config.InvalidEntry("my_app/"))
}

pub fn entry_that_is_not_a_string_is_rejected_test() {
  let source = "name = \"my_app\"\n[tools.giolt]\nentry = 3\n"

  assert config.parse(source) == Error(config.EntryNotAString)
}

pub fn unknown_target_is_rejected_test() {
  let source = "name = \"my_app\"\ntarget = \"wasm\"\n"

  assert config.parse(source) == Error(config.UnknownTarget("wasm"))
}

pub fn missing_name_is_rejected_test() {
  assert config.parse("version = \"1.0.0\"\n") == Error(config.MissingName)
}

pub fn invalid_toml_is_rejected_test() {
  assert config.parse("name = ") == Error(config.InvalidToml)
}

pub fn target_that_is_not_a_string_is_rejected_test() {
  assert config.parse("name = \"my_app\"\ntarget = 3\n")
    == Error(config.TargetNotAString)
}
