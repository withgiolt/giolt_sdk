import giolt/internal/credentials.{
  Credential, Environment, FromEnv, FromFile, NotLoggedIn, Session,
}
import gleam/option.{None, Some}

const stored =
  Credential(token: "giolt_stored", api_url: "http://localhost:8787")

fn unix(xdg: option.Option(String)) -> credentials.Environment {
  Environment(
    windows: False,
    home: "/home/ada",
    xdg_config_home: xdg,
    appdata: None,
  )
}

pub fn the_file_lives_under_dot_config_by_default_test() {
  assert credentials.path(unix(None))
    == "/home/ada/.config/giolt/credentials.json"
}

pub fn xdg_config_home_moves_it_test() {
  assert credentials.path(unix(Some("/tmp/conf")))
    == "/tmp/conf/giolt/credentials.json"
}

pub fn an_empty_or_relative_xdg_config_home_is_ignored_test() {
  assert credentials.path(unix(Some("")))
    == "/home/ada/.config/giolt/credentials.json"
  assert credentials.path(unix(Some("conf")))
    == "/home/ada/.config/giolt/credentials.json"
}

pub fn windows_uses_appdata_test() {
  let env =
    Environment(
      windows: True,
      home: "C:\\Users\\ada",
      xdg_config_home: Some("/ignored"),
      appdata: Some("C:\\Users\\ada\\AppData\\Roaming"),
    )

  assert credentials.path(env)
    == "C:\\Users\\ada\\AppData\\Roaming/giolt/credentials.json"
}

pub fn giolt_token_wins_over_the_stored_file_test() {
  assert credentials.resolve(
      env_token: Some("giolt_env"),
      env_api_url: None,
      stored: Some(stored),
    )
    == Ok(Session(
      token: "giolt_env",
      api_url: "https://dash.giolt.com",
      source: FromEnv,
    ))
}

pub fn giolt_api_url_applies_to_giolt_token_test() {
  let assert Ok(session) =
    credentials.resolve(
      env_token: Some("giolt_env"),
      env_api_url: Some("http://127.0.0.1:9000"),
      stored: None,
    )

  assert session.api_url == "http://127.0.0.1:9000"
}

pub fn the_stored_token_only_goes_to_the_server_that_issued_it_test() {
  assert credentials.resolve(
      env_token: None,
      env_api_url: Some("https://elsewhere.example"),
      stored: Some(stored),
    )
    == Ok(Session(
      token: "giolt_stored",
      api_url: "http://localhost:8787",
      source: FromFile,
    ))
}

pub fn an_empty_giolt_token_counts_as_unset_test() {
  let assert Ok(session) =
    credentials.resolve(
      env_token: Some(""),
      env_api_url: None,
      stored: Some(stored),
    )

  assert session.source == FromFile
}

pub fn no_token_anywhere_is_not_logged_in_test() {
  assert credentials.resolve(env_token: None, env_api_url: None, stored: None)
    == Error(NotLoggedIn)
}

pub fn login_uses_giolt_api_url_or_the_default_test() {
  assert credentials.api_url(Some("http://localhost:8787"))
    == "http://localhost:8787"
  assert credentials.api_url(Some("")) == "https://dash.giolt.com"
  assert credentials.api_url(None) == "https://dash.giolt.com"
}

pub fn a_credential_round_trips_through_json_test() {
  assert credentials.decode_credential(credentials.encode_credential(stored))
    == Ok(stored)
  assert credentials.encode_credential(stored)
    == "{\"token\":\"giolt_stored\",\"api_url\":\"http://localhost:8787\"}"
}

pub fn a_corrupt_file_does_not_decode_test() {
  assert credentials.decode_credential("{\"token\":") == Error(Nil)
  assert credentials.decode_credential("{\"api_url\":\"x\"}") == Error(Nil)
}

pub fn only_giolt_prefixed_values_are_api_tokens_test() {
  assert credentials.is_api_token("giolt_ABCDEF234567")
  assert !credentials.is_api_token("2f1c7c8e-4b1a-4f7e-9d7a-0c5b1e2a3f4d")
  assert !credentials.is_api_token("GIOLT_abc")
  assert !credentials.is_api_token("")
}
