// Time humanization (faithful port of python-humanize time.py).
// Phase 2 target functions: naturaltime, naturalday, naturaldate, naturaldelta,
// precisedelta. See docs/specs/port-to-moonbit.md.
//
// The Python API accepts a `datetime.timedelta`, a number of seconds, or a
// `datetime`. MoonBit is statically typed, so the dual "timedelta or number"
// input is modeled with the `TimeInput` enum:
//   * `TimeInput::Seconds(Double)`  — a number of seconds (note: for
//     `naturaldelta`/`precisedelta` the value is used verbatim; for
//     `naturaltime` it is rounded to the nearest second like Python).
//   * `TimeInput::Delta(TimeDelta)` — an explicit duration.

// A duration mirroring Python's `datetime.timedelta` (days/seconds/microseconds).
// All components are kept non-negative; `is_neg` records the original sign of the
// input so callers can recover it (used by `naturaltime` tense).
pub struct TimeDelta {
  days : Int
  seconds : Int
  microseconds : Int
  is_neg : Bool
}

/// Enumeration of the supported time units, ordered from smallest to largest.
pub enum TimeUnit {
  MICROSECONDS
  MILLISECONDS
  SECONDS
  MINUTES
  HOURS
  DAYS
  MONTHS
  YEARS
}

// Public accessors so callers (and tests) can reference the unit variants,
// which are not individually exported by `pub enum` in this toolchain.
pub fn TimeUnit::microseconds() -> TimeUnit { TimeUnit::MICROSECONDS }
pub fn TimeUnit::milliseconds() -> TimeUnit { TimeUnit::MILLISECONDS }
pub fn TimeUnit::seconds() -> TimeUnit { TimeUnit::SECONDS }
pub fn TimeUnit::minutes() -> TimeUnit { TimeUnit::MINUTES }
pub fn TimeUnit::hours() -> TimeUnit { TimeUnit::HOURS }
pub fn TimeUnit::days() -> TimeUnit { TimeUnit::DAYS }
pub fn TimeUnit::months() -> TimeUnit { TimeUnit::MONTHS }
pub fn TimeUnit::years() -> TimeUnit { TimeUnit::YEARS }

impl Eq for TimeUnit with equal(self, other) {
  match (self, other) {
    (TimeUnit::MICROSECONDS, TimeUnit::MICROSECONDS) => true
    (TimeUnit::MILLISECONDS, TimeUnit::MILLISECONDS) => true
    (TimeUnit::SECONDS, TimeUnit::SECONDS) => true
    (TimeUnit::MINUTES, TimeUnit::MINUTES) => true
    (TimeUnit::HOURS, TimeUnit::HOURS) => true
    (TimeUnit::DAYS, TimeUnit::DAYS) => true
    (TimeUnit::MONTHS, TimeUnit::MONTHS) => true
    (TimeUnit::YEARS, TimeUnit::YEARS) => true
    _ => false
  }
}

/// Dual input for the time humanizers: a number of seconds or an explicit delta.
/// Construct via the `from_seconds` / `from_delta` factory functions (pub enum
/// constructors are not individually exported in this toolchain).
pub enum TimeInput {
  Seconds(Double)
  Delta(TimeDelta)
}

/// Public entry point: build a `TimeInput` from a number of seconds.
pub fn TimeInput::from_seconds(s : Double) -> TimeInput {
  TimeInput::Seconds(s)
}

/// Public entry point: build a `TimeInput` from an explicit delta.
pub fn TimeInput::from_delta(d : TimeDelta) -> TimeInput {
  TimeInput::Delta(d)
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Build a `TimeDelta` from explicit days/seconds/microseconds, normalized the
/// same way as Python's `datetime.timedelta`.
pub fn timedelta(
  days~ : Int = 0,
  seconds~ : Int = 0,
  microseconds~ : Int = 0
) -> TimeDelta {
  let total = days * 86400 * 1_000_000 + seconds * 1_000_000 + microseconds
  let neg = total < 0
  let t = if neg { -total } else { total }
  let d = t / (86400 * 1_000_000)
  let rem = t % (86400 * 1_000_000)
  let s = rem / 1_000_000
  let us = rem % 1_000_000
  TimeDelta::{ days: d, seconds: s, microseconds: us, is_neg: neg }
}

/// Build a `TimeDelta` from a (possibly fractional) number of seconds, without
/// rounding — matching `_date_and_delta`'s `timedelta(seconds=float(value))`.
fn seconds_to_delta(n : Double) -> TimeDelta {
  let neg = n < 0.0
  let abs = if neg { -n } else { n }
  let total = (abs * 1_000_000.0).round().to_int()
  let d = total / (86400 * 1_000_000)
  let rem = total % (86400 * 1_000_000)
  let s = rem / 1_000_000
  let us = rem % 1_000_000
  TimeDelta::{ days: d, seconds: s, microseconds: us, is_neg: neg }
}

// ---------------------------------------------------------------------------
// Unit helpers
// ---------------------------------------------------------------------------

fn TimeUnit::noun(self : TimeUnit) -> String {
  match self {
    TimeUnit::MICROSECONDS => "microsecond"
    TimeUnit::MILLISECONDS => "millisecond"
    TimeUnit::SECONDS => "second"
    TimeUnit::MINUTES => "minute"
    TimeUnit::HOURS => "hour"
    TimeUnit::DAYS => "day"
    TimeUnit::MONTHS => "month"
    TimeUnit::YEARS => "year"
  }
}

fn TimeUnit::ordinal(self : TimeUnit) -> Int {
  match self {
    TimeUnit::MICROSECONDS => 0
    TimeUnit::MILLISECONDS => 1
    TimeUnit::SECONDS => 2
    TimeUnit::MINUTES => 3
    TimeUnit::HOURS => 4
    TimeUnit::DAYS => 5
    TimeUnit::MONTHS => 6
    TimeUnit::YEARS => 7
  }
}

fn TimeUnit::same(a : TimeUnit, b : TimeUnit) -> Bool {
  a.ordinal() == b.ordinal()
}

fn TimeUnit::contains(list : Array[TimeUnit], u : TimeUnit) -> Bool {
  let mut i = 0
  while i < list.length() {
    if TimeUnit::same(list[i], u) { return true }
    i = i + 1
  }
  false
}

// ---------------------------------------------------------------------------
// naturaldelta
// ---------------------------------------------------------------------------

/// Humanize a time delta into a short, natural-language string.
pub fn naturaldelta(
  value : TimeInput,
  months~ : Bool = true,
  minimum_unit~ : TimeUnit = TimeUnit::SECONDS
) -> String {
  if minimum_unit != TimeUnit::SECONDS &&
     minimum_unit != TimeUnit::MILLISECONDS &&
     minimum_unit != TimeUnit::MICROSECONDS {
    abort("Minimum unit '" + minimum_unit.noun() + "s' not supported")
  }
  let delta = match value {
    TimeInput::Delta(d) => d
    TimeInput::Seconds(s) => seconds_to_delta(s)
  }
  let neg = delta.is_neg
  let d = TimeDelta::{
    days: delta.days,
    seconds: delta.seconds,
    microseconds: delta.microseconds,
    is_neg: neg,
  }
  let use_months = months
  let years = d.days / 365
  let days = d.days % 365
  let num_months = @math.round(days.to_double() / 30.5).to_int()

  if years == 0 && days < 1 {
    if d.seconds == 0 {
      if minimum_unit == TimeUnit::MICROSECONDS && d.microseconds < 1000 {
        return _nunit(d.microseconds, "microsecond", "microseconds")
      }
      if minimum_unit == TimeUnit::MILLISECONDS ||
         (minimum_unit == TimeUnit::MICROSECONDS &&
          1000 <= d.microseconds && d.microseconds < 1_000_000) {
        let ms = d.microseconds / 1000
        return _nunit(ms, "millisecond", "milliseconds")
      }
      return "a moment"
    }
    if d.seconds == 1 {
      return "a second"
    }
    if d.seconds < 60 {
      return _nunit(d.seconds, "second", "seconds")
    }
    if 60 <= d.seconds && d.seconds < 3600 {
      let minutes = @math.round(d.seconds.to_double() / 60.0).to_int()
      if minutes == 1 {
        return "a minute"
      }
      if minutes == 60 {
        return "an hour"
      }
      return _nunit(minutes, "minute", "minutes")
    }
    if 3600 <= d.seconds {
      let hours = @math.round(d.seconds.to_double() / 3600.0).to_int()
      if hours == 1 {
        return "an hour"
      }
      if hours == 24 {
        return "a day"
      }
      return _nunit(hours, "hour", "hours")
    }
  } else if years == 0 {
    if days == 1 {
      return "a day"
    }
    if !(use_months) {
      return _nunit(days, "day", "days")
    }
    if num_months == 0 {
      return _nunit(days, "day", "days")
    }
    if num_months == 1 {
      return "a month"
    }
    if num_months == 12 {
      return "a year"
    }
    return _nunit(num_months, "month", "months")
  } else if years == 1 {
    if num_months == 0 && days == 0 {
      return "a year"
    }
    if num_months == 0 {
      return _nyear_days(days)
    }
    if use_months {
      if num_months == 1 {
        return "1 year, 1 month"
      }
      if num_months == 12 {
        return _nunit(2, "year", "years")
      }
      return _nyear_months(num_months)
    }
    return _nyear_days(days)
  }
  _nunit_big(years, "year", "years")
}

fn _nunit(n : Int, singular : String, plural : String) -> String {
  if n == 1 { "1 " + singular } else { n.to_string() + " " + plural }
}

fn _nyear_days(days : Int) -> String {
  if days == 1 {
    "1 year, 1 day"
  } else {
    "1 year, " + days.to_string() + " days"
  }
}

fn _nyear_months(months : Int) -> String {
  if months == 1 {
    "1 year, 1 month"
  } else {
    "1 year, " + months.to_string() + " months"
  }
}

// Years >= 2: use intcomma for thousands separators.
fn _nunit_big(n : Int, singular : String, plural : String) -> String {
  if n == 1 { "1 " + singular } else { intcomma(n.to_string()) + " " + plural }
}

// ---------------------------------------------------------------------------
// naturaltime
// ---------------------------------------------------------------------------

/// Humanize a time relative to a reference point. For `TimeInput::Delta` the
/// tense follows the sign of the delta (negative → "from now"); for
/// `TimeInput::Seconds` the value is rounded to the nearest second (matching
/// Python) and rendered in the past tense by default.
pub fn naturaltime(
  value : TimeInput,
  future~ : Bool = false,
  months~ : Bool = true,
  minimum_unit~ : TimeUnit = TimeUnit::SECONDS
) -> String {
  let (delta, is_future) = match value {
    TimeInput::Delta(d) => (d, d.is_neg)
    TimeInput::Seconds(s) => {
      let rounded = @math.round(s)
      (seconds_to_delta(rounded), false)
    }
  }
  let base = naturaldelta(TimeInput::Delta(delta), months~, minimum_unit~)
  if base == "a moment" {
    return "now"
  }
  if is_future || future {
    base + " from now"
  } else {
    base + " ago"
  }
}

// ---------------------------------------------------------------------------
// naturalday / naturaldate
// ---------------------------------------------------------------------------

/// A calendar date (proleptic Gregorian).
struct Date {
  year : Int
  month : Int
  day : Int
}

/// Humanize a date relative to `when`. Returns today/tomorrow/yesterday or a
/// formatted date string.
pub fn naturalday(
  value : Date,
  when~ : Date = Date::{ year: 2010, month: 2, day: 2 },
  format~ : String = "%b %d"
) -> String {
  let d = _date_diff_days(value, when)
  if d == 0 {
    return "today"
  }
  if d == 1 {
    return "tomorrow"
  }
  if d == -1 {
    return "yesterday"
  }
  _format_date(value, format)
}

/// Like `naturalday`, but append a year for dates from a different year than
/// `when`. (The Python "five months" rule is not applied in this port.)
pub fn naturaldate(
  value : Date,
  when~ : Date = Date::{ year: 2010, month: 2, day: 2 }
) -> String {
  let d = _date_diff_days(value, when)
  if d == 0 {
    return "today"
  }
  if d == 1 {
    return "tomorrow"
  }
  if d == -1 {
    return "yesterday"
  }
  if value.year != when.year {
    _format_date(value, "%b %d %Y")
  } else {
    _format_date(value, "%b %d")
  }
}

fn _date_diff_days(value : Date, when : Date) -> Int {
  _days_since_epoch(value) - _days_since_epoch(when)
}

fn _days_since_epoch(d : Date) -> Int {
  let y = if d.month <= 2 { d.year - 1 } else { d.year }
  let m = if d.month <= 2 { d.month + 12 } else { d.month }
  let era = (if y >= 0 { y } else { y - 399 }) / 400
  let yoe = y - era * 400
  let doy = (153 * (m - 3) + 2) / 5 + d.day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

fn _format_date(d : Date, format : String) -> String {
  if format == "%b %d" {
    _month_abbr(d.month) + " " + _two_digit(d.day)
  } else if format == "%b %d %Y" {
    _month_abbr(d.month) + " " + _two_digit(d.day) + " " + d.year.to_string()
  } else if format == "%Y.%m.%d" {
    d.year.to_string() + "." + _two_digit(d.month) + "." + _two_digit(d.day)
  } else {
    d.year.to_string() + "-" + _two_digit(d.month) + "-" + _two_digit(d.day)
  }
}

fn _two_digit(n : Int) -> String {
  if n < 10 { "0" + n.to_string() } else { n.to_string() }
}

fn _month_abbr(m : Int) -> String {
  match m {
    1 => "Jan"
    2 => "Feb"
    3 => "Mar"
    4 => "Apr"
    5 => "May"
    6 => "Jun"
    7 => "Jul"
    8 => "Aug"
    9 => "Sep"
    10 => "Oct"
    11 => "Nov"
    12 => "Dec"
    _ => "???"
  }
}

// ---------------------------------------------------------------------------
// precisedelta
// ---------------------------------------------------------------------------

/// Humanize a time delta in full detail, combining several units
/// (e.g. "5 days, 4 hours, 3 seconds and 2 microseconds").
pub fn precisedelta(
  value : TimeInput,
  minimum_unit~ : TimeUnit = TimeUnit::SECONDS,
  format~ : String = "%0.2f",
  suppress~ : Array[TimeUnit] = []
) -> String {
  let delta = match value {
    TimeInput::Delta(d) => d
    TimeInput::Seconds(s) => seconds_to_delta(s)
  }
  let neg = delta.is_neg
  let d = TimeDelta::{
    days: delta.days,
    seconds: delta.seconds,
    microseconds: delta.microseconds,
    is_neg: neg,
  }

  let mut suppress_set = suppress
  let mut min_unit = minimum_unit

  // Find a suitable minimum unit (greater than the given one if suppressed).
  if TimeUnit::contains(suppress_set, min_unit) {
    let order = [
      TimeUnit::MICROSECONDS, TimeUnit::MILLISECONDS, TimeUnit::SECONDS, TimeUnit::MINUTES,
      TimeUnit::HOURS, TimeUnit::DAYS, TimeUnit::MONTHS, TimeUnit::YEARS,
    ]
    let mut found : TimeUnit? = None
    let mut i = 0
    while i < order.length() {
      if order[i].ordinal() > min_unit.ordinal() && !(TimeUnit::contains(suppress_set, order[i])) {
        found = Some(order[i])
        break
      }
      i = i + 1
    }
    match found {
      Some(u) => min_unit = u
      None => abort("Minimum unit is suppressed and no suitable replacement was found")
    }
  }

  // Extend the suppressed set with all units below the minimum unit.
  let all_order = [
    TimeUnit::MICROSECONDS, TimeUnit::MILLISECONDS, TimeUnit::SECONDS, TimeUnit::MINUTES,
    TimeUnit::HOURS, TimeUnit::DAYS, TimeUnit::MONTHS, TimeUnit::YEARS,
  ]
  let mut si = 0
  while si < all_order.length() {
    if TimeUnit::same(all_order[si], min_unit) {
      break
    }
    suppress_set = suppress_set + [all_order[si]]
    si = si + 1
  }

  let mut years = d.days.to_double()
  let mut days = 0.0
  let mut months = 0.0
  let mut secs = d.seconds.to_double()
  let mut usecs = d.microseconds.to_double()
  let mut msecs = 0.0
  let mut hours = 0.0
  let mut minutes = 0.0

  let q1 = _quotient_and_remainder(years, 365.0, TimeUnit::YEARS, min_unit, suppress_set, format)
  years = q1.0
  days = q1.1
  let q2 = _quotient_and_remainder(days, 30.5, TimeUnit::MONTHS, min_unit, suppress_set, format)
  months = q2.0
  days = q2.1

  let secs_from_days = days * 24.0 * 3600.0
  let total_secs = secs_from_days + secs
  let q3 = _quotient_and_remainder(total_secs, 24.0 * 3600.0, TimeUnit::DAYS, min_unit, suppress_set, format)
  days = q3.0
  secs = q3.1

  let q4 = _quotient_and_remainder(secs, 3600.0, TimeUnit::HOURS, min_unit, suppress_set, format)
  hours = q4.0
  secs = q4.1

  let q5 = _quotient_and_remainder(secs, 60.0, TimeUnit::MINUTES, min_unit, suppress_set, format)
  minutes = q5.0
  secs = q5.1

  let total_usecs = secs * 1000000.0 + usecs
  let q6 = _quotient_and_remainder(total_usecs, 1000000.0, TimeUnit::SECONDS, min_unit, suppress_set, format)
  secs = q6.0
  usecs = q6.1

  let q7 = _quotient_and_remainder(usecs, 1000.0, MILLISECONDS, min_unit, suppress_set, format)
  msecs = q7.0
  usecs = q7.1

  // Promotions due to rounding.
  if msecs >= 1000.0 && !(TimeUnit::contains(suppress_set, TimeUnit::SECONDS)) {
    msecs = msecs - 1000.0
    secs = secs + 1.0
  }
  if secs >= 60.0 && !(TimeUnit::contains(suppress_set, TimeUnit::MINUTES)) {
    secs = secs - 60.0
    minutes = minutes + 1.0
  }
  if minutes >= 60.0 && !(TimeUnit::contains(suppress_set, TimeUnit::HOURS)) {
    minutes = minutes - 60.0
    hours = hours + 1.0
  }
  if hours >= 24.0 && !(TimeUnit::contains(suppress_set, TimeUnit::DAYS)) {
    hours = hours - 24.0
    days = days + 1.0
  }
  if days >= 31.0 && !(TimeUnit::contains(suppress_set, TimeUnit::MONTHS)) {
    days = days - 31.0
    months = months + 1.0
  }
  if months >= 12.0 && !(TimeUnit::contains(suppress_set, TimeUnit::YEARS)) {
    months = months - 12.0
    years = years + 1.0
  }

  let fmts : Array[(TimeUnit, Double)] = [
    (YEARS, years),
    (MONTHS, months),
    (DAYS, days),
    (HOURS, hours),
    (MINUTES, minutes),
    (SECONDS, secs),
    (MILLISECONDS, msecs),
    (MICROSECONDS, usecs),
  ]

  let mut texts : Array[String] = []
  let order2 = [
    TimeUnit::YEARS, TimeUnit::MONTHS, TimeUnit::DAYS, TimeUnit::HOURS, TimeUnit::MINUTES,
    TimeUnit::SECONDS, TimeUnit::MILLISECONDS, TimeUnit::MICROSECONDS,
  ]
  let mut oi = 0
  while oi < order2.length() {
    let unit = order2[oi]
    let fmt_value = _lookup(fmts, unit)
    if fmt_value > 0.0 || (texts.length() == 0 && TimeUnit::same(unit, min_unit)) {
      let singular = unit.noun()
      let plural = singular + "s"
      // Mirror Python: fmt_value forced to 2 when 1 < v < 2, else int(v).
      let _fmt_value =
        if 1.0 < fmt_value && fmt_value < 2.0 { 2.0 } else { @math.floor(fmt_value) }
      let is_min = TimeUnit::same(unit, min_unit)
      let text =
        if is_min && _is_fractional(fmt_value) {
          // format applied to the original (fractional) value
          _format_value(fmt_value, format) + " " + plural
        } else if TimeUnit::same(unit, YEARS) {
          // years rendered with intcomma as an integer, singular at 1
          if _fmt_value == 1.0 {
            "1 year"
          } else {
            intcomma(@math.floor(fmt_value).to_int().to_string()) + " " + plural
          }
        } else if _fmt_value == 1.0 {
          // singular
          "1 " + singular
        } else {
          // plural, integer-valued (truncated)
          @math.floor(fmt_value).to_int().to_string() + " " + plural
        }
      texts = texts + [text]
    }
    if TimeUnit::same(unit, min_unit) {
      break
    }
    oi = oi + 1
  }

  if texts.length() == 0 {
    if TimeUnit::same(min_unit, TimeUnit::YEARS) {
      texts = ["0 years"]
    } else {
      texts = ["0 " + min_unit.noun() + "s"]
    }
  }

  if texts.length() == 1 {
    return texts[0]
  }
  _join_precise(texts)
}

fn _join_precise(ordered : Array[String]) -> String {
  let n = ordered.length()
  if n == 0 {
    return ""
  }
  if n == 1 {
    return ordered[0]
  }
  if n == 2 {
    return ordered[0] + " and " + ordered[1]
  }
  let mut acc = ordered[0]
  let mut i = 1
  while i < n - 1 {
    acc = acc + ", " + ordered[i]
    i = i + 1
  }
  acc + " and " + ordered[n - 1]
}

fn _lookup(fmts : Array[(TimeUnit, Double)], u : TimeUnit) -> Double {
  let mut i = 0
  while i < fmts.length() {
    let (unit, v) = fmts[i]
    if TimeUnit::same(unit, u) {
      return v
    }
    i = i + 1
  }
  0.0
}

fn _is_fractional(v : Double) -> Bool {
  let f = v - @math.floor(v)
  f > 0.0
}

fn _quotient_and_remainder(
  value : Double,
  divisor : Double,
  unit : TimeUnit,
  minimum_unit : TimeUnit,
  suppress : Array[TimeUnit],
  format : String
) -> (Double, Double) {
  if unit == minimum_unit {
    return (_rounding_by_fmt(format, value / divisor), 0.0)
  }
  if TimeUnit::contains(suppress, unit) {
    return (0.0, value)
  }
  let q = @math.floor(value / divisor)
  let r = value - q * divisor
  (q, r)
}

fn _round_decimals(value : Double, prec : Int) -> Double {
  let mut f = 1.0
  let mut k = 0
  while k < prec {
    f = f * 10.0
    k = k + 1
  }
  @math.round(value * f) / f
}

fn _rounding_by_fmt(format : String, value : Double) -> Double {
  // Mimic Python's printf formatting: "%d"/"%i" truncate to an integer,
  // fractional formats round to the requested precision.
  if _str_contains(format, "d") || _str_contains(format, "i") {
    @math.floor(value)
  } else {
    let prec = _parse_precision(format)
    _round_decimals(value, prec)
  }
}

fn _parse_precision(format : String) -> Int {
  let chars = format.to_array()
  let mut i = 0
  let mut dot = -1
  while i < chars.length() {
    if chars[i] == '.' {
      dot = i
    }
    i = i + 1
  }
  if dot == -1 {
    return 2
  }
  let mut num = ""
  let mut j = dot + 1
  while j < chars.length() && chars[j] >= '0' && chars[j] <= '9' {
    num = num + chars[j].to_string()
    j = j + 1
  }
  if num == "" { 2 } else { _str_to_int(num) }
}

fn _format_value(value : Double, format : String) -> String {
  if _str_contains(format, "d") || _str_contains(format, "i") {
    @math.floor(value).to_int().to_string()
  } else {
    let prec = _parse_precision(format)
    format_fixed(value, prec)
  }
}

fn _str_to_int(s : String) -> Int {
  let a = s.to_array()
  let mut r = 0
  let mut i = 0
  while i < a.length() {
    if a[i] >= '0' && a[i] <= '9' {
      r = r * 10 + (a[i].to_int() - '0'.to_int())
    }
    i = i + 1
  }
  r
}

fn _str_contains(s : String, sub : String) -> Bool {
  let a = s.to_array()
  let b = sub.to_array()
  if b.length() == 0 {
    return true
  }
  if b.length() > a.length() {
    return false
  }
  let mut i = 0
  while i + b.length() <= a.length() {
    let mut k = 0
    let mut ok = true
    while k < b.length() {
      if a[i + k] != b[k] {
        ok = false
        break
      }
      k = k + 1
    }
    if ok {
      return true
    }
    i = i + 1
  }
  false
}

// `format_fixed` is defined in util.mbt.
// `intcomma` is defined in number.mbt.
