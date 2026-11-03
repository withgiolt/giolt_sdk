import giolt/internal/cli.{Build, Deploy, Dev, Invalid, Run, Usage}
import gleam/option.{None, Some}
import gleam/string

pub fn each_command_is_recognised_test() {
  assert cli.parse(["build"]) == Run(Build(config: None))
  assert cli.parse(["dev"]) == Run(Dev(config: None))
  assert cli.parse(["deploy"])
    == Run(Deploy(preview: False, artifact: None, config: None))
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
    == Run(Deploy(preview: True, artifact: None, config: None))
  assert cli.parse(["deploy", "--artifact", "site"])
    == Run(Deploy(preview: False, artifact: Some("site"), config: None))
}

pub fn deploy_message_is_no_longer_a_flag_test() {
  let assert Invalid(text) = cli.parse(["deploy", "--message", "x"])

  assert string.contains(text, "message")
}

pub fn deploy_flags_do_not_apply_to_other_commands_test() {
  let assert Invalid(_) = cli.parse(["build", "--preview"])
  let assert Invalid(_) = cli.parse(["dev", "--artifact", "x"])
}

pub fn deploy_usage_lists_its_flags_test() {
  let assert Usage(text) = cli.parse(["deploy", "--help"])

  assert string.contains(text, "--preview")
  assert string.contains(text, "--artifact")
}

pub fn deploy_artifact_flag_is_read_test() {
  assert cli.parse(["deploy", "--artifact", "./site"])
    == Run(Deploy(preview: False, artifact: Some("./site"), config: None))
}

pub fn deploy_usage_lists_the_artifact_flag_test() {
  let assert Usage(text) = cli.parse(["deploy", "--help"])

  assert string.contains(text, "--artifact")
}

pub fn config_flag_is_read_on_every_command_test() {
  assert cli.parse(["build", "--config", "giolt.dash.toml"])
    == Run(Build(config: Some("giolt.dash.toml")))
  assert cli.parse(["dev", "--config", "giolt.dash.toml"])
    == Run(Dev(config: Some("giolt.dash.toml")))
  assert cli.parse(["deploy", "--preview", "--config", "giolt.dash.toml"])
    == Run(Deploy(
      preview: True,
      artifact: None,
      config: Some("giolt.dash.toml"),
    ))
}

pub fn config_flag_without_a_value_is_invalid_test() {
  let assert Invalid(text) = cli.parse(["dev", "--config"])

  assert string.contains(text, "config")
}
