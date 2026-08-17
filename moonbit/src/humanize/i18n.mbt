// Internationalization helpers (port of python-humanize i18n.py).
//
// Phase 2 scope: i18n-aware number formatting is OUT OF SCOPE. This module only
// exposes the default `en` separators so that downstream functions (e.g.
// `naturalsize`) can opt into localized decimal/thousands separators later.
// See docs/specs/port-to-moonbit.md.

/// The decimal separator used by the active locale (default `"."`).
pub let decimal_separator : String = "."

/// The thousands separator used by the active locale (default `","`).
pub let thousands_separator : String = ","

/// Return the decimal separator for a given locale code. Only `"en"` (and the
/// empty/default case) is supported in Phase 2; anything else falls back to `"."`.
pub fn decimal_separator_for(locale : String) -> String {
  if locale == "" || locale == "en" {
    "."
  } else {
    "."
  }
}

/// Return the thousands separator for a given locale code. Only `"en"` is
/// supported in Phase 2; anything else falls back to `","`.
pub fn thousands_separator_for(locale : String) -> String {
  if locale == "" || locale == "en" {
    ","
  } else {
    ","
  }
}
