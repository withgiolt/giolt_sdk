import giolt_sdk/internal/cli.{Build, Deploy, Dev, Invalid, Run, Usage}
import gleam/string

pub fn each_command_is_recognised_test() {
  assert cli.parse(["build"]) == Run(Build)
  assert cli.parse(["dev"]) == Run(Dev)
  assert cli.parse(["deploy"]) == Run(Deploy)
}

pub fn no_arguments_shows_usage_test() {
  let assert Usage(text) = cli.parse([])

  assert string.contains(text, "build")
  assert string.contains(text, "dev")
  assert string.contains(text, "deploy")
}

pub fn help_flags_show_usage_test() {
  let assert Usage(long) = cli.parse(["--help"])
  let assert Usage(short) = cli.parse(["-h"])

  assert string.contains(long, "build")
  assert long == short
}

pub fn help_after_a_command_shows_usage_test() {
  let assert Usage(text) = cli.parse(["build", "--help"])

  assert string.contains(text, "build")
}

pub fn unknown_command_is_invalid_and_named_test() {
  let assert Invalid(text) = cli.parse(["frobnicate"])

  assert string.contains(text, "frobnicate")
  assert string.contains(text, "build")
}

pub fn extra_arguments_are_invalid_test() {
  let assert Invalid(text) = cli.parse(["build", "now"])

  assert string.contains(text, "now")
}
