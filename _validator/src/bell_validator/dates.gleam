//// Date keys from the `Special Days` section.
////
//// The client stores special days in a map keyed by the literal text, and
//// expands `A-B` ranges by stepping a date forward until its formatted form
//// equals `B` exactly. So a key that is not zero-padded `MM/DD/YYYY`, names a
//// day that does not exist, or ends before it starts, is never reached by that
//// loop and the browser hangs.
////
//// Only the parsing belongs here. Whether a date exists, and how two of them
//// compare, come from `gleam/time/calendar`.

import bell_validator/digits
import gleam/result
import gleam/string
import gleam/time/calendar.{type Date, Date}

pub type DateKey {
  Single(Date)
  Range(from: Date, to: Date)
}

/// Parse a zero-padded `MM/DD/YYYY` that names a day which actually exists.
///
/// The padding is not fussiness: the client looks days up by comparing against
/// its own zero-padded formatting, so `3/12/2018` never matches anything.
pub fn parse_date(text: String) -> Result(Date, Nil) {
  case string.split(text, "/") {
    [month, day, year] -> {
      use month <- result.try(digits.parse(month, min: 2, max: 2))
      use day <- result.try(digits.parse(day, min: 2, max: 2))
      use year <- result.try(digits.parse(year, min: 4, max: 4))
      use month <- result.try(calendar.month_from_int(month))
      let date = Date(year:, month:, day:)
      case calendar.is_valid_date(date) {
        True -> Ok(date)
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

pub fn parse_key(text: String) -> Result(DateKey, Nil) {
  case string.split(text, "-") {
    [single] -> parse_date(single) |> result.map(Single)
    [from, to] -> {
      use from <- result.try(parse_date(from))
      use to <- result.try(parse_date(to))
      Ok(Range(from, to))
    }
    _ -> Error(Nil)
  }
}
