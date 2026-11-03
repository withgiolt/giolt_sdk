import giolt/internal/static_path

pub fn plain_path_is_unchanged_test() {
  assert static_path.decode("/app.css") == Ok("/app.css")
}

pub fn encoded_space_is_decoded_test() {
  assert static_path.decode("/a%20b.txt") == Ok("/a b.txt")
}

pub fn encoded_utf8_is_decoded_test() {
  assert static_path.decode("/caf%C3%A9.txt") == Ok("/café.txt")
}

pub fn encoded_dot_dot_is_left_for_normalization_test() {
  assert static_path.decode("/%2e%2e/secret") == Ok("/../secret")
}

pub fn truncated_escape_is_malformed_test() {
  assert static_path.decode("/a%2") == Error(static_path.Malformed)
}

pub fn invalid_utf8_is_malformed_test() {
  assert static_path.decode("/%FF") == Error(static_path.Malformed)
}

pub fn nul_byte_is_rejected_test() {
  assert static_path.decode("/a%00b") == Error(static_path.NulByte)
}
