import gleam/string
import gleam/uri

pub type Error {
  Malformed
  NulByte
}

pub fn decode(url_path: String) -> Result(String, Error) {
  case uri.percent_decode(url_path) {
    Error(Nil) -> Error(Malformed)
    Ok(decoded) ->
      case string.contains(decoded, "\u{0}") {
        True -> Error(NulByte)
        False -> Ok(decoded)
      }
  }
}
