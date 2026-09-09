import giolt_sdk/internal/entry

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
      path: "./build/dev/javascript/app/app.mjs",
      exports: exports,
    )
    == Ok(Nil)
}

pub fn validate_javascript_missing_handler_test() {
  let exports = [entry.Export(name: "other", arity: 1)]

  assert entry.validate(
      target: entry.Javascript,
      path: "./build/dev/javascript/app/app.mjs",
      exports: exports,
    )
    == Error(entry.MissingHandler("./build/dev/javascript/app/app.mjs"))
}

pub fn validate_javascript_wrong_arity_test() {
  let exports = [entry.Export(name: "handler", arity: 2)]

  assert entry.validate(
      target: entry.Javascript,
      path: "./build/dev/javascript/app/app.mjs",
      exports: exports,
    )
    == Error(entry.HandlerWrongArity("./build/dev/javascript/app/app.mjs", 2))
}

pub fn validate_erlang_unsupported_test() {
  assert entry.validate(
      target: entry.Erlang,
      path: "./build/dev/javascript/app/app.mjs",
      exports: [],
    )
    == Error(entry.CheckUnsupported("erlang"))
}

pub fn target_from_string_test() {
  assert entry.target_from_string("javascript") == Ok(entry.Javascript)
  assert entry.target_from_string("erlang") == Ok(entry.Erlang)
  assert entry.target_from_string("nonsense") == Error(Nil)
}
