pub type Decision {
  Proceed
  Ask
  Refuse
}

pub fn decide(yes yes: Bool, interactive interactive: Bool) -> Decision {
  case yes, interactive {
    True, _ -> Proceed
    False, True -> Ask
    False, False -> Refuse
  }
}

pub fn accepts(expected expected: String, typed typed: String) -> Bool {
  typed == expected
}
