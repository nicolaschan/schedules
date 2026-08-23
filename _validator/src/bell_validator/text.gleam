/// Remove every carriage return, the way the client's `remove('\r', str)` does.
///
/// This has to go through Erlang. Gleam's string functions work on grapheme
/// clusters, and Unicode treats CR LF as a single cluster, so `string.replace`
/// and `string.split` cannot see the CR on its own and leave it in place.
/// Most files in this repository use CRLF, so getting this wrong makes every
/// line end in an invisible character.
@external(erlang, "bell_validator_ffi", "strip_carriage_returns")
pub fn strip_carriage_returns(text: String) -> String
