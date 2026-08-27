import argv
import bell_validator/report.{type Outcome}
import bell_validator/rules
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import simplifile

pub fn main() -> Nil {
  let root = case argv.load().arguments {
    [path, ..] -> path
    [] -> "."
  }
  case check(root) {
    report.Passed(message) -> io.println(message)
    report.Failed(message:, exit:) -> {
      io.println_error(message)
      halt(status(exit))
    }
  }
}

fn status(exit: report.Exit) -> Int {
  case exit {
    report.Problems -> 1
    report.Unreadable -> 2
  }
}

fn check(root: String) -> Outcome {
  let schools = root <> "/schools"
  case simplifile.read_directory(schools) {
    Error(error) -> report.unreadable(schools, string.inspect(error))
    Ok(names) -> report.of(sources(schools, names))
  }
}

fn sources(schools: String, names: List(String)) -> List(report.Source) {
  names
  |> list.sort(string.compare)
  |> list.map(fn(name) { report.Source(name, rules.check(load(schools, name))) })
}

fn load(schools: String, name: String) -> rules.Data {
  let read = fn(file) {
    option.from_result(simplifile.read(schools <> "/" <> name <> "/" <> file))
  }
  rules.Data(
    source: read("source.json"),
    meta: read("meta.json"),
    correction: read("correction.txt"),
    schedules: read("schedules.bell"),
    calendar: read("calendar.bell"),
  )
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil
