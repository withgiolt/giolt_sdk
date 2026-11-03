import envie
import filepath
import giolt/internal/api
import giolt/internal/bundle
import giolt/internal/config.{
  type Config, Erlang, Javascript, describe_missing_artifact,
}
import giolt/internal/confirm
import giolt/internal/credentials.{type Credential, type Session, Credential}
import giolt/internal/deploy
import giolt/internal/glowvm_bin
import giolt/internal/io
import giolt/internal/link
import giolt/internal/process
import giolt/internal/server
import giolt/internal/signature
import giolt/internal/watcher
import gleam/int
import gleam/io as stdio
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile

const javascript_steps = 3

const interface_path = "./build/.giolt-interface.json"

const login_expired =
  "The login code expired before it was approved. Run `giolt login` to get a new one."

const env_token_untouched =
  "`GIOLT_TOKEN` is set. Logging out only clears the stored token, so commands keep using GIOLT_TOKEN."

pub fn build(
  config config_path: Option(String),
) -> Promise(Result(Nil, String)) {
  case read_config(config_path, None) {
    Error(message) -> promise.resolve(Error(message))
    Ok(config) ->
      case config.artifact {
        Some(path) -> prepare_site(config, path)
        None -> run_build(config)
      }
  }
}

pub fn deploy(
  preview preview: Bool,
  artifact artifact: Option(String),
  project project: Option(String),
  config config_path: Option(String),
) -> Promise(Result(Nil, String)) {
  case read_config(config_path, artifact) {
    Error(message) -> promise.resolve(Error(message))
    Ok(config) ->
      case option.or(artifact, config.artifact), config.target {
        Some(path), _ ->
          build_then_submit(
            config,
            deploy.assets(deploy.new(), path),
            preview,
            project,
            fn() { prepare_site(config, path) },
          )
        None, Erlang ->
          promise.resolve(Error(
            "Deploying the Erlang target is not supported by the Giolt platform yet.",
          ))
        None, Javascript ->
          build_then_submit(
            config,
            deploy.artifact(deploy.new(), config.outdir),
            preview,
            project,
            fn() { run_build(config) },
          )
      }
  }
}

fn build_then_submit(
  config: Config,
  artifact: deploy.Config(deploy.HasArtifact),
  preview: Bool,
  project: Option(String),
  build: fn() -> Promise(Result(Nil, String)),
) -> Promise(Result(Nil, String)) {
  let configured =
    artifact
    |> deploy.preview(preview)
    |> deploy.spa(config.spa)

  // A missing token or unknown project is knowable up front; don't make the
  // user wait for a build.
  use destination <- promise.try_await(deploy_destination(config, project))
  use built <- promise.await(build())
  case built {
    Error(message) -> promise.resolve(Error(message))
    Ok(Nil) -> submit(configured, destination)
  }
}

fn deploy_destination(
  config: Config,
  project: Option(String),
) -> Promise(Result(deploy.Destination, String)) {
  let route =
    deploy.route(
      project:,
      linked: config.project,
      env_token: env_var(credentials.token_env),
      env_api_url: env_var(credentials.api_url_env),
      config_api_url: config.api_url,
      stored: credentials.load(credentials_path()) |> result.unwrap(None),
    )

  case route {
    Error(error) -> promise.resolve(Error(deploy.describe_error(error)))
    Ok(deploy.Ready(destination)) -> promise.resolve(Ok(destination))
    Ok(deploy.Lookup(name:, client:)) -> {
      use found <- promise.map(api_call(api.find_project(client, name)))
      use found <- result.map(found)
      deploy.ToProject(id: found.id, client:)
    }
  }
}

pub fn link_project(
  name name: String,
  config config_path: Option(String),
) -> Promise(Result(Nil, String)) {
  let path = option.unwrap(config_path, "gleam.toml")
  case simplifile.read(path) {
    Error(_) -> promise.resolve(Error("Could not read " <> path <> "."))
    Ok(source) -> {
      use _, client <- signed_in()
      use project <- promise.map(api_call(api.find_project(client, name)))
      use project <- result.try(project)
      use edited <- result.try(
        link.set_project(source, project.id)
        |> result.replace_error(cannot_edit(path)),
      )
      use _ <- result.map(write_config(path, edited))
      io.println_success(
        "Linked to "
        <> project.slug
        <> " (project "
        <> int.to_string(project.id)
        <> ") in "
        <> path
        <> ". Commit it so CI deploys there too.",
      )
    }
  }
}

pub fn unlink_project(
  config config_path: Option(String),
) -> Promise(Result(Nil, String)) {
  let path = option.unwrap(config_path, "gleam.toml")
  promise.resolve({
    use source <- result.try(
      simplifile.read(path)
      |> result.replace_error("Could not read " <> path <> "."),
    )
    use edited <- result.try(
      link.remove_project(source) |> result.replace_error(cannot_edit(path)),
    )
    case edited == source {
      True -> Ok(io.println_info("No project is linked in " <> path <> "."))
      False -> {
        use _ <- result.map(write_config(path, edited))
        io.println_success("Removed the linked project from " <> path <> ".")
      }
    }
  })
}

fn cannot_edit(path: String) -> String {
  "Could not edit `project` in "
  <> path
  <> ". Set `project` under [tools.giolt] by hand."
}

fn write_config(path: String, text: String) -> Result(Nil, String) {
  simplifile.write(path, text)
  |> result.replace_error("Could not write " <> path <> ".")
}

pub fn dev(config config_path: Option(String)) -> Promise(Result(Nil, String)) {
  case read_config(config_path, None) {
    Error(message) -> promise.resolve(Error(message))
    Ok(config) ->
      case config.artifact, config.target {
        Some(path), _ -> serve_dev(config, path, "")
        None, Erlang ->
          promise.resolve(Error(
            "`giolt dev` supports the javascript target only for now.",
          ))
        None, Javascript ->
          serve_dev(
            config,
            option.unwrap(config.assets, ""),
            filepath.join(config.outdir, "index.mjs"),
          )
      }
  }
}

fn serve_dev(
  config: Config,
  static_dir: String,
  worker_path: String,
) -> Promise(Result(Nil, String)) {
  use _ <- promise.await(rebuild(config))

  let stop_watching =
    watcher.watch(config.watch, fn(paths) {
      io.println_info("Changed " <> string.join(paths, ", ") <> ", rebuilding")
      rebuild(config)
    })

  server.serve(
    port: config.port,
    static_dir: case static_dir {
      "" -> None
      path -> Some(path)
    },
    worker_path:,
    live_reload: config.live_reload,
    spa: config.spa,
  )

  let _ = stop_watching
  process.forever() |> promise.map(fn(_) { Ok(Nil) })
}

fn rebuild(config: Config) -> Promise(Nil) {
  let building = case config.artifact {
    Some(path) -> prepare_site(config, path)
    None -> run_build(config)
  }

  use result <- promise.map(building)
  case result {
    Ok(Nil) -> server.notify_reload()
    Error(message) -> io.println_error(message)
  }
}

fn prepare_site(config: Config, path: String) -> Promise(Result(Nil, String)) {
  use prebuilt <- promise.map(run_prebuild(config.prebuild))
  use _ <- result.try(prebuilt)

  case simplifile.read_directory(path) {
    Ok([_, ..]) -> {
      io.println_success("Static site ready in " <> path)
      Ok(Nil)
    }
    Ok([]) -> Error("The artifact directory " <> path <> " is empty.")
    Error(_) -> {
      let site_prebuild = case config.artifact == Some(path) {
        True -> config.prebuild
        False -> None
      }
      Error(describe_missing_artifact(path, site_prebuild))
    }
  }
}

fn read_config(
  settings_path: Option(String),
  artifact_flag: Option(String),
) -> Result(Config, String) {
  use source <- result.try(
    simplifile.read("gleam.toml")
    |> result.replace_error(
      "Could not read gleam.toml. Run this from the root of a Gleam project.",
    ),
  )
  use settings <- result.try(case settings_path {
    None -> Ok(None)
    Some(path) ->
      simplifile.read(path)
      |> result.map(Some)
      |> result.replace_error(
        "Could not read the --config file " <> path <> ".",
      )
  })

  config.parse_with(source, settings)
  |> result.try(fn(parsed) {
    // The platform rejects spa with a worker, and dev would silently ignore it.
    config.check_spa(parsed, option.or(artifact_flag, parsed.artifact))
    |> result.replace(parsed)
  })
  |> result.map_error(fn(error) {
    case settings_path {
      Some(path) -> {
        case config.blames_settings_file(error) {
          True ->
            config.describe_error(error) <> " The value is in " <> path <> "."
          False -> config.describe_error(error)
        }
      }
      None -> config.describe_error(error)
    }
  })
}

fn run_build(config: Config) -> Promise(Result(Nil, String)) {
  let tooling = case config.target {
    Javascript -> Ok(Nil)
    Erlang -> glowvm_bin.check_tooling()
  }

  case tooling {
    Error(message) -> promise.resolve(Error(message))
    Ok(Nil) -> {
      use _ <- promise.try_await(run_prebuild(config.prebuild))
      use _ <- promise.try_await(check_handle(config))

      case config.target {
        Javascript -> {
          io.println_progress(1, javascript_steps, "Checked handle")
          bundle_javascript(config)
        }
        Erlang -> {
          io.println_progress(1, glowvm_bin.steps, "Checked handle")
          warn_unused_assets(config)
          glowvm_bin.build(config, config.outdir)
        }
      }
    }
  }
}

fn run_prebuild(prebuild: Option(String)) -> Promise(Result(Nil, String)) {
  case prebuild {
    None -> promise.resolve(Ok(Nil))
    Some(command) -> {
      io.println_info("Running prebuild: " <> command)
      process.shell(command)
    }
  }
}

fn check_handle(config: Config) -> Promise(Result(Nil, String)) {
  io.println_info("Checking `handle` in " <> config.entry <> "...")

  case simplifile.create_directory_all("./build") {
    Error(_) -> promise.resolve(Error("Could not create the build directory."))
    Ok(Nil) -> {
      use exported <- promise.map(
        process.run("gleam", [
          "export",
          "package-interface",
          "--out",
          interface_path,
        ]),
      )

      use _ <- result.try(exported)
      use interface <- result.try(
        simplifile.read(interface_path)
        |> result.replace_error("Could not read " <> interface_path <> "."),
      )

      signature.check(interface, config.entry, config.target)
      |> result.map_error(signature.describe_error)
    }
  }
}

fn bundle_javascript(config: Config) -> Promise(Result(Nil, String)) {
  use _ <- promise.try_await(
    process.run("gleam", ["build", "--target", "javascript"]),
  )
  io.println_progress(2, javascript_steps, "Compiled")

  let base =
    bundle.new()
    |> bundle.entry(config.compiled_entry(config))
    |> bundle.outdir(config.outdir)
    |> bundle.additional_args(config.esbuild_args)
  let with_assets = case config.assets {
    Some(path) -> bundle.static_dir(base, path)
    None -> base
  }

  use bundled <- promise.map(bundle.run(with_assets))
  bundled
  |> result.replace_error("Build failed.")
  |> result.map(fn(_) { io.println_progress(3, javascript_steps, "Bundled") })
}

fn warn_unused_assets(config: Config) -> Nil {
  case config.assets {
    Some(_) ->
      io.println_warning(
        "`assets` is ignored for the Erlang target: GlowVM apps have no static directory yet.",
      )
    None -> Nil
  }
}

fn submit(
  configured: deploy.Config(deploy.HasArtifact),
  destination: deploy.Destination,
) -> Promise(Result(Nil, String)) {
  use result <- promise.map(deploy.run(configured, destination))
  case result {
    Ok(deployment) -> {
      deploy.print_result(Ok(deployment))
      Ok(Nil)
    }
    Error(error) -> Error(deploy.describe_error(error))
  }
}

pub fn login(token token: Option(String)) -> Promise(Result(Nil, String)) {
  let api_url = credentials.api_url(env_var(credentials.api_url_env))
  case token {
    None -> login_in_browser(api_url)
    Some("-") -> {
      let prompt = case process.is_interactive() {
        True -> "Paste the token: "
        False -> ""
      }
      use line <- promise.await(process.read_line(prompt))
      case string.trim(line) {
        "" -> promise.resolve(Error("No token on stdin."))
        token -> login_with_token(api_url, token)
      }
    }
    Some(token) -> login_with_token(api_url, token)
  }
}

fn login_with_token(
  api_url: String,
  token: String,
) -> Promise(Result(Nil, String)) {
  case credentials.token_kind(token) {
    credentials.UserToken -> {
      use previous <- promise.try_await(verify_and_store(api_url, token))
      revoke_previous(previous, token)
    }
    credentials.DeployKey ->
      promise.resolve(Error(
        "That is a deploy key, which can only deploy its one project. "
        <> "`giolt login --token` needs a user token, which starts with "
        <> "`giolt_`. Deploy keys go in `GIOLT_TOKEN` for `giolt deploy`.",
      ))
  }
}

fn login_in_browser(api_url: String) -> Promise(Result(Nil, String)) {
  use device <- promise.try_await(api_call(api.start_device_login(api_url)))

  io.println_info("Your login code is " <> device.user_code)
  io.println_info("Approve it at " <> device.verification_url)
  case api.can_open_in_browser(device.verification_url) {
    True -> process.open_url(device.verification_url)
    False -> Nil
  }
  io.println_info("Waiting for approval...")

  use token <- promise.try_await(await_approval(
    api_url,
    device.device_code,
    device.interval,
    device.expires_in,
  ))
  use stored <- promise.await(verify_and_store(api_url, token))
  case stored {
    Ok(previous) -> revoke_previous(previous, token)
    // Nobody else holds this token, so don't leave it live on the server.
    Error(message) -> {
      let unsaved = api.Client(api_url:, token:)
      use _ <- promise.map(api.revoke_token(unsaved))
      Error(message)
    }
  }
}

fn await_approval(
  api_url: String,
  device_code: String,
  interval: Int,
  seconds_left: Int,
) -> Promise(Result(String, String)) {
  let interval = int.max(interval, 1)
  case seconds_left <= 0 {
    True -> promise.resolve(Error(login_expired))
    False -> {
      use _ <- promise.await(process.sleep(interval * 1000))
      use step <- promise.await(api.poll_device_login(
        api_url,
        device_code,
        interval,
      ))
      case step {
        api.Approved(token) -> promise.resolve(Ok(token))
        api.Pending(next) ->
          await_approval(api_url, device_code, next, seconds_left - interval)
        api.CodeExpired -> promise.resolve(Error(login_expired))
        api.Denied ->
          promise.resolve(Error(
            "The login was denied in the browser. Run `giolt login` to try again.",
          ))
        api.PollFailed(error) ->
          promise.resolve(Error(api.describe_error(error)))
      }
    }
  }
}

fn verify_and_store(
  api_url: String,
  token: String,
) -> Promise(Result(Option(Credential), String)) {
  let path = credentials_path()
  let previous = credentials.load(path) |> result.unwrap(None)
  use me <- promise.map(api_call(api.me(api.Client(api_url:, token:))))
  use me <- result.try(me)
  use _ <- result.try(
    credentials.save(path, Credential(token:, api_url:))
    |> result.map_error(credentials.describe_error),
  )

  io.println_success("Logged in as " <> me.email <> ".")
  io.println_info("Stored the token in " <> path <> ".")
  warn_if_env_token("`GIOLT_TOKEN` is set and takes precedence over it.")
  Ok(previous)
}

fn revoke_previous(
  previous: Option(Credential),
  token: String,
) -> Promise(Result(Nil, String)) {
  case previous {
    Some(old) if old.token != token -> {
      let replaced = api.Client(api_url: old.api_url, token: old.token)
      use revoked <- promise.map(api.revoke_token(replaced))
      case api.revocation(revoked) {
        api.NotRevoked(warning) ->
          io.println_warning("The previous login was replaced. " <> warning)
        api.Revoked | api.AlreadyInvalid -> Nil
      }
      Ok(Nil)
    }
    _ -> promise.resolve(Ok(Nil))
  }
}

pub fn logout() -> Promise(Result(Nil, String)) {
  let path = credentials_path()
  case credentials.load(path) {
    Error(_) -> {
      io.println_warning(
        "The stored token is unreadable, so it was not revoked.",
      )
      promise.resolve(forget(path))
    }
    Ok(None) -> {
      io.println_info("No stored token to remove.")
      warn_if_env_token(env_token_untouched)
      promise.resolve(Ok(Nil))
    }
    Ok(Some(stored)) -> {
      let client = api.Client(api_url: stored.api_url, token: stored.token)
      use revoked <- promise.map(api.revoke_token(client))
      case api.revocation(revoked) {
        api.Revoked -> io.println_success("Revoked the token.")
        api.AlreadyInvalid -> Nil
        api.NotRevoked(warning) -> io.println_warning(warning)
      }
      forget(path)
    }
  }
}

fn forget(path: String) -> Result(Nil, String) {
  use _ <- result.map(
    credentials.remove(path) |> result.map_error(credentials.describe_error),
  )
  io.println_success("Removed the stored token from " <> path <> ".")
  warn_if_env_token(env_token_untouched)
}

pub fn whoami() -> Promise(Result(Nil, String)) {
  use session, client <- signed_in()
  use me <- promise.map(api_call(api.me(client)))
  use me <- result.map(me)

  let expiry = case me.expires_at {
    Some(at) -> "expires " <> at
    None -> "never expires"
  }
  let source = case session.source {
    credentials.FromEnv -> credentials.token_env
    credentials.FromFile -> credentials_path()
  }
  io.println_info("Logged in as " <> me.email)
  stdio.println("Token:  " <> me.token_name <> " (" <> expiry <> ")")
  stdio.println("Scopes: " <> string.join(me.scopes, ", "))
  stdio.println("From:   " <> source)
  case session.api_url == config.default_api_url {
    True -> Nil
    False -> stdio.println("API:    " <> session.api_url)
  }
}

pub fn list_projects() -> Promise(Result(Nil, String)) {
  use _, client <- signed_in()
  use projects <- promise.map(api_call(api.list_projects(client)))
  use projects <- result.map(projects)

  case projects {
    [] ->
      io.println_info(
        "No projects yet. Create one with `giolt projects create <name>`.",
      )
    _ -> list.each(project_lines(projects), stdio.println)
  }
}

fn project_lines(projects: List(api.Project)) -> List(String) {
  let widest = fn(field: fn(api.Project) -> String) {
    list.fold(projects, 0, fn(width, project) {
      int.max(width, string.length(field(project)))
    })
  }
  let slug_width = widest(fn(project) { project.slug })
  let url_width = widest(fn(project) { project.url })

  list.map(projects, fn(project) {
    string.pad_end(project.slug, slug_width, " ")
    <> "  "
    <> string.pad_end(project.url, url_width, " ")
    <> "  "
    <> deployment_status(project)
  })
}

fn deployment_status(project: api.Project) -> String {
  case project.suspended, project.latest_deployment {
    True, _ -> "suspended"
    False, Some(deployment) -> deployment.status
    False, None -> "not deployed"
  }
}

pub fn create_project(name name: String) -> Promise(Result(Nil, String)) {
  use _, client <- signed_in()
  use project <- promise.map(api_call(api.create_project(client, name)))
  use project <- result.map(project)

  io.println_success("Created " <> project.slug <> " at " <> project.url)
}

pub fn rename_project(
  from from: String,
  to to: String,
) -> Promise(Result(Nil, String)) {
  use _, client <- signed_in()
  use old <- promise.try_await(api_call(api.find_project(client, from)))
  use renamed <- promise.map(api_call(api.rename_project(client, old.id, to)))
  use renamed <- result.map(renamed)

  io.println_success(
    "Renamed "
    <> old.slug
    <> " to "
    <> renamed.slug
    <> ", now at "
    <> renamed.url,
  )
  io.println_warning(old.url <> " no longer serves it.")
}

pub fn delete_project(
  name name: String,
  yes yes: Bool,
) -> Promise(Result(Nil, String)) {
  case confirm.decide(yes:, interactive: process.is_interactive()) {
    confirm.Refuse ->
      promise.resolve(Error(
        "Not deleting "
        <> name
        <> " without confirmation. Pass --yes to delete it from a script.",
      ))
    decision -> {
      use _, client <- signed_in()
      use project <- promise.try_await(api_call(api.find_project(client, name)))
      use confirmed <- promise.await(case decision {
        confirm.Ask -> ask_to_type(name)
        _ -> promise.resolve(True)
      })

      case confirmed {
        False ->
          promise.resolve(Error(
            "Not deleted: the name you typed did not match.",
          ))
        True -> {
          let deleting = api_call(api.delete_project(client, project.id))
          use deleted <- promise.map(deleting)
          use _ <- result.map(deleted)
          io.println_success("Deleted " <> project.slug <> ".")
        }
      }
    }
  }
}

fn ask_to_type(name: String) -> Promise(Bool) {
  io.println_warning(
    "This deletes " <> name <> " and all its deployments. It can't be undone.",
  )
  let prompt = "Type " <> name <> " to confirm: "
  use typed <- promise.map(process.read_line(prompt))
  confirm.accepts(expected: name, typed:)
}

pub fn usage(json json: Bool) -> Promise(Result(Nil, String)) {
  use _, client <- signed_in()
  use usage <- promise.map(api_call(api.usage(client)))
  use usage <- result.map(usage)

  case json {
    True -> stdio.println(api.usage_json(usage))
    False -> list.each(api.describe_usage(usage), stdio.println)
  }
}

fn signed_in(
  next: fn(Session, api.Client) -> Promise(Result(Nil, String)),
) -> Promise(Result(Nil, String)) {
  case open_session() {
    Error(message) -> promise.resolve(Error(message))
    Ok(session) ->
      next(session, api.Client(api_url: session.api_url, token: session.token))
  }
}

fn open_session() -> Result(Session, String) {
  let stored = credentials.load(credentials_path())
  let resolved =
    credentials.resolve(
      env_token: env_var(credentials.token_env),
      env_api_url: env_var(credentials.api_url_env),
      stored: result.unwrap(stored, None),
    )

  // An unreadable file only matters when there is no GIOLT_TOKEN to use.
  case resolved, stored {
    Ok(session), _ ->
      credentials.require_user_token(session)
      |> result.map_error(credentials.describe_error)
    Error(_), Error(unreadable) -> Error(credentials.describe_error(unreadable))
    Error(missing), Ok(_) -> Error(credentials.describe_error(missing))
  }
}

fn credentials_path() -> String {
  credentials.path(credentials.environment())
}

fn env_var(name: String) -> Option(String) {
  envie.get(name) |> option.from_result
}

fn warn_if_env_token(message: String) -> Nil {
  case env_var(credentials.token_env) {
    Some("") | None -> Nil
    Some(_) -> io.println_warning(message)
  }
}

fn api_call(call: Promise(Result(a, api.Error))) -> Promise(Result(a, String)) {
  promise.map(call, result.map_error(_, api.describe_error))
}
