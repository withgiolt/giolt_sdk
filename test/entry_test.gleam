import giolt_sdk/internal/entry

pub fn normalise_plain_test() {
  assert entry.normalise("app") == "app"
}

pub fn normalise_with_extension_test() {
  assert entry.normalise("app.gleam") == "app"
}

pub fn normalise_with_src_prefix_test() {
  assert entry.normalise("src/app.gleam") == "app"
}

pub fn normalise_with_dot_slash_test() {
  assert entry.normalise("./app.gleam") == "app"
}

pub fn normalise_nested_module_test() {
  assert entry.normalise("app/server") == "app/server"
}

pub fn normalise_nested_module_with_extension_test() {
  assert entry.normalise("src/app/server.gleam") == "app/server"
}

pub fn compiled_path_test() {
  assert entry.compiled_path(project: "myapp", module: "app")
    == "./build/dev/javascript/myapp/app.mjs"
}

pub fn shim_specifier_test() {
  assert entry.shim_specifier(project: "myapp", module: "app")
    == "../myapp/app.mjs"
}

pub fn scan_exports_finds_handler_test() {
  let source =
    "
    export function handler(request) {
      return request;
    }
    "

  assert entry.scan_exports(source) == [entry.Export(name: "handler", arity: 1)]
}

pub fn scan_exports_finds_async_handler_test() {
  let source =
    "
    export async function handler(request) {
      return request;
    }
    "

  assert entry.scan_exports(source) == [entry.Export(name: "handler", arity: 1)]
}

pub fn scan_exports_counts_arity_test() {
  let source = "export function two(a, b) { return a; }"

  assert entry.scan_exports(source) == [entry.Export(name: "two", arity: 2)]
}

pub fn scan_exports_zero_arity_test() {
  let source = "export function zero() { return 1; }"

  assert entry.scan_exports(source) == [entry.Export(name: "zero", arity: 0)]
}

pub fn scan_exports_multiple_test() {
  let source =
    "
    export function handler(request) { return request; }
    export function other(a, b, c) { return a; }
    "

  assert entry.scan_exports(source)
    == [
      entry.Export(name: "handler", arity: 1),
      entry.Export(name: "other", arity: 3),
    ]
}

pub fn scan_exports_none_test() {
  assert entry.scan_exports("const x = 1;") == []
}

pub fn validate_javascript_ok_test() {
  let exports = [entry.Export(name: "handler", arity: 1)]

  assert entry.validate(
      target: entry.Javascript,
      module: "app",
      exports: exports,
    )
    == Ok(Nil)
}

pub fn validate_javascript_missing_handler_test() {
  let exports = [entry.Export(name: "other", arity: 1)]

  assert entry.validate(
      target: entry.Javascript,
      module: "app",
      exports: exports,
    )
    == Error(entry.MissingHandler("app"))
}

pub fn validate_javascript_wrong_arity_test() {
  let exports = [entry.Export(name: "handler", arity: 2)]

  assert entry.validate(
      target: entry.Javascript,
      module: "app",
      exports: exports,
    )
    == Error(entry.HandlerWrongArity("app", 2))
}

pub fn validate_erlang_unsupported_test() {
  assert entry.validate(target: entry.Erlang, module: "app", exports: [])
    == Error(entry.CheckUnsupported("erlang"))
}

pub fn target_from_string_test() {
  assert entry.target_from_string("javascript") == Ok(entry.Javascript)
  assert entry.target_from_string("erlang") == Ok(entry.Erlang)
  assert entry.target_from_string("nonsense") == Error(Nil)
}
