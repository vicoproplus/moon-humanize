// File size humanization (port of python-humanize filesize.py).
// Phase 2 target functions: naturalsize.
// See docs/specs/port-to-moonbit.md.

// Symbol tables without the trailing "B" (the `suffix` is appended separately).
// Index 0 is unused here; the sub-threshold "Byte"/"Bytes" case is handled
// specially. Decimal/binary/gnu follow python-humanize's tables.
let decimal_symbols : Array[String] = [
  "", "k", "M", "G", "T", "P", "E", "Z", "Y", "R", "Q",
]

let binary_symbols : Array[String] = [
  "", "Ki", "Mi", "Gi", "Ti", "Pi", "Ei", "Zi", "Yi", "Ri", "Qi",
]

let gnu_symbols : Array[String] = [
  "", "K", "M", "G", "T", "P", "E", "Z", "Y", "R", "Q",
]

fn _fs_get_symbols(symbols : String?) -> Array[String] {
  match symbols {
    Some("decimal") => decimal_symbols
    Some("binary") => binary_symbols
    Some("gnu") => gnu_symbols
    Some(_) => decimal_symbols
    None => decimal_symbols
  }
}

/// Humanize a byte count into a friendly size string.
///
/// * `value` is the number of bytes (a Double or Int).
/// * `binary` selects binary (1024-based) units when `true` and `symbols` is None.
/// * `gnu` selects GNU units (1024-based, space-free, e.g. `"300B"`, `"2.9K"`) —
///   mirrors python-humanize's `gnu=True` exactly, including the quirk that the
///   suffix is only shown below one unit (`ls -sh` style).
/// * `suffix` is appended after the unit symbol (default `"B"`).
/// * `format` is a Python-style format string (default `"%.1f"`); passing `"%.0f"`
///   mirrors python-humanize's `format=True` (no fractional digits).
/// * `symbols` selects the unit set: `None`, `"decimal"`, `"binary"`, or `"gnu"`.
pub fn naturalsize(
  value : Double,
  binary~ : Bool = false,
  gnu~ : Bool = false,
  suffix~ : String = "B",
  format~ : String = "%.1f",
  symbols~ : String? = None
) -> String {
  let is_gnu = gnu || symbols is Some("gnu")
  let symbols_arr = if is_gnu {
    gnu_symbols
  } else if binary {
    if symbols is Some(_) {
      _fs_get_symbols(symbols)
    } else {
      binary_symbols
    }
  } else {
    _fs_get_symbols(symbols)
  }
  // python: base = 1024 if (gnu or binary) else 1000.
  let base = if is_gnu || binary { 1024.0 } else { 1000.0 }

  let mut negative = false
  let mut num = value
  if num < 0.0 {
    negative = true
    num = -num
  }

  // Largest exponent with `num / base^exponent >= base`, capped at the top
  // symbol — mirrors python's `int(min(log(abs, base), len(suffix)))`.
  let mut exponent = 0
  let mut divisor = 1.0
  let mut n = num
  while n >= base && exponent < symbols_arr.length() - 1 {
    n = n / base
    divisor = divisor * base
    exponent = exponent + 1
  }

  let sign = if negative { "-" } else { "" }
  if exponent == 0 {
    // Sub-threshold (incl. exactly one byte): python renders an integer and
    // ignores `format` — `"%d Byte"/"%d Bytes"`, or `f"{int}B"` for gnu.
    let count = num.to_int().to_string()
    if is_gnu {
      sign + count + suffix
    } else if num == 1.0 {
      sign + count + " Byte"
    } else {
      sign + count + " Bytes"
    }
  } else {
    let mut val = num / divisor
    // python 4.16.0: rounding can push the mantissa up to `base` (999999 is
    // 999.999 kB, which formats to "1000.0 kB"); step up one unit so it
    // reads "1.0 MB". (`exponent == 0` already returned above.)
    if exponent < symbols_arr.length() - 1 {
      if _fs_str_to_double(_fs_format(val, format)) >= base {
        exponent = exponent + 1
        divisor = divisor * base
        val = num / divisor
      }
    }
    let mantissa = _fs_format(val, format)
    if is_gnu {
      // python: no space and no `suffix` above the threshold ("2.9K").
      sign + mantissa + symbols_arr[exponent]
    } else {
      sign + mantissa + " " + symbols_arr[exponent] + suffix
    }
  }
}

fn _fs_format(value : Double, format : String) -> String {
  let prec = _fs_parse_precision(format)
  format_fixed(value, prec)
}

fn _fs_parse_precision(format : String) -> Int {
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
    return 1
  }
  let mut num = ""
  let mut j = dot + 1
  while j < chars.length() && chars[j] >= '0' && chars[j] <= '9' {
    num = num + chars[j].to_string()
    j = j + 1
  }
  if num == "" { 1 } else { _fs_str_to_int(num) }
}

fn _fs_str_to_int(s : String) -> Int {
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

// Parse a fixed-point string like "1000.0" / "-2.9" back into a Double, used to
// mirror python's rounding push-up check (abs(float(format % ...)) >= base).
fn _fs_str_to_double(s : String) -> Double {
  let a = s.to_array()
  let mut i = 0
  let mut sign = 1.0
  if a.length() > 0 && a[0] == '-' {
    sign = -1.0
    i = 1
  }
  let mut int_part = 0.0
  while i < a.length() && a[i] != '.' {
    if a[i] >= '0' && a[i] <= '9' {
      int_part = int_part * 10.0 + (a[i].to_int() - '0'.to_int()).to_double()
    }
    i = i + 1
  }
  if i >= a.length() {
    return sign * int_part
  }
  i = i + 1 // skip '.'
  let mut frac = 0.0
  let mut place = 0.1
  while i < a.length() {
    if a[i] >= '0' && a[i] <= '9' {
      frac = frac + (a[i].to_int() - '0'.to_int()).to_double() * place
      place = place * 0.1
    }
    i = i + 1
  }
  sign * (int_part + frac)
}

fn _fs_str_contains(s : String, sub : String) -> Bool {
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

fn _fs_pow10(n : Int) -> Double {
  let mut r = 1.0
  let m = if n < 0 { -n } else { n }
  let mut i = 0
  while i < m {
    r = r * 10.0
    i = i + 1
  }
  if n < 0 { 1.0 / r } else { r }
}
