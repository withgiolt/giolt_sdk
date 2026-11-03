import argv
import giolt/internal/cli
import giolt/internal/commands
import giolt/internal/io
import giolt/internal/process
import gleam/io as stdio
import gleam/javascript/promise.{type Promise}

pub fn main() -> Promise(Nil) {
  case cli.parse(argv.load().arguments) {
    cli.Usage(text) -> promise.resolve(stdio.println(text))
    cli.Invalid(text) -> {
      stdio.println_error(text)
      process.exit(2)
      promise.resolve(Nil)
    }
    cli.Run(command) -> {
      use result <- promise.map(run(command))
      case result {
        Ok(Nil) -> Nil
        Error(message) -> {
          io.println_error(message)
          process.exit(1)
        }
      }
    }
  }
}

fn run(command: cli.Command) -> Promise(Result(Nil, String)) {
  case command {
    cli.Build(config:) -> commands.build(config:)
    cli.Dev(config:) -> commands.dev(config:)
    cli.Deploy(preview:, artifact:, project:, config:) ->
      commands.deploy(preview:, artifact:, project:, config:)
    cli.Link(name:, config:) -> commands.link_project(name:, config:)
    cli.Unlink(config:) -> commands.unlink_project(config:)
    cli.Login(token:) -> commands.login(token:)
    cli.Logout -> commands.logout()
    cli.Whoami -> commands.whoami()
    cli.ListProjects -> commands.list_projects()
    cli.CreateProject(name:) -> commands.create_project(name:)
    cli.RenameProject(from:, to:) -> commands.rename_project(from:, to:)
    cli.DeleteProject(name:, yes:) -> commands.delete_project(name:, yes:)
    cli.ShowUsage -> commands.usage()
  }
}
