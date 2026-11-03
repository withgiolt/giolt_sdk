import giolt/internal/watcher
import gleam/javascript/promise
import gleam/list
import gleam/string
import simplifile

fn record_to(
  log: String,
  hold_ms: Int,
) -> fn(List(String)) -> promise.Promise(Nil) {
  fn(paths) {
    let assert Ok(_) = simplifile.append(log, string.join(paths, ",") <> "\n")
    promise.wait(hold_ms)
  }
}

fn calls(log: String) -> List(String) {
  case simplifile.read(log) {
    Ok(text) -> string.split(text, "\n") |> list.filter(fn(line) { line != "" })
    Error(_) -> []
  }
}

fn fresh(dir: String) -> String {
  let log = dir <> ".log"
  let _ = simplifile.delete(dir)
  let _ = simplifile.delete(log)
  let assert Ok(_) = simplifile.create_directory_all(dir)
  log
}

fn until(check: fn() -> Bool, tries: Int) -> promise.Promise(Nil) {
  case check() || tries == 0 {
    True -> promise.resolve(Nil)
    False -> {
      use _ <- promise.await(promise.wait(50))
      until(check, tries - 1)
    }
  }
}

fn mentions(log: String, file: String) -> fn() -> Bool {
  fn() { list.any(calls(log), string.contains(_, file)) }
}

fn clean(dir: String, log: String) -> Nil {
  let _ = simplifile.delete(dir)
  let _ = simplifile.delete(log)
  Nil
}

pub fn files_saved_together_arrive_as_one_batch_test() {
  let dir = "./test_tmp_watch_batch"
  let log = fresh(dir)

  // Node on macOS reports a directory created just before the watcher starts.
  use _ <- promise.await(promise.wait(300))
  let stop = watcher.watch([dir], record_to(log, 0))
  use _ <- promise.await(promise.wait(150))
  let assert Ok(_) = simplifile.write(dir <> "/a.txt", "a")
  let assert Ok(_) = simplifile.write(dir <> "/b.txt", "b")
  use _ <- promise.map(until(mentions(log, "b.txt"), 60))

  stop()
  let seen = calls(log)
  clean(dir, log)

  assert list.any(seen, fn(call) {
    string.contains(call, "a.txt") && string.contains(call, "b.txt")
  })
}

pub fn changes_during_a_slow_run_become_one_follow_up_test() {
  let dir = "./test_tmp_watch_followup"
  let log = fresh(dir)

  use _ <- promise.await(promise.wait(300))
  let stop = watcher.watch([dir], record_to(log, 400))
  use _ <- promise.await(promise.wait(150))
  let assert Ok(_) = simplifile.write(dir <> "/a.txt", "a")
  use _ <- promise.await(until(mentions(log, "a.txt"), 60))
  let assert Ok(_) = simplifile.write(dir <> "/b.txt", "b")
  let assert Ok(_) = simplifile.write(dir <> "/c.txt", "c")
  use _ <- promise.await(until(mentions(log, "c.txt"), 60))
  use _ <- promise.map(promise.wait(600))

  stop()
  let seen = calls(log)
  clean(dir, log)

  let with_a = list.filter(seen, string.contains(_, "a.txt"))
  let with_b = list.filter(seen, string.contains(_, "b.txt"))
  let with_c = list.filter(seen, string.contains(_, "c.txt"))
  assert list.length(with_a) == 1
  assert with_b == with_c
  assert list.length(with_b) == 1
  assert !list.any(with_b, string.contains(_, "a.txt"))
}

pub fn stopping_the_watcher_ends_the_calls_test() {
  let dir = "./test_tmp_watch_stop"
  let log = fresh(dir)

  use _ <- promise.await(promise.wait(300))
  let stop = watcher.watch([dir], record_to(log, 0))
  use _ <- promise.await(promise.wait(150))
  stop()
  let assert Ok(_) = simplifile.write(dir <> "/a.txt", "a")
  use _ <- promise.map(promise.wait(400))

  let seen = calls(log)
  clean(dir, log)

  assert seen == []
}
