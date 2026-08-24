import gleam/list
import gleam/string

/// Remove every carriage return, as the client's `remove('\r', str)` does.
///
/// Codepoint at a time: Gleam's string functions are grapheme-based and
/// Unicode treats CR LF as one cluster, so `string.replace` cannot see the CR
/// at all and leaves it in place.
pub fn strip_carriage_returns(text: String) -> String {
  text
  |> string.to_utf_codepoints
  |> list.filter(fn(point) { string.utf_codepoint_to_int(point) != 13 })
  |> string.from_utf_codepoints
}
