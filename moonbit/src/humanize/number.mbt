// Number humanization (faithful port of python-humanize number.py).
// See docs/specs/port-to-moonbit.md.
//
// Functions: clamp, metric, intcomma, intword, apnumber, fractional,
// scientific, ordinal.
//
// All outputs are aligned to the real python-humanize `number.py` semantics
// (golden values verified against the Python reference).

/// Clamp `value` into [floor, ceil], formatting with `format` and prepending
/// `floor_token`/`ceil_token` when clamped. Mirrors python-humanize `clamp`.
/// None / non-finite inputs are not representable as a String here; non-finite
/// values return their `Inf` / `NaN` string form (Python returns None/Inf).
pub fn clamp(
  value : Double,
  floor~ : Double? = None,
  ceil~ : Double? = None,
  floor_token~ : String = "<",
  ceil_token~ : String = ">",
  format~ : (Double) -> String = default_clamp_fmt,
) -> String {
  if value.is_nan() {
    return "NaN"
  }
  if value.is_inf() {
    return if value < 0.0 { "-Inf" } else { "+Inf" }
  }
  let mut v = value
  let mut token = ""
  match floor {
    Some(f) => if value < f {
      v = f
      token = floor_token
    }
    None => ()
  }
  match ceil {
    Some(c) => if v > c {
      v = c
      token = ceil_token
    }
    None => ()
  }
  token + format(v)
}

pub fn default_clamp_fmt(x : Double) -> String {
  x.to_string()
}

/// Floor division by 3 (MoonBit `/` truncates toward zero).
fn floor_div3(e : Int) -> Int {
  let q = e / 3
  if e < 0 && e % 3 != 0 {
    q - 1
  } else {
    q
  }
}

/// Largest multiple of 3 that is <= e (floor to 3-bucket), matching Python
/// `int(e / 3) * 3` with floor division.
fn floor_mul3(e : Int) -> Int {
  floor_div3(e) * 3
}

/// Non-negative remainder modulo 3 (0, 1, or 2), matching Python `%`.
fn mod3(e : Int) -> Int {
  let r = e % 3
  if r < 0 {
    r + 3
  } else {
    r
  }
}

/// Format a magnitude with an SI metric prefix. Mirrors python-humanize
/// `metric(value, unit="", precision=3)`.
pub fn metric(value : Double, unit~ : String = "", precision~ : Int = 3) -> String {
  if value.is_nan() {
    return "NaN"
  }
  if value.is_inf() {
    return if value < 0.0 { "-Inf" } else { "+Inf" }
  }
  let exponent = if value == 0.0 {
    0
  } else {
    ilog10(value.abs())
  }

  if exponent >= 33 || exponent < -30 {
    return scientific(value.to_string(), precision = precision - 1) + unit
  }

  let old_bucket = floor_mul3(exponent)
  let mut v = value / pow10_double(old_bucket)
  let mut exp = exponent
  let mut digits = if 0 > precision - mod3(exp) - 1 { 0 } else { precision - mod3(exp) - 1 }
  let rounded = round_half_up(v.abs(), digits)
  if exp < 30 && rounded >= 1000.0 {
    let new_exponent = exp + 3 - mod3(exp)
    let new_bucket = floor_mul3(new_exponent)
    v = v / pow10_double(new_bucket - old_bucket)
    exp = new_exponent
    digits = if 0 > precision - mod3(exp) - 1 { 0 } else { precision - mod3(exp) - 1 }
  }

  let mut ordinal_ : String = ""
  if exp >= 3 {
    ordinal_ = positive_prefix[(floor_div3(exp) - 1)]
  } else if exp < 0 {
    ordinal_ = negative_prefix[((-exp - 1) / 3)]
  } else {
    ordinal_ = ""
  }
  let value_ = format_fixed(v, digits)
  let space = if !(unit != "" || ordinal_ != "") || unit == "°" || unit == "′" || unit == "″" {
    ""
  } else {
    " "
  }
  value_ + space + ordinal_ + unit
}

/// Integer base-10 logarithm (floor), matching `int(math.floor(log10(x)))` for
/// positive `x`. Implemented with a loop to avoid floating-point edge cases.
fn ilog10(x : Double) -> Int {
  // floor(log10(x)) with a tiny epsilon to avoid floating-point errors at
  // exact powers of ten (e.g. 1e-14 would otherwise drift to -15).
  @math.floor(@math.log10(x) + 1.0e-9).to_int()
}

/// Positive SI prefixes: k, M, G, T, P, E, Z, Y, R, Q (index = exp/3 - 1).
let positive_prefix : Array[String] = [
  "k", "M", "G", "T", "P", "E", "Z", "Y", "R", "Q",
]

/// Negative SI prefixes: m, µ, n, p, f, a, z, y, r, q (index = (-exp-1)/3).
let negative_prefix : Array[String] = [
  "m", "μ", "n", "p", "f", "a", "z", "y", "r", "q",
]

fn round_half_up(x : Double, digits : Int) -> Double {
  let r = format_fixed(x, digits)
  try {
    @string.parse_double(r)
  } catch {
    _ => x
  }
}

/// Add thousands separators to a numeric string, optionally rounding to
/// `ndigits` decimals. Mirrors python-humanize `intcomma(value, ndigits=None)`.
pub fn intcomma(value : String, ndigits~ : Int? = None) -> String {
  let neg = value.has_prefix("-")
  let body = if neg { value[1:].to_owned() } else { value }
  let formatted = try {
    let f = @string.parse_double(body)
    match ndigits {
      Some(d) => format_fixed(f, d)
      None => f.to_string()
    }
  } catch {
    _ => body
  }
  let grouped = group_number_string(formatted)
  if neg {
    "-" + grouped
  } else {
    grouped
  }
}

fn group_number_string(s : String) -> String {
  match s.find(".") {
    Some(idx) => group_thousands(s[0:idx].to_owned()) + s[idx:].to_owned()
    None => group_thousands(s)
  }
}

fn group_thousands(int_part : String) -> String {
  if int_part.length() <= 3 {
    return int_part
  }
  // Use the active locale's thousands separator (e.g. "." for de_DE),
  // defaulting to "," when no locale is active.
  let sep = thousands_separator()
  let mut buf = ""
  let len = int_part.length()
  let mut count = 0
  for i = len - 1; i >= 0; i = i - 1 {
    if count == 3 {
      buf = sep + buf
      count = 0
    }
    buf = int_part[i:i + 1].to_owned() + buf
    count = count + 1
  }
  buf
}

/// Powers of ten thresholds for `intword` (matches python-humanize: the last
/// entry is the googol, 10**100).
let intword_powers : Array[Double] = [
  1.0e3, 1.0e6, 1.0e9, 1.0e12, 1.0e15, 1.0e18, 1.0e21, 1.0e24, 1.0e27, 1.0e30,
  1.0e33, 1.0e100,
]

let intword_units : Array[String] = [
  "thousand", "million", "billion", "trillion", "quadrillion", "quintillion",
  "sextillion", "septillion", "octillion", "nonillion", "decillion", "googol",
]

/// Convert a large integer (given as String) to a friendly magnitude, e.g.
/// "1.0 million". Mirrors python-humanize `intword(value, format="%.1f")`.
pub fn intword(value : String, format~ : String = "%.1f") -> String {
  let neg = value.has_prefix("-")
  let body = if neg { value[1:].to_owned() } else { value }
  match bisect_intword_powers(body) {
    Some((ordinal, power)) => {
      let v = try {
        @string.parse_double(body)
      } catch {
        _ => return value
      }
      let chopped = v / power
      let unit = gettext(intword_units[ordinal])
      let number = format_float_with(format, chopped)
      (if neg { "-" } else { "" }) + number + " " + unit
    }
    None => {
      // below the smallest power: return the (possibly negative) integer string
      if neg {
        "-" + body
      } else {
        body
      }
    }
  }
}

/// Find the ordinal index into `intword_powers`/`intword_units` for a numeric
/// string, using bisect_right semantics. Returns None if the value is smaller
/// than the smallest power (10**3).
fn bisect_intword_powers(body : String) -> Option[(Int, Double)] {
  let v = try {
    @string.parse_double(body)
  } catch {
    _ => return None
  }
  if v < 1.0e3 {
    return None
  }
  let mut lo = 0
  let mut hi = intword_powers.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if intword_powers[mid] <= v {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  // lo == bisect_right; ordinal index is lo-1
  let idx = lo - 1
  // The googol entry may be out of Double range; treat index 11 as the cap.
  Some((idx, intword_powers[idx]))
}

/// Apply a Python-style `"%.Nf"` format string to a Double using `format_fixed`.
fn format_float_with(format : String, x : Double) -> String {
  let n = try {
    let idx = format.find(".")
    match idx {
      Some(i) => @string.parse_int(format[i + 1:format.length() - 1].to_owned(), base=10)
      None => 1
    }
  } catch {
    _ => 1
  }
  format_fixed(x, n)
}

/// Convert an integer (given as String) to AP-style words for 0-9, else the
/// decimal string. Mirrors python-humanize `apnumber`.
pub fn apnumber(value : String) -> String {
  let n = try {
    @string.parse_int(value, base=10)
  } catch {
    _ => return value
  }
  if n < 0 || n > 9 {
    return value
  }
  let words = [
    "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
    "nine",
  ]
  // User-visible word passes through gettext so locale catalogs (e.g. zh_CN,
  // fr_FR) can translate it; English / unknown locales fall back to the word.
  gettext(words[n])
}

/// Convert a float/number (given as String) to a human-readable fraction or
/// mixed fraction. Mirrors python-humanize `fractional`.
pub fn fractional(value : String) -> String {
  let num = try {
    @string.parse_double(value)
  } catch {
    _ => return value
  }
  if num.is_nan() {
    return "NaN"
  }
  if num.is_inf() {
    return if num < 0.0 { "-Inf" } else { "+Inf" }
  }
  let whole = @math.trunc(num).to_int()
  let frac = num - whole.to_double()
  let r = Rational::from_float_approx(frac, 1000)
  let numer = r.numerator()
  let denom = r.denominator()
  if whole != 0 && numer == 0 && denom == 1 {
    // an integer (or integer variant like 1.0000)
    return format_fixed(whole.to_double(), 0)
  }
  if whole == 0 {
    return gettext(numer.to_string() + "/" + denom.to_string())
  }
  // mixed fraction; sign rides on whole part, abs on numerator
  gettext(format_fixed(whole.to_double(), 0) + " " + numer.abs().to_string() + "/" + denom.to_string())
}

/// Render a number (given as String) in scientific notation "z.wq x 10ⁿ".
/// Mirrors python-humanize `scientific(value, precision=2)`.
pub fn scientific(value : String, precision~ : Int = 2) -> String {
  let num = try {
    @string.parse_double(value)
  } catch {
    _ => return value
  }
  if num.is_nan() {
    return "NaN"
  }
  if num.is_inf() {
    return if num < 0.0 { "-Inf" } else { "+Inf" }
  }
  let neg = num < 0.0
  let abs = if neg { -num } else { num }
  let exp = if abs == 0.0 {
    0
  } else {
    ilog10(abs)
  }
  let mantissa = abs / pow10_double(exp)
  let mant_str = format_fixed(mantissa, precision)
  let exp_str = to_superscript(exp.to_string())
  let sign = if neg { "-" } else { "" }
  // Whole expression passes through gettext so locale catalogs can translate
  // the coefficient words / connector; English / unknown locales fall back.
  gettext(sign + mant_str + " x 10" + exp_str)
}

// ---------------------------------------------------------------------------
// Feature 1: locale-aware scientific notation + decimal/word helpers
// ---------------------------------------------------------------------------

/// Trait for locale-aware number formatting. Concrete number types can
/// implement `scientific` to produce a localized scientific-notation string.
/// The free `scientific(value : Double, ~precision, ~exponent, ~locale)`
/// function below is the default, generic implementation.
pub trait NumberFormatter {
  scientific(value : Double, precision~ : Int = 6, exponent~ : Int = 3) -> String
}

/// Convert a real number to scientific notation as a plain (locale-neutral)
/// string, e.g. `to_scientific(3.14159, 2, 3) == "3.14 x 10^3"`.
///
/// This is the building block used by the localized `scientific` overload.
pub fn to_scientific(value : Double, precision~ : Int = 6, exponent~ : Int = 3) -> String {
  let mantissa = value / pow10_double(exponent)
  let m = format_fixed(mantissa, precision)
  m + " x 10^" + exponent.to_string()
}

/// Format a number with grouped thousands and a fixed number of `decimals`,
/// e.g. `to_decimal(1234567.891, decimals=2) == "1,234,567.89"`.
pub fn to_decimal(value : Double, decimals~ : Int = 2) -> String {
  let neg = value < 0.0
  let v = if neg { -value } else { value }
  let factor = pow10_double(decimals)
  let x = v * factor
  let scaled = if x >= 0.0 {
    (x + 0.5).floor().to_int()
  } else {
    (x - 0.5).ceil().to_int()
  }
  let denom = pow10_int(decimals)
  let int_part = scaled / denom
  let frac_part = scaled % denom
  let int_str = group_thousands(int_part.to_string())
  let frac_str = pad_left(frac_part.to_string(), decimals, '0')
  let body = int_str + "." + frac_str
  if neg { "-" + body } else { body }
}

/// Spell out an integer in English cardinal words, e.g. `123` -> `"one hundred and twenty-three"`.
///
/// Negative numbers are prefixed with `"negative"`. Locale-specific spelling
/// (e.g. Chinese 读数) is out of scope for the initial implementation; this
/// returns English regardless of the active locale.
pub fn integer_to_words(n : Int) -> String {
  if n == 0 {
    return "zero"
  }
  let neg = n < 0
  let x = if neg { -n } else { n }
  let words = int_to_words_positive(x)
  if neg { "negative " + words } else { words }
}

fn int_to_words_positive(n : Int) -> String {
  let scales = [
    "", " thousand", " million", " billion", " trillion", " quadrillion",
    " quintillion",
  ]
  if n == 0 {
    return ""
  }
  let mut groups : Array[Int] = []
  let mut rem = n
  while rem > 0 {
    groups.push(rem % 1000)
    rem = rem / 1000
  }
  let mut parts : Array[String] = []
  let mut i = groups.length() - 1
  while i >= 0 {
    let g = groups[i]
    if g != 0 {
      let w = under1000_words(g)
      let scale = scales[i]
      parts.push(if scale == "" { w } else { w + scale })
    }
    i = i - 1
  }
  parts.join(" ")
}

fn under1000_words(n : Int) -> String {
  let ones = [
    "", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
    "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
    "seventeen", "eighteen", "nineteen",
  ]
  let tens = [
    "", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty",
    "ninety",
  ]
  let h = n / 100
  let t = n % 100
  let mut s = ""
  if h > 0 {
    s = s + ones[h] + " hundred"
  }
  if t > 0 {
    if h > 0 {
      s = s + " and "
    }
    if t < 20 {
      s = s + ones[t]
    } else {
      let d = t / 10
      let u = t % 10
      s = s + tens[d]
      if u > 0 {
        s = s + "-" + ones[u]
      }
    }
  }
  s
}

fn pow10_int(n : Int) -> Int {
  let mut r = 1
  for i = 0; i < n; i = i + 1 {
    r = r * 10
  }
  r
}

fn group_thousands(s : String) -> String {
  let chars = s.to_array()
  let len = chars.length()
  let mut out : Array[Char] = []
  for i = 0; i < len; i = i + 1 {
    if i != 0 && i % 3 == 0 {
      out.push(',')
    }
    out.push(chars[len - 1 - i])
  }
  out.to_string()
}

fn pad_left(s : String, width : Int, ch : Char) -> String {
  let len = s.length()
  if len >= width {
    return s
  }
  let mut prefix = ""
  for _ = 0; < width - len; _ = _ + 1 {
    prefix = prefix + ch.to_string()
  }
  prefix + s
}

/// Map a power-of-ten exponent to its localized magnitude word id (used by the
/// localized `scientific`). Falls back to the raw exponent string for powers
/// not covered by the catalog.
fn exponent_word_id(exponent : Int) -> MsgId {
  match exponent {
    3 => EXPword1
    6 => EXPword2
    9 => EXPword3
    12 => EXPword4
    15 => EXPword5
    18 => EXPword6
    _ => EXPword1
  }
}

/// Format a real number in scientific notation, localized via the i18n catalog.
///
/// Uses the `scientific_tmpl` message (`"%s x 10^%s"` for en, `"%s × 10^%s"`
/// for ru_RU, `"%s×10^%s"` for zh/zh_CN) and substitutes the mantissa and a
/// localized magnitude word for the exponent when available.
pub fn scientific(
  value : Double,
  precision~ : Int = 6,
  exponent~ : Int = 3,
  locale~ : Locale = match current_locale() {
    Some(l) => l
    None => En
  }
) -> String {
  let mantissa = value / pow10_double(exponent)
  let m = format_fixed(mantissa, precision)
  let exp_words = msg_str(locale, exponent_word_id(exponent)).to_string()
  let exp_repr = if exp_words == "" {
    exponent.to_string()
  } else {
    exp_words
  }
  msg_str(locale, SCItmpl).format([m, exp_repr])
}

/// Convert an integer (given as String) to its English ordinal, e.g. "1st".
/// Mirrors python-humanize `ordinal` (gender ignored, uses male form).
pub fn ordinal(value : String) -> String {
  let n = try {
    @string.parse_int(value, base=10)
  } catch {
    _ => return value
  }
  let abs_n = n.abs()
  let mod100 = abs_n % 100
  let digit = if mod100 == 11 || mod100 == 12 || mod100 == 13 {
    0
  } else {
    abs_n % 10
  }
  let suffixes = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"]
  let suffix = suffixes[digit]
  // Localize the ordinal suffix via pgettext using the digit context, exactly
  // like python-humanize ("{digit} (male)" ctx + English suffix word). This lets
  // catalogs such as ru_RU map e.g. digit 2 / "nd" -> "ой". English / unknown
  // locales fall back to the English suffix; the number is always ASCII digits.
  let localized = pgettext(digit.to_string() + " (male)", suffix)
  n.to_string() + localized
}
