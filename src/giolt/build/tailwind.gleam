import envie
import gleam/io
import tailwind

pub fn build(css_path css_path: String) {
  let is_dev = envie.get_string("NODE_ENV", "production") == "development"

  let result =
    tailwind.install_and_run([
      "-i",
      css_path,
      "-o",
      "./dist/app.css",
      ..case is_dev {
        True -> []
        False -> ["--minify"]
      }
    ])

  case result {
    Ok(_) -> io.println("[GioltSDK] TailwindCSS succeeded!")
    Error(e) -> {
      echo e
      panic as "[GioltSDK] TailwindCSS failed!"
    }
  }
}
