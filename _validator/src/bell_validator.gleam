import bell_validator/problem
import bell_validator/rules
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import simplifile

pub fn main() -> Nil {
  let root = case arguments() {
    [path, ..] -> path
    [] -> "."
  }
  let schools = root <> "/schools"
  case simplifile.read_directory(schools) {
    Error(error) -> {
      io.println_error(
        "bell-validator: cannot read "
        <> schools
        <> ": "
        <> string.inspect(error),
      )
      halt(2)
    }
    Ok(names) -> report(source_problems(schools, names))
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

fn report(sources: List(List(String))) -> Nil {
  let count = int.to_string(list.length(sources))
  case list.flatten(sources) {
    [] -> io.println("bell-validator: " <> count <> " sources, no problems")
    problems -> {
      list.each(problems, io.println_error)
      io.println_error(
        "\nbell-validator: "
        <> int.to_string(list.length(problems))
        <> " problem(s) across "
        <> count
        <> " sources",
      )
      halt(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil

@external(erlang, "bell_validator_ffi", "arguments")
fn arguments() -> List(String)
