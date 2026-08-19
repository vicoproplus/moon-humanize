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

// Library version. Must stay in sync with moon.mod `version` and
// src/humanize/wasm.mbt `wasm_version()` (see spec §5.3).
pub let __version__ : String = "0.1.2"

// —— time ——
pub fn naturalday(
  value : @humanize.Date,
  when~ : @humanize.Date = @humanize.Date::today(),
  format~ : String = "%b %d",
) -> String {
  @humanize.naturalday(value, when~, format~)
}

pub fn naturaldate(
  value : @humanize.Date,
  when~ : @humanize.Date = @humanize.Date::today(),
) -> String {
  @humanize.naturaldate(value, when~)
}

pub fn naturaldelta(
  value : @humanize.TimeInput,
  months~ : Bool = true,
  minimum_unit~ : @humanize.TimeUnit = @humanize.TimeUnit::seconds(),
) -> String {
  @humanize.naturaldelta(value, months~, minimum_unit~)
}

pub fn naturaltime(
  value : @humanize.TimeInput,
  future~ : Bool = false,
  months~ : Bool = true,
  minimum_unit~ : @humanize.TimeUnit = @humanize.TimeUnit::seconds(),
  when~ : @humanize.DateTime? = None,
) -> String {
  @humanize.naturaltime(value, future~, months~, minimum_unit~, when~)
}

pub fn precisedelta(
  value : @humanize.TimeInput,
  minimum_unit~ : @humanize.TimeUnit = @humanize.TimeUnit::seconds(),
  format~ : String = "%0.2f",
  suppress~ : Array[@humanize.TimeUnit] = [],
) -> String {
  @humanize.precisedelta(value, minimum_unit~, format~, suppress~)
}

// —— filesize ——
pub fn naturalsize(
  value : Double,
  binary~ : Bool = false,
  gnu~ : Bool = false,
  format~ : String = "%.1f",
) -> String {
  @humanize.naturalsize(value, binary~, gnu~, format~)
}

// —— lists ——
pub fn natural_list(
  value : ArrayView[String],
  style~ : String = "standard",
  cx~ : String = ", ",
  ox~ : String = " ",
) -> String {
  @humanize.natural_list(value, style~, cx~, ox~)
}
