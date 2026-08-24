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
  case simplifile.read_directory(root) {
    Error(error) -> {
      io.println_error(
        "bell-validator: cannot read " <> root <> ": " <> string.inspect(error),
      )
      halt(2)
    }
    Ok(entries) -> report(school_problems(root, entries))
  }
}

fn school_problems(root: String, entries: List(String)) -> List(List(String)) {
  entries
  |> list.filter(fn(name) { !string.starts_with(name, "_") })
  |> list.sort(string.compare)
  |> list.map(fn(name) { #(name, load(root, name)) })
  |> list.filter(fn(school) { rules.is_school(school.1) })
  |> list.map(fn(school) {
    rules.check(school.1) |> list.map(problem.to_string(school.0, _))
  })
}

fn load(root: String, name: String) -> rules.Data {
  let read = fn(file) {
    option.from_result(simplifile.read(root <> "/" <> name <> "/" <> file))
  }
  rules.Data(
    source: read("source.json"),
    meta: read("meta.json"),
    correction: read("correction.txt"),
    schedules: read("schedules.bell"),
    calendar: read("calendar.bell"),
  )
}

fn report(schools: List(List(String))) -> Nil {
  let count = int.to_string(list.length(schools))
  case list.flatten(schools) {
    [] -> {
      io.println("bell-validator: " <> count <> " schools, no problems")
      halt(0)
    }
    problems -> {
      list.each(problems, io.println_error)
      io.println_error(
        "\nbell-validator: "
        <> int.to_string(list.length(problems))
        <> " problem(s) across "
        <> count
        <> " schools",
      )
      halt(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil

@external(erlang, "bell_validator_ffi", "arguments")
fn arguments() -> List(String)
