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
    Ok(entries) -> {
      let schools = schools(root, entries)
      report(list.length(schools), list.flat_map(schools, problems))
    }
  }
}

/// Names starting with `_` hold data shared between schools, not a school.
fn schools(root: String, entries: List(String)) -> List(#(String, rules.Data)) {
  entries
  |> list.filter(fn(name) { !string.starts_with(name, "_") })
  |> list.sort(string.compare)
  |> list.map(fn(name) { #(name, load(root, name)) })
  |> list.filter(fn(school) { rules.is_school(school.1) })
}

/// Reads through symlinks, as the bell server does.
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

fn problems(school: #(String, rules.Data)) -> List(String) {
  let #(name, data) = school
  data
  |> rules.check
  |> list.sort(problem.compare)
  |> list.map(problem.to_string(name, _))
}

fn report(count: Int, problems: List(String)) -> Nil {
  let schools = int.to_string(count)
  case problems {
    [] -> {
      io.println("bell-validator: " <> schools <> " schools, no problems")
      halt(0)
    }
    _ -> {
      list.each(problems, io.println_error)
      io.println_error(
        "\nbell-validator: "
        <> int.to_string(list.length(problems))
        <> " problem(s) across "
        <> schools
        <> " schools",
      )
      halt(1)
    }
  }
}

@external(erlang, "bell_validator_ffi", "halt")
fn halt(code: Int) -> Nil

@external(erlang, "bell_validator_ffi", "arguments")
fn arguments() -> List(String)
