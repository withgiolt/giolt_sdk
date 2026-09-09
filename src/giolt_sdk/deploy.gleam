import giolt_sdk/bundle
import giolt_sdk/internal/io
import gleam/javascript/promise.{type Promise}
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

const default_api_url = "https://api.giolt.com"

const default_artifact_dir = "./dist"

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
  let result = {
    use plan <- result.try(plan(config, lookup_env))
    use _ <- result.try(check_artifact(plan.artifact_dir))
    submit(plan)
  }

  case result {
    Ok(_) -> Nil
    Error(error) -> io.println_error(describe_error(error))
  }

  promise.resolve(result)
}

pub fn plan(
  config: Config(HasProjectId, HasArtifact),
  lookup_env: fn(String) -> Result(String, Nil),
) -> Result(Plan, Error) {
  use token <- result.try(resolve_token(config.token, lookup_env))

  Ok(Plan(
    project_id: config.project_id,
    artifact_dir: artifact_dir(config.artifact),
    preview: config.preview,
    token: token,
    message: config.message,
    api_url: config.api_url,
  ))
}

fn artifact_dir(artifact: Option(Artifact)) -> String {
  case artifact {
    Some(Directory(path)) -> path
    Some(FromBundle(output)) -> output.outdir
    None -> default_artifact_dir
  }
}

fn resolve_token(
  source: TokenSource,
  lookup_env: fn(String) -> Result(String, Nil),
) -> Result(String, Error) {
  case source {
    Explicit(value) -> Ok(value)
    FromEnv(var) -> lookup_env(var) |> result.replace_error(MissingToken(var))
  }
}

@external(javascript, "./internal/ffi_env.mjs", "get_env")
fn lookup_env(var: String) -> Result(String, Nil)

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

fn submit(plan: Plan) -> Result(Deployment, Error) {
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

  // TODO: send `plan` to `{plan.api_url}` and return a real `Deployment`.
  Error(NotImplemented("giolt_sdk/deploy does not talk to the Giolt API yet."))
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
