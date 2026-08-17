// Number humanization (faithful port of python-humanize number.py).
// See docs/specs/port-to-moonbit.md.
//
// Functions: clamp, metric, intcomma, intword, apnumber, fractional,
// scientific, ordinal.
//
// All outputs are aligned to the real python-humanize `number.py` semantics
// (golden values verified against the Python reference).

/// Helper: format a non-finite value the way python-humanize does.
fn format_not_finite(value : Double) -> String {
  if value.is_nan() {
    "NaN"
  } else if value < 0.0 {
    "-Inf"
  } else {
    "+Inf"
  }
}

/// Clamp `value` into [floor, ceil], formatting with `format` and prepending
/// `floor_token`/`ceil_token` when clamped. Mirrors python-humanize `clamp`.
/// None / non-finite inputs are not representable as a String here; non-finite
/// values return their `Inf` / `NaN` string form (Python returns None/Inf).
pub fn clamp(
  value : Double,
  ~floor : Double? = None,
  ~ceil : Double? = None,
  ~floor_token : String = "<",
  ~ceil_token : String = ">",
  ~format : (Double) -> String = default_clamp_fmt,
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

fn default_clamp_fmt(x : Double) -> String {
  x.to_string()
}

/// Format a magnitude with an SI metric prefix. Mirrors python-humanize
/// `metric(value, unit="", precision=3)`.
pub fn metric(value : Double, ~unit : String = "", ~precision : Int = 3) -> String {
  if value.is_nan() {
    return "NaN"
  }
  if value.is_inf() {
    return if value < 0.0 { "-Inf" } else { "+Inf" }
  }
  let exponent = if value == 0.0 {
    0
  } else {
    @math.floor(@math.log10(value.abs())).to_int()
  }

  if exponent >= 33 || exponent < -30 {
    return scientific(value.to_string(), precision - 1) + unit
  }

  let old_bucket = exponent / 3 * 3
  let v = value / pow10_double(old_bucket)
  let mut digits = @math.max(0, precision - exponent % 3 - 1).to_int()
  let rounded = round_half_up(v.abs(), digits)
  if exponent < 30 && rounded >= 1000.0 {
    let new_exponent = exponent + 3 - exponent % 3
    let new_bucket = new_exponent / 3 * 3
    v = v / pow10_double(new_bucket - old_bucket)
    exponent = new_exponent
    digits = @math.max(0, precision - exponent % 3 - 1).to_int()
  }

  let ordinal_ : String
  if exponent >= 3 {
    ordinal_ = "kMGTPEZYRQ"[(exponent / 3 - 1)].to_string()
  } else if exponent < 0 {
    ordinal_ = "mμnpfazyrq"[(-exponent - 1) / 3].to_string()
  } else {
    ordinal_ = ""
  }
  let value_ = format_fixed(v, digits)
  let space = if (unit == "" && ordinal_ == "") || unit == "°" || unit == "′" || unit == "″" {
    ""
  } else {
    " "
  }
  value_ + space + ordinal_ + unit
}

fn round_half_up(x : Double, digits : Int) -> Double {
  let r = format_fixed(x, digits)
  try {
    @string.parse_float(r)
  } catch {
    _ => x
  }
}

/// Add thousands separators to a numeric string, optionally rounding to
/// `ndigits` decimals. Mirrors python-humanize `intcomma(value, ndigits=None)`.
pub fn intcomma(value : String, ~ndigits : Int? = None) -> String {
  let neg = value.has_prefix("-")
  let body = if neg { value[1:].to_owned() } else { value }
  let formatted = try {
    let f = @string.parse_float(body)
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
  let mut buf = ""
  let len = int_part.length()
  let mut count = 0
  for i = len - 1; i >= 0; i = i - 1 {
    if count == 3 {
      buf = "," + buf
      count = 0
    }
    buf = int_part[i].to_string() + buf
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
pub fn intword(value : String, ~format : String = "%.1f") -> String {
  let neg = value.has_prefix("-")
  let body = if neg { value[1:].to_owned() } else { value }
  let chopped : Double
  match bisect_intword_powers(body) {
    Some((ordinal, power)) => {
      let v = try {
        @string.parse_float(body)
      } catch {
        _ => return value
      }
      chopped = v / power
      let unit = intword_units[ordinal]
      let number = format_float_with(format, chopped)
      return (if neg { "-" } else { "" }) + number + " " + unit
    }
    None => {
      // below the smallest power: return the (possibly negative) integer string
      return if neg { "-" + body } else { body }
    }
  }
}

/// Find the ordinal index into `intword_powers`/`intword_units` for a numeric
/// string, using bisect_right semantics. Returns None if the value is smaller
/// than the smallest power (10**3).
fn bisect_intword_powers(body : String) -> Option[(Int, Double)] {
  let v = try {
    @string.parse_float(body)
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
  words[n]
}

/// Convert a float/number (given as String) to a human-readable fraction or
/// mixed fraction. Mirrors python-humanize `fractional`.
pub fn fractional(value : String) -> String {
  let num = try {
    @string.parse_float(value)
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
    return numer.to_string() + "/" + denom.to_string()
  }
  // mixed fraction; sign rides on whole part, abs on numerator
  format_fixed(whole.to_double(), 0) + " " + numer.abs().to_string() + "/" + denom.to_string()
}

/// Render a number (given as String) in scientific notation "z.wq x 10ⁿ".
/// Mirrors python-humanize `scientific(value, precision=2)`.
pub fn scientific(value : String, ~precision : Int = 2) -> String {
  let num = try {
    @string.parse_float(value)
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
    @math.floor(@math.log10(abs)).to_int()
  }
  let mantissa = abs / pow10_double(exp)
  let mant_str = format_fixed(mantissa, precision)
  let exp_str = to_superscript(exp.to_string())
  let sign = if neg { "-" } else { "" }
  sign + mant_str + " x 10" + exp_str
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
  n.to_string() + suffix
}
