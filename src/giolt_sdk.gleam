import argv
import clip
import clip/help
import clip/opt
import giolt_sdk/internal/build
import giolt_sdk/internal/io
import giolt_sdk/internal/project
import gleam/option

type Args {
  Build(target: project.BuildTarget)
}

fn build_command() -> clip.Command(Args) {
  // Resolve default from gleam.toml, fallback to javascript if missing/unreadable
  let default_target = case project.load() {
    Ok(proj) ->
      case proj.target {
        option.Some(t) -> t
        option.None -> project.Javascript
      }
    Error(_) -> project.Javascript
  }

  clip.command({
    use target <- clip.parameter

    Build(target)
  })
  |> clip.opt(
    opt.new("target")
    |> opt.help(
      "(erlang, javascript) Target Javascript or Erlang(not supported yet)",
    )
    |> opt.short("t")
    |> opt.try_map(fn(value) {
      case value {
        "javascript" -> Ok(project.Javascript)
        "erlang" -> Ok(project.Erlang)
        _ -> Error("target must be 'javascript' or 'erlang', got: " <> value)
      }
    })
    |> opt.default(default_target),
  )
  |> clip.help(help.simple("build", "Run a build"))
}

fn command() -> clip.Command(Args) {
  clip.subcommands([#("build", build_command())])
}

pub fn main() -> Nil {
  let result =
    command()
    |> clip.help(help.simple("", "Run a subcommand"))
    |> clip.run(argv.load().arguments)

  case result {
    Error(e) -> io.println_error(e)
    Ok(args) ->
      case args {
        Build(target) -> build.build(target)
      }
  }
}
