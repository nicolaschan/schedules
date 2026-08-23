//// A port of the bell client's `src/Lexer.ts`.
////
//// The validator has to agree with the consumer about how a line splits into
//// tokens, otherwise it would approve files the app then reads differently.
//// So this mirrors the client's lexer rather than approximating it.

import gleam/list
import gleam/string

const separators = ["*", " ", "{", "}", "#"]

/// Split a line on the separator characters, keeping the separators as tokens
/// of their own and discarding empty pieces.
pub fn lex(line: String) -> List(String) {
  line
  |> string.to_graphemes
  |> list.fold([""], fn(pieces, char) {
    case list.contains(separators, char), pieces {
      True, _ -> ["", char, ..pieces]
      False, [current, ..rest] -> [current <> char, ..rest]
      False, [] -> [char]
    }
  })
  |> list.reverse
  |> list.filter(fn(piece) { piece != "" })
}

/// Drop leading tokens equal to `char`.
pub fn drop(char: String, tokens: List(String)) -> List(String) {
  case tokens {
    [first, ..rest] if first == char -> drop(char, rest)
    _ -> tokens
  }
}

/// Drop trailing tokens equal to `char`.
pub fn drop_end(char: String, tokens: List(String)) -> List(String) {
  tokens
  |> list.reverse
  |> drop(char, _)
  |> list.reverse
}

/// Drop leading and trailing tokens equal to `char`.
pub fn trim(char: String, tokens: List(String)) -> List(String) {
  tokens
  |> drop(char, _)
  |> drop_end(char, _)
}

/// Rejoin tokens into the string they came from.
pub fn concat(tokens: List(String)) -> String {
  string.concat(tokens)
}

/// Drop the first token, mirroring JavaScript's `Array.slice(1)` on an empty
/// array yielding an empty array rather than an error.
pub fn rest(tokens: List(String)) -> List(String) {
  case tokens {
    [_, ..tail] -> tail
    [] -> []
  }
}
