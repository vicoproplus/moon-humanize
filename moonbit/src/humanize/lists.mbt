// List/collection humanization (port of python-humanize lists.py).
// Phase 2 target: natural_list.
// See docs/specs/port-to-moonbit.md.

/// Humanize a collection of items into a natural-language enumeration.
///
/// * `value` is the list of items (each rendered with `to_string`).
/// * `style` selects the connector: `"standard"` (and), `"or"`, or `"and"`.
/// * `cx` (default `", "`) separates items; `ox` (default `" "`) separates the
///   final item from the connector.
pub fn natural_list(
  value : ArrayView[String],
  style~ : String = "standard",
  cx~ : String = ", ",
  ox~ : String = " "
) -> String {
  // `cx` is the item separator; python-humanize's natural_list hardcodes ", ",
  // which is exactly the default here, so default output matches byte-for-byte.
  let conjs = _get_conjs(style)
  let l = value.length()
  if l == 0 {
    return ""
  }
  if l == 1 {
    return value[0]
  }
  if l == 2 {
    // python-humanize: a two-item standard list reads "a and b" (no comma).
    return value[0] + " " + conjs + " " + value[1]
  }
  let mut s = ""
  let mut i = 0
  while i < l - 1 {
    if i > 0 {
      s = s + cx
    }
    s = s + value[i]
    i = i + 1
  }
  let last = value[l - 1]
  s + ox + conjs + " " + last
}

fn _get_conjs(style : String) -> String {
  if style == "or" {
    "or"
  } else if style == "and" {
    "and"
  } else {
    // python-humanize's "standard" style connects with "and".
    "and"
  }
}
