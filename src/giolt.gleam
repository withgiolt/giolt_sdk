import argv
import clip
import clip/help
import clip/opt
import giolt/internal/bundle
import gleam/io

type Args {
  Build(target: bundle.BuildTarget)
}

fn build_command() -> clip.Command(Args) {
  clip.command({
    use target <- clip.parameter

    Build(target)
  })
  |> clip.opt(
    opt.new("target")
    |> opt.help("Target Javascript or Erlang")
    |> opt.short("t")
    |> opt.map(fn(opt) {
      case opt {
        "javascript" -> bundle.Javascript
        "erlang" -> bundle.Erlang
        _ -> bundle.Javascript
      }
    })
    |> opt.default(bundle.Javascript),
  )
  |> clip.help(help.simple("build", "Run a build"))
}

fn command() -> clip.Command(Args) {
  clip.subcommands([#("build", build_command())])
}

pub fn main() -> Nil {
  let result =
    command()
    |> clip.help(help.simple("subcommand", "Run a subcommand"))
    |> clip.run(argv.load().arguments)

  case result {
    Error(e) -> io.println_error(e)
    Ok(args) ->
      case args {
        Build(target) -> bundle.build(target)
      }
  }
}
