import giolt_sdk/internal/config.{Erlang, Javascript}
import giolt_sdk/internal/signature
import interface_fixture.{Fn}

fn handle(parameters, return) {
  interface_fixture.package(module: "hello", functions: [
    Fn("handle", parameters, return),
  ])
}

pub fn javascript_handle_is_accepted_test() {
  let json =
    handle([interface_fixture.js_request()], interface_fixture.js_response())

  assert signature.check(json, "hello", Javascript) == Ok(Nil)
}

pub fn javascript_handle_may_return_a_promise_test() {
  let json =
    handle(
      [interface_fixture.js_request()],
      interface_fixture.js_promise_response(),
    )

  assert signature.check(json, "hello", Javascript) == Ok(Nil)
}

pub fn erlang_handle_is_accepted_test() {
  let json =
    handle(
      [interface_fixture.wisp_request()],
      interface_fixture.wisp_response(),
    )

  assert signature.check(json, "hello", Erlang) == Ok(Nil)
}

pub fn missing_handle_is_reported_test() {
  let json =
    interface_fixture.package(module: "hello", functions: [
      Fn("main", [], interface_fixture.prelude("Nil")),
    ])

  assert signature.check(json, "hello", Javascript)
    == Error(signature.HandleMissing("hello"))
}

pub fn handler_export_is_reported_as_renamed_test() {
  let json =
    interface_fixture.package(module: "hello", functions: [
      Fn(
        "handler",
        [interface_fixture.js_request()],
        interface_fixture.js_response(),
      ),
    ])

  assert signature.check(json, "hello", Javascript)
    == Error(signature.HandlerRenamed("hello"))
}

pub fn handle_wins_over_a_leftover_handler_test() {
  let json =
    interface_fixture.package(module: "hello", functions: [
      Fn(
        "handler",
        [interface_fixture.js_request()],
        interface_fixture.js_response(),
      ),
      Fn(
        "handle",
        [interface_fixture.js_request()],
        interface_fixture.js_response(),
      ),
    ])

  assert signature.check(json, "hello", Javascript) == Ok(Nil)
}

pub fn handle_with_the_wrong_number_of_parameters_is_reported_test() {
  let none = handle([], interface_fixture.js_response())
  let two =
    handle(
      [interface_fixture.js_request(), interface_fixture.prelude("Int")],
      interface_fixture.js_response(),
    )

  assert signature.check(none, "hello", Javascript)
    == Error(signature.WrongParameterCount(module: "hello", found: 0))
  assert signature.check(two, "hello", Javascript)
    == Error(signature.WrongParameterCount(module: "hello", found: 2))
}

pub fn handle_with_the_wrong_request_type_is_reported_test() {
  let json =
    handle(
      [interface_fixture.prelude("String")],
      interface_fixture.js_response(),
    )

  assert signature.check(json, "hello", Javascript)
    == Error(signature.WrongSignature(
      module: "hello",
      expected: "fn(request.Request(conversation.RequestBody)) -> response.Response(conversation.ResponseBody)",
      found: "fn(String) -> response.Response(conversation.ResponseBody)",
    ))
}

pub fn handle_with_the_wrong_return_type_is_reported_test() {
  let json =
    handle(
      [interface_fixture.js_request()],
      interface_fixture.prelude("String"),
    )

  assert signature.check(json, "hello", Javascript)
    == Error(signature.WrongSignature(
      module: "hello",
      expected: "fn(request.Request(conversation.RequestBody)) -> response.Response(conversation.ResponseBody)",
      found: "fn(request.Request(conversation.RequestBody)) -> String",
    ))
}

pub fn the_other_targets_signature_is_rejected_test() {
  let wisp =
    handle(
      [interface_fixture.wisp_request()],
      interface_fixture.wisp_response(),
    )
  let js =
    handle([interface_fixture.js_request()], interface_fixture.js_response())

  assert signature.check(wisp, "hello", Javascript) != Ok(Nil)
  assert signature.check(js, "hello", Erlang) != Ok(Nil)
}

pub fn erlang_handle_may_not_return_a_promise_test() {
  let json =
    handle(
      [interface_fixture.wisp_request()],
      interface_fixture.js_promise_response(),
    )

  assert signature.check(json, "hello", Erlang) != Ok(Nil)
}

pub fn unknown_entry_module_is_reported_test() {
  let json =
    handle([interface_fixture.js_request()], interface_fixture.js_response())

  assert signature.check(json, "other", Javascript)
    == Error(signature.ModuleNotFound("other"))
}

pub fn unreadable_interface_is_reported_test() {
  assert signature.check("not json", "hello", Javascript)
    == Error(signature.UnreadableInterface)
}
