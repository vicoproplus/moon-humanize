// moon-humanize: MoonBit port of python-humanize.
// See docs/specs/port-to-moonbit.md for the plan.
// Root package re-exports the humanize module.

pub fn clamp(
  value : Double,
  floor~ : Double? = None,
  ceil~ : Double? = None,
  floor_token~ : String = "<",
  ceil_token~ : String = ">",
  format~ : (Double) -> String = @humanize.default_clamp_fmt,
) -> String {
  @humanize.clamp(value, floor~, ceil~, floor_token~, ceil_token~, format~)
}

pub fn metric(value : Double, unit~ : String = "", precision~ : Int = 3) -> String {
  @humanize.metric(value, unit~, precision~)
}

pub fn intcomma(value : String, ndigits~ : Int? = None) -> String {
  @humanize.intcomma(value, ndigits~)
}

pub fn intword(value : String, format~ : String = "%.1f") -> String {
  @humanize.intword(value, format~)
}

pub fn apnumber(value : String) -> String {
  @humanize.apnumber(value)
}

pub fn fractional(value : String) -> String {
  @humanize.fractional(value)
}

pub fn scientific(value : String, precision~ : Int = 2) -> String {
  @humanize.scientific(value, precision~)
}

pub fn ordinal(value : String) -> String {
  @humanize.ordinal(value)
}
