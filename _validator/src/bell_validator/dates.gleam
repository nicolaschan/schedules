import bell_validator/digits
import gleam/order
import gleam/result
import gleam/string
import gleam/time/calendar.{type Date, Date}

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

pub fn parse_key(text: String) -> Result(#(Date, Date), Nil) {
  case string.split(text, "-") {
    [single] -> parse_date(single) |> result.map(fn(date) { #(date, date) })
    [from, to] -> {
      use from <- result.try(parse_date(from))
      use to <- result.try(parse_date(to))
      Ok(#(from, to))
    }
    _ -> Error(Nil)
  }
}

pub fn ends_before_start(days: #(Date, Date)) -> Bool {
  calendar.naive_date_compare(days.0, days.1) == order.Gt
}
