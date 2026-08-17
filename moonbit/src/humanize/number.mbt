// Number humanization (port of python-humanize number.py).
// Phase 1 target functions: intcomma, ordinal, apnumber, intword,
// scientific, clamp, metric, fractional.
// See docs/specs/port-to-moonbit.md.

// intcomma: add thousands separators to an integer string.
pub fn intcomma(n : Int) -> String {
  // Placeholder implementation (Phase 1 start). Converts to string and,
  // for now, returns the raw value; real grouping lands in Phase 1.
  n.to_string()
}
