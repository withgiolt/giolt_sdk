import giolt/internal/api.{
  AlreadyInvalid, Approved, Client, CodeExpired, Denied, Deployment, DeviceLogin,
  Me, NoSuchProject, NotRevoked, Pending, PollFailed, Project, Rejected, Revoked,
  UnexpectedResponse, Unreachable, Usage,
}
import gleam/http
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string

const client = Client(api_url: "https://dash.giolt.com", token: "giolt_abc")

fn project(id: Int, slug: String) -> api.Project {
  Project(
    id:,
    slug:,
    url: "https://" <> slug <> ".giolt.app",
    suspended: False,
    latest_deployment: None,
  )
}

pub fn requests_carry_the_bearer_token_under_api_v1_test() {
  let assert Ok(req) = api.me_request(client)

  assert req.method == http.Get
  assert req.host == "dash.giolt.com"
  assert req.path == "/api/v1/me"
  assert req.headers |> has_header("authorization", "Bearer giolt_abc")
}

pub fn a_trailing_slash_on_api_url_is_ignored_test() {
  let assert Ok(req) =
    api.me_request(Client(api_url: "http://localhost:8787/", token: "t"))

  assert req.path == "/api/v1/me"
  assert req.port == Some(8787)
}

pub fn an_unusable_api_url_is_reported_test() {
  assert api.me_request(Client(api_url: "dash.giolt.com", token: "t"))
    == Error(api.InvalidApiUrl("dash.giolt.com"))
}

pub fn project_lookup_filters_by_encoded_slug_test() {
  let assert Ok(req) = api.find_project_request(client, "my blog")

  assert req.path == "/api/v1/projects"
  assert req.query == Some("slug=my%20blog")
}

pub fn create_posts_the_slug_as_json_test() {
  let assert Ok(req) = api.create_project_request(client, "blog")

  assert req.method == http.Post
  assert req.path == "/api/v1/projects"
  assert req.body == "{\"slug\":\"blog\"}"
  assert req.headers |> has_header("content-type", "application/json")
}

pub fn rename_and_delete_address_the_project_by_id_test() {
  let assert Ok(rename) = api.rename_project_request(client, 7, "notes")
  let assert Ok(delete) = api.delete_project_request(client, 7)

  assert rename.method == http.Patch
  assert rename.path == "/api/v1/projects/7"
  assert rename.body == "{\"slug\":\"notes\"}"
  assert delete.method == http.Delete
  assert delete.path == "/api/v1/projects/7"
}

pub fn a_project_list_is_decoded_test() {
  let body =
    "{\"data\":[{\"id\":7,\"slug\":\"blog\",\"url\":\"https://blog.giolt.app\","
    <> "\"target\":\"javascript\",\"suspended\":false,"
    <> "\"created_at\":\"2026-10-01T00:00:00Z\","
    <> "\"updated_at\":\"2026-10-02T00:00:00Z\","
    <> "\"latest_deployment\":{\"id\":3,\"url\":\"https://blog.giolt.app\","
    <> "\"status\":\"live\",\"created_at\":\"2026-10-02T00:00:00Z\"}},"
    <> "{\"id\":8,\"slug\":\"notes\",\"url\":\"https://notes.giolt.app\","
    <> "\"target\":\"javascript\",\"suspended\":true,"
    <> "\"created_at\":\"2026-10-01T00:00:00Z\","
    <> "\"updated_at\":\"2026-10-01T00:00:00Z\","
    <> "\"latest_deployment\":null}]}"

  assert api.parse_json(200, body, api.list_decoder(api.project_decoder()))
    == Ok([
      Project(
        id: 7,
        slug: "blog",
        url: "https://blog.giolt.app",
        suspended: False,
        latest_deployment: Some(Deployment(
          url: "https://blog.giolt.app",
          status: "live",
        )),
      ),
      Project(
        id: 8,
        slug: "notes",
        url: "https://notes.giolt.app",
        suspended: True,
        latest_deployment: None,
      ),
    ])
}

pub fn me_is_decoded_with_a_nullable_expiry_test() {
  let body =
    "{\"user\":{\"id\":1,\"email\":\"ada@example.com\"},"
    <> "\"token\":{\"name\":\"laptop\","
    <> "\"scopes\":[\"projects:read\",\"deploy\"],"
    <> "\"expires_at\":null}}"

  assert api.parse_json(200, body, api.me_decoder())
    == Ok(Me(
      email: "ada@example.com",
      token_name: "laptop",
      scopes: ["projects:read", "deploy"],
      expires_at: None,
    ))
}

pub fn usage_is_decoded_test() {
  let body =
    "{\"requests\":1234,\"period_start\":\"2026-11-01T00:00:00Z\","
    <> "\"period_end\":\"2026-12-01T00:00:00Z\"}"

  assert api.parse_json(200, body, api.usage_decoder())
    == Ok(Usage(
      requests: 1234,
      period_start: "2026-11-01T00:00:00Z",
      period_end: "2026-12-01T00:00:00Z",
    ))
}

pub fn the_error_envelope_becomes_a_typed_code_test() {
  let body =
    "{\"error\":{\"code\":\"project_limit\","
    <> "\"message\":\"You've reached the limit of 5 projects.\"}}"

  assert api.parse_json(409, body, api.me_decoder())
    == Error(Rejected(
      code: api.ProjectLimit,
      message: "You've reached the limit of 5 projects.",
    ))
}

pub fn an_unknown_code_keeps_its_name_and_message_test() {
  let body =
    "{\"error\":{\"code\":\"rate_limited\",\"message\":\"Slow down.\"}}"

  assert api.parse_json(429, body, api.me_decoder())
    == Error(Rejected(
      code: api.OtherCode("rate_limited"),
      message: "Slow down.",
    ))
}

pub fn a_body_without_the_envelope_keeps_status_and_body_test() {
  assert api.parse_json(502, "Bad gateway", api.me_decoder())
    == Error(UnexpectedResponse(status: 502, body: "Bad gateway"))
}

pub fn a_malformed_success_body_is_unexpected_test() {
  assert api.parse_json(200, "{\"data\":5}", api.me_decoder())
    == Error(UnexpectedResponse(status: 200, body: "{\"data\":5}"))
}

pub fn no_content_is_success_test() {
  assert api.parse_empty(204, "") == Ok(Nil)
  assert api.parse_empty(
      404,
      "{\"error\":{\"code\":\"not_found\",\"message\":\"No such project.\"}}",
    )
    == Error(Rejected(code: api.NotFound, message: "No such project."))
}

pub fn a_slug_lookup_picks_the_exact_match_test() {
  assert api.pick_project([project(1, "blog"), project(2, "blog-2")], "blog-2")
    == Ok(project(2, "blog-2"))
  assert api.pick_project([], "blog") == Error(NoSuchProject("blog"))
}

pub fn unauthorized_points_to_login_test() {
  let message =
    api.describe_error(Rejected(
      code: api.Unauthorized,
      message: "Token expired.",
    ))

  assert string.contains(message, "Token expired.")
  assert string.contains(message, "giolt login")
}

pub fn server_messages_are_printed_as_is_test() {
  let message = "Add a payment method at https://dash.giolt.com/billing."

  assert api.describe_error(Rejected(code: api.BillingRequired, message:))
    == message
  assert api.describe_error(Rejected(code: api.OtherCode("new_code"), message:))
    == message
}

pub fn an_unexpected_response_names_the_status_but_not_the_body_test() {
  let message =
    api.describe_error(UnexpectedResponse(
      status: 502,
      body: "error code: 502 from some edge proxy",
    ))

  assert string.contains(message, "502")
  assert !string.contains(message, "proxy")
}

pub fn a_missing_project_suggests_listing_test() {
  let message = api.describe_error(NoSuchProject("blog"))

  assert string.contains(message, "`blog`")
  assert string.contains(message, "giolt projects")
}

pub fn the_device_flow_requests_carry_no_token_test() {
  let assert Ok(start) =
    api.start_device_login_request("https://dash.giolt.com")
  let assert Ok(poll) =
    api.poll_device_login_request("https://dash.giolt.com", "dev_123")

  assert start.method == http.Post
  assert start.path == "/api/v1/auth/device"
  assert poll.method == http.Post
  assert poll.path == "/api/v1/auth/device/token"
  assert poll.body == "{\"device_code\":\"dev_123\"}"
  assert !list.any(poll.headers, fn(header) { header.0 == "authorization" })
}

pub fn a_device_login_is_decoded_test() {
  let body =
    "{\"device_code\":\"dev_123\",\"user_code\":\"ABCD-EFGH\","
    <> "\"verification_url\":\"https://dash.giolt.com/device?code=ABCD-EFGH\","
    <> "\"expires_in\":600,\"interval\":5}"

  assert api.parse_json(200, body, api.device_login_decoder())
    == Ok(DeviceLogin(
      device_code: "dev_123",
      user_code: "ABCD-EFGH",
      verification_url: "https://dash.giolt.com/device?code=ABCD-EFGH",
      expires_in: 600,
      interval: 5,
    ))
}

pub fn an_approved_poll_carries_the_token_test() {
  let body = "{\"token\":\"giolt_new\",\"expires_at\":\"2027-02-01T00:00:00Z\"}"

  assert api.poll_step(200, body, 5) == Approved("giolt_new")
}

pub fn a_pending_poll_keeps_the_interval_test() {
  let body =
    "{\"error\":{\"code\":\"authorization_pending\",\"message\":\"Waiting.\"}}"

  assert api.poll_step(428, body, 5) == Pending(5)
}

pub fn slow_down_adds_five_seconds_test() {
  let body = "{\"error\":{\"code\":\"slow_down\",\"message\":\"Slow down.\"}}"

  assert api.poll_step(429, body, 5) == Pending(10)
  assert api.poll_step(429, body, 10) == Pending(15)
}

pub fn expired_and_denied_polls_stop_test() {
  assert api.poll_step(410, "", 5) == CodeExpired
  assert api.poll_step(403, "", 5) == Denied
}

pub fn any_other_poll_answer_fails_test() {
  assert api.poll_step(500, "oops", 5)
    == PollFailed(UnexpectedResponse(status: 500, body: "oops"))
  assert api.poll_step(200, "{}", 5)
    == PollFailed(UnexpectedResponse(status: 200, body: "{}"))
}

pub fn logout_revokes_the_token_with_a_delete_test() {
  let assert Ok(req) = api.revoke_token_request(client)

  assert req.method == http.Delete
  assert req.path == "/api/v1/auth/token"
  assert req.headers |> has_header("authorization", "Bearer giolt_abc")
}

pub fn revocation_outcomes_test() {
  assert api.revocation(Ok(Nil)) == Revoked
  assert api.revocation(
      Error(Rejected(code: api.Unauthorized, message: "Token revoked.")),
    )
    == AlreadyInvalid
}

pub fn a_failed_revoke_is_a_warning_naming_the_dashboard_test() {
  let assert NotRevoked(network) =
    api.revocation(Error(Unreachable("https://dash.giolt.com")))
  let assert NotRevoked(server) =
    api.revocation(Error(UnexpectedResponse(status: 503, body: "")))

  assert string.contains(network, "may still be valid")
  assert string.contains(network, "Tokens page")
  assert string.contains(server, "503")
}

pub fn only_https_or_local_urls_are_opened_test() {
  assert api.can_open_in_browser("https://dash.giolt.com/device?code=AB")
  assert api.can_open_in_browser("http://localhost:8787/device")
  assert api.can_open_in_browser("http://127.0.0.1:8787/device")
  assert !api.can_open_in_browser("http://dash.giolt.com/device")
  assert !api.can_open_in_browser("http://localhost.evil.example/device")
  assert !api.can_open_in_browser("http://127.0.0.1.evil.example/device")
  assert !api.can_open_in_browser("file:///etc/passwd")
  assert !api.can_open_in_browser("calc.exe")
  assert !api.can_open_in_browser("javascript:alert(1)")
}

fn has_header(
  headers: List(#(String, String)),
  name: String,
  value: String,
) -> Bool {
  list.contains(headers, #(name, value))
}

pub fn a_deployment_posts_the_body_to_the_project_test() {
  let body = json.object([#("preview", json.bool(False))])
  let assert Ok(req) = api.create_deployment_request(client, 7, body)

  assert req.method == http.Post
  assert req.path == "/api/v1/projects/7/deployments"
  assert req.body == "{\"preview\":false}"
  assert req.headers |> has_header("authorization", "Bearer giolt_abc")
}

pub fn a_created_deployment_is_decoded_test() {
  let body =
    "{\"id\":\"v1\",\"url\":\"https://blog.giolt.app\",\"preview\":false}"

  assert api.parse_json(201, body, api.deployed_decoder())
    == Ok(api.Deployed(id: "v1", url: "https://blog.giolt.app", preview: False))
}
