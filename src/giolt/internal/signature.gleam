import giolt/internal/config.{type Target, Erlang, Javascript}
import gleam/dict
import gleam/json
import gleam/list
import gleam/package_interface.{type Function, type Type}
import gleam/result
import gleam/string

pub type Error {
  UnreadableInterface
  ModuleNotFound(module: String)
  HandleMissing(module: String)
  HandlerRenamed(module: String)
  WrongParameterCount(module: String, found: Int)
  WrongSignature(module: String, expected: String, found: String)
}

pub fn check(
  interface: String,
  module: String,
  target: Target,
) -> Result(Nil, Error) {
  use package <- result.try(
    json.parse(interface, package_interface.decoder())
    |> result.replace_error(UnreadableInterface),
  )
  use found <- result.try(
    dict.get(package.modules, module)
    |> result.replace_error(ModuleNotFound(module)),
  )

  case dict.get(found.functions, "handle") {
    Ok(function) -> check_handle(function, module, target)
    Error(_) ->
      case dict.has_key(found.functions, "handler") {
        True -> Error(HandlerRenamed(module))
        False -> Error(HandleMissing(module))
      }
  }
}

fn check_handle(
  function: Function,
  module: String,
  target: Target,
) -> Result(Nil, Error) {
  case function.parameters {
    [parameter] ->
      case accepts(target, parameter.type_, function.return) {
        True -> Ok(Nil)
        False ->
          Error(WrongSignature(
            module:,
            expected: expected(target),
            found: "fn("
              <> render(parameter.type_)
              <> ") -> "
              <> render(function.return),
          ))
      }
    parameters ->
      Error(WrongParameterCount(module:, found: list.length(parameters)))
  }
}

fn accepts(target: Target, request: Type, response: Type) -> Bool {
  case target {
    Javascript ->
      is_request(request, "conversation")
      && {
        is_response(response, "conversation")
        || is_promise_of(response, is_response(_, "conversation"))
      }
    Erlang -> is_request(request, "wisp") && is_response(response, "wisp")
  }
}

fn is_request(type_: Type, body_package: String) -> Bool {
  is_http(type_, "gleam/http/request", "Request", body_package)
}

fn is_response(type_: Type, body_package: String) -> Bool {
  is_http(type_, "gleam/http/response", "Response", body_package)
}

fn is_http(
  type_: Type,
  module: String,
  name: String,
  body_package: String,
) -> Bool {
  case type_ {
    package_interface.Named(
      name: found_name,
      package: "gleam_http",
      module: found_module,
      parameters: [package_interface.Named(package:, parameters: [], ..)],
    ) -> found_name == name && found_module == module && package == body_package
    _ -> False
  }
}

fn is_promise_of(type_: Type, inner: fn(Type) -> Bool) -> Bool {
  case type_ {
    package_interface.Named(
      name: "Promise",
      package: "gleam_javascript",
      module: "gleam/javascript/promise",
      parameters: [value],
    ) -> inner(value)
    _ -> False
  }
}

fn expected(target: Target) -> String {
  case target {
    Javascript ->
      "fn(request.Request(conversation.RequestBody)) -> response.Response(conversation.ResponseBody)"
    Erlang -> "fn(wisp.Request) -> wisp.Response"
  }
}

fn render(type_: Type) -> String {
  case type_ {
    package_interface.Tuple(elements:) ->
      "#(" <> string.join(list.map(elements, render), ", ") <> ")"
    package_interface.Fn(parameters:, return:) ->
      "fn("
      <> string.join(list.map(parameters, render), ", ")
      <> ") -> "
      <> render(return)
    package_interface.Variable(..) -> "a"
    package_interface.Named(name:, module:, parameters:, ..) -> {
      let qualified = case module {
        "gleam" -> name
        _ -> last_segment(module) <> "." <> name
      }
      case parameters {
        [] -> qualified
        _ ->
          qualified
          <> "("
          <> string.join(list.map(parameters, render), ", ")
          <> ")"
      }
    }
  }
}

fn last_segment(module: String) -> String {
  case list.last(string.split(module, "/")) {
    Ok(segment) -> segment
    Error(_) -> module
  }
}

pub fn describe_error(error: Error) -> String {
  case error {
    UnreadableInterface ->
      "Could not read the package interface that `gleam export package-interface` wrote."
    ModuleNotFound(module) ->
      "The entry module `"
      <> module
      <> "` is not in the package interface. Check `entry` under [tools.giolt]; "
      <> "the module must exist and must not be listed in `internal_modules`."
    HandleMissing(module) ->
      "`"
      <> module
      <> "` does not export `pub fn handle`. Add one, or set `entry` under "
      <> "[tools.giolt] to the module that has it."
    HandlerRenamed(module) ->
      "`"
      <> module
      <> "` exports `handler`, which was renamed to `handle`. Rename the function."
    WrongParameterCount(module, found) ->
      "`"
      <> module
      <> ".handle` takes "
      <> string.inspect(found)
      <> " parameters, but must take exactly one: the request."
    WrongSignature(module, expected, found) ->
      "`"
      <> module
      <> ".handle` has the wrong type.\n  expected: "
      <> expected
      <> "\n  found:    "
      <> found
  }
}
