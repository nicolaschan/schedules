import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string

/// Something wrong with a school's data. `line` is absent for problems about a
/// file as a whole rather than one line of it.
pub type Problem {
  Problem(file: String, line: Option(Int), message: String)
}

pub fn at(file: String, line: Int, message: String) -> Problem {
  Problem(file, Some(line), message)
}

pub fn in_file(file: String, message: String) -> Problem {
  Problem(file, None, message)
}

/// Render as `school/file:line: message`, the shape editors and CI logs can
/// both jump from.
pub fn to_string(school: String, problem: Problem) -> String {
  let where = case problem.line {
    Some(line) -> school <> "/" <> problem.file <> ":" <> int.to_string(line)
    None -> school <> "/" <> problem.file
  }
  where <> ": " <> problem.message
}

/// Order problems the way a reader walks a file: by file, then by line.
pub fn compare(a: Problem, b: Problem) -> order.Order {
  order.break_tie(string.compare(a.file, b.file), case a.line, b.line {
    Some(x), Some(y) -> int.compare(x, y)
    None, Some(_) -> order.Lt
    Some(_), None -> order.Gt
    None, None -> order.Eq
  })
}
