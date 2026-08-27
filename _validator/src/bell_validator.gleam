import argv
import bell_validator/problem
import bell_validator/rules
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import simplifile

/// What the run has to say for itself, and how the process should end.
type Outcome {
  Passed(summary: String)
  Failed(report: String, status: Int)
}

pub fn main() -> Nil {
  let root = case argv.load().arguments {
    [path, ..] -> path
    [] -> "."
  }
  case check(root) {
    Passed(summary) -> io.println(summary)
    Failed(report:, status:) -> {
      io.println_error(report)
      halt(status)
    }
  }
}

fn check(root: String) -> Outcome {
  let schools = root <> "/schools"
  case simplifile.read_directory(schools) {
    Error(error) ->
      Failed(
        report: "bell-validator: cannot read "
          <> schools
          <> ": "
          <> string.inspect(error),
        status: 2,
      )
    Ok(names) -> summarise(source_problems(schools, names))
  }
}

fn source_problems(schools: String, names: List(String)) -> List(List(String)) {
  names
  |> list.sort(string.compare)
  |> list.map(fn(name) {
    rules.check(load(schools, name)) |> list.map(problem.to_string(name, _))
  })
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

fn summarise(sources: List(List(String))) -> Outcome {
  let count = int.to_string(list.length(sources))
  case list.flatten(sources) {
    [] -> Passed("bell-validator: " <> count <> " sources, no problems")
    problems ->
      Failed(
        report: string.join(problems, "\n")
          <> "\n\nbell-validator: "
          <> int.to_string(list.length(problems))
          <> " problem(s) across "
          <> count
          <> " sources",
        status: 1,
      )
  }
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil
