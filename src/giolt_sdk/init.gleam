import giolt_sdk/internal/io
import giolt_sdk/internal/project
import giolt_sdk/internal/templates
import gleam/list
import gleam/string
import simplifile

type ScaffoldFile {
  ScaffoldFile(path: String, contents: String)
}

pub fn main() -> Nil {
  case project.load() {
    Error(reason) -> io.println_error(project.describe_error(reason))
    Ok(proj) -> scaffold(proj.name)
  }
}

fn scaffold(project_name: String) -> Nil {
  let files = [
    ScaffoldFile(templates.build_path, templates.render_build(project_name)),
    ScaffoldFile(templates.deploy_path, templates.render_deploy(project_name)),
    ScaffoldFile(
      templates.dev_path(project_name),
      templates.render_dev(project_name),
    ),
  ]

  list.each(files, write_if_missing)

  io.println_info(
    "Next steps:\n"
    <> "  gleam run -m build                     bundle your app\n"
    <> "  gleam run -m deploy                     deploy it\n"
    <> "  gleam run -m "
    <> templates.dev_module(project_name)
    <> "               run it locally, with rebuild on change",
  )
}

fn write_if_missing(file: ScaffoldFile) -> Nil {
  case simplifile.is_file(file.path) {
    Ok(True) ->
      io.println_warning("Skipped " <> file.path <> " (already exists)")
    Ok(False) | Error(_) ->
      case simplifile.write(file.path, file.contents) {
        Ok(_) -> io.println_success("Created " <> file.path)
        Error(reason) ->
          io.println_error(
            "Could not write " <> file.path <> ": " <> string.inspect(reason),
          )
      }
  }
}
