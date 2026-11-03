import giolt/internal/confirm.{Ask, Proceed, Refuse}

pub fn yes_skips_the_prompt_test() {
  assert confirm.decide(yes: True, interactive: True) == Proceed
  assert confirm.decide(yes: True, interactive: False) == Proceed
}

pub fn a_terminal_is_asked_test() {
  assert confirm.decide(yes: False, interactive: True) == Ask
}

pub fn no_terminal_and_no_yes_refuses_test() {
  assert confirm.decide(yes: False, interactive: False) == Refuse
}

pub fn only_the_exact_name_confirms_test() {
  assert confirm.accepts(expected: "blog", typed: "blog")
  assert !confirm.accepts(expected: "blog", typed: "Blog")
  assert !confirm.accepts(expected: "blog", typed: "blog ")
  assert !confirm.accepts(expected: "blog", typed: "y")
  assert !confirm.accepts(expected: "blog", typed: "")
}
