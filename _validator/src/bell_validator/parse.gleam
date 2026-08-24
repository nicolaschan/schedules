import bell_validator/lexer
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string

pub type ScheduleLine {
  Schedule(line: Int, name: Option(String), display: String)
  Period(line: Int, time: String, label: String)
  Spaces(line: Int)
}

pub type CalendarLine {
  Section(line: Int, name: Option(String))
  Day(line: Int, key: String, schedule: Option(String), display: String)
}

/// Codepoints, not `string.replace`: Gleam's string functions work on grapheme
/// clusters and Unicode makes CR LF a single one, so a lone `\r` never matches.
fn lines(content: String) -> List(#(Int, String)) {
  content
  |> string.to_utf_codepoints
  |> list.filter(fn(point) { string.utf_codepoint_to_int(point) != 13 })
  |> string.from_utf_codepoints
  |> string.split("\n")
  |> list.index_map(fn(line, index) { #(index + 1, line) })
}

fn name_and_display(tokens: List(String)) -> #(Option(String), String) {
  let tokens = lexer.trim(" ", tokens)
  let after_name = drop_token(tokens)
  let after_hash = drop_token(after_name)
  let name = case tokens {
    [] | ["#", ..] -> option.None
    [first, ..] -> option.Some(first)
  }
  #(name, string.concat(after_hash))
}

fn drop_token(tokens: List(String)) -> List(String) {
  tokens |> list.drop(1) |> lexer.trim(" ", _)
}

pub fn schedules(content: String) -> List(ScheduleLine) {
  content
  |> lines
  |> list.filter(fn(pair) { pair.1 != "" })
  |> list.map(fn(pair) {
    let #(number, line) = pair
    case lexer.drop(" ", lexer.lex(line)) {
      [] -> Spaces(number)
      ["*", ..tokens] -> {
        let #(name, display) = name_and_display(tokens)
        Schedule(number, name, display)
      }
      [time, ..tokens] ->
        Period(number, time, string.concat(lexer.trim(" ", tokens)))
    }
  })
}

pub fn calendar(content: String) -> List(CalendarLine) {
  content
  |> lines
  |> list.filter_map(fn(pair) {
    let #(number, line) = pair
    case lexer.drop(" ", lexer.lex(line)) {
      [] -> Error(Nil)
      ["*", ..tokens] -> {
        let name = case lexer.trim(" ", tokens) {
          [] -> option.None
          named -> option.Some(string.concat(named))
        }
        Ok(Section(number, name))
      }
      [key, ..tokens] -> {
        let #(schedule, display) = name_and_display(tokens)
        Ok(Day(number, key, schedule, display))
      }
    }
  })
}

pub fn bindings(label: String) -> List(String) {
  label
  |> string.split("{")
  |> list.flat_map(string.split(_, "}"))
  |> list.index_map(fn(piece, index) { #(index, piece) })
  |> list.filter(fn(pair) { int.is_odd(pair.0) })
  |> list.map(fn(pair) { pair.1 })
}
