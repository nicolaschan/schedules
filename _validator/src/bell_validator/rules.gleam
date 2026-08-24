import bell_validator/dates
import bell_validator/digits
import bell_validator/parse
import bell_validator/problem
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import gleam/string

pub type Data {
  Data(
    source: Option(String),
    meta: Option(String),
    correction: Option(String),
    schedules: Option(String),
    calendar: Option(String),
  )
}

type Meta {
  Meta(periods: Option(Set(String)), custom: Bool)
}

type Section {
  DefaultWeek
  SpecialDays
  Ignored
}

const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

/// Grouped by file in name order, whole-file problems before line problems.
pub fn check(data: Data) -> List(String) {
  let #(local, source_problems) =
    read("source.json", data.source, False, False, source_rules)
  let #(meta, meta_problems) =
    read("meta.json", data.meta, local, Meta(None, False), meta_rules)
  let required = local && !meta.custom
  let #(defined, schedules_problems) =
    read("schedules.bell", data.schedules, required, None, fn(text) {
      schedules_rules(text, meta.periods)
    })
  let #(_, calendar_problems) =
    read("calendar.bell", data.calendar, required, Nil, fn(text) {
      #(Nil, calendar_rules(text, defined))
    })
  let #(_, correction_problems) =
    read("correction.txt", data.correction, required, Nil, fn(text) {
      #(Nil, correction_rules(text))
    })

  list.flatten([
    calendar_problems,
    correction_problems,
    meta_problems,
    schedules_problems,
    source_problems,
  ])
}

fn read(
  file: String,
  content: Option(String),
  required: Bool,
  absent: a,
  rules: fn(String) -> #(a, List(String)),
) -> #(a, List(String)) {
  case content, required {
    Some(text), _ -> rules(text)
    None, True -> #(absent, [
      problem.in_file(file, "missing; a local school needs it"),
    ])
    None, False -> #(absent, [])
  }
}

type Source {
  Source(location: String, url: Option(String), to: Option(String))
}

fn source_decoder() -> decode.Decoder(Source) {
  use location <- decode.field("location", decode.string)
  use url <- decode.optional_field("url", None, decode.optional(decode.string))
  use to <- decode.optional_field("to", None, decode.optional(decode.string))
  decode.success(Source(location, url, to))
}

fn source_rules(text: String) -> #(Bool, List(String)) {
  case json.parse(text, source_decoder()) {
    Error(_) -> #(False, [
      problem.in_file(
        "source.json",
        "is not valid JSON with a string \"location\"",
      ),
    ])
    Ok(Source("local", _, _)) -> #(True, [])
    Ok(source) -> #(False, source_problems(source))
  }
}

fn source_problems(source: Source) -> List(String) {
  case source.location, source.url, source.to {
    "web", Some(_), _ -> []
    "web", None, _ -> [
      problem.in_file("source.json", "location \"web\" needs a \"url\""),
    ]
    "redirect", _, Some(_) -> []
    "redirect", _, None -> [
      problem.in_file("source.json", "location \"redirect\" needs a \"to\""),
    ]
    other, _, _ -> [
      problem.in_file(
        "source.json",
        "unknown location \"" <> other <> "\"; expected local, web or redirect",
      ),
    ]
  }
}

fn meta_decoder() -> decode.Decoder(Meta) {
  use _ <- decode.field("name", decode.string)
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
  decode.success(Meta(
    option.map(periods, set.from_list),
    kind == Some("custom"),
  ))
}

fn meta_rules(text: String) -> #(Meta, List(String)) {
  case json.parse(text, meta_decoder()) {
    Error(_) -> #(Meta(None, False), [
      problem.in_file("meta.json", "is not valid JSON with a string \"name\""),
    ])
    Ok(meta) ->
      case meta.periods, meta.custom {
        None, False -> #(meta, [
          problem.in_file("meta.json", "has no \"periods\" list"),
        ])
        _, _ -> #(meta, [])
      }
  }
}

fn correction_rules(content: String) -> List(String) {
  let trimmed = string.trim(content)
  case digits.parse(string.remove_prefix(trimmed, "-"), min: 1, max: 20) {
    Ok(_) -> []
    Error(_) -> [
      problem.in_file(
        "correction.txt",
        "should hold a number of milliseconds, not \"" <> trimmed <> "\"",
      ),
    ]
  }
}

fn schedules_rules(
  text: String,
  periods: Option(Set(String)),
) -> #(Option(Set(String)), List(String)) {
  let file = "schedules.bell"
  let #(named, _, found) =
    list.fold(parse.schedules(text), #(set.new(), False, []), fn(state, line) {
      let #(named, headed, found) = state
      let #(named, headed, messages) = case line {
        parse.Spaces(_) -> #(named, headed, [
          "line holds only spaces; the client keeps it, reads it as a period, and throws",
        ])
        parse.Schedule(_, None, _) -> #(named, True, [
          "schedule header has no name after the *",
        ])
        parse.Schedule(_, Some(name), _) ->
          case set.contains(named, name) {
            True -> #(named, True, [
              "a second schedule named \""
              <> name
              <> "\"; the client keeps only this one and the earlier periods are lost",
            ])
            False -> #(set.insert(named, name), True, [])
          }
        parse.Period(_, time, label) -> #(
          named,
          headed,
          list.flatten([
            time_problems(time),
            case headed {
              True -> []
              False -> [
                "period appears before any \"* name\" header, so it belongs to no schedule and is dropped",
              ]
            },
            unknown_bindings(label, periods),
          ]),
        )
      }
      #(named, headed, [
        list.map(messages, problem.at(file, line.line, _)),
        ..found
      ])
    })
  #(Some(named), found |> list.reverse |> list.flatten)
}

fn time_problems(time: String) -> List(String) {
  case string.split(time, ":") {
    [hour, minute] ->
      case
        digits.parse(hour, min: 1, max: 2),
        digits.parse(minute, min: 2, max: 2)
      {
        Ok(hour), Ok(minute) ->
          case hour < 24 && minute < 60 {
            True -> []
            False -> [
              "\"" <> time <> "\" is not a time of day (hour 0-23, minute 0-59)",
            ]
          }
        _, _ -> ["\"" <> time <> "\" is not a H:MM time"]
      }
    _ -> ["line starts with \"" <> time <> "\", not a H:MM time"]
  }
}

fn unknown_bindings(
  label: String,
  periods: Option(Set(String)),
) -> List(String) {
  case periods {
    None -> []
    Some(known) ->
      parse.bindings(label)
      |> list.filter(fn(name) { !set.contains(known, name) })
      |> list.map(fn(name) {
        "{"
        <> name
        <> "} is not in meta.json \"periods\", so it cannot be renamed or hidden in settings"
      })
  }
}

fn calendar_rules(
  content: String,
  defined: Option(Set(String)),
) -> List(String) {
  let file = "calendar.bell"
  let #(_, seen, found) =
    list.fold(
      parse.calendar(content),
      #(Ignored, set.new(), []),
      fn(state, line) {
        let #(section, seen, found) = state
        let #(section, seen, messages) = case line {
          parse.Section(_, Some("Default Week")) -> #(DefaultWeek, seen, [])
          parse.Section(_, Some("Special Days")) -> #(SpecialDays, seen, [])
          parse.Section(_, None) -> #(Ignored, seen, [
            "section header has no name after the *; the client throws reducing an empty list",
          ])
          parse.Section(_, Some(name)) -> #(Ignored, seen, [
            "unknown section \""
            <> name
            <> "\"; every entry under it is ignored. Expected \"Default Week\" or \"Special Days\"",
          ])
          parse.Day(_, key, schedule, _) -> #(
            section,
            set.insert(seen, #(section, key)),
            list.flatten([
              case schedule {
                None -> [
                  "entry names no schedule; the client reads the \"#\" as the name and throws looking it up",
                ]
                Some(_) -> []
              },
              day_in_section(section, key, seen),
              dangling(section, schedule, defined),
            ]),
          )
        }
        #(section, seen, [
          list.map(messages, problem.at(file, line.line, _)),
          ..found
        ])
      },
    )

  let uncovered =
    weekdays
    |> list.filter(fn(day) { !set.contains(seen, #(DefaultWeek, day)) })
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

  list.flatten([uncovered, found |> list.reverse |> list.flatten])
}

fn day_in_section(
  section: Section,
  key: String,
  seen: Set(#(Section, String)),
) -> List(String) {
  let repeat = case set.contains(seen, #(section, key)) {
    True -> ["a second entry for " <> key <> "; only the last one is used"]
    False -> []
  }
  case section {
    Ignored -> []
    DefaultWeek ->
      case list.contains(weekdays, key) {
        False -> [
          "\"" <> key <> "\" is not a weekday, so this line has no effect",
        ]
        True -> repeat
      }
    SpecialDays -> list.append(repeat, key_problems(key))
  }
}

fn key_problems(key: String) -> List(String) {
  case dates.parse_key(key) {
    Error(_) -> [
      "\""
      <> key
      <> "\" is not a real MM/DD/YYYY date or MM/DD/YYYY-MM/DD/YYYY range",
    ]
    Ok(days) ->
      case dates.ends_before_start(days) {
        True -> [
          "range \""
          <> key
          <> "\" ends before it starts; the client steps forward from the start looking for the end and never stops",
        ]
        False -> []
      }
  }
}

fn dangling(
  section: Section,
  schedule: Option(String),
  defined: Option(Set(String)),
) -> List(String) {
  case section, schedule, defined {
    Ignored, _, _ | _, None, _ | _, _, None -> []
    _, Some(name), Some(known) ->
      case set.contains(known, name) {
        True -> []
        False -> [
          "no schedule named \""
          <> name
          <> "\" in schedules.bell; the client throws on this date",
        ]
      }
  }
}
