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
/// * `suffix` is appended after the unit symbol (default `"B"`).
/// * `format` is a Python-style format string (default `"%.1f"`).
/// * `symbols` selects the unit set: `None`, `"decimal"`, `"binary"`, or `"gnu"`.
pub fn naturalsize(
  value : Double,
  binary~ : Bool = false,
  suffix~ : String = "B",
  format~ : String = "%.1f",
  symbols~ : String? = None
) -> String {
  let symbols_arr = if binary {
    if symbols is Some(_) {
      _fs_get_symbols(symbols)
    } else {
      binary_symbols
    }
  } else {
    _fs_get_symbols(symbols)
  }
  let is_gnu = symbols is Some("gnu")

  let mut negative = false
  let mut num = value
  if num < 0.0 {
    negative = true
    num = -num
  }

  let mut exponent = 0
  let mut divisor = 1.0

  if is_gnu {
    // GNU format uses 1024-based units, one step per power of 1024.
    let mut n = num
    while n >= 1024.0 && exponent < symbols_arr.length() - 1 {
      n = n / 1024.0
      divisor = divisor * 1024.0
      exponent = exponent + 1
    }
  } else {
    let threshold = if binary { 1024.0 } else { 1000.0 }
    let mut n = num
    while n >= threshold && exponent < symbols_arr.length() - 1 {
      n = n / threshold
      divisor = divisor * threshold
      exponent = exponent + 1
    }
  }

  let val = num / divisor

  let mut result = _fs_format(val, format)
  if exponent == 0 {
    // Sub-threshold: render "Byte"/"Bytes" (python-humanize strips a trailing
    // ".0" from the default 1-decimal format). The suffix is not appended.
    if result.has_suffix(".0") {
      result = (result[: result.length() - 2]).to_owned()
    }
    if num == 1.0 {
      result = result + " Byte"
    } else {
      result = result + " Bytes"
    }
  } else if is_gnu {
    // GNU does not add a decimal point before the symbol
    result = result.replace(old= ".0", new= "")
    result = result + symbols_arr[exponent] + suffix
  } else {
    result = result + " " + symbols_arr[exponent] + suffix
  }
  if negative {
    "-" + result
  } else {
    result
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
