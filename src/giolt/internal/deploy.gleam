import giolt/internal/api.{type Client, type Deployed, Client}
import giolt/internal/bundle
import giolt/internal/credentials.{type Credential}
import giolt/internal/io
import gleam/bit_array
import gleam/dynamic/decode
import gleam/fetch
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile

pub type NoArtifact

pub type HasArtifact

type Artifact {
  Directory(path: String)
  FromBundle(output: bundle.Output)
  AssetsOnly(path: String)
}

pub opaque type Config(has_artifact) {
  Config(artifact: Option(Artifact), preview: Bool, spa: Bool)
}

pub type Destination {
  // POST /api/deploy, where the key itself names the project.
  WithDeployKey(client: Client)
  ToProject(id: Int, client: Client)
}

pub type Route {
  Ready(Destination)
  Lookup(name: String, client: Client)
}

pub type Error {
  MissingToken
  NoProject
  NameNeedsUserToken(name: String)
  Api(api.Error)
  ArtifactNotFound(path: String)
  ArtifactEmpty(path: String)
  CannotReadArtifact(path: String)
  NotImplemented(detail: String)
  ApiError(status: Int, body: String)
}

pub type Plan {
  Plan(artifact_dir: String, assets_only: Bool, preview: Bool, spa: Bool)
}

const default_artifact_dir = "./dist"

/// Files under this directory (relative to the artifact dir) are uploaded as
/// static assets; everything else is uploaded as a worker module.
const static_subdir = "static"

pub fn new() -> Config(NoArtifact) {
  Config(artifact: None, preview: False, spa: False)
}

pub fn artifact(
  config: Config(has_artifact),
  path: String,
) -> Config(HasArtifact) {
  set_artifact(config, Directory(path))
}

pub fn assets(
  config: Config(has_artifact),
  path: String,
) -> Config(HasArtifact) {
  set_artifact(config, AssetsOnly(path))
}

pub fn from(
  config: Config(has_artifact),
  output: bundle.Output,
) -> Config(HasArtifact) {
  set_artifact(config, FromBundle(output))
}

fn set_artifact(
  config: Config(has_artifact),
  artifact: Artifact,
) -> Config(HasArtifact) {
  let Config(preview:, spa:, ..) = config
  Config(artifact: Some(artifact), preview:, spa:)
}

pub fn preview(
  config: Config(has_artifact),
  is_preview: Bool,
) -> Config(has_artifact) {
  Config(..config, preview: is_preview)
}

/// Serves `index.html` for any path that matches no file, so client-side
/// routes survive a refresh or deep link. Only valid for a static-only
/// artifact: Giolt rejects it alongside worker modules.
pub fn spa(config: Config(has_artifact), is_spa: Bool) -> Config(has_artifact) {
  Config(..config, spa: is_spa)
}

// A user token in GIOLT_TOKEN goes to GIOLT_API_URL or the configured
// `api_url`, like a deploy key always has. A stored login only goes to the
// server that issued it.
pub fn route(
  project project: Option(String),
  linked linked: Option(Int),
  env_token env_token: Option(String),
  env_api_url env_api_url: Option(String),
  config_api_url config_api_url: String,
  stored stored: Option(Credential),
) -> Result(Route, Error) {
  let env_client = case non_empty(env_token) {
    Some(token) -> {
      let api_url = non_empty(env_api_url) |> option.unwrap(config_api_url)
      Some(#(credentials.token_kind(token), Client(api_url:, token:)))
    }
    None -> None
  }
  // GIOLT_TOKEN wins outright, so a CI deploy key is never swapped for a
  // login stored on the same machine.
  let #(user, deploy_key) = case env_client, stored {
    Some(#(credentials.UserToken, client)), _ -> #(Some(client), None)
    Some(#(credentials.DeployKey, client)), _ -> #(None, Some(client))
    None, Some(credential) -> #(
      Some(Client(api_url: credential.api_url, token: credential.token)),
      None,
    )
    None, None -> #(None, None)
  }

  case project, linked, user, deploy_key {
    Some(name), _, Some(client), _ -> Ok(Lookup(name:, client:))
    Some(name), _, None, Some(_) -> Error(NameNeedsUserToken(name))
    None, Some(id), Some(client), _ | None, Some(id), None, Some(client) ->
      Ok(Ready(ToProject(id:, client:)))
    None, None, _, Some(client) -> Ok(Ready(WithDeployKey(client)))
    None, None, Some(_), None -> Error(NoProject)
    _, _, None, None -> Error(MissingToken)
  }
}

fn non_empty(value: Option(String)) -> Option(String) {
  case value {
    Some("") -> None
    _ -> value
  }
}

pub fn run(
  config: Config(HasArtifact),
  destination: Destination,
) -> Promise(Result(Deployed, Error)) {
  let plan = plan(config)
  case check_artifact(plan.artifact_dir) {
    Error(error) -> promise.resolve(Error(error))
    Ok(Nil) -> submit(plan, destination)
  }
}

pub fn plan(config: Config(HasArtifact)) -> Plan {
  Plan(
    artifact_dir: artifact_dir(config.artifact),
    assets_only: is_assets_only(config.artifact),
    preview: config.preview,
    spa: config.spa,
  )
}

fn artifact_dir(artifact: Option(Artifact)) -> String {
  case artifact {
    Some(Directory(path)) -> path
    Some(FromBundle(output)) -> output.outdir
    Some(AssetsOnly(path)) -> path
    None -> default_artifact_dir
  }
}

fn is_assets_only(artifact: Option(Artifact)) -> Bool {
  case artifact {
    Some(AssetsOnly(_)) -> True
    _ -> False
  }
}

fn check_artifact(path: String) -> Result(Nil, Error) {
  use is_dir <- result.try(
    simplifile.is_directory(path)
    |> result.replace_error(ArtifactNotFound(path)),
  )
  case is_dir {
    False -> Error(ArtifactNotFound(path))
    True -> {
      use entries <- result.try(
        simplifile.read_directory(path)
        |> result.replace_error(ArtifactNotFound(path)),
      )
      case entries {
        [] -> Error(ArtifactEmpty(path))
        _ -> Ok(Nil)
      }
    }
  }
}

fn submit(
  plan: Plan,
  destination: Destination,
) -> Promise(Result(Deployed, Error)) {
  io.println_info(
    "Deploying "
    <> plan.artifact_dir
    <> case plan.preview {
      True -> " (preview)"
      False -> ""
    }
    <> "...",
  )

  let files = case plan.assets_only {
    True ->
      assets_only_files(plan.artifact_dir)
      |> result.map(fn(assets) { #([], assets) })
    False -> artifact_files(plan.artifact_dir)
  }

  case files {
    Error(error) -> promise.resolve(Error(error))
    Ok(#(modules, assets)) -> {
      let body = deploy_body(plan, modules, assets)
      case destination {
        WithDeployKey(client) -> post_with_deploy_key(client, body)
        ToProject(id:, client:) ->
          api.create_deployment(client, id, body)
          |> promise.map(result.map_error(_, Api))
      }
    }
  }
}

/// Reads every file under `dir`, splitting it into worker modules and static
/// assets (files under `dir/static`). Each entry is `#(path, content_base64)`,
/// with `path` relative to `dir` for modules and relative to `dir/static` for
/// assets — matching what `/api/deploy` expects.
pub fn artifact_files(
  dir: String,
) -> Result(#(List(#(String, String)), List(#(String, String))), Error) {
  use paths <- result.try(
    simplifile.get_files(dir) |> result.replace_error(CannotReadArtifact(dir)),
  )

  let dir_prefix = strip_trailing_slash(dir) <> "/"
  let static_prefix = dir_prefix <> static_subdir <> "/"

  let #(asset_paths, module_paths) =
    list.partition(paths, string.starts_with(_, static_prefix))

  use modules <- result.try(read_and_encode(module_paths, dir_prefix))
  use assets <- result.try(read_and_encode(asset_paths, static_prefix))

  Ok(#(modules, assets))
}

pub fn assets_only_files(
  dir: String,
) -> Result(List(#(String, String)), Error) {
  use paths <- result.try(
    simplifile.get_files(dir) |> result.replace_error(CannotReadArtifact(dir)),
  )

  read_and_encode(paths, strip_trailing_slash(dir) <> "/")
}

fn read_and_encode(
  paths: List(String),
  prefix: String,
) -> Result(List(#(String, String)), Error) {
  list.try_map(paths, fn(path) {
    use content <- result.try(
      simplifile.read_bits(path)
      |> result.replace_error(CannotReadArtifact(path)),
    )
    Ok(#(
      string.drop_start(path, string.length(prefix)),
      bit_array.base64_encode(content, True),
    ))
  })
}

fn strip_trailing_slash(path: String) -> String {
  case string.ends_with(path, "/") {
    True -> string.drop_end(path, 1)
    False -> path
  }
}

fn deploy_body(
  plan: Plan,
  modules: List(#(String, String)),
  assets: List(#(String, String)),
) -> json.Json {
  json.object([
    #("preview", json.bool(plan.preview)),
    #("spa", json.bool(plan.spa)),
    #("modules", json.array(modules, file_json)),
    #("assets", json.array(assets, file_json)),
  ])
}

fn post_with_deploy_key(
  client: Client,
  body: json.Json,
) -> Promise(Result(Deployed, Error)) {
  case request.to(client.api_url <> "/api/deploy") {
    Error(Nil) ->
      promise.resolve(Error(ApiError(0, "Invalid api_url: " <> client.api_url)))
    Ok(base_request) -> {
      let req =
        base_request
        |> request.set_method(http.Post)
        |> request.set_header("content-type", "application/json")
        |> request.set_header("authorization", "Bearer " <> client.token)
        |> request.set_body(json.to_string(body))

      use send_result <- promise.await(fetch.send(req))

      case send_result {
        Error(fetch_error) ->
          promise.resolve(Error(ApiError(0, string.inspect(fetch_error))))
        Ok(res) -> handle_response(res)
      }
    }
  }
}

fn file_json(file: #(String, String)) -> json.Json {
  let #(path, content_base64) = file
  json.object([
    #("path", json.string(path)),
    #("content_base64", json.string(content_base64)),
  ])
}

fn handle_response(
  res: response.Response(fetch.FetchBody),
) -> Promise(Result(Deployed, Error)) {
  case res.status {
    200 -> {
      use body_result <- promise.await(fetch.read_json_body(res))
      case body_result {
        Error(fetch_error) ->
          promise.resolve(
            Error(ApiError(res.status, string.inspect(fetch_error))),
          )
        Ok(json_res) ->
          decode.run(json_res.body, api.deployed_decoder())
          |> result.replace_error(ApiError(
            res.status,
            "Malformed response body",
          ))
          |> promise.resolve
      }
    }
    status -> {
      use body_result <- promise.await(fetch.read_text_body(res))
      let body = case body_result {
        Ok(text_res) -> text_res.body
        Error(_) -> ""
      }
      promise.resolve(Error(ApiError(status, body)))
    }
  }
}

pub fn describe_error(error: Error) -> String {
  case error {
    MissingToken ->
      "No token found. Run `giolt login`, or set `"
      <> credentials.token_env
      <> "` to a user token or the project's deploy key."

    NoProject ->
      "No project to deploy to. Run `giolt link <name>` or pass `--project <name>`."

    NameNeedsUserToken(name) ->
      "Deploying to `"
      <> name
      <> "` by name needs a user token, but `"
      <> credentials.token_env
      <> "` holds a deploy key. Run `giolt link "
      <> name
      <> "` once with a user token so the project id is in gleam.toml, or set `"
      <> credentials.token_env
      <> "` to a user token."

    Api(error) -> api.describe_error(error)

    ArtifactNotFound(path) ->
      "No such artifact directory: " <> path <> ". Run `giolt build` first."

    ArtifactEmpty(path) -> "The artifact directory " <> path <> " is empty."

    CannotReadArtifact(path) -> "Could not read artifact file: " <> path

    NotImplemented(detail) -> detail

    // The deploy-key route answers a refused deploy with a plain-text message
    // that already says what to change, such as the file-count or size limit,
    // so it is shown as it is.
    ApiError(status, body) if status == 400 || status == 402 || status == 413 ->
      body

    ApiError(status, body) ->
      "Giolt API request failed with status "
      <> string.inspect(status)
      <> ": "
      <> body
  }
}

pub fn print_result(result: Result(Deployed, Error)) -> Nil {
  case result {
    Ok(deployment) -> io.println_success("Deployed: " <> deployment.url)
    Error(_) -> Nil
  }
}
