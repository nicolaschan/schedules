import gleam/int

pub fn at(file: String, line: Int, message: String) -> String {
  file <> ":" <> int.to_string(line) <> ": " <> message
}

pub fn in_file(file: String, message: String) -> String {
  file <> ": " <> message
}

pub fn to_string(source: String, problem: String) -> String {
  source <> "/" <> problem
}
