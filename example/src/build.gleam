import example
import giolt/build/bundle
import giolt/build/islands
import giolt/build/ssg

pub fn main() {
  ssg.build(routes: example.static_routes, static_dir: "./priv")
  islands.build(islands_project_path: "./islands")
  bundle.build()
}
