import gleam/dict
import gleam/io
import shellout

pub fn println_error(string: String) {
  "[Giolt SDK]"
  |> shellout.style(
    shellout.display(["bold"])
      |> dict.merge(shellout.color(["white"]))
      |> dict.merge(shellout.background(["brightblack"])),
    [],
  )
  |> io.print_error

  { " " <> string }
  |> shellout.style(
    shellout.display(["bold"])
      |> dict.merge(shellout.color(["red"]))
      |> dict.merge(shellout.background(["black"])),
    [],
  )
  |> io.println_error
}

pub fn println_info(string: String) {
  "[Giolt SDK]"
  |> shellout.style(
    shellout.display(["bold"])
      |> dict.merge(shellout.color(["white"]))
      |> dict.merge(shellout.background(["brightblack"])),
    [],
  )
  |> io.print

  { " " <> string }
  |> shellout.style(
    shellout.display(["bold"])
      |> dict.merge(shellout.color(["white"]))
      |> dict.merge(shellout.background(["black"])),
    [],
  )
  |> io.println
}

pub fn println_success(string: String) {
  "[Giolt SDK]"
  |> shellout.style(
    shellout.display(["bold"])
      |> dict.merge(shellout.color(["white"]))
      |> dict.merge(shellout.background(["brightblack"])),
    [],
  )
  |> io.print

  { " " <> string }
  |> shellout.style(
    shellout.display(["bold"])
      |> dict.merge(shellout.color(["brightgreen"]))
      |> dict.merge(shellout.background(["black"])),
    [],
  )
  |> io.println
}
