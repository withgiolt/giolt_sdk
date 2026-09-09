import giolt_sdk/bundle
import giolt_sdk/deploy
import gleam/list
import gleam/option
import gleam/string

fn no_env(_var: String) -> Result(String, Nil) {
  Error(Nil)
}

fn stub_env(
  vars: List(#(String, String)),
) -> fn(String) -> Result(String, Nil) {
  fn(var) { list.key_find(vars, var) }
}

pub fn plan_missing_token_test() {
  let config =
    deploy.new()
    |> deploy.project_id("prj_123")
    |> deploy.artifact("./dist")

  assert deploy.plan(config, no_env)
    == Error(deploy.MissingToken("GIOLT_TOKEN"))
}

pub fn plan_resolves_token_from_env_test() {
  let config =
    deploy.new()
    |> deploy.project_id("prj_123")
    |> deploy.artifact("./dist")

  let lookup = stub_env([#("GIOLT_TOKEN", "secret")])

  assert deploy.plan(config, lookup)
    == Ok(deploy.Plan(
      project_id: "prj_123",
      artifact_dir: "./dist",
      preview: False,
      token: "secret",
      message: option.None,
      api_url: "https://api.giolt.com",
    ))
}

pub fn plan_uses_explicit_token_test() {
  let config =
    deploy.new()
    |> deploy.project_id("prj_123")
    |> deploy.artifact("./dist")
    |> deploy.token("explicit-token")

  assert deploy.plan(config, no_env)
    == Ok(deploy.Plan(
      project_id: "prj_123",
      artifact_dir: "./dist",
      preview: False,
      token: "explicit-token",
      message: option.None,
      api_url: "https://api.giolt.com",
    ))
}

pub fn plan_custom_token_env_var_test() {
  let config =
    deploy.new()
    |> deploy.project_id("prj_123")
    |> deploy.artifact("./dist")
    |> deploy.token_from_env("CUSTOM_TOKEN")

  assert deploy.plan(config, no_env)
    == Error(deploy.MissingToken("CUSTOM_TOKEN"))

  let lookup = stub_env([#("CUSTOM_TOKEN", "abc")])
  let assert Ok(plan) = deploy.plan(config, lookup)
  assert plan.token == "abc"
}

pub fn plan_carries_preview_flag_test() {
  let config =
    deploy.new()
    |> deploy.project_id("prj_123")
    |> deploy.artifact("./dist")
    |> deploy.preview(True)

  let lookup = stub_env([#("GIOLT_TOKEN", "secret")])
  let assert Ok(plan) = deploy.plan(config, lookup)

  assert plan.preview == True
}

pub fn plan_carries_message_test() {
  let config =
    deploy.new()
    |> deploy.project_id("prj_123")
    |> deploy.artifact("./dist")
    |> deploy.message("release notes")

  let lookup = stub_env([#("GIOLT_TOKEN", "secret")])
  let assert Ok(plan) = deploy.plan(config, lookup)

  assert plan.message == option.Some("release notes")
}

pub fn plan_carries_custom_api_url_test() {
  let config =
    deploy.new()
    |> deploy.project_id("prj_123")
    |> deploy.artifact("./dist")
    |> deploy.api_url("https://staging.giolt.com")

  let lookup = stub_env([#("GIOLT_TOKEN", "secret")])
  let assert Ok(plan) = deploy.plan(config, lookup)

  assert plan.api_url == "https://staging.giolt.com"
}

pub fn plan_from_bundle_output_uses_its_outdir_test() {
  let output =
    bundle.Output(
      outdir: "./build-output",
      entry: "app",
      static_dir: option.None,
    )

  let config =
    deploy.new()
    |> deploy.project_id("prj_123")
    |> deploy.from(output)

  let lookup = stub_env([#("GIOLT_TOKEN", "secret")])
  let assert Ok(plan) = deploy.plan(config, lookup)

  assert plan.artifact_dir == "./build-output"
}

pub fn describe_error_missing_token_test() {
  let message = deploy.describe_error(deploy.MissingToken("GIOLT_TOKEN"))

  assert string.contains(message, "GIOLT_TOKEN")
}

pub fn describe_error_artifact_not_found_test() {
  let message = deploy.describe_error(deploy.ArtifactNotFound("./dist"))

  assert string.contains(message, "./dist")
}

pub fn describe_error_artifact_empty_test() {
  let message = deploy.describe_error(deploy.ArtifactEmpty("./dist"))

  assert string.contains(message, "empty")
}

pub fn print_result_error_does_not_crash_test() {
  deploy.print_result(Error(deploy.NotImplemented("not yet")))
}
