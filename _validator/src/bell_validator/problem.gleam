import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string

pub type Problem {
  Problem(file: String, line: Option(Int), message: String)
}

pub fn at(file: String, line: Int, message: String) -> Problem {
  Problem(file, Some(line), message)
}

pub fn in_file(file: String, message: String) -> Problem {
  Problem(file, None, message)
}

/// `school/file:line: message`, so editors and CI logs can jump to it.
pub fn to_string(school: String, problem: Problem) -> String {
  let line = case problem.line {
    Some(line) -> ":" <> int.to_string(line)
    None -> ""
  }
  school <> "/" <> problem.file <> line <> ": " <> problem.message
}

pub fn compare(a: Problem, b: Problem) -> order.Order {
  order.break_tie(string.compare(a.file, b.file), case a.line, b.line {
    Some(x), Some(y) -> int.compare(x, y)
    None, Some(_) -> order.Lt
    Some(_), None -> order.Gt
    None, None -> order.Eq
  })
}
