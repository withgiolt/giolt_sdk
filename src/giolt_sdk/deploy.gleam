import envie
import giolt_sdk/bundle
import giolt_sdk/internal/io
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

pub type NoProjectId

pub type HasProjectId

pub type NoArtifact

pub type HasArtifact

type Artifact {
  Directory(path: String)
  FromBundle(output: bundle.Output)
}

type TokenSource {
  Explicit(value: String)
  FromEnv(var: String)
}

pub opaque type Config(has_project_id, has_artifact) {
  Config(
    project_id: String,
    artifact: Option(Artifact),
    preview: Bool,
    token: TokenSource,
    message: Option(String),
    api_url: String,
  )
}

pub type Deployment {
  Deployment(id: String, url: String, preview: Bool)
}

pub type Error {
  MissingToken(env_var: String)
  ArtifactNotFound(path: String)
  ArtifactEmpty(path: String)
  CannotReadArtifact(path: String)
  NotImplemented(detail: String)
  ApiError(status: Int, body: String)
}

pub type Plan {
  Plan(
    project_id: String,
    artifact_dir: String,
    preview: Bool,
    token: String,
    message: Option(String),
    api_url: String,
  )
}

const default_token_env = "GIOLT_TOKEN"

const default_api_url = "https://giolt.com"

const default_artifact_dir = "./dist"

/// Overrides `deploy.api_url` when set — handy for pointing a deploy at a
/// local dev server without editing the scaffolded `deploy.gleam`.
const api_url_env = "GIOLT_API_URL"

/// Files under this directory (relative to the artifact dir) are uploaded as
/// static assets; everything else is uploaded as a worker module.
const static_subdir = "static"

pub fn new() -> Config(NoProjectId, NoArtifact) {
  Config(
    project_id: "",
    artifact: None,
    preview: False,
    token: FromEnv(default_token_env),
    message: None,
    api_url: default_api_url,
  )
}

pub fn project_id(
  config: Config(has_project_id, has_artifact),
  id: String,
) -> Config(HasProjectId, has_artifact) {
  let Config(artifact:, preview:, token:, message:, api_url:, ..) = config
  Config(project_id: id, artifact:, preview:, token:, message:, api_url:)
}

pub fn artifact(
  config: Config(has_project_id, has_artifact),
  path: String,
) -> Config(has_project_id, HasArtifact) {
  set_artifact(config, Directory(path))
}

pub fn from(
  config: Config(has_project_id, has_artifact),
  output: bundle.Output,
) -> Config(has_project_id, HasArtifact) {
  set_artifact(config, FromBundle(output))
}

fn set_artifact(
  config: Config(has_project_id, has_artifact),
  artifact: Artifact,
) -> Config(has_project_id, HasArtifact) {
  let Config(project_id:, preview:, token:, message:, api_url:, ..) = config
  Config(
    project_id:,
    artifact: Some(artifact),
    preview:,
    token:,
    message:,
    api_url:,
  )
}

pub fn preview(
  config: Config(has_project_id, has_artifact),
  is_preview: Bool,
) -> Config(has_project_id, has_artifact) {
  Config(..config, preview: is_preview)
}

pub fn token(
  config: Config(has_project_id, has_artifact),
  value: String,
) -> Config(has_project_id, has_artifact) {
  Config(..config, token: Explicit(value))
}

pub fn token_from_env(
  config: Config(has_project_id, has_artifact),
  var: String,
) -> Config(has_project_id, has_artifact) {
  Config(..config, token: FromEnv(var))
}

pub fn message(
  config: Config(has_project_id, has_artifact),
  text: String,
) -> Config(has_project_id, has_artifact) {
  Config(..config, message: Some(text))
}

pub fn api_url(
  config: Config(has_project_id, has_artifact),
  url: String,
) -> Config(has_project_id, has_artifact) {
  Config(..config, api_url: url)
}

pub fn run(
  config: Config(HasProjectId, HasArtifact),
) -> Promise(Result(Deployment, Error)) {
  let plan_result = {
    use plan <- result.try(plan(config))
    use _ <- result.try(check_artifact(plan.artifact_dir))
    Ok(plan)
  }

  case plan_result {
    Error(error) -> {
      io.println_error(describe_error(error))
      promise.resolve(Error(error))
    }
    Ok(plan) -> {
      use result <- promise.map(submit(plan))
      case result {
        Ok(_) -> Nil
        Error(error) -> io.println_error(describe_error(error))
      }
      result
    }
  }
}

pub fn plan(config: Config(HasProjectId, HasArtifact)) -> Result(Plan, Error) {
  use token <- result.try(resolve_token(config.token))

  Ok(Plan(
    project_id: config.project_id,
    artifact_dir: artifact_dir(config.artifact),
    preview: config.preview,
    token: token,
    message: config.message,
    api_url: envie.get_string(api_url_env, config.api_url),
  ))
}

fn artifact_dir(artifact: Option(Artifact)) -> String {
  case artifact {
    Some(Directory(path)) -> path
    Some(FromBundle(output)) -> output.outdir
    None -> default_artifact_dir
  }
}

fn resolve_token(source: TokenSource) -> Result(String, Error) {
  case source {
    Explicit(value) -> Ok(value)
    FromEnv(var) ->
      envie.require_string(var) |> result.replace_error(MissingToken(var))
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

fn submit(plan: Plan) -> Promise(Result(Deployment, Error)) {
  io.println_info(
    "Deploying "
    <> plan.artifact_dir
    <> " to project "
    <> plan.project_id
    <> case plan.preview {
      True -> " (preview)"
      False -> ""
    }
    <> "...",
  )

  case artifact_files(plan.artifact_dir) {
    Error(error) -> promise.resolve(Error(error))
    Ok(#(modules, assets)) -> post_deploy(plan, modules, assets)
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

fn post_deploy(
  plan: Plan,
  modules: List(#(String, String)),
  assets: List(#(String, String)),
) -> Promise(Result(Deployment, Error)) {
  case request.to(plan.api_url <> "/api/deploy") {
    Error(Nil) ->
      promise.resolve(Error(ApiError(0, "Invalid api_url: " <> plan.api_url)))
    Ok(base_request) -> {
      let req =
        base_request
        |> request.set_method(http.Post)
        |> request.set_header("content-type", "application/json")
        |> request.set_header("authorization", "Bearer " <> plan.token)
        |> request.set_body(
          json.object([
            #("preview", json.bool(plan.preview)),
            #("modules", json.array(modules, file_json)),
            #("assets", json.array(assets, file_json)),
          ])
          |> json.to_string,
        )

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
) -> Promise(Result(Deployment, Error)) {
  case res.status {
    200 -> {
      use body_result <- promise.await(fetch.read_json_body(res))
      case body_result {
        Error(fetch_error) ->
          promise.resolve(
            Error(ApiError(res.status, string.inspect(fetch_error))),
          )
        Ok(json_res) ->
          decode.run(json_res.body, deployment_decoder())
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

fn deployment_decoder() -> decode.Decoder(Deployment) {
  use id <- decode.field("id", decode.string)
  use url <- decode.field("url", decode.string)
  use preview <- decode.field("preview", decode.bool)
  decode.success(Deployment(id:, url:, preview:))
}

pub fn describe_error(error: Error) -> String {
  case error {
    MissingToken(var) ->
      "No deploy token found. Set the `"
      <> var
      <> "` environment variable, or pass one with `deploy.token`."

    ArtifactNotFound(path) ->
      "No such artifact directory: "
      <> path
      <> ". Run your build first, or pass its `bundle.Output` to `deploy.from`."

    ArtifactEmpty(path) -> "The artifact directory " <> path <> " is empty."

    CannotReadArtifact(path) -> "Could not read artifact file: " <> path

    NotImplemented(detail) -> detail

    ApiError(status, body) ->
      "Giolt API request failed with status "
      <> string.inspect(status)
      <> ": "
      <> body
  }
}

pub fn print_result(result: Result(Deployment, Error)) -> Nil {
  case result {
    Ok(deployment) -> io.println_success("Deployed: " <> deployment.url)
    Error(_) -> Nil
  }
}
