import gleam/io

const reset = "\u{001b}[0m"

const bold_white_on_grey = "\u{001b}[1;37;100m"

const bold_red = "\u{001b}[1;31m"

const bold_green = "\u{001b}[1;32m"

const bold_yellow = "\u{001b}[1;33m"

const bold = "\u{001b}[1m"

fn tag() -> String {
  bold_white_on_grey <> "[Giolt SDK]" <> reset
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
