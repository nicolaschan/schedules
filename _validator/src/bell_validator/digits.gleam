import gleam/int
import gleam/list
import gleam/string

/// Stricter than `int.parse`, which accepts a leading `+` and other shapes
/// these hand-written formats must not permit.
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
