import giolt_sdk/internal/shim
import gleam/string

pub fn render_substitutes_entry_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert string.contains(
    rendered,
    "import * as app from \"/home/user/app/build/dev/javascript/app/app.mjs\";",
  )
}

pub fn render_has_no_leftover_placeholder_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert !string.contains(rendered, "{entry}")
}

pub fn render_imports_conversation_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert string.contains(rendered, "conversation/conversation.mjs")
}

pub fn render_calls_handler_test() {
  let rendered = shim.render("/home/user/app/build/dev/javascript/app/app.mjs")

  assert string.contains(rendered, "app.handler(req)")
}
