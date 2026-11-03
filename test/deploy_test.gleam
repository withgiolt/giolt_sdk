import giolt/internal/api.{Client}
import giolt/internal/bundle
import giolt/internal/config
import giolt/internal/credentials.{type Credential, Credential}
import giolt/internal/deploy.{
  ApiError, Lookup, MissingToken, NameNeedsUserToken, NoProject, Ready,
  ToProject, WithDeployKey,
}
import gleam/bit_array
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile

const deploy_key = "3f2a9c1e-0000-4000-8000-000000000000"

const stored = Credential(token: "giolt_stored", api_url: "http://stored")

const env_client = Client(api_url: "http://env", token: "giolt_env")

const stored_client = Client(api_url: "http://stored", token: "giolt_stored")

const key_client = Client(api_url: "http://env", token: deploy_key)

fn route(
  project: Option(String),
  linked: Option(Int),
  env_token: Option(String),
  stored: Option(Credential),
) -> Result(deploy.Route, deploy.Error) {
  deploy.route(
    project:,
    linked:,
    env_token:,
    env_api_url: Some("http://env"),
    config_api_url: "https://config.example",
    stored:,
  )
}

pub fn the_target_and_credential_pick_the_route_test() {
  let rows = [
    // --project names need a user token to resolve. GIOLT_TOKEN wins over a
    // stored login, so a deploy key there can't resolve a name.
    #(
      Some("blog"),
      None,
      Some("giolt_env"),
      None,
      Ok(Lookup("blog", env_client)),
    ),
    #(Some("blog"), None, None, Some(stored), Ok(Lookup("blog", stored_client))),
    #(
      Some("blog"),
      None,
      Some(deploy_key),
      Some(stored),
      Error(NameNeedsUserToken("blog")),
    ),
    #(
      Some("blog"),
      None,
      Some(deploy_key),
      None,
      Error(NameNeedsUserToken("blog")),
    ),
    #(
      Some("blog"),
      Some(7),
      Some("giolt_env"),
      None,
      Ok(Lookup("blog", env_client)),
    ),
    // A linked id needs no lookup, and a deploy key may deploy it too.
    #(
      None,
      Some(7),
      Some("giolt_env"),
      None,
      Ok(Ready(ToProject(7, env_client))),
    ),
    #(None, Some(7), None, Some(stored), Ok(Ready(ToProject(7, stored_client)))),
    #(
      None,
      Some(7),
      Some(deploy_key),
      None,
      Ok(Ready(ToProject(7, key_client))),
    ),
    #(
      None,
      Some(7),
      Some(deploy_key),
      Some(stored),
      Ok(Ready(ToProject(7, key_client))),
    ),
    // Without a target, a deploy key keeps today's route.
    #(None, None, Some(deploy_key), None, Ok(Ready(WithDeployKey(key_client)))),
    #(
      None,
      None,
      Some(deploy_key),
      Some(stored),
      Ok(Ready(WithDeployKey(key_client))),
    ),
    #(None, None, Some("giolt_env"), None, Error(NoProject)),
    #(None, None, None, Some(stored), Error(NoProject)),
    #(None, None, None, None, Error(MissingToken)),
    #(None, Some(7), None, None, Error(MissingToken)),
    #(None, None, Some(""), None, Error(MissingToken)),
  ]

  list.each(rows, fn(row) {
    let #(project, linked, env_token, stored, expected) = row
    assert route(project, linked, env_token, stored) == expected
  })
}

pub fn giolt_token_goes_to_giolt_api_url_then_config_then_default_test() {
  let route = fn(env_api_url, config_api_url) {
    deploy.route(
      project: None,
      linked: Some(7),
      env_token: Some("giolt_env"),
      env_api_url:,
      config_api_url:,
      stored: None,
    )
  }
  let to = fn(api_url) {
    Ok(Ready(ToProject(7, Client(api_url:, token: "giolt_env"))))
  }

  assert route(Some("http://env"), "https://config.example") == to("http://env")
  assert route(None, "https://config.example") == to("https://config.example")
  assert route(Some(""), "https://config.example")
    == to("https://config.example")
  assert route(None, config.default_api_url) == to("https://dash.giolt.com")
}

pub fn a_stored_login_only_goes_to_the_server_that_issued_it_test() {
  assert deploy.route(
      project: None,
      linked: Some(7),
      env_token: None,
      env_api_url: Some("http://env"),
      config_api_url: "https://config.example",
      stored: Some(stored),
    )
    == Ok(Ready(ToProject(7, stored_client)))
}

pub fn plan_carries_the_artifact_and_flags_test() {
  let config =
    deploy.new()
    |> deploy.artifact("./dist")
    |> deploy.preview(True)

  assert deploy.plan(config)
    == deploy.Plan(
      artifact_dir: "./dist",
      assets_only: False,
      preview: True,
      spa: False,
    )
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

  let plan = deploy.plan(config)

  assert plan.artifact_dir == "./build-output"
}

// The deploy-key route's refusals are plain text that already names the
// limit, so they must not be wrapped in a status line.
pub fn refused_deploys_show_the_server_message_test() {
  assert deploy.describe_error(ApiError(
      413,
      "Too many files: a deploy can contain at most 5000 files",
    ))
    == "Too many files: a deploy can contain at most 5000 files"
  assert deploy.describe_error(ApiError(400, "Nothing to deploy"))
    == "Nothing to deploy"
}

pub fn other_api_failures_keep_their_status_test() {
  assert deploy.describe_error(ApiError(502, "Deployment failed"))
    == "Giolt API request failed with status 502: Deployment failed"
}

pub fn describe_error_missing_token_test() {
  let message = deploy.describe_error(MissingToken)

  assert string.contains(message, "giolt login")
  assert string.contains(message, "GIOLT_TOKEN")
}

pub fn describe_error_no_project_test() {
  assert deploy.describe_error(NoProject)
    == "No project to deploy to. Run `giolt link <name>` or pass `--project <name>`."
}

pub fn describe_error_name_needs_user_token_test() {
  let message = deploy.describe_error(NameNeedsUserToken("blog"))

  assert string.contains(message, "`blog`")
  assert string.contains(message, "giolt link")
}

pub fn describe_error_prints_the_api_message_test() {
  let message = "Add a payment method at https://dash.giolt.com/billing."

  assert deploy.describe_error(
      deploy.Api(api.Rejected(code: api.BillingRequired, message:)),
    )
    == message
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
  let config =
    deploy.new()
    |> deploy.artifact("./dist")
    |> deploy.spa(True)

  let plan = deploy.plan(config)
  assert plan.spa
}

pub fn plan_for_an_assets_only_site_test() {
  let config =
    deploy.new()
    |> deploy.assets("./site")

  let plan = deploy.plan(config)

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
