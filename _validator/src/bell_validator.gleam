//// Checks every school directory in the schedules repository against the
//// things the bell client cannot cope with.
////
//// Usage: `bell_validator [path-to-repository]`, defaulting to the working
//// directory. Exits 0 when clean, 1 when something is wrong, 2 when the
//// repository itself could not be read.

import bell_validator/problem
import bell_validator/rules
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import simplifile

pub fn main() -> Nil {
  let root = case arguments() {
    [path, ..] -> path
    [] -> "."
  }
  case schools(root) {
    Error(message) -> {
      io.println_error("bell-validator: " <> message)
      halt(2)
    }
    Ok(names) -> {
      let found = list.map(names, fn(name) { #(name, load(root, name)) })
      let schools = list.filter(found, fn(pair) { rules.is_school(pair.1) })
      report(
        list.map(schools, fn(pair) { pair.0 }),
        list.flat_map(schools, report_for),
      )
    }
  }
}

/// Directories that hold a school. Names starting with `_` are shared data
/// rather than a school, matching how the bell server treats them, and dot
/// directories are not ours.
fn schools(root: String) -> Result(List(String), String) {
  simplifile.read_directory(root)
  |> result.map_error(fn(error) {
    "cannot read " <> root <> ": " <> string.inspect(error)
  })
  |> result.map(fn(entries) {
    entries
    |> list.filter(fn(name) {
      !string.starts_with(name, ".") && !string.starts_with(name, "_")
    })
    |> list.filter(fn(name) {
      simplifile.is_directory(root <> "/" <> name) == Ok(True)
    })
    |> list.sort(string.compare)
  })
}

fn load(root: String, name: String) -> rules.Data {
  let read = fn(file) { read_file(root <> "/" <> name <> "/" <> file) }
  rules.Data(
    source: read("source.json"),
    meta: read("meta.json"),
    correction: read("correction.txt"),
    schedules: read("schedules.bell"),
    calendar: read("calendar.bell"),
  )
}

fn report_for(school: #(String, rules.Data)) -> List(String) {
  let #(name, data) = school
  data
  |> rules.check
  |> list.sort(problem.compare)
  |> list.map(problem.to_string(name, _))
}

/// Reads through symlinks, as the bell server does.
fn read_file(path: String) -> Option(String) {
  simplifile.read(path)
  |> option.from_result
}

fn report(names: List(String), problems: List(String)) -> Nil {
  let schools = int.to_string(list.length(names))
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
