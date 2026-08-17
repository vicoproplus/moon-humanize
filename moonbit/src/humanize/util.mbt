// Private helpers for moon-humanize.
// See docs/specs/port-to-moonbit.md Phase 1 / util.mbt.

// Format a Double with fixed `digits` after the decimal point (approximates Python "%.Nf").
// NOTE: MoonBit's Double::to_string does not support precision specifiers,
// so this is a self-implemented helper and a known porting gap (see spec R1).
pub fn format_fixed(value : Double, digits : Int) -> String {
  // Placeholder: delegate to to_string until a real implementation lands in Phase 1.
  ignore(digits)
  value.to_string()
}

// Superscript digit map for scientific() (Python's str.maketrans).
pub let superscript : Map[Char, Char] = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
}
