import gleam/string

pub const package_name = "giolt_glowvm_build"

pub const build_dir = "./build/.giolt/glowvm"

pub const pack_module = "giolt_glowvm_pack"

pub const archive = "build/app.avm"

pub const start_module = "giolt_glowvm_start"

const runtime_range = ">= 0.2.0 and < 1.0.0"

pub fn runtime_files() -> List(String) {
  ["glowvm.wasm", "index.js", "index.min.js"]
}

pub fn gleam_toml(
  package package: String,
  project_path project_path: String,
) -> String {
  "name = \"" <> package_name <> "\"
version = \"0.0.0\"
target = \"erlang\"

[dependencies]
gleam_stdlib = \">= 1.0.0 and < 2.0.0\"
filepath = \">= 1.1.0 and < 2.0.0\"
simplifile = \">= 2.7.0 and < 3.0.0\"
orbital = \">= 1.1.0 and < 2.0.0\"
glowvm = \"" <> runtime_range <> "\"
" <> package <> " = { path = \"" <> project_path <> "\" }
"
}

pub fn start_source(entry: String) -> String {
  "import glowvm
import " <> entry <> " as user

pub fn start() {
  glowvm.serve(fn(req) { user.handle(req) })
}
"
}

pub fn pack_source() -> String {
  pack_template
  |> string.replace("{archive}", archive)
  |> string.replace("{start_module}", start_module)
}

const pack_template =
  "import filepath
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplifile

const stdlib_dir = \"build/packages/glowvm/priv/stdlib\"

pub fn main() {
  case pack() {
    Ok(Nil) -> Nil
    Error(message) -> {
      io.println_error(message)
      halt(1)
    }
  }
}

fn pack() -> Result(Nil, String) {
  use entries <- result.try(
    simplifile.read_directory(stdlib_dir)
    |> result.replace_error(\"cannot read \" <> stdlib_dir),
  )
  let stdlib =
    entries
    |> list.filter(is_beam)
    |> list.map(filepath.join(stdlib_dir, _))

  use _ <- result.try(case stdlib {
    [] -> Error(\"no .beam files found in \" <> stdlib_dir)
    _ -> Ok(Nil)
  })

  use compiled <- result.try(
    simplifile.get_files(\"build/dev/erlang\")
    |> result.replace_error(\"cannot list the compiled modules\"),
  )
  let app =
    list.filter(compiled, fn(file) {
      is_beam(file) && !list.contains(string.split(file, \"/\"), \"priv\")
    })

  packbeam_create(\"{archive}\", \"{start_module}\", list.append(app, stdlib))
  |> result.map_error(fn(error) { \"packbeam failed: \" <> string.inspect(error) })
}

fn is_beam(path: String) -> Bool {
  filepath.extension(path) == Ok(\"beam\")
}

@external(erlang, \"orbital_ffi\", \"packbeam_create\")
fn packbeam_create(
  output_path: String,
  start_module: String,
  beam_files: List(String),
) -> Result(Nil, String)

@external(erlang, \"erlang\", \"halt\")
fn halt(status: Int) -> a
"
