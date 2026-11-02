import giolt/internal/cli.{Build, Deploy, Dev, Invalid, Run, Usage}
import gleam/option.{None, Some}
import gleam/string

pub fn each_command_is_recognised_test() {
  assert cli.parse(["build"]) == Run(Build)
  assert cli.parse(["dev"]) == Run(Dev)
  assert cli.parse(["deploy"]) == Run(Deploy(preview: False, message: None))
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

pub fn deploy_flags_are_read_test() {
  assert cli.parse(["deploy", "--preview"])
    == Run(Deploy(preview: True, message: None))
  assert cli.parse(["deploy", "--message", "fix the header"])
    == Run(Deploy(preview: False, message: Some("fix the header")))
  assert cli.parse(["deploy", "--preview", "--message", "try it"])
    == Run(Deploy(preview: True, message: Some("try it")))
}

pub fn deploy_message_without_a_value_is_invalid_test() {
  let assert Invalid(text) = cli.parse(["deploy", "--message"])

  assert string.contains(text, "message")
}

pub fn deploy_flags_do_not_apply_to_other_commands_test() {
  let assert Invalid(_) = cli.parse(["build", "--preview"])
  let assert Invalid(_) = cli.parse(["dev", "--message", "x"])
}

pub fn deploy_usage_lists_its_flags_test() {
  let assert Usage(text) = cli.parse(["deploy", "--help"])

  assert string.contains(text, "--preview")
  assert string.contains(text, "--message")
}
