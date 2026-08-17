// moon-humanize: MoonBit port of python-humanize.
// See docs/specs/port-to-moonbit.md for the plan.
// Root package re-exports the humanize module.

pub use @humanize.{clamp, metric, intcomma, intword, apnumber, fractional, scientific, ordinal}

/// Convenience wrapper: group thousands for an integer.
pub fn intcomma_int(n : Int) -> String {
  @humanize.intcomma(n.to_string())
}
