//// Turns the two `.bell` file formats into data, following the client's
//// `ScheduleParser.ts` and `CalendarParser.ts` step for step.
////
//// Anything the client would read as absent is `None` here rather than a
//// placeholder string, so the rules can tell "no name" apart from a name
//// that happens to look odd.

import bell_validator/lexer
import bell_validator/text
import gleam/list
import gleam/option.{type Option}
import gleam/string

/// One meaningful line of a `schedules.bell` file.
pub type ScheduleLine {
  /// `* name # Display`. `name` is `None` when nothing followed the `*`.
  Schedule(line: Int, name: Option(String), display: String)
  /// `8:25 {A}`. `time` is kept as written so the rules can judge it.
  Period(line: Int, time: String, label: String)
  /// A line of only spaces. The client filters empty lines but not these, so
  /// it reaches `head.split(':')` with `head` undefined and throws.
  Spaces(line: Int)
}

/// One meaningful line of a `calendar.bell` file.
pub type CalendarLine {
  /// `* Default Week`. `name` is `None` when nothing followed the `*`, which
  /// makes the client's `tail.reduce()` throw on an empty array.
  Section(line: Int, name: Option(String))
  /// `Mon schedule-a` or `03/12/2018 holiday # Note`.
  Day(line: Int, key: String, schedule: Option(String), display: String)
}

/// Split into lines the way the client does, keeping 1-based line numbers.
/// The client strips every `\r` in the file, not just the ones before `\n`.
fn lines(content: String) -> List(#(Int, String)) {
  content
  |> text.strip_carriage_returns
  |> string.split("\n")
  |> list.index_map(fn(line, index) { #(index + 1, line) })
}

/// Read the trailing `name # Display` shape shared by both formats, returning
/// the name and the display text.
fn name_and_display(tokens: List(String)) -> #(Option(String), String) {
  let tokens = lexer.trim(" ", tokens)
  let name = tokens |> list.first |> option.from_result
  let display =
    tokens
    |> lexer.rest
    |> lexer.trim(" ", _)
    // the '#'
    |> lexer.rest
    |> lexer.trim(" ", _)
    |> lexer.concat
  #(name, display)
}

/// Parse a `schedules.bell` file.
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
        Period(number, time, lexer.concat(lexer.trim(" ", tokens)))
    }
  })
}

/// Parse a `calendar.bell` file.
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
          named -> option.Some(lexer.concat(named))
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

/// The `{binding}` names in a period label, following `FormatString.ts`: the
/// label is split on `{` and then on `}`, and the odd-indexed pieces are the
/// names looked up in the user's bindings.
pub fn bindings(label: String) -> List(String) {
  label
  |> string.split("{")
  |> list.map(string.split(_, "}"))
  |> list.flatten
  |> list.index_map(fn(piece, index) { #(index, piece) })
  |> list.filter(fn(pair) { pair.0 % 2 == 1 })
  |> list.map(fn(pair) { pair.1 })
}
