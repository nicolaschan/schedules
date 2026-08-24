import gleam/list
import gleam/string

const separators = "* {}#"

pub fn lex(line: String) -> List(String) {
  let #(last, pieces) =
    line
    |> string.to_graphemes
    |> list.fold(#("", []), fn(state, char) {
      let #(current, pieces) = state
      case string.contains(separators, char) {
        True -> #("", [char, current, ..pieces])
        False -> #(current <> char, pieces)
      }
    })
  [last, ..pieces]
  |> list.reverse
  |> list.filter(fn(piece) { piece != "" })
}

pub fn drop(char: String, tokens: List(String)) -> List(String) {
  list.drop_while(tokens, fn(token) { token == char })
}

pub fn trim(char: String, tokens: List(String)) -> List(String) {
  tokens
  |> drop(char, _)
  |> list.reverse
  |> drop(char, _)
  |> list.reverse
}
