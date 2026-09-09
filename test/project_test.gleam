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
