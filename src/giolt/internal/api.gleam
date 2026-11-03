import gleam/dynamic/decode.{type Decoder}
import gleam/fetch
import gleam/http.{type Method}
import gleam/http/request.{type Request}
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type Client {
  Client(api_url: String, token: String)
}

pub type Project {
  Project(
    id: Int,
    slug: String,
    url: String,
    suspended: Bool,
    latest_deployment: Option(Deployment),
  )
}

pub type Deployment {
  Deployment(url: String, status: String)
}

pub type Deployed {
  Deployed(id: String, url: String, preview: Bool)
}

pub type Me {
  Me(
    email: String,
    token_name: String,
    scopes: List(String),
    expires_at: Option(String),
  )
}

// `included` is missing from servers that predate it. The period is null for
// an account with no billing customer yet, which has used nothing.
pub type Usage {
  Usage(
    requests: Int,
    included: Option(Int),
    period_start: Option(String),
    period_end: Option(String),
  )
}

pub type DeviceLogin {
  DeviceLogin(
    device_code: String,
    user_code: String,
    verification_url: String,
    expires_in: Int,
    interval: Int,
  )
}

pub type PollStep {
  Approved(token: String)
  Pending(interval: Int)
  CodeExpired
  Denied
  PollFailed(Error)
}

pub type Revocation {
  Revoked
  AlreadyInvalid
  NotRevoked(warning: String)
}

pub type Code {
  InvalidRequest
  InvalidSlug
  NotImplemented
  Unauthorized
  BillingRequired
  Forbidden
  NotFound
  SlugTaken
  SlugReserved
  ProjectLimit
  PayloadTooLarge
  UpstreamFailed
  OtherCode(String)
}

pub type Error {
  Rejected(code: Code, message: String)
  UnexpectedResponse(status: Int, body: String)
  Unreachable(api_url: String)
  InvalidApiUrl(api_url: String)
  NoSuchProject(slug: String)
}

const slow_down_seconds = 5

pub fn me(client: Client) -> Promise(Result(Me, Error)) {
  send_json(client.api_url, me_request(client), me_decoder())
}

pub fn list_projects(client: Client) -> Promise(Result(List(Project), Error)) {
  send_json(
    client.api_url,
    list_projects_request(client),
    list_decoder(project_decoder()),
  )
}

pub fn find_project(
  client: Client,
  slug: String,
) -> Promise(Result(Project, Error)) {
  use projects <- promise.try_await(send_json(
    client.api_url,
    find_project_request(client, slug),
    list_decoder(project_decoder()),
  ))
  promise.resolve(pick_project(projects, slug))
}

pub fn create_project(
  client: Client,
  slug: String,
) -> Promise(Result(Project, Error)) {
  send_json(
    client.api_url,
    create_project_request(client, slug),
    project_decoder(),
  )
}

pub fn rename_project(
  client: Client,
  id: Int,
  slug: String,
) -> Promise(Result(Project, Error)) {
  send_json(
    client.api_url,
    rename_project_request(client, id, slug),
    project_decoder(),
  )
}

pub fn delete_project(client: Client, id: Int) -> Promise(Result(Nil, Error)) {
  send_empty(client.api_url, delete_project_request(client, id))
}

pub fn create_deployment(
  client: Client,
  project_id: Int,
  body: Json,
) -> Promise(Result(Deployed, Error)) {
  send_json(
    client.api_url,
    create_deployment_request(client, project_id, body),
    deployed_decoder(),
  )
}

pub fn usage(client: Client) -> Promise(Result(Usage, Error)) {
  send_json(client.api_url, usage_request(client), usage_decoder())
}

pub fn revoke_token(client: Client) -> Promise(Result(Nil, Error)) {
  send_empty(client.api_url, revoke_token_request(client))
}

pub fn start_device_login(
  api_url: String,
) -> Promise(Result(DeviceLogin, Error)) {
  send_json(
    api_url,
    start_device_login_request(api_url),
    device_login_decoder(),
  )
}

pub fn poll_device_login(
  api_url: String,
  device_code: String,
  interval: Int,
) -> Promise(PollStep) {
  use sent <- promise.map(send(
    api_url,
    poll_device_login_request(api_url, device_code),
  ))
  case sent {
    Ok(#(status, body)) -> poll_step(status, body, interval)
    Error(error) -> PollFailed(error)
  }
}

pub fn me_request(client: Client) -> Result(Request(String), Error) {
  build(client, http.Get, "/me", None)
}

pub fn list_projects_request(client: Client) -> Result(Request(String), Error) {
  build(client, http.Get, "/projects", None)
}

pub fn find_project_request(
  client: Client,
  slug: String,
) -> Result(Request(String), Error) {
  build(client, http.Get, "/projects", None)
  |> result.map(request.set_query(_, [#("slug", slug)]))
}

pub fn create_project_request(
  client: Client,
  slug: String,
) -> Result(Request(String), Error) {
  build(client, http.Post, "/projects", Some(slug_body(slug)))
}

pub fn rename_project_request(
  client: Client,
  id: Int,
  slug: String,
) -> Result(Request(String), Error) {
  build(client, http.Patch, project_path(id), Some(slug_body(slug)))
}

pub fn delete_project_request(
  client: Client,
  id: Int,
) -> Result(Request(String), Error) {
  build(client, http.Delete, project_path(id), None)
}

pub fn create_deployment_request(
  client: Client,
  project_id: Int,
  body: Json,
) -> Result(Request(String), Error) {
  build(
    client,
    http.Post,
    project_path(project_id) <> "/deployments",
    Some(body),
  )
}

pub fn usage_request(client: Client) -> Result(Request(String), Error) {
  build(client, http.Get, "/usage", None)
}

pub fn revoke_token_request(client: Client) -> Result(Request(String), Error) {
  build(client, http.Delete, "/auth/token", None)
}

pub fn start_device_login_request(
  api_url: String,
) -> Result(Request(String), Error) {
  unauthenticated(api_url, "/auth/device", json.object([]))
}

pub fn poll_device_login_request(
  api_url: String,
  device_code: String,
) -> Result(Request(String), Error) {
  unauthenticated(
    api_url,
    "/auth/device/token",
    json.object([#("device_code", json.string(device_code))]),
  )
}

fn project_path(id: Int) -> String {
  "/projects/" <> int.to_string(id)
}

fn slug_body(slug: String) -> Json {
  json.object([#("slug", json.string(slug))])
}

fn build(
  client: Client,
  method: Method,
  path: String,
  body: Option(Json),
) -> Result(Request(String), Error) {
  use req <- result.try(new_request(client.api_url, method, path, body))
  Ok(request.set_header(req, "authorization", "Bearer " <> client.token))
}

fn unauthenticated(
  api_url: String,
  path: String,
  body: Json,
) -> Result(Request(String), Error) {
  new_request(api_url, http.Post, path, Some(body))
}

fn new_request(
  api_url: String,
  method: Method,
  path: String,
  body: Option(Json),
) -> Result(Request(String), Error) {
  let base_url = case string.ends_with(api_url, "/") {
    True -> string.drop_end(api_url, 1)
    False -> api_url
  }
  use base <- result.try(
    request.to(base_url <> "/api/v1" <> path)
    |> result.replace_error(InvalidApiUrl(api_url)),
  )
  let req =
    base
    |> request.set_method(method)
    |> request.set_header("accept", "application/json")

  case body {
    None -> Ok(req)
    Some(body) ->
      req
      |> request.set_header("content-type", "application/json")
      |> request.set_body(json.to_string(body))
      |> Ok
  }
}

fn send(
  api_url: String,
  built: Result(Request(String), Error),
) -> Promise(Result(#(Int, String), Error)) {
  case built {
    Error(error) -> promise.resolve(Error(error))
    Ok(req) -> {
      use sent <- promise.await(fetch.send(req))
      case sent {
        Error(_) -> promise.resolve(Error(Unreachable(api_url)))
        Ok(res) -> {
          use read <- promise.map(fetch.read_text_body(res))
          case read {
            Ok(res) -> Ok(#(res.status, res.body))
            Error(_) -> Error(UnexpectedResponse(status: res.status, body: ""))
          }
        }
      }
    }
  }
}

fn send_json(
  api_url: String,
  built: Result(Request(String), Error),
  decoder: Decoder(a),
) -> Promise(Result(a, Error)) {
  use #(status, body) <- promise.try_await(send(api_url, built))
  promise.resolve(parse_json(status, body, decoder))
}

fn send_empty(
  api_url: String,
  built: Result(Request(String), Error),
) -> Promise(Result(Nil, Error)) {
  use #(status, body) <- promise.try_await(send(api_url, built))
  promise.resolve(parse_empty(status, body))
}

pub fn parse_json(
  status: Int,
  body: String,
  decoder: Decoder(a),
) -> Result(a, Error) {
  case is_success(status) {
    True ->
      json.parse(body, decoder)
      |> result.replace_error(UnexpectedResponse(status:, body:))
    False -> Error(parse_error(status, body))
  }
}

pub fn parse_empty(status: Int, body: String) -> Result(Nil, Error) {
  case is_success(status) {
    True -> Ok(Nil)
    False -> Error(parse_error(status, body))
  }
}

fn is_success(status: Int) -> Bool {
  status >= 200 && status < 300
}

fn parse_error(status: Int, body: String) -> Error {
  let envelope = {
    use code <- decode.subfield(["error", "code"], decode.string)
    use message <- decode.subfield(["error", "message"], decode.string)
    decode.success(Rejected(code: code_from_string(code), message:))
  }

  json.parse(body, envelope)
  |> result.unwrap(UnexpectedResponse(status:, body:))
}

fn code_from_string(code: String) -> Code {
  case code {
    "invalid_request" -> InvalidRequest
    "invalid_slug" -> InvalidSlug
    "not_implemented" -> NotImplemented
    "unauthorized" -> Unauthorized
    "billing_required" -> BillingRequired
    "forbidden" -> Forbidden
    "not_found" -> NotFound
    "slug_taken" -> SlugTaken
    "slug_reserved" -> SlugReserved
    "project_limit" -> ProjectLimit
    "payload_too_large" -> PayloadTooLarge
    "upstream_failed" -> UpstreamFailed
    other -> OtherCode(other)
  }
}

pub fn list_decoder(item: Decoder(a)) -> Decoder(List(a)) {
  decode.at(["data"], decode.list(item))
}

pub fn project_decoder() -> Decoder(Project) {
  use id <- decode.field("id", decode.int)
  use slug <- decode.field("slug", decode.string)
  use url <- decode.field("url", decode.string)
  use suspended <- decode.field("suspended", decode.bool)
  use latest_deployment <- decode.optional_field(
    "latest_deployment",
    None,
    decode.optional(deployment_decoder()),
  )
  decode.success(Project(id:, slug:, url:, suspended:, latest_deployment:))
}

fn deployment_decoder() -> Decoder(Deployment) {
  use url <- decode.field("url", decode.string)
  use status <- decode.field("status", decode.string)
  decode.success(Deployment(url:, status:))
}

pub fn deployed_decoder() -> Decoder(Deployed) {
  use id <- decode.field("id", decode.string)
  use url <- decode.field("url", decode.string)
  use preview <- decode.field("preview", decode.bool)
  decode.success(Deployed(id:, url:, preview:))
}

pub fn me_decoder() -> Decoder(Me) {
  use email <- decode.subfield(["user", "email"], decode.string)
  use token_name <- decode.subfield(["token", "name"], decode.string)
  use scopes <- decode.subfield(["token", "scopes"], decode.list(decode.string))
  use expires_at <- decode.subfield(
    ["token", "expires_at"],
    decode.optional(decode.string),
  )
  decode.success(Me(email:, token_name:, scopes:, expires_at:))
}

pub fn usage_decoder() -> Decoder(Usage) {
  use requests <- decode.field("requests", decode.int)
  use included <- decode.optional_field(
    "included",
    None,
    decode.optional(decode.int),
  )
  use period_start <- decode.field(
    "period_start",
    decode.optional(decode.string),
  )
  use period_end <- decode.field("period_end", decode.optional(decode.string))
  decode.success(Usage(requests:, included:, period_start:, period_end:))
}

pub fn describe_usage(usage: Usage) -> List(String) {
  let requests = case usage.included {
    Some(included) ->
      int.to_string(usage.requests) <> " of " <> int.to_string(included)
    None -> int.to_string(usage.requests)
  }
  let period = case usage.period_start, usage.period_end {
    Some(start), Some(end) -> start <> " to " <> end
    _, _ -> "no billing period yet"
  }
  ["Requests: " <> requests, "Period:   " <> period]
}

// The same fields and names as the API, so a script reads one shape from
// either.
pub fn usage_json(usage: Usage) -> String {
  json.object([
    #("requests", json.int(usage.requests)),
    #("included", json.nullable(usage.included, json.int)),
    #("period_start", json.nullable(usage.period_start, json.string)),
    #("period_end", json.nullable(usage.period_end, json.string)),
  ])
  |> json.to_string
}

pub fn device_login_decoder() -> Decoder(DeviceLogin) {
  use device_code <- decode.field("device_code", decode.string)
  use user_code <- decode.field("user_code", decode.string)
  use verification_url <- decode.field("verification_url", decode.string)
  use expires_in <- decode.field("expires_in", decode.int)
  use interval <- decode.field("interval", decode.int)
  decode.success(DeviceLogin(
    device_code:,
    user_code:,
    verification_url:,
    expires_in:,
    interval:,
  ))
}

pub fn poll_step(status: Int, body: String, interval: Int) -> PollStep {
  case status {
    200 ->
      case json.parse(body, decode.at(["token"], decode.string)) {
        Ok(token) -> Approved(token)
        Error(_) -> PollFailed(UnexpectedResponse(status:, body:))
      }
    428 -> Pending(interval)
    429 -> Pending(interval + slow_down_seconds)
    410 -> CodeExpired
    403 -> Denied
    _ -> PollFailed(parse_error(status, body))
  }
}

// Callers forget the local token whatever happens here, so a failure is only
// ever a warning: the token may still be live on the server.
pub fn revocation(result: Result(Nil, Error)) -> Revocation {
  case result {
    Ok(Nil) -> Revoked
    Error(Rejected(code: Unauthorized, ..)) -> AlreadyInvalid
    Error(error) ->
      NotRevoked(
        "Could not revoke the token, so it may still be valid. "
        <> describe_error(error)
        <> " Revoke it on the dashboard's Tokens page.",
      )
  }
}

// The URL comes from the server, and opening it hands it to the OS. Anything
// but https (or plain http to this machine, for local development) is only
// printed.
pub fn can_open_in_browser(url: String) -> Bool {
  case url {
    "https://" <> _ -> True
    "http://localhost" <> after_host | "http://127.0.0.1" <> after_host ->
      after_host == ""
      || string.starts_with(after_host, ":")
      || string.starts_with(after_host, "/")
    _ -> False
  }
}

pub fn pick_project(
  projects: List(Project),
  slug: String,
) -> Result(Project, Error) {
  list.find(projects, fn(project) { project.slug == slug })
  |> result.replace_error(NoSuchProject(slug))
}

pub fn describe_error(error: Error) -> String {
  case error {
    Rejected(code: Unauthorized, message:) ->
      message <> " Run `giolt login`, or check `GIOLT_TOKEN` if it is set."
    Rejected(message:, ..) -> message
    // The body of a response without our error envelope comes from something
    // in front of the API, and may name the hosting provider.
    UnexpectedResponse(status:, ..) ->
      "The Giolt API sent an unexpected response (status "
      <> int.to_string(status)
      <> "). Try again in a moment."
    Unreachable(api_url) ->
      "Could not reach the Giolt API at "
      <> api_url
      <> ". Check your connection, `api_url` and `GIOLT_API_URL`."
    InvalidApiUrl(api_url) ->
      "`"
      <> api_url
      <> "` is not a valid API URL. "
      <> "Check `api_url` under [tools.giolt] and `GIOLT_API_URL`."
    NoSuchProject(slug) ->
      "No project named `" <> slug <> "`. Run `giolt projects` to list yours."
  }
}
