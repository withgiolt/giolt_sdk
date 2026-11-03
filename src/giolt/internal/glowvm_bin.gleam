import filepath
import giolt/internal/config.{type Config}
import giolt/internal/glowvm
import giolt/internal/io
import giolt/internal/process
import giolt/internal/tooling
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub const steps = 3

pub fn build(config: Config, outdir: String) -> Promise(Result(Nil, String)) {
  case generate_package(config) {
    Error(message) -> promise.resolve(Error(message))
    Ok(Nil) -> {
      use packed <- promise.map(pack())

      use _ <- result.try(packed)
      io.println_progress(2, steps, "Packed app")

      use _ <- result.try(copy_output(outdir))
      io.println_progress(3, steps, "Copied runtime")
      Ok(Nil)
    }
  }
}

pub fn check_tooling() -> Result(Nil, String) {
  let missing =
    list.filter(tooling.required(), fn(tool) {
      let #(command, args) = tooling.probe(tool)
      !process.available(command, args)
    })

  case missing {
    [] -> Ok(Nil)
    _ -> Error(tooling.describe_missing(missing))
  }
}

fn generate_package(config: Config) -> Result(Nil, String) {
  let files = [
    #(
      "gleam.toml",
      glowvm.gleam_toml(package: config.package, project_path: "../../.."),
    ),
    #(
      "src/" <> glowvm.start_module <> ".gleam",
      glowvm.start_source(config.entry),
    ),
    #("src/" <> glowvm.pack_module <> ".gleam", glowvm.pack_source()),
  ]

  use _ <- result.try(
    simplifile.create_directory_all(filepath.join(glowvm.build_dir, "src"))
    |> result.map_error(describe_file_error),
  )

  list.try_each(files, fn(file) {
    simplifile.write(filepath.join(glowvm.build_dir, file.0), file.1)
    |> result.map_error(describe_file_error)
  })
}

fn pack() -> Promise(Result(Nil, String)) {
  io.println_info("Packing the app for GlowVM...")

  let _ = simplifile.delete(filepath.join(glowvm.build_dir, glowvm.archive))

  process.run_in(glowvm.build_dir, "gleam", [
    "run",
    "--target",
    "erlang",
    "-m",
    glowvm.pack_module,
  ])
}

fn copy_output(outdir: String) -> Result(Nil, String) {
  let runtime_dir =
    filepath.join(glowvm.build_dir, "build/packages/glowvm/priv")
  let files = [
    #(filepath.join(glowvm.build_dir, glowvm.archive), "app.avm"),
    ..list.map(glowvm.runtime_files(), fn(name) {
      #(filepath.join(runtime_dir, name), name)
    })
  ]

  let _ = simplifile.delete(outdir)
  use _ <- result.try(
    simplifile.create_directory_all(outdir)
    |> result.map_error(describe_file_error),
  )

  list.try_each(files, fn(file) {
    simplifile.copy_file(file.0, filepath.join(outdir, file.1))
    |> result.map_error(fn(error) {
      "Could not copy " <> file.0 <> ": " <> simplifile.describe_error(error)
    })
  })
}

fn describe_file_error(error: simplifile.FileError) -> String {
  "Could not write the GlowVM build package: " <> string.inspect(error)
}
