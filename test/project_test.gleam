import giolt_sdk/internal/entry
import giolt_sdk/internal/project

pub fn parse_name_test() {
  let source =
    "name = \"my_app\"\nversion = \"1.0.0\"\ntarget = \"javascript\"\n"

  assert project.parse_name(source) == Ok("my_app")
}

pub fn parse_name_ignores_unrelated_keys_test() {
  let source = "description = \"has a name in it\"\nname = \"real_name\"\n"

  assert project.parse_name(source) == Ok("real_name")
}

pub fn parse_name_missing_test() {
  assert project.parse_name("version = \"1.0.0\"\n") == Error(Nil)
}

pub fn parse_target_javascript_test() {
  let source = "name = \"app\"\ntarget = \"javascript\"\n"

  assert project.parse_target(source) == entry.Javascript
}

pub fn parse_target_erlang_test() {
  let source = "name = \"app\"\ntarget = \"erlang\"\n"

  assert project.parse_target(source) == entry.Erlang
}

pub fn parse_target_defaults_to_javascript_when_absent_test() {
  assert project.parse_target("name = \"app\"\n") == entry.Javascript
}

pub fn parse_target_defaults_to_javascript_when_invalid_test() {
  let source = "name = \"app\"\ntarget = \"nonsense\"\n"

  assert project.parse_target(source) == entry.Javascript
}
