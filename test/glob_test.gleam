import giolt_sdk/internal/glob

pub fn matches_bare_star_test() {
  assert glob.matches(pattern: "*.gleam", path: "app.gleam")
}

pub fn matches_bare_star_by_basename_test() {
  assert glob.matches(pattern: "*.gleam", path: "src/app.gleam")
}

pub fn matches_bare_star_non_match_test() {
  assert !glob.matches(pattern: "*.gleam", path: "src/app.mjs")
}

pub fn matches_globstar_test() {
  assert glob.matches(pattern: "**/*_dev.gleam", path: "src/app_dev.gleam")
}

pub fn matches_globstar_at_root_test() {
  assert glob.matches(pattern: "**/*_dev.gleam", path: "app_dev.gleam")
}

pub fn matches_globstar_non_match_test() {
  assert !glob.matches(pattern: "**/*_dev.gleam", path: "src/app.gleam")
}

pub fn matches_directory_star_test() {
  assert glob.matches(pattern: "./public/*", path: "./public/app.css")
}

pub fn matches_directory_star_does_not_cross_segments_test() {
  assert !glob.matches(pattern: "./public/*", path: "./public/nested/app.css")
}

pub fn matches_question_mark_test() {
  assert glob.matches(pattern: "a?c", path: "abc")
}

pub fn matches_normalises_dot_slash_test() {
  assert glob.matches(pattern: "src/*.gleam", path: "./src/app.gleam")
}

pub fn matches_any_test() {
  let patterns = ["*.css", "**/*_dev.gleam"]

  assert glob.matches_any(patterns, "src/app_dev.gleam")
  assert glob.matches_any(patterns, "public/app.css")
  assert !glob.matches_any(patterns, "src/app.gleam")
}
