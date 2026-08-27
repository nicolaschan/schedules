import bell_validator/problem
import gleam/int
import gleam/list
import gleam/string

pub type Source {
  Source(name: String, problems: List(String))
}

/// Why a run failed. Naming these keeps exit codes out of the report.
pub type Exit {
  Problems
  Unreadable
}

pub type Outcome {
  Passed(message: String)
  Failed(message: String, exit: Exit)
}

pub fn unreadable(schools: String, error: String) -> Outcome {
  Failed(says("cannot read " <> schools <> ": " <> error), Unreadable)
}

pub fn of(sources: List(Source)) -> Outcome {
  let count = int.to_string(list.length(sources))
  case list.flat_map(sources, lines) {
    [] -> Passed(says(count <> " sources, no problems"))
    problems ->
      Failed(
        string.join(problems, "\n")
          <> "\n\n"
          <> says(
          int.to_string(list.length(problems))
          <> " problem(s) across "
          <> count
          <> " sources",
        ),
        Problems,
      )
  }
}

fn lines(source: Source) -> List(String) {
  list.map(source.problems, problem.to_string(source.name, _))
}

fn says(message: String) -> String {
  "bell-validator: " <> message
}
