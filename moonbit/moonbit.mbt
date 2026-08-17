// moon-humanize: MoonBit port of python-humanize.
// See docs/specs/port-to-moonbit.md for the plan.
// Root package re-exports the humanize module.

pub fn intcomma(n : Int) -> String {
  humanize.intcomma(n)
}
