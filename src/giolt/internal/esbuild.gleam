pub const install_dir = "./build/dev/bin/package/bin"

pub type Plan {
  Plan(entry: String, outfile: String, additional_args: List(String))
}

pub fn flags(plan: Plan) -> List(String) {
  [
    plan.entry,
    "--bundle",
    "--format=esm",
    "--platform=node",
    "--minify",
    "--tree-shaking=true",
    "--outfile=" <> plan.outfile,
    ..plan.additional_args
  ]
}

pub fn exe_path(exe_name: String) -> String {
  install_dir <> "/" <> exe_name
}

pub fn tarball_url(package: String) -> String {
  "https://registry.npmjs.org/@esbuild/"
  <> package
  <> "/-/"
  <> package
  <> "-"
  <> version
  <> ".tgz"
}

pub const version = "0.28.2"
