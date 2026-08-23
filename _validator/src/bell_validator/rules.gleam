//// The rules. Each one exists because the bell client does something bad with
//// the data otherwise, and each message says what that is.

import bell_validator/dates
import bell_validator/digits
import bell_validator/parse
import bell_validator/problem.{type Problem}
import bell_validator/text
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/set.{type Set}
import gleam/string

/// The contents of a school's files. `None` means the file is not there.
pub type Data {
  Data(
    source: Option(String),
    meta: Option(String),
    correction: Option(String),
    schedules: Option(String),
    calendar: Option(String),
  )
}

/// Where a school's data comes from, per `source.json`.
type Location {
  Local
  Elsewhere
}

/// What `meta.json` told us. `periods` is `None` when the file was missing or
/// unreadable, so binding checks stay quiet instead of blaming every line.
type Meta {
  Meta(periods: Option(Set(String)), custom: Bool)
}

const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

/// The schedule a line names, if it names one at all.
///
/// A lone `#` means the line carries only a comment. The client reads that "#"
/// as the schedule name and then throws looking it up, so it is the same defect
/// as writing no name, and saying so is more use than reporting a missing
/// schedule called "#".
fn schedule_name(name: Option(String)) -> Option(String) {
  case name {
    Some("#") -> None
    other -> other
  }
}

pub fn check(data: Data) -> List(Problem) {
  let #(location, source_problems) = read_source(data.source)
  let #(meta, meta_problems) = read_meta(data.meta)

  // The client handles `type: custom` schedules in code, not from these files.
  let expects_data = location == Local && !meta.custom
  let defined = case data.schedules {
    Some(content) -> Some(defined_schedules(content))
    None -> None
  }

  list.flatten([
    source_problems,
    meta_problems,
    case expects_data {
      True -> missing_files(data)
      False -> []
    },
    optional(data.correction, correction_rules),
    optional(data.schedules, schedules_rules(_, meta.periods)),
    optional(data.calendar, calendar_rules(_, defined)),
  ])
}

fn optional(content: Option(String), rules: fn(String) -> List(Problem)) {
  case content {
    Some(text) -> rules(text)
    None -> []
  }
}

// --- source.json -------------------------------------------------------------

type Source {
  Source(location: String, url: Option(String), to: Option(String))
}

fn source_decoder() -> decode.Decoder(Source) {
  use location <- decode.field("location", decode.string)
  use url <- decode.optional_field("url", None, decode.optional(decode.string))
  use to <- decode.optional_field("to", None, decode.optional(decode.string))
  decode.success(Source(location, url, to))
}

/// True when the directory holds any school data at all. A directory with none
/// of these files is not a school, so it is left alone rather than reported.
pub fn is_school(data: Data) -> Bool {
  [data.source, data.meta, data.correction, data.schedules, data.calendar]
  |> list.any(fn(file) { file != None })
}

fn read_source(content: Option(String)) -> #(Location, List(Problem)) {
  case content {
    // The server falls back to `_default/source.json`, which is a web source,
    // so a school without one is served from the editor rather than from here.
    None -> #(Elsewhere, [])
    Some(text) ->
      case json.parse(text, source_decoder()) {
        Error(_) -> #(Elsewhere, [
          problem.in_file(
            "source.json",
            "is not valid JSON with a string \"location\"",
          ),
        ])
        Ok(source) ->
          case source.location, source.url, source.to {
            "local", _, _ -> #(Local, [])
            "web", Some(_), _ -> #(Elsewhere, [])
            "web", None, _ -> #(Elsewhere, [
              problem.in_file("source.json", "location \"web\" needs a \"url\""),
            ])
            "redirect", _, Some(_) -> #(Elsewhere, [])
            "redirect", _, None -> #(Elsewhere, [
              problem.in_file("source.json", "location \"redirect\" needs a \"to\""),
            ])
            other, _, _ -> #(Elsewhere, [
              problem.in_file(
                "source.json",
                "unknown location \"" <> other <> "\"; expected local, web or redirect",
              ),
            ])
          }
      }
  }
}

// --- meta.json ---------------------------------------------------------------

type RawMeta {
  RawMeta(name: String, periods: Option(List(String)), kind: Option(String))
}

fn meta_decoder() -> decode.Decoder(RawMeta) {
  use name <- decode.field("name", decode.string)
  use periods <- decode.optional_field(
    "periods",
    None,
    decode.optional(decode.list(decode.string)),
  )
  use kind <- decode.optional_field(
    "type",
    None,
    decode.optional(decode.string),
  )
  decode.success(RawMeta(name, periods, kind))
}

fn read_meta(content: Option(String)) -> #(Meta, List(Problem)) {
  case content {
    None -> #(Meta(None, False), [])
    Some(text) ->
      case json.parse(text, meta_decoder()) {
        Error(_) -> #(Meta(None, False), [
          problem.in_file(
            "meta.json",
            "is not valid JSON with a string \"name\"",
          ),
        ])
        Ok(raw) -> {
          let custom = raw.kind == Some("custom")
          case raw.periods, custom {
            Some(periods), _ -> #(Meta(Some(set.from_list(periods)), custom), [])
            None, True -> #(Meta(None, True), [])
            None, False -> #(Meta(None, False), [
              problem.in_file("meta.json", "has no \"periods\" list"),
            ])
          }
        }
      }
  }
}

// --- presence ----------------------------------------------------------------

fn missing_files(data: Data) -> List(Problem) {
  [
    #("meta.json", data.meta),
    #("correction.txt", data.correction),
    #("schedules.bell", data.schedules),
    #("calendar.bell", data.calendar),
  ]
  |> list.filter(fn(pair) { pair.1 == None })
  |> list.map(fn(pair) {
    problem.in_file(pair.0, "missing; a local school needs it")
  })
}

// --- correction.txt ----------------------------------------------------------

fn correction_rules(content: String) -> List(Problem) {
  let trimmed = string.trim(text.strip_carriage_returns(content))
  let numeric = case string.starts_with(trimmed, "-") {
    True -> string.drop_start(trimmed, 1)
    False -> trimmed
  }
  case digits.parse(numeric, min: 1, max: 20) {
    Ok(_) -> []
    Error(_) -> [
      problem.in_file(
        "correction.txt",
        "should hold a number of milliseconds, but holds \"" <> trimmed <> "\"",
      ),
    ]
  }
}

// --- schedules.bell ----------------------------------------------------------

fn defined_schedules(content: String) -> Set(String) {
  content
  |> parse.schedules
  |> list.filter_map(fn(line) {
    case line {
      parse.Schedule(_, name, _) -> option.to_result(schedule_name(name), Nil)
      _ -> Error(Nil)
    }
  })
  |> set.from_list
}

fn schedules_rules(
  content: String,
  periods: Option(Set(String)),
) -> List(Problem) {
  let lines = parse.schedules(content)
  let file = "schedules.bell"

  let structural =
    list.filter_map(lines, fn(line) {
      case line {
        parse.Spaces(number) ->
          Ok(problem.at(
            file,
            number,
            "line holds only spaces; the client keeps it and then reads it as a period, which throws",
          ))
        parse.Schedule(number, name, _) ->
          case schedule_name(name) {
            None ->
              Ok(problem.at(
                file,
                number,
                "schedule header has no name after the *",
              ))
            Some(_) -> Error(Nil)
          }
        parse.Period(number, time, _) ->
          case valid_time(time) {
            Ok(_) -> Error(Nil)
            Error(why) -> Ok(problem.at(file, number, why))
          }
      }
    })

  list.flatten([
    structural,
    duplicate_schedules(lines, file),
    periods_before_header(lines, file),
    unknown_bindings(lines, periods, file),
  ])
}

fn valid_time(time: String) -> Result(Nil, String) {
  case string.split(time, ":") {
    [hour, minute] ->
      case
        digits.parse(hour, min: 1, max: 2),
        digits.parse(minute, min: 2, max: 2)
      {
        Ok(hour), Ok(minute) ->
          case hour <= 23 && minute <= 59 {
            True -> Ok(Nil)
            False ->
              Error(
                "\"" <> time <> "\" is not a time of day (hour 0-23, minute 0-59)",
              )
          }
        _, _ -> Error("\"" <> time <> "\" is not a H:MM time")
      }
    _ -> Error("line starts with \"" <> time <> "\", which is not a H:MM time")
  }
}

fn duplicate_schedules(
  lines: List(parse.ScheduleLine),
  file: String,
) -> List(Problem) {
  lines
  |> list.filter_map(fn(line) {
    case line {
      parse.Schedule(number, name, _) ->
        schedule_name(name)
        |> option.map(fn(found) { #(number, found) })
        |> option.to_result(Nil)
      _ -> Error(Nil)
    }
  })
  |> list.fold(#(set.new(), []), fn(state, entry) {
    let #(seen, found) = state
    let #(number, name) = entry
    case set.contains(seen, name) {
      True -> #(seen, [
        problem.at(
          file,
          number,
          "a second schedule named \""
            <> name
            <> "\"; the client keeps only this one and the earlier periods are lost",
        ),
        ..found
      ])
      False -> #(set.insert(seen, name), found)
    }
  })
  |> fn(state) { list.reverse(state.1) }
}

fn periods_before_header(
  lines: List(parse.ScheduleLine),
  file: String,
) -> List(Problem) {
  lines
  |> list.take_while(fn(line) {
    case line {
      parse.Schedule(..) -> False
      _ -> True
    }
  })
  |> list.filter_map(fn(line) {
    case line {
      parse.Period(number, _, _) ->
        Ok(problem.at(
          file,
          number,
          "period appears before any \"* name\" header, so it belongs to no schedule and is dropped",
        ))
      _ -> Error(Nil)
    }
  })
}

fn unknown_bindings(
  lines: List(parse.ScheduleLine),
  periods: Option(Set(String)),
  file: String,
) -> List(Problem) {
  case periods {
    None -> []
    Some(known) ->
      lines
      |> list.filter_map(fn(line) {
        case line {
          parse.Period(number, _, label) -> Ok(#(number, parse.bindings(label)))
          _ -> Error(Nil)
        }
      })
      |> list.flat_map(fn(entry) {
        let #(number, used) = entry
        used
        |> list.filter(fn(name) { !set.contains(known, name) })
        |> list.map(fn(name) {
          problem.at(
            file,
            number,
            "{"
              <> name
              <> "} is not in meta.json \"periods\", so it cannot be renamed or hidden in settings",
          )
        })
      })
  }
}

// --- calendar.bell -----------------------------------------------------------

type Section {
  DefaultWeek
  SpecialDays
  Ignored
}

/// A calendar entry together with the section it fell under.
type Entry {
  Entry(line: Int, section: Section, key: String, schedule: Option(String))
}

fn calendar_rules(
  content: String,
  defined: Option(Set(String)),
) -> List(Problem) {
  let lines = parse.calendar(content)
  let entries = assign_sections(lines)
  let file = "calendar.bell"

  list.flatten([
    section_rules(lines, file),
    unnamed_rules(entries, file),
    week_rules(entries, file),
    special_rules(entries, file),
    dangling_rules(entries, defined, file),
  ])
}

/// Pair every entry with the section it fell under, the way the client's
/// running `section` variable does.
fn assign_sections(lines: List(parse.CalendarLine)) -> List(Entry) {
  lines
  |> list.fold(#(Ignored, []), fn(state, line) {
    let #(current, found) = state
    case line {
      parse.Section(_, Some("Default Week")) -> #(DefaultWeek, found)
      parse.Section(_, Some("Special Days")) -> #(SpecialDays, found)
      parse.Section(..) -> #(Ignored, found)
      parse.Day(number, key, schedule, _) -> #(current, [
        Entry(number, current, key, schedule),
        ..found
      ])
    }
  })
  |> fn(state) { list.reverse(state.1) }
}

fn section_rules(
  lines: List(parse.CalendarLine),
  file: String,
) -> List(Problem) {
  list.filter_map(lines, fn(line) {
    case line {
      parse.Section(number, None) ->
        Ok(problem.at(
          file,
          number,
          "section header has no name after the *; the client throws reducing an empty list",
        ))
      parse.Section(number, Some(name)) ->
        case name == "Default Week" || name == "Special Days" {
          True -> Error(Nil)
          False ->
            Ok(problem.at(
              file,
              number,
              "unknown section \""
                <> name
                <> "\"; every entry under it is ignored. Expected \"Default Week\" or \"Special Days\"",
            ))
        }
      parse.Day(..) -> Error(Nil)
    }
  })
}

fn unnamed_rules(entries: List(Entry), file: String) -> List(Problem) {
  list.filter_map(entries, fn(entry) {
    case schedule_name(entry.schedule) {
      None ->
        Ok(problem.at(
          file,
          entry.line,
          "entry names no schedule; the client reads the \"#\" as the schedule name and throws looking it up",
        ))
      Some(_) -> Error(Nil)
    }
  })
}

fn entries_in(entries: List(Entry), wanted: Section) -> List(Entry) {
  list.filter(entries, fn(entry) { entry.section == wanted })
}

fn week_rules(entries: List(Entry), file: String) -> List(Problem) {
  let days = entries_in(entries, DefaultWeek)

  let listed =
    days
    |> list.fold(#(set.new(), []), fn(state, day) {
      let #(seen, found) = state
      case list.contains(weekdays, day.key) {
        False -> #(seen, [
          problem.at(
            file,
            day.line,
            "\"" <> day.key <> "\" is not a weekday, so this line has no effect",
          ),
          ..found
        ])
        True ->
          case set.contains(seen, day.key) {
            True -> #(seen, [
              problem.at(
                file,
                day.line,
                "a second entry for " <> day.key <> "; only this one is used",
              ),
              ..found
            ])
            False -> #(set.insert(seen, day.key), found)
          }
      }
    })

  let covered = days |> list.map(fn(day) { day.key }) |> set.from_list
  let missing =
    weekdays
    |> list.filter(fn(day) { !set.contains(covered, day) })
    |> list.map(fn(day) {
      problem.in_file(
        file,
        "Default Week has no entry for "
          <> day
          <> "; every "
          <> day
          <> " without a special day throws",
      )
    })

  list.append(list.reverse(listed.1), missing)
}

fn special_rules(entries: List(Entry), file: String) -> List(Problem) {
  entries
  |> entries_in(SpecialDays)
  |> list.fold(#(set.new(), []), fn(state, entry) {
    let #(seen, found) = state
    let duplicate = case set.contains(seen, entry.key) {
      True -> [
        problem.at(
          file,
          entry.line,
          "a second entry for "
            <> entry.key
            <> "; only the last one for a date is used",
        ),
      ]
      False -> []
    }
    let malformed = case dates.parse_key(entry.key) {
      Error(_) -> [
        problem.at(
          file,
          entry.line,
          "\""
            <> entry.key
            <> "\" is not a real MM/DD/YYYY date or MM/DD/YYYY-MM/DD/YYYY range",
        ),
      ]
      Ok(dates.Single(_)) -> []
      Ok(dates.Range(from, to)) ->
        case dates.compare(from, to) {
          order.Gt -> [
            problem.at(
              file,
              entry.line,
              "range \""
                <> entry.key
                <> "\" ends before it starts; the client steps forward from the start looking for the end and never stops",
            ),
          ]
          _ -> []
        }
    }
    #(set.insert(seen, entry.key), list.flatten([found, duplicate, malformed]))
  })
  |> fn(state) { state.1 }
}

fn dangling_rules(
  entries: List(Entry),
  defined: Option(Set(String)),
  file: String,
) -> List(Problem) {
  case defined {
    None -> []
    Some(known) ->
      entries
      |> list.filter(fn(entry) { entry.section != Ignored })
      |> list.filter_map(fn(entry) {
        case schedule_name(entry.schedule) {
          Some(name) ->
            case set.contains(known, name) {
              True -> Error(Nil)
              False ->
                Ok(problem.at(
                  file,
                  entry.line,
                  "no schedule named \""
                    <> name
                    <> "\" in schedules.bell; the client throws on this date",
                ))
            }
          None -> Error(Nil)
        }
      })
  }
}
