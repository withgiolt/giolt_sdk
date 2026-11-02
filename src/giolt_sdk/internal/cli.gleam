import clip
import clip/flag
import clip/help
import clip/opt
import gleam/list
import gleam/option.{type Option}
import gleam/string

pub type Command {
  Build
  Dev
  Deploy(preview: Bool, message: Option(String))
}

pub type Outcome {
  Run(Command)
  Usage(String)
  Invalid(String)
}

const command_names = ["build", "dev", "deploy"]

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
  ])
  |> clip.help(help.simple("giolt", "Build, run and deploy Gleam apps on Giolt"))
}

fn deploy_command() -> clip.Command(Command) {
  clip.command(fn(preview) {
    fn(message) { Deploy(preview:, message: option.from_result(message)) }
  })
  |> clip.flag(
    flag.new("preview") |> flag.help("Deploy as a preview, not to production"),
  )
  |> clip.opt(
    opt.new("message")
    |> opt.help("A note to attach to the deployment")
    |> opt.optional,
  )
  |> clip.help(help.simple("giolt deploy", "Deploy the bundle to Giolt"))
}

fn subcommand(
  value: Command,
  name: String,
  description: String,
) -> clip.Command(Command) {
  clip.return(value)
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
