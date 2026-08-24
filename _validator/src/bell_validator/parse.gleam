//// The two `.bell` formats, following the client's `ScheduleParser.ts` and
//// `CalendarParser.ts` step for step.

import bell_validator/lexer
import bell_validator/text
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string

pub type ScheduleLine {
  /// `* name # Display`
  Schedule(line: Int, name: Option(String), display: String)
  /// `8:25 {A}`, with `time` as written so the rules can judge it.
  Period(line: Int, time: String, label: String)
  /// A line of only spaces: the client filters empty lines but not these, so
  /// it reaches `head.split(':')` with `head` undefined and throws.
  Spaces(line: Int)
}

pub type CalendarLine {
  /// `* Default Week`, or `*` alone, which makes the client's `tail.reduce()`
  /// throw on an empty array.
  Section(line: Int, name: Option(String))
  /// `Mon schedule-a` or `03/12/2018 holiday # Note`.
  Day(line: Int, key: String, schedule: Option(String), display: String)
}

fn lines(content: String) -> List(#(Int, String)) {
  content
  |> text.strip_carriage_returns
  |> string.split("\n")
  |> list.index_map(fn(line, index) { #(index + 1, line) })
}

fn name_and_display(tokens: List(String)) -> #(Option(String), String) {
  let tokens = lexer.trim(" ", tokens)
  let name = case tokens {
    // `#` is a separator token, so a line starting with one names nothing:
    // the client takes the `#` as the name and throws.
    [] | ["#", ..] -> option.None
    [first, ..] -> option.Some(first)
  }
  let display =
    tokens
    |> list.drop(1)
    |> lexer.trim(" ", _)
    // the '#'
    |> list.drop(1)
    |> lexer.trim(" ", _)
    |> string.concat
  #(name, display)
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

/// The `{binding}` names in a period label, split as `FormatString.ts` does.
pub fn bindings(label: String) -> List(String) {
  label
  |> string.split("{")
  |> list.flat_map(string.split(_, "}"))
  |> list.index_map(fn(piece, index) { #(index, piece) })
  |> list.filter(fn(pair) { int.is_odd(pair.0) })
  |> list.map(fn(pair) { pair.1 })
}
