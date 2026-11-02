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
    cli.Build -> promise.resolve(commands.build())
    cli.Dev -> commands.dev()
    cli.Deploy(preview:, message:) -> commands.deploy(preview:, message:)
  }
}
