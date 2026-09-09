//// Deploying a bundled app to Giolt.
////
//// Call this from your own `deploy.gleam`, typically composed with your
//// `build.gleam`:
////
//// ```gleam
//// import build
//// import giolt_sdk/deploy
//// import gleam/javascript/promise
////
//// pub fn main() {
////   let assert Ok(output) = build.main()
////
////   deploy.new()
////   |> deploy.project_id("prj_replace_me")
////   |> deploy.from(output)
////   |> deploy.preview(True)
////   |> deploy.token_from_env("GIOLT_TOKEN")
////   |> deploy.run
////   |> promise.map(deploy.print_result)
//// }
//// ```
////
//// Run it with `gleam run -m deploy`.
////
//// The API call itself is not wired up yet — `run` validates everything it
//// can locally (project id set, artifact present, token resolved) and then
//// fails with `NotImplemented` at the point the request would be sent. See
//// the `// TODO` in `submit` below.

import giolt_sdk/bundle
import giolt_sdk/internal/env
import giolt_sdk/internal/io
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile

/// A configuration that has not been given a project id yet.
pub type NoProjectId

/// A configuration that has a project id.
pub type HasProjectId

/// A configuration that has not been given anything to deploy yet.
pub type NoArtifact

/// A configuration that has something to deploy.
pub type HasArtifact

/// Where the deploy comes from: either a bare directory, or the `Output` of a
/// `bundle.run` call.
type Artifact {
  Directory(path: String)
  FromBundle(output: bundle.Output)
}

/// Where the API token comes from.
type TokenSource {
  Explicit(value: String)
  FromEnv(var: String)
}

/// A deploy configuration.
///
/// The type parameters track whether a project id and an artifact have been
/// set. `run` only accepts a configuration that has both, so forgetting
/// either is a compile error rather than something you find out about at
/// deploy time.
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
  /// The API call has not been implemented yet.
  NotImplemented(detail: String)
  ApiError(status: Int, body: String)
}

/// A fully resolved plan, ready to submit.
///
/// Exposed so the resolution logic (which env var, which artifact directory,
/// which defaults) can be unit tested with a stub environment lookup instead
/// of a real one.
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

/// Start a new deploy configuration.
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

/// The Giolt project to deploy to. Required.
pub fn project_id(
  config: Config(has_project_id, has_artifact),
  id: String,
) -> Config(HasProjectId, has_artifact) {
  let Config(artifact:, preview:, token:, message:, api_url:, ..) = config
  Config(project_id: id, artifact:, preview:, token:, message:, api_url:)
}

/// Deploy a directory that has already been bundled, such as one produced by
/// a `gleam run -m build` you ran separately. Required, unless `from` is used
/// instead.
pub fn artifact(
  config: Config(has_project_id, has_artifact),
  path: String,
) -> Config(has_project_id, HasArtifact) {
  set_artifact(config, Directory(path))
}

/// Deploy the output of a `bundle.run` call. Required, unless `artifact` is
/// used instead.
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

/// Deploy as a preview rather than promoting to production. Defaults to
/// `False`.
pub fn preview(
  config: Config(has_project_id, has_artifact),
  is_preview: Bool,
) -> Config(has_project_id, has_artifact) {
  Config(..config, preview: is_preview)
}

/// Use this exact token rather than reading one from the environment.
pub fn token(
  config: Config(has_project_id, has_artifact),
  value: String,
) -> Config(has_project_id, has_artifact) {
  Config(..config, token: Explicit(value))
}

/// Read the token from this environment variable. Defaults to `GIOLT_TOKEN`.
pub fn token_from_env(
  config: Config(has_project_id, has_artifact),
  var: String,
) -> Config(has_project_id, has_artifact) {
  Config(..config, token: FromEnv(var))
}

/// An optional message to attach to the deployment.
pub fn message(
  config: Config(has_project_id, has_artifact),
  text: String,
) -> Config(has_project_id, has_artifact) {
  Config(..config, message: Some(text))
}

/// Override the Giolt API endpoint. Defaults to `https://api.giolt.com`.
pub fn api_url(
  config: Config(has_project_id, has_artifact),
  url: String,
) -> Config(has_project_id, has_artifact) {
  Config(..config, api_url: url)
}

/// Deploy.
///
/// Only compiles once both `project_id` and one of `artifact`/`from` have
/// been set — `deploy.new() |> deploy.run` is a type error.
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

/// Resolve a configuration into a `Plan`, given a way to look up environment
/// variables.
///
/// Pure aside from the injected lookup, so token resolution — the only branch
/// that depends on the environment — is unit testable with a stub.
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

fn lookup_env(var: String) -> Result(String, Nil) {
  env.load()
  |> list.find(fn(entry) { entry.0 == var })
  |> result.map(fn(entry) { entry.1 })
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

  // TODO: send `plan` to `{plan.api_url}` and turn the response into a
  // `Deployment`. Everything above this line — the project id, the artifact
  // directory, and the token — has already been validated, so filling this in
  // is the only thing standing between here and a real deployment.
  Error(NotImplemented("giolt_sdk/deploy does not talk to the Giolt API yet."))
}

/// A message suitable for showing to the user.
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

/// Print the result of a `run` call. Handy as `promise.map(_, deploy.print_result)`.
pub fn print_result(result: Result(Deployment, Error)) -> Nil {
  case result {
    Ok(deployment) -> io.println_success("Deployed: " <> deployment.url)
    Error(_) -> Nil
  }
}
