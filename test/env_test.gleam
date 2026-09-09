import giolt_sdk/internal/env

pub fn is_exposed_public_test() {
  assert env.is_exposed("PUBLIC_API_URL") == True
}

pub fn is_exposed_private_test() {
  assert env.is_exposed("PRIVATE_SECRET") == True
}

pub fn is_exposed_other_test() {
  assert env.is_exposed("PATH") == False
}

pub fn is_exposed_prefix_only_test() {
  assert env.is_exposed("PUBLICSOMETHING") == False
}

pub fn quote_plain_test() {
  assert env.quote("hello") == "\"hello\""
}

pub fn quote_escapes_backslash_test() {
  assert env.quote("a\\b") == "\"a\\\\b\""
}

pub fn quote_escapes_double_quote_test() {
  assert env.quote("say \"hi\"") == "\"say \\\"hi\\\"\""
}

pub fn quote_escapes_newline_test() {
  assert env.quote("line1\nline2") == "\"line1\\nline2\""
}

pub fn defines_filters_non_exposed_test() {
  let vars = [#("PATH", "/usr/bin"), #("HOME", "/root")]

  assert env.defines(vars) == []
}

pub fn defines_keeps_exposed_test() {
  let vars = [#("PUBLIC_URL", "https://example.com")]

  assert env.defines(vars)
    == ["--define:process.env.PUBLIC_URL=\"https://example.com\""]
}

pub fn defines_is_sorted_test() {
  let vars = [#("PUBLIC_B", "2"), #("PUBLIC_A", "1")]

  assert env.defines(vars)
    == [
      "--define:process.env.PUBLIC_A=\"1\"",
      "--define:process.env.PUBLIC_B=\"2\"",
    ]
}

pub fn defines_mixed_test() {
  let vars = [
    #("PRIVATE_KEY", "shh"),
    #("PATH", "/usr/bin"),
    #("PUBLIC_NAME", "giolt"),
  ]

  assert env.defines(vars)
    == [
      "--define:process.env.PRIVATE_KEY=\"shh\"",
      "--define:process.env.PUBLIC_NAME=\"giolt\"",
    ]
}
