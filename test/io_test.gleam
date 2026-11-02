import giolt_sdk/internal/io
import gleam/list
import gleam/string

fn count(text: String, char: String) -> Int {
  list.length(string.split(text, char)) - 1
}

pub fn progress_fills_in_proportion_to_steps_done_test() {
  let line = io.progress_line(2, 4, "Compiled")

  assert count(line, "█") == 10
  assert count(line, "░") == 10
}

pub fn progress_is_full_when_every_step_is_done_test() {
  let line = io.progress_line(3, 3, "Bundled")

  assert count(line, "█") == 20
  assert count(line, "░") == 0
}

pub fn progress_with_one_step_done_of_many_is_never_empty_test() {
  let line = io.progress_line(1, 20, "Checked")

  assert count(line, "█") == 1
  assert count(line, "░") == 19
}

pub fn progress_names_the_step_and_the_count_test() {
  let line = io.progress_line(2, 3, "Compiled")

  assert string.contains(line, "2/3")
  assert string.contains(line, "Compiled")
}
