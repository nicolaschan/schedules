import gleam/int
import gleam/list
import gleam/string

/// Parse a run of ASCII digits whose length is between `min` and `max`.
///
/// The formats are written by hand, so leading `+`, whitespace and other
/// things `int.parse` might tolerate elsewhere are rejected here.
pub fn parse(text: String, min min: Int, max max: Int) -> Result(Int, Nil) {
  let length = string.length(text)
  let all_digits =
    text
    |> string.to_graphemes
    |> list.all(string.contains("0123456789", _))
  case length >= min && length <= max && all_digits {
    True -> int.parse(text)
    False -> Error(Nil)
  }
}
