import giolt/internal/config.{Erlang, Javascript}
import gleam/option.{None, Some}

pub fn entry_defaults_to_the_package_module_test() {
  let source = "name = \"my_app\"\nversion = \"1.0.0\"\n"

  assert config.parse(source) == Ok(config.default("my_app", Erlang))
}

pub fn target_is_read_from_gleam_toml_test() {
  let source = "name = \"my_app\"\ntarget = \"javascript\"\n"

  assert config.parse(source) == Ok(config.default("my_app", Javascript))
}

pub fn entry_is_read_from_tools_giolt_test() {
  let source =
    "name = \"my_app\"\ntarget = \"javascript\"\n\n[tools.giolt]\nentry = \"my_app/server\"\n"

  assert config.parse(source)
    == Ok(
      config.Config(
        ..config.default("my_app", Javascript),
        entry: "my_app/server",
      ),
    )
}

pub fn other_tools_tables_are_ignored_test() {
  let source =
    "name = \"my_app\"\n\n[tools.other]\nentry = \"nope\"\n\n[tools.giolt]\n"

  assert config.parse(source) == Ok(config.default("my_app", Erlang))
}

pub fn entry_that_is_not_a_module_name_is_rejected_test() {
  let build = fn(entry) {
    config.parse(
      "name = \"my_app\"\n[tools.giolt]\nentry = \"" <> entry <> "\"\n",
    )
  }

  assert build("src/my_app.gleam")
    == Error(config.InvalidEntry("src/my_app.gleam"))
  assert build("My_App") == Error(config.InvalidEntry("My_App"))
  assert build("") == Error(config.InvalidEntry(""))
  assert build("my_app/") == Error(config.InvalidEntry("my_app/"))
}

pub fn entry_that_is_not_a_string_is_rejected_test() {
  let source = "name = \"my_app\"\n[tools.giolt]\nentry = 3\n"

  assert config.parse(source)
    == Error(config.InvalidValue(key: "entry", expected: "a string"))
}

pub fn unknown_target_is_rejected_test() {
  let source = "name = \"my_app\"\ntarget = \"wasm\"\n"

  assert config.parse(source) == Error(config.UnknownTarget("wasm"))
}

pub fn missing_name_is_rejected_test() {
  assert config.parse("version = \"1.0.0\"\n") == Error(config.MissingName)
}

pub fn invalid_toml_is_rejected_test() {
  assert config.parse("name = ") == Error(config.InvalidToml)
}

pub fn target_that_is_not_a_string_is_rejected_test() {
  assert config.parse("name = \"my_app\"\ntarget = 3\n")
    == Error(config.InvalidValue(key: "target", expected: "a string"))
}

pub fn compiled_entry_points_at_the_javascript_output_test() {
  let default = config.default("my_app", Javascript)
  let nested = config.Config(..default, entry: "my_app/server")

  assert config.compiled_entry(default)
    == "./build/dev/javascript/my_app/my_app.mjs"
  assert config.compiled_entry(nested)
    == "./build/dev/javascript/my_app/my_app/server.mjs"
}

const every_key =
  "name = \"my_app\"
target = \"javascript\"

[tools.giolt]
entry = \"my_app/server\"
assets = \"public\"
outdir = \"./out\"
esbuild_args = [\"--minify=false\", \"--external:foo\"]
spa = true
watch = [\"src\", \"content\"]
port = 8080
live_reload = false
api_url = \"http://localhost:4000\"
prebuild = \"gleam run -m docs/build\"
artifact = \"./site\"
"

pub fn every_key_is_read_from_tools_giolt_test() {
  assert config.parse(every_key)
    == Ok(config.Config(
      package: "my_app",
      target: Javascript,
      entry: "my_app/server",
      assets: Some("public"),
      outdir: "./out",
      esbuild_args: ["--minify=false", "--external:foo"],
      spa: True,
      watch: ["src", "content"],
      port: 8080,
      live_reload: False,
      api_url: "http://localhost:4000",
      prebuild: Some("gleam run -m docs/build"),
      artifact: Some("./site"),
    ))
}

pub fn defaults_apply_when_no_keys_are_set_test() {
  let assert Ok(parsed) = config.parse("name = \"my_app\"\n")

  assert parsed.assets == None
  assert parsed.outdir == "./dist"
  assert parsed.esbuild_args == []
  assert parsed.spa == False
  assert parsed.watch == ["src"]
  assert parsed.port == 3000
  assert parsed.live_reload == True
  assert parsed.api_url == "https://dash.giolt.com"
  assert parsed.prebuild == None
  assert parsed.artifact == None
}

pub fn assets_directory_is_watched_by_default_test() {
  let source = "name = \"my_app\"\n[tools.giolt]\nassets = \"public\"\n"
  let assert Ok(parsed) = config.parse(source)

  assert parsed.watch == ["src", "public"]
}

pub fn explicit_watch_replaces_the_default_test() {
  let source =
    "name = \"my_app\"\n[tools.giolt]\nassets = \"public\"\nwatch = [\"content\"]\n"
  let assert Ok(parsed) = config.parse(source)

  assert parsed.watch == ["content"]
}

pub fn wrongly_typed_keys_are_rejected_test() {
  let parse = fn(line) {
    config.parse("name = \"my_app\"\n[tools.giolt]\n" <> line <> "\n")
  }

  assert parse("assets = 1")
    == Error(config.InvalidValue(key: "assets", expected: "a string"))
  assert parse("outdir = true")
    == Error(config.InvalidValue(key: "outdir", expected: "a string"))
  assert parse("esbuild_args = \"--minify\"")
    == Error(config.InvalidValue(
      key: "esbuild_args",
      expected: "a list of strings",
    ))
  assert parse("esbuild_args = [1]")
    == Error(config.InvalidValue(
      key: "esbuild_args",
      expected: "a list of strings",
    ))
  assert parse("watch = [\"src\", 2]")
    == Error(config.InvalidValue(key: "watch", expected: "a list of strings"))
  assert parse("spa = \"yes\"")
    == Error(config.InvalidValue(key: "spa", expected: "true or false"))
  assert parse("live_reload = 1")
    == Error(config.InvalidValue(key: "live_reload", expected: "true or false"))
  assert parse("port = \"80\"")
    == Error(config.InvalidValue(key: "port", expected: "a whole number"))
  assert parse("prebuild = 3")
    == Error(config.InvalidValue(key: "prebuild", expected: "a string"))
  assert parse("artifact = 1")
    == Error(config.InvalidValue(key: "artifact", expected: "a string"))
  assert parse("api_url = []")
    == Error(config.InvalidValue(key: "api_url", expected: "a string"))
}

pub fn port_outside_the_valid_range_is_rejected_test() {
  let parse = fn(port) {
    config.parse("name = \"my_app\"\n[tools.giolt]\nport = " <> port <> "\n")
  }

  assert parse("0") == Error(config.InvalidPort(0))
  assert parse("65536") == Error(config.InvalidPort(65_536))
  assert parse("-1") == Error(config.InvalidPort(-1))

  let assert Ok(highest) = parse("65535")
  let assert Ok(lowest) = parse("1")
  assert highest.port == 65_535
  assert lowest.port == 1
}

pub fn settings_file_replaces_tools_giolt_but_not_name_or_target_test() {
  let source =
    "name = \"my_app\"\ntarget = \"javascript\"\n\n[tools.giolt]\nentry = \"my_app/server\"\nport = 4000\n"
  let settings =
    "[tools.giolt]\nentry = \"my_app/admin\"\noutdir = \"./dist/admin\"\n"

  assert config.parse_with(source, Some(settings))
    == Ok(
      config.Config(
        ..config.default("my_app", Javascript),
        entry: "my_app/admin",
        outdir: "./dist/admin",
      ),
    )
}

pub fn settings_file_without_tools_giolt_means_all_defaults_test() {
  let source =
    "name = \"my_app\"\ntarget = \"javascript\"\n\n[tools.giolt]\nport = 4000\n"

  assert config.parse_with(source, Some("# nothing here\n"))
    == Ok(config.default("my_app", Javascript))
}

pub fn invalid_settings_file_is_reported_apart_from_gleam_toml_test() {
  let source = "name = \"my_app\"\ntarget = \"javascript\"\n"

  assert config.parse_with(source, Some("[tools.giolt\n"))
    == Error(config.InvalidSettingsToml)
}

pub fn settings_file_values_are_checked_like_gleam_toml_test() {
  let source = "name = \"my_app\"\ntarget = \"javascript\"\n"

  assert config.parse_with(source, Some("[tools.giolt]\nport = 0\n"))
    == Error(config.InvalidPort(0))
}

pub fn blames_settings_file_for_tools_giolt_errors_only_test() {
  assert config.blames_settings_file(config.InvalidSettingsToml)
  assert !config.blames_settings_file(config.InvalidToml)
  assert !config.blames_settings_file(config.MissingName)
  assert !config.blames_settings_file(config.SpaWithoutArtifact)
}

pub fn spa_without_artifact_is_rejected_test() {
  let assert Ok(spa) =
    config.parse(
      "name = \"my_app\"\ntarget = \"javascript\"\n[tools.giolt]\nspa = true\n",
    )

  assert config.check_spa(spa, None) == Error(config.SpaWithoutArtifact)
  assert config.check_spa(spa, Some("dist")) == Ok(Nil)
  assert config.check_spa(config.default("my_app", Javascript), None) == Ok(Nil)
}

pub fn missing_artifact_mentions_prebuild_only_when_configured_test() {
  assert config.describe_missing_artifact("site", Some("make site"))
    == "No such artifact directory: site. Make `prebuild` write the site there."
  assert config.describe_missing_artifact("site", None)
    == "No such artifact directory: site. Create it first."
}
