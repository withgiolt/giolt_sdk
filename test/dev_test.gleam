import giolt_sdk/dev

pub fn change_kind_created_test() {
  assert dev.change_kind("created") == dev.Created
}

pub fn change_kind_modified_test() {
  assert dev.change_kind("modified") == dev.Modified
}

pub fn change_kind_deleted_test() {
  assert dev.change_kind("deleted") == dev.Deleted
}

pub fn change_kind_unknown_defaults_to_modified_test() {
  assert dev.change_kind("something-else") == dev.Modified
}

pub fn initial_change_test() {
  assert dev.initial_change == dev.Change(path: "", kind: dev.Modified)
}
