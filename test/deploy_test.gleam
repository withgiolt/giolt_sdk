import envie
import giolt/internal/bundle
import giolt/internal/deploy
import gleam/bit_array
import gleam/list
import gleam/option
import gleam/string
import simplifile

pub fn plan_missing_token_test() {
  envie.unset("GIOLT_TOKEN")

  let config =
    deploy.new()
    |> deploy.artifact("./dist")

  assert deploy.plan(config) == Error(deploy.MissingToken("GIOLT_TOKEN"))
}

pub fn plan_resolves_token_from_env_test() {
  envie.unset("GIOLT_API_URL")

  let config =
    deploy.new()
    |> deploy.artifact("./dist")

  envie.set("GIOLT_TOKEN", "secret")

  assert deploy.plan(config)
    == Ok(deploy.Plan(
      artifact_dir: "./dist",
      assets_only: False,
      preview: False,
      spa: False,
      token: "secret",
      api_url: "https://dash.giolt.com",
    ))
}

pub fn plan_uses_explicit_token_test() {
  envie.unset("GIOLT_API_URL")

  let config =
    deploy.new()
    |> deploy.artifact("./dist")
    |> deploy.token("explicit-token")

  assert deploy.plan(config)
    == Ok(deploy.Plan(
      artifact_dir: "./dist",
      assets_only: False,
      preview: False,
      spa: False,
      token: "explicit-token",
      api_url: "https://dash.giolt.com",
    ))
}

pub fn plan_custom_token_env_var_test() {
  let config =
    deploy.new()
    |> deploy.artifact("./dist")
    |> deploy.token_from_env("CUSTOM_TOKEN")

  assert deploy.plan(config) == Error(deploy.MissingToken("CUSTOM_TOKEN"))

  envie.set("CUSTOM_TOKEN", "abc")
  let assert Ok(plan) = deploy.plan(config)
  assert plan.token == "abc"
}

pub fn plan_carries_preview_flag_test() {
  let config =
    deploy.new()
    |> deploy.artifact("./dist")
    |> deploy.preview(True)

  envie.set("GIOLT_TOKEN", "secret")
  let assert Ok(plan) = deploy.plan(config)

  assert plan.preview == True
}

pub fn plan_carries_custom_api_url_test() {
  envie.unset("GIOLT_API_URL")

  let config =
    deploy.new()
    |> deploy.artifact("./dist")
    |> deploy.api_url("https://staging.giolt.com")

  envie.set("GIOLT_TOKEN", "secret")
  let assert Ok(plan) = deploy.plan(config)

  assert plan.api_url == "https://staging.giolt.com"
}

pub fn plan_api_url_env_overrides_configured_url_test() {
  let config =
    deploy.new()
    |> deploy.artifact("./dist")
    |> deploy.api_url("https://staging.giolt.com")

  envie.set("GIOLT_TOKEN", "secret")
  envie.set("GIOLT_API_URL", "http://localhost:8787")
  let assert Ok(plan) = deploy.plan(config)

  assert plan.api_url == "http://localhost:8787"
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
    |> deploy.from(output)

  envie.set("GIOLT_TOKEN", "secret")
  let assert Ok(plan) = deploy.plan(config)

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

pub fn artifact_files_splits_modules_from_static_assets_test() {
  let dir = "./test_tmp_artifact_files"
  let _ = simplifile.delete(dir)
  let assert Ok(_) = simplifile.create_directory_all(dir <> "/static/sub")
  let assert Ok(_) = simplifile.write(dir <> "/index.mjs", "console.log(1)")
  let assert Ok(_) = simplifile.write(dir <> "/static/sub/x.css", "body{}")

  let result = deploy.artifact_files(dir)

  let assert Ok(_) = simplifile.delete(dir)
  let assert Ok(#(modules, assets)) = result

  assert modules
    == [
      #("index.mjs", bit_array.base64_encode(<<"console.log(1)":utf8>>, True)),
    ]
  assert assets
    == [#("sub/x.css", bit_array.base64_encode(<<"body{}":utf8>>, True))]
}

pub fn plan_carries_spa_flag_test() {
  envie.unset("GIOLT_API_URL")

  let config =
    deploy.new()
    |> deploy.artifact("./dist")
    |> deploy.token("explicit-token")
    |> deploy.spa(True)

  let assert Ok(plan) = deploy.plan(config)
  assert plan.spa
}

pub fn plan_for_an_assets_only_site_test() {
  envie.unset("GIOLT_API_URL")

  let config =
    deploy.new()
    |> deploy.assets("./site")
    |> deploy.token("explicit-token")

  let assert Ok(plan) = deploy.plan(config)

  assert plan.artifact_dir == "./site"
  assert plan.assets_only
}

pub fn assets_only_files_uploads_every_file_as_an_asset_test() {
  let dir = "./test_tmp_assets_only"
  let _ = simplifile.delete(dir)
  let assert Ok(_) = simplifile.create_directory_all(dir <> "/blog")
  let assert Ok(_) = simplifile.write(dir <> "/index.html", "<h1>hi</h1>")
  let assert Ok(_) = simplifile.write(dir <> "/index.mjs", "not a module")
  let assert Ok(_) = simplifile.write(dir <> "/blog/post.html", "<p>x</p>")

  let result = deploy.assets_only_files(dir)

  let assert Ok(_) = simplifile.delete(dir)
  let assert Ok(assets) = result

  assert list.sort(assets, fn(a, b) { string.compare(a.0, b.0) })
    == [
      #("blog/post.html", bit_array.base64_encode(<<"<p>x</p>":utf8>>, True)),
      #("index.html", bit_array.base64_encode(<<"<h1>hi</h1>":utf8>>, True)),
      #("index.mjs", bit_array.base64_encode(<<"not a module":utf8>>, True)),
    ]
}

pub fn assets_only_files_reports_an_unreadable_directory_test() {
  assert deploy.assets_only_files("./no_such_site_dir")
    == Error(deploy.CannotReadArtifact("./no_such_site_dir"))
}
