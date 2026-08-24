import bell_validator/dates
import bell_validator/lexer
import bell_validator/parse
import bell_validator/problem
import bell_validator/rules
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/time/calendar
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// --- helpers -----------------------------------------------------------------

const source = "{\"location\": \"local\"}"

const meta = "{\"name\": \"Test\", \"periods\": [\"A\"]}"

const schedules = "* weekend # Weekend
* day # Day
8:00 {A}
15:00 Free
"

const calendar = "* Default Week
Sun weekend
Mon day
Tue day
Wed day
Thu day
Fri day
Sat weekend

* Special Days
01/01/2020 weekend # New Year
"

fn school() -> rules.Data {
  rules.Data(
    source: Some(source),
    meta: Some(meta),
    correction: Some("0"),
    schedules: Some(schedules),
    calendar: Some(calendar),
  )
}

fn messages(data: rules.Data) -> List(String) {
  data
  |> rules.check
  |> list.map(problem.to_string("test", _))
}

/// Assert that the data is rejected, and specifically for `reason`.
fn rejected_for(data: rules.Data, reason: String) -> Nil {
  let found = messages(data)
  assert list.any(found, string.contains(_, reason))
}

fn accepted(data: rules.Data) -> Nil {
  assert messages(data) == []
}

// --- the lexer ---------------------------------------------------------------

pub fn lex_keeps_separators_as_tokens_test() {
  assert lexer.lex("* weekend # Weekend")
    == ["*", " ", "weekend", " ", "#", " ", "Weekend"]
}

pub fn lex_drops_empty_pieces_test() {
  assert lexer.lex("{A}") == ["{", "A", "}"]
}

pub fn trim_removes_only_the_given_token_test() {
  assert lexer.trim(" ", [" ", "a", " ", "b", " "]) == ["a", " ", "b"]
}

// --- carriage returns --------------------------------------------------------

/// Most files in this repository use CRLF. Gleam treats CR LF as one grapheme
/// cluster, so `string.replace` and `string.split` cannot strip the CR and every
/// name would silently end in an invisible character.
pub fn crlf_does_not_leak_into_names_test() {
  assert parse.calendar("* Default Week\r\nSun weekend\r\n")
    == [
      parse.Section(1, Some("Default Week")),
      parse.Day(2, "Sun", Some("weekend"), ""),
    ]
}

pub fn a_crlf_school_is_accepted_test() {
  let crlf = fn(text) { string.replace(text, "\n", "\r\n") }
  accepted(
    rules.Data(
      ..school(),
      schedules: Some(crlf(schedules)),
      calendar: Some(crlf(calendar)),
    ),
  )
}

// --- parsing -----------------------------------------------------------------

pub fn schedule_header_display_is_read_test() {
  assert parse.schedules("* day # Big Day\n")
    == [parse.Schedule(1, Some("day"), "Big Day")]
}

pub fn period_label_is_kept_whole_test() {
  assert parse.schedules("8:00 Passing to {Period 1}\n")
    == [parse.Period(1, "8:00", "Passing to {Period 1}")]
}

pub fn bindings_are_read_like_the_client_test() {
  assert parse.bindings("Passing to {Period 1}") == ["Period 1"]
  assert parse.bindings("{A} and {B}") == ["A", "B"]
  assert parse.bindings("Brunch") == []
}

// --- dates -------------------------------------------------------------------

pub fn leap_years_are_understood_test() {
  assert dates.parse_date("02/29/2020")
    == Ok(calendar.Date(2020, calendar.February, 29))
  assert dates.parse_date("02/29/2021") == Error(Nil)
  assert dates.parse_date("02/29/2000")
    == Ok(calendar.Date(2000, calendar.February, 29))
  assert dates.parse_date("02/29/1900") == Error(Nil)
}

pub fn dates_must_be_zero_padded_test() {
  // The client compares against its own zero-padded formatting, so an
  // unpadded key never matches.
  assert dates.parse_date("3/12/2018") == Error(Nil)
  assert dates.parse_date("03/12/2018")
    == Ok(calendar.Date(2018, calendar.March, 12))
}

// --- a good school -----------------------------------------------------------

pub fn a_valid_school_is_accepted_test() {
  accepted(school())
}

pub fn a_custom_school_needs_no_data_files_test() {
  accepted(rules.Data(
    source: Some(source),
    meta: Some("{\"name\": \"Custom\", \"type\": \"custom\"}"),
    correction: None,
    schedules: None,
    calendar: None,
  ))
}

pub fn a_web_school_needs_no_data_files_test() {
  accepted(rules.Data(
    source: Some("{\"location\": \"web\", \"url\": \"https://example.com\"}"),
    meta: None,
    correction: None,
    schedules: None,
    calendar: None,
  ))
}

// --- things that crash the client -------------------------------------------

pub fn dangling_schedule_reference_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      calendar: Some(string.replace(calendar, "Mon day", "Mon mondya")),
    ),
    "no schedule named \"mondya\"",
  )
}

pub fn calendar_entry_without_a_name_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      calendar: Some(string.replace(
        calendar,
        "01/01/2020 weekend # New Year",
        "01/01/2020 # New Year",
      )),
    ),
    "names no schedule",
  )
}

pub fn a_missing_weekday_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      calendar: Some(string.replace(calendar, "Thu day\n", "")),
    ),
    "no entry for Thu",
  )
}

pub fn a_reversed_range_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      calendar: Some(string.replace(
        calendar,
        "01/01/2020",
        "01/09/2020-01/02/2020",
      )),
    ),
    "ends before it starts",
  )
}

pub fn an_impossible_date_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      calendar: Some(string.replace(calendar, "01/01/2020", "02/30/2020")),
    ),
    "is not a real",
  )
}

pub fn a_whitespace_only_line_is_rejected_test() {
  rejected_for(
    rules.Data(..school(), schedules: Some(schedules <> "   \n")),
    "holds only spaces",
  )
}

pub fn an_unnamed_section_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      calendar: Some(string.replace(calendar, "* Default Week", "*")),
    ),
    "section header has no name",
  )
}

pub fn an_unknown_section_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      calendar: Some(string.replace(
        calendar,
        "* Default Week",
        "* Defualt Week",
      )),
    ),
    "unknown section",
  )
}

// --- things that quietly misbehave -------------------------------------------

pub fn an_out_of_range_time_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      schedules: Some(string.replace(schedules, "8:00", "25:00")),
    ),
    "is not a time of day",
  )
}

pub fn a_line_that_is_not_a_time_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      schedules: Some(string.replace(schedules, "8:00 {A}", "Brunch time")),
    ),
    "line starts with \"Brunch\", not a H:MM time",
  )
}

pub fn a_duplicate_schedule_name_is_rejected_test() {
  rejected_for(
    rules.Data(..school(), schedules: Some(schedules <> "* day # Again\n")),
    "a second schedule named \"day\"",
  )
}

pub fn a_duplicate_date_is_rejected_test() {
  rejected_for(
    rules.Data(..school(), calendar: Some(calendar <> "01/01/2020 day\n")),
    "a second entry for 01/01/2020",
  )
}

pub fn an_unknown_binding_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      schedules: Some(string.replace(schedules, "{A}", "{Peroid 4}")),
    ),
    "{Peroid 4} is not in meta.json",
  )
}

pub fn a_period_before_any_header_is_rejected_test() {
  rejected_for(
    rules.Data(..school(), schedules: Some("7:00 Early\n" <> schedules)),
    "before any \"* name\" header",
  )
}

pub fn a_bad_weekday_is_rejected_test() {
  rejected_for(
    rules.Data(
      ..school(),
      calendar: Some(string.replace(calendar, "Mon day", "Munday day")),
    ),
    "is not a weekday",
  )
}

// --- the surrounding files ---------------------------------------------------

pub fn a_non_numeric_correction_is_rejected_test() {
  rejected_for(
    rules.Data(..school(), correction: Some("abc")),
    "should hold a number",
  )
}

pub fn a_negative_correction_is_accepted_test() {
  accepted(rules.Data(..school(), correction: Some("-1500\n")))
}

pub fn broken_meta_json_is_rejected_test() {
  rejected_for(rules.Data(..school(), meta: Some("{")), "is not valid JSON")
}

pub fn meta_without_periods_is_rejected_test() {
  rejected_for(
    rules.Data(..school(), meta: Some("{\"name\": \"Test\"}")),
    "has no \"periods\" list",
  )
}

/// When meta.json cannot be read we do not also blame every binding in
/// schedules.bell for it.
pub fn broken_meta_does_not_cascade_test() {
  let found = messages(rules.Data(..school(), meta: Some("{")))
  assert list.length(found) == 1
}

/// The server falls back to `_default/source.json` when a school has none, so
/// this is a web school rather than a broken one.
pub fn a_school_without_a_source_is_accepted_test() {
  accepted(rules.Data(..school(), source: None))
}

pub fn a_directory_without_school_data_is_not_a_school_test() {
  assert !rules.is_school(rules.Data(None, None, None, None, None))
  assert rules.is_school(rules.Data(..school(), schedules: None))
}

pub fn a_web_source_without_a_url_is_rejected_test() {
  rejected_for(
    rules.Data(..school(), source: Some("{\"location\": \"web\"}")),
    "needs a \"url\"",
  )
}

pub fn an_unknown_location_is_rejected_test() {
  rejected_for(
    rules.Data(..school(), source: Some("{\"location\": \"elsewhere\"}")),
    "unknown location",
  )
}

pub fn a_local_school_missing_a_file_is_rejected_test() {
  rejected_for(
    rules.Data(..school(), calendar: None),
    "missing; a local school needs it",
  )
}
