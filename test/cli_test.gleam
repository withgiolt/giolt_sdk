import giolt/internal/cli.{
  Build, CreateProject, DeleteProject, Deploy, Dev, Invalid, Link, ListProjects,
  Login, Logout, RenameProject, Run, ShowUsage, Unlink, Usage, Whoami,
}
import gleam/option.{None, Some}
import gleam/string

pub fn each_command_is_recognised_test() {
  assert cli.parse(["build"]) == Run(Build(config: None))
  assert cli.parse(["dev"]) == Run(Dev(config: None))
  assert cli.parse(["deploy"])
    == Run(Deploy(preview: False, artifact: None, project: None, config: None))
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
    == Run(Deploy(preview: True, artifact: None, project: None, config: None))
  assert cli.parse(["deploy", "--artifact", "site"])
    == Run(Deploy(
      preview: False,
      artifact: Some("site"),
      project: None,
      config: None,
    ))
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
    == Run(Deploy(
      preview: False,
      artifact: Some("./site"),
      project: None,
      config: None,
    ))
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
      project: None,
      config: Some("giolt.dash.toml"),
    ))
  assert cli.parse(["link", "blog", "--config", "giolt.dash.toml"])
    == Run(Link(name: "blog", config: Some("giolt.dash.toml")))
  assert cli.parse(["unlink", "--config", "giolt.dash.toml"])
    == Run(Unlink(config: Some("giolt.dash.toml")))
}

pub fn deploy_takes_a_project_name_test() {
  assert cli.parse(["deploy", "--project", "blog"])
    == Run(Deploy(
      preview: False,
      artifact: None,
      project: Some("blog"),
      config: None,
    ))
}

pub fn link_needs_a_name_test() {
  let assert Invalid(_) = cli.parse(["link"])
  assert cli.parse(["link", "blog"]) == Run(Link(name: "blog", config: None))
  assert cli.parse(["unlink"]) == Run(Unlink(config: None))
}

pub fn config_flag_without_a_value_is_invalid_test() {
  let assert Invalid(text) = cli.parse(["dev", "--config"])

  assert string.contains(text, "config")
}

pub fn account_commands_are_recognised_test() {
  assert cli.parse(["login", "--token", "giolt_abc"])
    == Run(Login(token: Some("giolt_abc")))
  assert cli.parse(["login"]) == Run(Login(token: None))
  assert cli.parse(["login", "--token", "-"]) == Run(Login(token: Some("-")))
  assert cli.parse(["logout"]) == Run(Logout)
  assert cli.parse(["whoami"]) == Run(Whoami)
  assert cli.parse(["usage"]) == Run(ShowUsage)
}

pub fn projects_subcommands_are_recognised_test() {
  assert cli.parse(["projects"]) == Run(ListProjects)
  assert cli.parse(["projects", "create", "blog"])
    == Run(CreateProject(name: "blog"))
  assert cli.parse(["projects", "rename", "blog", "notes"])
    == Run(RenameProject(from: "blog", to: "notes"))
  assert cli.parse(["projects", "delete", "blog"])
    == Run(DeleteProject(name: "blog", yes: False))
}

pub fn delete_reads_yes_on_either_side_of_the_name_test() {
  assert cli.parse(["projects", "delete", "blog", "--yes"])
    == Run(DeleteProject(name: "blog", yes: True))
  assert cli.parse(["projects", "delete", "--yes", "blog"])
    == Run(DeleteProject(name: "blog", yes: True))
}

pub fn projects_subcommands_need_their_names_test() {
  let assert Invalid(create) = cli.parse(["projects", "create"])
  let assert Invalid(rename) = cli.parse(["projects", "rename", "blog"])

  assert string.contains(create, "name")
  assert string.contains(rename, "new")
}

pub fn an_unknown_projects_subcommand_is_invalid_test() {
  let assert Invalid(text) = cli.parse(["projects", "frobnicate"])

  assert string.contains(text, "frobnicate")
}

pub fn projects_usage_lists_its_subcommands_test() {
  let assert Usage(text) = cli.parse(["projects", "--help"])

  assert string.contains(text, "create")
  assert string.contains(text, "rename")
  assert string.contains(text, "delete")
}

pub fn delete_usage_lists_yes_test() {
  let assert Usage(text) = cli.parse(["projects", "delete", "--help"])

  assert string.contains(text, "--yes")
}

pub fn usage_lists_the_account_commands_test() {
  let assert Usage(text) = cli.parse([])

  assert string.contains(text, "login")
  assert string.contains(text, "whoami")
  assert string.contains(text, "projects")
  assert string.contains(text, "usage")
}
