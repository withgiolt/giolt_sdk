import giolt/internal/link

pub fn replaces_the_project_line_in_tools_giolt_test() {
  let source =
    "name = \"app\"\n\n[tools.giolt]\n# where CI deploys\nproject = 7\nport = 4000\n"

  assert link.set_project(source, 42)
    == Ok(
      "name = \"app\"\n\n[tools.giolt]\n# where CI deploys\nproject = 42\nport = 4000\n",
    )
}

pub fn replaces_a_line_without_spaces_or_with_a_comment_test() {
  assert link.set_project("[tools.giolt]\nproject=7\n", 8)
    == Ok("[tools.giolt]\nproject = 8\n")
  assert link.set_project("[tools.giolt]\n  project = 7 # old\n", 8)
    == Ok("[tools.giolt]\n  project = 8\n")
}

pub fn inserts_the_line_after_the_table_header_test() {
  let source = "name = \"app\"\n\n[tools.giolt] # build settings\nport = 4000\n"

  assert link.set_project(source, 42)
    == Ok(
      "name = \"app\"\n\n[tools.giolt] # build settings\nproject = 42\nport = 4000\n",
    )
}

pub fn appends_the_table_when_there_is_none_test() {
  assert link.set_project("name = \"app\"\n", 42)
    == Ok("name = \"app\"\n\n[tools.giolt]\nproject = 42\n")
  assert link.set_project("name = \"app\"", 42)
    == Ok("name = \"app\"\n\n[tools.giolt]\nproject = 42\n")
}

pub fn a_project_key_in_another_table_is_left_alone_test() {
  let source =
    "name = \"app\"\n\n[tools.other]\nproject = 1\n\n[tools.giolt]\nport = 1\n\n[dependencies]\nproject = \"x\"\n"

  assert link.set_project(source, 42)
    == Ok(
      "name = \"app\"\n\n[tools.other]\nproject = 1\n\n[tools.giolt]\nproject = 42\nport = 1\n\n[dependencies]\nproject = \"x\"\n",
    )
}

pub fn a_spaced_or_quoted_header_still_names_the_table_test() {
  assert link.set_project("[ tools . \"giolt\" ]\nport = 1\n", 3)
    == Ok("[ tools . \"giolt\" ]\nproject = 3\nport = 1\n")
}

pub fn keeps_windows_line_endings_test() {
  assert link.set_project("name = \"app\"\r\n[tools.giolt]\r\nport = 1\r\n", 5)
    == Ok("name = \"app\"\r\n[tools.giolt]\r\nproject = 5\r\nport = 1\r\n")
}

pub fn refuses_a_layout_it_cannot_edit_test() {
  // A [tools.giolt] header can't be appended after an inline or dotted table.
  assert link.set_project("tools = { giolt = { port = 1 } }\n", 5) == Error(Nil)
  assert link.set_project("[tools]\ngiolt.project = 1\n", 5) == Error(Nil)
}

pub fn refuses_a_file_that_is_not_valid_toml_test() {
  assert link.set_project("name = \n", 5) == Error(Nil)
}

pub fn removes_the_project_line_test() {
  let source =
    "name = \"app\"\n\n[tools.giolt]\nproject = 7\nport = 4000\n\n[tools.other]\nproject = 1\n"

  assert link.remove_project(source)
    == Ok(
      "name = \"app\"\n\n[tools.giolt]\nport = 4000\n\n[tools.other]\nproject = 1\n",
    )
}

pub fn removing_when_unlinked_changes_nothing_test() {
  let source = "name = \"app\"\n\n[tools.other]\nproject = 1\n"

  assert link.remove_project(source) == Ok(source)
}

pub fn refuses_to_remove_a_project_it_cannot_find_test() {
  assert link.remove_project("[tools]\ngiolt.project = 1\n") == Error(Nil)
}
