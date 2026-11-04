import envie
import filepath
import giolt/internal/config
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile

pub type Credential {
  Credential(token: String, api_url: String)
}

pub type Environment {
  Environment(
    windows: Bool,
    home: String,
    xdg_config_home: Option(String),
    appdata: Option(String),
  )
}

pub type Source {
  FromEnv
  FromFile
}

pub type Session {
  Session(token: String, api_url: String, source: Source)
}

pub type Error {
  NotLoggedIn
  UnreadableFile(path: String)
  CannotWrite(path: String)
  CannotDelete(path: String)
}

pub const token_env = "GIOLT_TOKEN"

pub const api_url_env = "GIOLT_API_URL"

const token_prefix = "giolt_"

pub fn environment() -> Environment {
  Environment(
    windows: is_windows(),
    home: home_directory(),
    xdg_config_home: envie.get("XDG_CONFIG_HOME") |> option.from_result,
    appdata: envie.get("APPDATA") |> option.from_result,
  )
}

pub fn path(env: Environment) -> String {
  filepath.join(directory(env), "credentials.json")
}

pub fn directory(env: Environment) -> String {
  case env.windows {
    True ->
      case non_empty(env.appdata) {
        Some(appdata) -> filepath.join(appdata, "giolt")
        None -> filepath.join(env.home, "AppData/Roaming/giolt")
      }
    False ->
      case non_empty(env.xdg_config_home) {
        // The XDG spec says to ignore a relative XDG_CONFIG_HOME.
        Some("/" <> rest) -> filepath.join("/" <> rest, "giolt")
        _ -> filepath.join(env.home, ".config/giolt")
      }
  }
}

// gleam.toml is never consulted: a cloned repository must not be able to send
// the user's token to a server of its choosing through `api_url`.
pub fn resolve(
  env_token env_token: Option(String),
  env_api_url env_api_url: Option(String),
  stored stored: Option(Credential),
) -> Result(Session, Error) {
  case non_empty(env_token), stored {
    Some(token), _ ->
      Ok(Session(token:, api_url: api_url(env_api_url), source: FromEnv))
    // A stored token only goes to the server that issued it.
    None, Some(credential) ->
      Ok(Session(
        token: credential.token,
        api_url: credential.api_url,
        source: FromFile,
      ))
    None, None -> Error(NotLoggedIn)
  }
}

pub fn api_url(env_api_url: Option(String)) -> String {
  non_empty(env_api_url) |> option.unwrap(config.default_api_url)
}

fn non_empty(value: Option(String)) -> Option(String) {
  case value {
    Some("") -> None
    _ -> value
  }
}

pub fn is_api_token(token: String) -> Bool {
  string.starts_with(token, token_prefix)
}

pub fn encode_credential(credential: Credential) -> String {
  json.object([
    #("token", json.string(credential.token)),
    #("api_url", json.string(credential.api_url)),
  ])
  |> json.to_string
}

pub fn decode_credential(text: String) -> Result(Credential, Nil) {
  let decoder = {
    use token <- decode.field("token", decode.string)
    use api_url <- decode.field("api_url", decode.string)
    decode.success(Credential(token:, api_url:))
  }

  json.parse(text, decoder) |> result.replace_error(Nil)
}

pub fn load(path: String) -> Result(Option(Credential), Error) {
  case simplifile.read(path) {
    Error(simplifile.Enoent) -> Ok(None)
    Error(_) -> Error(UnreadableFile(path))
    Ok(text) ->
      decode_credential(text)
      |> result.map(Some)
      |> result.replace_error(UnreadableFile(path))
  }
}

// The directory is locked down before the file is written, so the token is
// never readable by other users, even for the moment before the file's own
// chmod.
pub fn save(path: String, credential: Credential) -> Result(Nil, Error) {
  let folder = filepath.directory_name(path)
  {
    use _ <- result.try(simplifile.create_directory_all(folder))
    use _ <- result.try(simplifile.set_permissions_octal(folder, 0o700))
    use _ <- result.try(simplifile.write(path, encode_credential(credential)))
    simplifile.set_permissions_octal(path, 0o600)
  }
  |> result.replace_error(CannotWrite(path))
}

pub fn remove(path: String) -> Result(Bool, Error) {
  case simplifile.delete_file(path) {
    Ok(Nil) -> Ok(True)
    Error(simplifile.Enoent) -> Ok(False)
    Error(_) -> Error(CannotDelete(path))
  }
}

pub fn describe_error(error: Error) -> String {
  case error {
    NotLoggedIn ->
      "Not logged in. Run `giolt login`, or set `" <> token_env <> "`."
    UnreadableFile(path) ->
      "Could not read the stored login in "
      <> path
      <> ". Run `giolt login` to replace it, or `giolt logout` to remove it."
    CannotWrite(path) -> "Could not write " <> path <> "."
    CannotDelete(path) -> "Could not delete " <> path <> "."
  }
}

@external(javascript, "./ffi_credentials.mjs", "is_windows")
fn is_windows() -> Bool

@external(javascript, "./ffi_credentials.mjs", "home_directory")
fn home_directory() -> String
