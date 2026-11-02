import gleam/int
import gleam/io
import gleam/list
import glitzer/progress

const reset = "\u{001b}[0m"

const bold_white_on_grey = "\u{001b}[1;37;100m"

const bold_red = "\u{001b}[1;31m"

const bold_green = "\u{001b}[1;32m"

const bold_yellow = "\u{001b}[1;33m"

const bold = "\u{001b}[1m"

fn tag() -> String {
  bold_white_on_grey <> "[Giolt]" <> reset
}

fn line(colour: String, message: String) -> String {
  tag() <> " " <> colour <> message <> reset
}

pub fn println_info(message: String) -> Nil {
  io.println(line(bold, message))
}

pub fn println_success(message: String) -> Nil {
  io.println(line(bold_green, message))
}

pub fn println_warning(message: String) -> Nil {
  io.println(line(bold_yellow, message))
}

pub fn println_error(message: String) -> Nil {
  io.println_error(line(bold_red, message))
}

const bar_width = 20

// glitzer draws length + 1 cells and fills progress + 1 of them, hence the
// off-by-one: a bar_width bar has length bar_width - 1 and is ticked fills - 1 times.
pub fn progress_line(done: Int, total: Int, label: String) -> String {
  let fills = int.clamp(done * bar_width / total, min: 1, max: bar_width)

  let bar =
    list.repeat(Nil, fills - 1)
    |> list.fold(
      progress.new_bar()
        |> progress.with_length(bar_width - 1)
        |> progress.with_fill(progress.char_from_string("█"))
        |> progress.with_empty(progress.char_from_string("░"))
        |> progress.with_newline_on_finished(False),
      fn(bar, _) { progress.tick(bar) },
    )

  line(
    bold_green,
    progress.get_raw_bar(bar)
      <> " "
      <> int.to_string(done)
      <> "/"
      <> int.to_string(total)
      <> " "
      <> label,
  )
}

pub fn println_progress(done: Int, total: Int, label: String) -> Nil {
  io.println(progress_line(done, total, label))
}
