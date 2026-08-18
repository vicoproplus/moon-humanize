# Implementation Plan — MoonBit Port Gap-Fill (port-to-moonbit.md)

**Source spec:** `docs/specs/2026-08-18-moonbit-gap-fill-spec.md`
**Companion gap doc:** `docs/specs/port-to-moonbit.md`
**Date:** 2026-08-18

## Scope

Fill the i18n + edge-case gaps in the MoonBit backend so it reaches parity with
`python-humanize` golden values. Work is confined to `moonbit/src/humanize/`.
No new public API surface; every function already exists, we only add i18n
lookup, locale overrides, and non-finite/None parity.

### Confirmed current state (read before coding)

- `i18n.mbt` + `i18n_data.mbt`: `gettext`, `active_lang`, `set_lang`, `deactivate_lang`,
  `set_locale`, `number_omit_space`, `thousands_separator`, `decimal_point` all exist.
- `number.mbt`: `clamp`, `metric`, `intcomma`, `intword`, `apnumber`, `fractional`,
  `scientific`, `ordinal` all exist. `__ordinal`/`ordinal` mapping NOT used.
- `i18n_data.mbt` already contains: `ap_number`, `fractional`, `ordinal` tables;
  `FRACTIONAL`, `NUMBER_GROUPING`; `intword` units already wrapped via `gettext`
  in `intword`.
- `time.mbt`: `naturaldelta`/`naturaltime` exist; `now()` used.
- `lists.mbt`: `andlist`/`olist` exist and already call `gettext` on connectors.
- `filesize.mbt`: exists, but NOT in spec scope — skip (depends on enum sysconfig gap G5/G6).

---

## Task 1 — `apnumber` i18n (gap G1)

**File:** `moonbit/src/humanize/number.mbt`
**Tests:** Python `test_number.py::test_apnumber`

Wrap the word lookup with `gettext` and keep a gender/plural override table
(`gender`/`plural` params are accepted but ignored, mirroring other ports).

Changes in `apnumber`:
```moonbit
pub fn apnumber(
  value : String,
  gender~ : String = "male",
  plural~ : Bool = false,
) -> String {
  let n = try {
    @string.parse_int(value, base=10)
  } catch {
    _ => return value
  }
  if n < 0 || n > 9 {
    return value
  }
  let words = [
    "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
  ]
  gettext(words[n])
}
```
- `i18n_data.mbt` `ap_number` table already maps `zero..nine`; `gettext` falls back
  to the key for `en_US`. No new table needed.
- Golden values (en): `0→zero, 1→one, …, 9→nine, 10→"10", "7"→seven`.
  Non-finite inputs (`NaN`/`inf`/`"nan"`/`"-inf"`) never reach here because the
  Python entry points pass `None`/float which MoonBit represents as raw `String`;
  reproduce exact Python behavior only where a stringified number is passed. Keep
  parse-failure → return `value` (matches Python `ValueError` fallback).

---

## Task 2 — `fractional` i18n (gap G2)

**File:** `moonbit/src/humanize/number.mbt`
**Tests:** `test_number.py::test_fractional`

Add `gender~`/`plural~` ignored params (signature parity) and localize the
connector space + minus sign using `FRACTIONAL` and `NUMBER_GROUPING` tables.

```moonbit
pub fn fractional(
  value : String,
  gender~ : String = "male",
  plural~ : Bool = false,
) -> String {
  let num = try {
    @string.parse_double(value)
  } catch {
    _ => return value
  }
  if num.is_nan() { return "NaN" }
  if num.is_inf() { return if num < 0.0 { "-Inf" } else { "+Inf" } }
  let whole = @math.trunc(num).to_int()
  let frac = num - whole.to_double()
  let r = Rational::from_float_approx(frac, 1000)
  let numer = r.numerator()
  let denom = r.denominator()
  let fractional_conjunction = gettext(FRACTIONAL) // e.g. en " " (space)
  let minus = gettext(NUMBER_GROUPING)             // e.g. en "-"
  if whole != 0 && numer == 0 && denom == 1 {
    return format_fixed(whole.to_double(), 0)
  }
  if whole == 0 {
    return numer.to_string() + "/" + denom.to_string()
  }
  let w = format_fixed(whole.to_double(), 0)
  let sign = if w.has_prefix("-") { minus } else { "" }
  let w_abs = if w.has_prefix("-") { w[1:] } else { w }
  sign + w_abs + fractional_conjunction + numer.abs().to_string() + "/" + denom.to_string()
}
```
- `i18n_data.mbt` already declares `FRACTIONAL` and `NUMBER_GROUPING` constants
  with en values `" "` and `"-"` respectively; `gettext` returns the key for `en_US`.
- Matches golden: `4.0/3.0→"1 1/3"`, `-1.3→"-1 3/10"`, `0.3→"3/10"`.

---

## Task 3 — `ordinal` i18n + override (gap G3)

**File:** `moonbit/src/humanize/number.mbt`
**Tests:** `test_number.py::test_ordinal`

Map to the i18n `ordinal` table (keys `0`–`3`, with special handling for
`11/12/13`). Add `gender~`/`plural~` ignored params and a `to_ordinal~`
override hook.

```moonbit
pub fn ordinal(
  value : String,
  gender~ : String = "male",
  plural~ : Bool = false,
  to_ordinal~ : ((String, String, Bool) -> String)? = None,
) -> String {
  let n = try {
    @string.parse_int(value, base=10)
  } catch {
    _ => return value
  }
  if to_ordinal is Some(f) {
    return f(value, gender, plural)
  }
  let abs_n = n.abs()
  let mod100 = abs_n % 100
  let found_gender = gender // table selects by gender at runtime
  let digit = if mod100 == 11 || mod100 == 12 || mod100 == 13 {
    0 // "th"
  } else {
    match abs_n % 10 {
      1 => 1 // "st"
      2 => 2 // "nd"
      3 => 3 // "rd"
      _ => 0 // "th"
    }
  }
  // ordinal table keys are "0".."3"; look up with gender form.
  let suffix = gettext_ordinal(digit, found_gender)
  n.to_string() + suffix
}
```
- `i18n_data.mbt` `ordinal` table: `{"0":"th","1":"st","2":"nd","3":"rd"}`.
  Add helper `fn gettext_ordinal(d : Int, gender : String) -> String` that reads
  `i18n.ordinal[d.to_string()]` for the active language (fallback `en_US`).
- Golden: `11→11th, 12→12th, 13→13th, 101→101st, 111→111th`.
- Note: Python `ordinal` ignores `value`'s non-finite forms at the API boundary
  (caller passes `None`/float). Keep parse-failure → return `value`.

---

## Task 4 — `scientific` i18n overrides (gap G7)

**File:** `moonbit/src/humanize/number.mbt`
**Tests:** `test_number.py::test_scientific`

Add `decimal_separator~` and `exp_separator~` overrides (defaults `None` →
current behavior). Keeps golden en output identical; gives locale hooks for fr_FR etc.

```moonbit
pub fn scientific(
  value : String,
  precision~ : Int = 2,
  decimal_separator~ : String? = None,
  exp_separator~ : String? = None,
) -> String {
  // ... existing parse + nan/inf handling ...
  let mant_str = format_fixed(mantissa, precision)
  let mant_str = match decimal_separator {
    Some(sep) => replace_dot(mant_str, sep)
    None => mant_str
  }
  let exp_sep = match exp_separator {
    Some(s) => s
    None => " x 10"
  }
  let exp_str = to_superscript(exp.to_string())
  let sign = if neg { "-" } else { "" }
  sign + mant_str + exp_sep + exp_str
}
```
- When overrides are `None`, output is byte-identical to current (`" x 10ⁿ"`).
- Golden en unchanged: `1000→"1.00 x 10³"`, `0.3→"3.00 x 10⁻¹"`.
- Add small local helper `replace_dot(s, sep)` to swap the `.` in the mantissa.

---

## Task 5 — `clamp` None / non-finite parity (gap G9)

**File:** `moonbit/src/humanize/number.mbt`
**Tests:** `test_number.py::test_clamp`

MoonBit has no `None`/`NaN`/`Inf` distinct string for the *input* `None` case
(Python returns `None`). Two faithful options:

1. **Minimal (chosen):** keep `clamp(value : Double, ...)`. For callers that need
   the `None`-input Python behavior, the MoonBit type system already prevents
   passing `None` (it's `Double`, not `Double?`), so `clamp(None)` is
   unrepresentable. Document this in `README.md` mapping table (already partially
   noted at line 296). Non-finite inputs already return `"NaN"`/`"+Inf"`/`"-Inf"`,
   matching Python's string form for `NaN`/`inf`.
2. **Optional overload:** add `clamp_opt(value : Double?, ...)` returning
   `"None"` for `None` and delegating otherwise. (Only if tests require it.)

Decision: implement **(1)** plus update the README note to state `clamp(None)` is
unrepresentable in MoonBit and returns `"None"` only when an explicit `Double?`
wrapper is used. Add a `clamp_opt` convenience if a test demands `None`→`"None"`.
Keep current non-finite handling (already correct vs golden).

---

## Task 6 — `intword` threshold format + `metric` locale (gaps G10/G11)

**File:** `moonbit/src/humanize/number.mbt`
**Tests:** `test_number.py::test_intword`, `test_metric`

### 6a. `intword` threshold formatting (`"%0.2f"` etc.)
Python supports arbitrary `format` such as `"%0.2f"` (→ `"1.23 million"`) and
`"%.0f"` (→ `"1 million"`). Current `format_float_with` strips to `%.Nf` only;
`"%.0f"` → `n=0` works, but `"%0.2f"` parses `0` (the leading zero) → wrong.
Fix `format_float_with` to parse the digits *between* `.` and the trailing `f`:

```moonbit
fn format_float_with(format : String, x : Double) -> String {
  let n = try {
    let idx = format.find(".")
    let end = format.find("f") // last 'f'
    match (idx, end) {
      (Some(i), Some(e)) => @string.parse_int(format[i + 1:e].to_owned(), base=10)
      _ => 1
    }
  } catch {
    _ => 1
  }
  format_fixed(x, n)
}
```
This makes `"%0.2f"` → `n=2` and `"%.0f"` → `n=0`, matching golden
(`1230000,"%0.2f"`→`"1.23 million"`; `1234567,"%.0f"`→`"1 million"`).

### 6b. `metric` spacing override (gap G11)
Add `space~ : String? = None` and `spacing_override~`? Python `metric` uses
`number_omit_space` + unit rules. MoonBit already hardcodes the space logic
(lines 118–122). Add a `space~ : String? = None` override:

```moonbit
pub fn metric(
  value : Double,
  unit~ : String = "",
  precision~ : Int = 3,
  space~ : String? = None,
) -> String {
  // ... existing ...
  let space = match space {
    Some(s) => s
    None => /* existing unit/° logic */
  }
  value_ + space + ordinal_ + unit
}
```
Default `None` preserves current behavior (golden unchanged). Enables fr_FR
`" "` rule parity without breaking en.

---

## Task 7 — `set_locale` for number grouping (gap G12)

**File:** `moonbit/src/humanize/i18n.mbt` (wiring) — mostly already present.
`intcomma` already calls `thousands_separator()`. Verify `set_locale(locale)`
propagates to `thousands_separator`/`decimal_point`/`number_omit_space`.

Action: add a focused unit test `test_set_locale_grouping` in the MoonBit test
block (or `tests/`) that sets `"de_DE"`, asserts `intcomma("1234567")` →
`"1.234.567"` and `decimal_point()` → `"."`, then `deactivate_lang()`.
If `set_locale` does not yet switch `thousands_separator`, implement the switch
in `i18n.mbt` using the existing `fr_FR`/`de_DE` table pattern.

---

## Task 8 — `naturaldelta`/`naturaltime` i18n (gap G13)

**File:** `moonbit/src/humanize/time.mbt`
**Tests:** `test_time.py` (review for connector/unit localization)

- Wrap the `, ` and ` and ` connectors and the unit words (`second(s)`,
  `minute(s)`, `hour(s)`, `day(s)`, `month(s)`, `year(s)`) with `gettext`.
- Add `when~`/`days0~`? Python signature: `naturaldelta(value, months=True,
  minimum_unit="seconds", when=None)`, `naturaltime(value, when=None, ...)`.
  MoonBit currently takes `value : Int64` (seconds) — keep; add optional
  `minimum_unit~ : String = "seconds"` to match Python's `minimum_unit` knob if
  tests exercise it. Localize only; no behavior change for `en_US`.
- Verify `precisedelta` (if present) similarly wraps units; if absent, out of scope
  (depends on `Rational` + G4, already done in `rational.mbt`).

---

## Task 9 — Build, test, validate

1. `cd e:/moonbit/moon-humanize && moon build` — must succeed with no new errors.
2. `moon test` — all existing tests green (no regression from signature additions;
   default args keep call sites valid).
3. Optional: `python -m pytest tests/` to confirm golden Python values unchanged
   (reference only; our parity target).
4. Spot-check new i18n behavior with a tiny MoonBit test snippet or `moon test`
   cases added per task (apnumber/fractional/ordinal/intword/metric locale).

---

## Deliverables checklist

- [ ] `apnumber` localized via `gettext`, `gender`/`plural` params added (G1)
- [ ] `fractional` localized connector/minus, params added (G2)
- [ ] `ordinal` uses `ordinal` i18n table, `gender`/`plural`/`to_ordinal` added (G3)
- [ ] `scientific` `decimal_separator`/`exp_separator` overrides (G7)
- [ ] `clamp` None/non-finite parity documented + optional `clamp_opt` (G9)
- [ ] `intword` arbitrary `format` parsing fixed (G10)
- [ ] `metric` `space` override + locale spacing (G11)
- [ ] `set_locale` grouping verified/wired (G12)
- [ ] `naturaldelta`/`naturaltime` unit/connector localization (G13)
- [ ] `moon build` + `moon test` green
- [ ] README mapping table updated for `clamp(None)` note

## Out of scope (explicitly)

- `filesize` i18n (G14) — blocked by enum/sysconfig gaps G5/G6; separate plan.
- Locale data population beyond `en_US`/`fr_FR`/`de_DE` already present — only
  wire existing tables; do not author new translation tables.
- Public API renames — all changes are backward-compatible (added optional
  named args only).
