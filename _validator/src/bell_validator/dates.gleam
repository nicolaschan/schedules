//// Date keys from the `Special Days` section.
////
//// The client stores special days in a map keyed by the literal text, and
//// expands `A-B` ranges by stepping a `Date` forward until its formatted form
//// equals `B` exactly. So a key that is not zero-padded `MM/DD/YYYY`, names a
//// day that does not exist, or ends before it starts, is never reached by that
//// loop and the browser hangs.

import bell_validator/digits
import gleam/int
import gleam/order.{type Order}
import gleam/result
import gleam/string

pub type Date {
  Date(year: Int, month: Int, day: Int)
}

pub type DateKey {
  Single(Date)
  Range(from: Date, to: Date)
}

pub fn is_leap_year(year: Int) -> Bool {
  { year % 4 == 0 && year % 100 != 0 } || year % 400 == 0
}

pub fn days_in_month(month month: Int, year year: Int) -> Int {
  case month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
    4 | 6 | 9 | 11 -> 30
    2 ->
      case is_leap_year(year) {
        True -> 29
        False -> 28
      }
    _ -> 0
  }
}

pub fn compare(a: Date, b: Date) -> Order {
  order.break_tie(
    order.break_tie(int.compare(a.year, b.year), int.compare(a.month, b.month)),
    int.compare(a.day, b.day),
  )
}

/// Parse a zero-padded `MM/DD/YYYY` that names a day which actually exists.
pub fn parse_date(text: String) -> Result(Date, Nil) {
  case string.split(text, "/") {
    [month, day, year] -> {
      use month <- result.try(digits.parse(month, min: 2, max: 2))
      use day <- result.try(digits.parse(day, min: 2, max: 2))
      use year <- result.try(digits.parse(year, min: 4, max: 4))
      case month >= 1 && month <= 12 && day >= 1 {
        True ->
          case day <= days_in_month(month: month, year: year) {
            True -> Ok(Date(year, month, day))
            False -> Error(Nil)
          }
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
