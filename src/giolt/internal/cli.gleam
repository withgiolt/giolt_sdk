import clip
import clip/arg
import clip/flag
import clip/help
import clip/opt
import gleam/list
import gleam/option.{type Option}
import gleam/string

pub type Command {
  Build(config: Option(String))
  Dev(config: Option(String))
  Deploy(
    preview: Bool,
    artifact: Option(String),
    project: Option(String),
    config: Option(String),
  )
  Link(name: String, config: Option(String))
  Unlink(config: Option(String))
  Login(token: Option(String))
  Logout
  Whoami
  ListProjects
  CreateProject(name: String)
  RenameProject(from: String, to: String)
  DeleteProject(name: String, yes: Bool)
  ShowUsage
}

pub type Outcome {
  Run(Command)
  Usage(String)
  Invalid(String)
}

const command_names = [
  "build", "dev", "deploy", "link", "unlink", "login", "logout", "whoami",
  "projects", "usage",
]

pub fn parse(args: List(String)) -> Outcome {
  case clip.parse(command(), args) {
    Ok(#(command, [])) -> Run(command)
    Ok(#(_, extra)) ->
      Invalid(
        "Unexpected argument `"
        <> string.join(extra, " ")
        <> "`.\n\n"
        <> usage_text(),
      )
    Error(text) ->
      case args {
        [] -> Usage(usage_text())
        _ ->
          case wants_usage(args) {
            True -> Usage(text)
            False -> Invalid(invalid_message(args, text))
          }
      }
  }
}

fn command() -> clip.Command(Command) {
  clip.subcommands([
    #("build", subcommand(Build, "build", "Bundle the app for deployment")),
    #("dev", subcommand(Dev, "dev", "Run the app locally with live reload")),
    #("deploy", deploy_command()),
    #("link", link_command()),
    #("unlink", subcommand(Unlink, "unlink", "Forget the linked project")),
    #("login", login_command()),
    #("logout", plain(Logout, "logout", "Revoke and remove the token")),
    #("whoami", plain(Whoami, "whoami", "Show who the token belongs to")),
    #("projects", projects_command()),
    #("usage", plain(ShowUsage, "usage", "Show this billing period's usage")),
  ])
  |> clip.help(help.simple("giolt", "Build, run and deploy Gleam apps on Giolt"))
}

fn deploy_command() -> clip.Command(Command) {
  clip.command(fn(preview) {
    fn(artifact) {
      fn(project) {
        fn(config) {
          Deploy(
            preview:,
            artifact: option.from_result(artifact),
            project: option.from_result(project),
            config: option.from_result(config),
          )
        }
      }
    }
  })
  |> clip.flag(
    flag.new("preview") |> flag.help("Deploy as a preview, not to production"),
  )
  |> clip.opt(
    opt.new("artifact")
    |> opt.help("Deploy this directory as a static site, skipping the build")
    |> opt.optional,
  )
  |> clip.opt(
    opt.new("project")
    |> opt.help("Deploy to this project instead of the linked one")
    |> opt.optional,
  )
  |> clip.opt(config_opt())
  |> clip.help(help.simple("giolt deploy", "Deploy the bundle to Giolt"))
}

fn link_command() -> clip.Command(Command) {
  clip.command(fn(name) {
    fn(config) { Link(name:, config: option.from_result(config)) }
  })
  |> clip.arg(arg.new("name") |> arg.help("The project to deploy to"))
  |> clip.opt(config_opt())
  |> clip.help(help.simple(
    "giolt link",
    "Remember a project in [tools.giolt] so deploy needs no flags",
  ))
}

fn login_command() -> clip.Command(Command) {
  clip.command(fn(token) { Login(token: option.from_result(token)) })
  |> clip.opt(
    opt.new("token")
    |> opt.help("A user token from the dashboard, or - to read it from stdin")
    |> opt.optional,
  )
  |> clip.help(help.simple(
    "giolt login",
    "Sign in through the browser, or store a token",
  ))
}

fn projects_command() -> clip.Command(Command) {
  clip.subcommands_with_default(
    [
      #(
        "create",
        clip.command(fn(name) { CreateProject(name:) })
          |> clip.arg(arg.new("name") |> arg.help("The project's name"))
          |> clip.help(help.simple("giolt projects create", "Create a project")),
      ),
      #(
        "rename",
        clip.command(fn(from) { fn(to) { RenameProject(from:, to:) } })
          |> clip.arg(arg.new("old") |> arg.help("The project's current name"))
          |> clip.arg(arg.new("new") |> arg.help("Its new name"))
          |> clip.help(help.simple(
            "giolt projects rename",
            "Rename a project, which changes its URL",
          )),
      ),
      #(
        "delete",
        clip.command(fn(name) { fn(yes) { DeleteProject(name:, yes:) } })
          |> clip.arg(arg.new("name") |> arg.help("The project to delete"))
          |> clip.flag(
            flag.new("yes") |> flag.help("Delete without asking to confirm"),
          )
          |> clip.help(help.simple(
            "giolt projects delete",
            "Delete a project and its deployments for good",
          )),
      ),
    ],
    clip.return(ListProjects),
  )
  |> clip.help(help.simple(
    "giolt projects",
    "List your projects, or create, rename or delete one",
  ))
}

fn plain(
  command: Command,
  name: String,
  description: String,
) -> clip.Command(Command) {
  clip.return(command)
  |> clip.help(help.simple("giolt " <> name, description))
}

fn config_opt() -> opt.Opt(Result(String, Nil)) {
  opt.new("config")
  |> opt.help("Read [tools.giolt] from this TOML file instead of gleam.toml")
  |> opt.optional
}

fn subcommand(
  command: fn(Option(String)) -> Command,
  name: String,
  description: String,
) -> clip.Command(Command) {
  clip.command(fn(config) { command(option.from_result(config)) })
  |> clip.opt(config_opt())
  |> clip.help(help.simple("giolt " <> name, description))
}

fn wants_usage(args: List(String)) -> Bool {
  list.contains(args, "--help") || list.contains(args, "-h")
}

fn usage_text() -> String {
  case clip.run(command(), ["--help"]) {
    Ok(_) -> ""
    Error(text) -> text
  }
}

fn invalid_message(args: List(String), clip_text: String) -> String {
  case args {
    [first, ..] ->
      case list.contains(command_names, first) {
        True -> clip_text
        False -> "Unknown command `" <> first <> "`.\n\n" <> usage_text()
      }
    [] -> usage_text()
  }
}
