import giolt_sdk/internal/tooling.{Erlang, Rebar3}
import gleam/string

pub fn missing_tools_are_named_with_a_hint_test() {
  let message = tooling.describe_missing([Erlang, Rebar3])

  assert string.contains(message, "Erlang/OTP")
  assert string.contains(message, "https://www.erlang.org/downloads")
  assert string.contains(message, "rebar3")
  assert string.contains(message, "https://rebar3.org")
}

pub fn only_the_missing_tools_are_named_test() {
  let message = tooling.describe_missing([Rebar3])

  assert string.contains(message, "rebar3")
  assert !string.contains(message, "Erlang/OTP")
}

pub fn each_tool_has_a_probe_that_exits_without_a_shell_test() {
  assert tooling.probe(Erlang) == #("erl", ["-noshell", "-eval", "halt(0)."])
  assert tooling.probe(Rebar3) == #("rebar3", ["version"])
}

pub fn the_erlang_target_needs_erlang_and_rebar3_test() {
  assert tooling.required() == [Erlang, Rebar3]
}
