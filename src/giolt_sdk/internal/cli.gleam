import clip
import clip/help
import gleam/list
import gleam/string

pub type Command {
  Build
  Dev
  Deploy
}

pub type Outcome {
  Run(Command)
  Usage(String)
  Invalid(String)
}

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
            False -> Invalid(invalid_message(args))
          }
      }
  }
}

fn command() -> clip.Command(Command) {
  clip.subcommands([
    #("build", subcommand(Build, "build", "Bundle the app for deployment")),
    #("dev", subcommand(Dev, "dev", "Run the app locally with live reload")),
    #("deploy", subcommand(Deploy, "deploy", "Deploy the bundle to Giolt")),
  ])
  |> clip.help(help.simple("giolt", "Build, run and deploy Gleam apps on Giolt"))
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

fn invalid_message(args: List(String)) -> String {
  case args {
    [unknown, ..] -> "Unknown command `" <> unknown <> "`.\n\n" <> usage_text()
    [] -> usage_text()
  }
}
