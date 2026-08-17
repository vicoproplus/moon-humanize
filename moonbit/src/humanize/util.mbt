// Private helpers for moon-humanize.
// See docs/specs/port-to-moonbit.md Phase 1 / util.mbt.

/// Minimal superscript map used by `scientific` to render "x 10ⁿ".
/// Mirrors Python's `str.maketrans` based `_SUPERSCRIPT_TRANS`.
pub let superscript : Map[Char, Char] = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '-': '⁻',
}

/// Translate a string into superscript form using `superscript`.
pub fn to_superscript(s : String) -> String {
  s.to_array()
    .map(fn(c : Char) -> String {
      match superscript.get(c) {
        Some(sc) => sc.to_string()
        None => c.to_string()
      }
    })
    .join("")
}

/// Format a Double with fixed `digits` after the decimal point, rounding
/// half-up — approximating Python's `"%.Nf"`. MoonBit's `Double::to_string`
/// does not support precision specifiers, so this is a self-implemented
/// helper (known porting gap R1). A trailing ".0" is kept (callers decide
/// whether to strip it).
pub fn format_fixed(value : Double, digits : Int) -> String {
  let neg = value < 0.0
  let abs = if neg { -value } else { value }
  if digits <= 0 {
    let r = abs + 0.5
    let i = @math.floor(r).to_int()
    return if neg && i != 0 { "-" + i.to_string() } else { i.to_string() }
  }
  let scale = pow10_double(digits)
  let scaled = abs * scale + 0.5
  let trunc = @math.floor(scaled).to_int()
  let s = trunc.to_string()
  let mut int_part : String = ""
  let mut frac_part : String = ""
  if s.length() <= digits {
    int_part = "0"
    frac_part = "0".repeat(digits - s.length()) + s
  } else {
    int_part = s[0:s.length() - digits].to_owned()
    frac_part = s[s.length() - digits:].to_owned()
  }
  let body = int_part + "." + frac_part
  if neg {
    "-" + body
  } else {
    body
  }
}

fn pow10_double(n : Int) -> Double {
  let mut r = 1.0
  let mut i = 0
  if n >= 0 {
    while i < n {
      r = r * 10.0
      i = i + 1
    }
  } else {
    while i > n {
      r = r / 10.0
      i = i - 1
    }
  }
  r
}
