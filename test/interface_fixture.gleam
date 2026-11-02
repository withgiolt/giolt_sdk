import gleam/list
import gleam/string

pub type Fn {
  Fn(name: String, parameters: List(String), return: String)
}

pub fn named(
  package package: String,
  module module: String,
  name name: String,
  parameters parameters: List(String),
) -> String {
  "{\"kind\":\"named\",\"name\":\""
  <> name
  <> "\",\"package\":\""
  <> package
  <> "\",\"module\":\""
  <> module
  <> "\",\"parameters\":["
  <> string.join(parameters, ",")
  <> "]}"
}

pub fn prelude(name: String) -> String {
  named(package: "", module: "gleam", name:, parameters: [])
}

pub fn variable() -> String {
  "{\"kind\":\"variable\",\"id\":0}"
}

pub fn package(module module: String, functions functions: List(Fn)) -> String {
  "{\"name\":\"hello\",\"version\":\"1.0.0\",\"gleam-version-constraint\":null,\"modules\":{\""
  <> module
  <> "\":{\"documentation\":[],\"type-aliases\":{},\"types\":{},\"constants\":{},\"functions\":{"
  <> string.join(list.map(functions, function), ",")
  <> "}}}}"
}

fn function(fun: Fn) -> String {
  "\""
  <> fun.name
  <> "\":{\"documentation\":null,\"deprecation\":null,\"implementations\":{\"gleam\":true,\"uses-erlang-externals\":false,\"uses-javascript-externals\":false,\"can-run-on-erlang\":true,\"can-run-on-javascript\":true},\"parameters\":["
  <> string.join(list.map(fun.parameters, parameter), ",")
  <> "],\"return\":"
  <> fun.return
  <> "}"
}

fn parameter(type_: String) -> String {
  "{\"label\":null,\"type\":" <> type_ <> "}"
}

pub fn js_request() -> String {
  named(
    package: "gleam_http",
    module: "gleam/http/request",
    name: "Request",
    parameters: [
      named(
        package: "conversation",
        module: "conversation",
        name: "RequestBody",
        parameters: [],
      ),
    ],
  )
}

pub fn js_response() -> String {
  named(
    package: "gleam_http",
    module: "gleam/http/response",
    name: "Response",
    parameters: [
      named(
        package: "conversation",
        module: "conversation",
        name: "ResponseBody",
        parameters: [],
      ),
    ],
  )
}

pub fn js_promise_response() -> String {
  named(
    package: "gleam_javascript",
    module: "gleam/javascript/promise",
    name: "Promise",
    parameters: [js_response()],
  )
}

pub fn wisp_request() -> String {
  named(
    package: "gleam_http",
    module: "gleam/http/request",
    name: "Request",
    parameters: [
      named(
        package: "wisp",
        module: "wisp/internal",
        name: "Connection",
        parameters: [],
      ),
    ],
  )
}

pub fn wisp_response() -> String {
  named(
    package: "gleam_http",
    module: "gleam/http/response",
    name: "Response",
    parameters: [
      named(package: "wisp", module: "wisp", name: "Body", parameters: []),
    ],
  )
}
