import giolt/internal/config
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import tom

type Line {
  Header(text: String, giolt: Bool)
  Body(text: String, in_giolt: Bool)
}

// The file is edited as text rather than re-serialised, so the user's comments
// and layout survive. The result is parsed again before it is returned, which
// catches layouts the line scan can't see, such as `tools = { giolt = ... }` or
// a header inside a multi-line string.
pub fn set_project(source: String, id: Int) -> Result(String, Nil) {
  let #(mark, source) = config.split_byte_order_mark(source)
  use text <- result.map(set_project_in(source, id))
  mark <> text
}

fn set_project_in(source: String, id: Int) -> Result(String, Nil) {
  let eol = line_ending(source)
  let lines = label(string.split(source, eol))
  let line = "project = " <> int.to_string(id)

  let edited = case
    list.any(lines, is_linked_line),
    list.any(lines, is_giolt_header)
  {
    True, _ -> list.map(lines, replace_project(_, line))
    False, True -> insert_after_header(lines, line)
    False, False -> append_table(lines, line)
  }
  let text = join(edited, eol)

  case linked_project(text) {
    Ok(Some(found)) if found == id -> Ok(text)
    _ -> Error(Nil)
  }
}

pub fn remove_project(source: String) -> Result(String, Nil) {
  let #(mark, source) = config.split_byte_order_mark(source)
  use text <- result.map(remove_project_in(source))
  mark <> text
}

fn remove_project_in(source: String) -> Result(String, Nil) {
  let eol = line_ending(source)
  let lines = label(string.split(source, eol))
  let text = join(list.filter(lines, fn(line) { !is_linked_line(line) }), eol)

  case linked_project(text) {
    Ok(None) -> Ok(text)
    _ -> Error(Nil)
  }
}

fn linked_project(text: String) -> Result(Option(Int), Nil) {
  use toml <- result.try(tom.parse(text) |> result.replace_error(Nil))
  case tom.get_int(toml, ["tools", "giolt", "project"]) {
    Ok(id) -> Ok(Some(id))
    Error(tom.NotFound(_)) -> Ok(None)
    Error(tom.WrongType(..)) -> Error(Nil)
  }
}

fn line_ending(source: String) -> String {
  case string.contains(source, "\r\n") {
    True -> "\r\n"
    False -> "\n"
  }
}

fn label(lines: List(String)) -> List(Line) {
  let #(_, labelled) =
    list.fold(lines, #(False, []), fn(state, text) {
      let #(in_giolt, acc) = state
      case table_name(text) {
        Ok(name) -> {
          let giolt = name == "tools.giolt"
          #(giolt, [Header(text:, giolt:), ..acc])
        }
        Error(Nil) -> #(in_giolt, [Body(text:, in_giolt:), ..acc])
      }
    })
  list.reverse(labelled)
}

// An array-of-tables header `[[x]]` comes back as `[x]`, which never equals
// `tools.giolt`, so its keys count as another table's.
fn table_name(text: String) -> Result(String, Nil) {
  case string.trim_start(text) {
    "[" <> rest -> {
      use #(name, _) <- result.map(string.split_once(rest, "]"))
      name
      |> string.replace(" ", "")
      |> string.replace("\t", "")
      |> string.replace("\"", "")
      |> string.replace("'", "")
    }
    _ -> Error(Nil)
  }
}

fn is_giolt_header(line: Line) -> Bool {
  case line {
    Header(giolt:, ..) -> giolt
    Body(..) -> False
  }
}

fn is_linked_line(line: Line) -> Bool {
  case line {
    Body(text:, in_giolt: True) -> is_project_key(text)
    _ -> False
  }
}

fn is_project_key(text: String) -> Bool {
  case string.trim_start(text) {
    "project" <> rest | "\"project\"" <> rest ->
      string.starts_with(string.trim_start(rest), "=")
    _ -> False
  }
}

fn replace_project(line: Line, replacement: String) -> Line {
  case is_linked_line(line) {
    True -> Body(text: indentation(line.text) <> replacement, in_giolt: True)
    False -> line
  }
}

fn indentation(text: String) -> String {
  string.drop_end(text, string.length(string.trim_start(text)))
}

fn insert_after_header(lines: List(Line), project: String) -> List(Line) {
  case lines {
    [] -> []
    [Header(giolt: True, ..) as header, ..rest] -> [
      header,
      Body(text: project, in_giolt: True),
      ..rest
    ]
    [line, ..rest] -> [line, ..insert_after_header(rest, project)]
  }
}

// Splitting text that ends in a newline leaves an empty last line, so the
// table goes before it and the file still ends in exactly one newline.
fn append_table(lines: List(Line), project: String) -> List(Line) {
  let table = [
    Body(text: "", in_giolt: False),
    Header(text: "[tools.giolt]", giolt: True),
    Body(text: project, in_giolt: True),
  ]
  case list.reverse(lines) {
    [Body(text: "", ..) as last, ..before] ->
      list.reverse(before) |> list.append(table) |> list.append([last])
    _ -> list.append(lines, table) |> list.append([Body("", False)])
  }
}

fn join(lines: List(Line), eol: String) -> String {
  list.map(lines, fn(line) { line.text }) |> string.join(eol)
}
