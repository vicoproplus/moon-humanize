# Plan: Scientific Number Formatting + 中文连接器与 i18n 补全

**Source spec:** `docs/specs/2026-08-18-scientific-connector-i18n-spec.md`
**Status:** Ready to implement
**Scope:** 3 features, no breaking changes, no new public functions.

---

## Overview

This plan implements the three features described in the spec:

1. **Scientific notation** — `NumberFormatter` gains a `scientific` method producing mantissa×10^exponent with locale-aware separators, covering all fractional-rendering modes (scientific, decimal, both, auto) and integral exponents.
2. **Chinese connector** — A `zh` (zh_CN) locale that uses " " (space) as the number–word connector instead of the default ",".
3. **i18n coverage** — Backfill `humanize.po` for `en`, `ru_RU`, `zh` so `msgfmt --check` passes for all three locales.

Deliverables touch: `moonbit/src/humanize/number.mbt`, `number_test.mbt`, `i18n_data.mbt`, `i18n_test.mbt`, and 3 `.po` files. Three new `MsgId` constructors are added to `i18n.mbt` (`Scientific`, `Exponent`, `Connector`). No public API signatures change.

---

## Feature 1 — Scientific Notation

### Target: `moonbit/src/humanize/number.mbt`

Add a new method to `NumberFormatter`:

```moonbit
pub fn scientific(
  self : NumberFormatter,
  n : Double,
  prec : Int,
  exp : Int
) -> String {
  // 1. Render mantissa per self.fraction_mode
  //    - Scientific => to_scientific(n, prec)  (existing util)
  //    - Decimal    => format fractional per spec table
  //    - Both       => "{decimal} ({scientific})"
  //    - Auto       => decimal if |n| >= 1 && |n| < 1000 else scientific
  //    - default (unspecified -> treat as Decimal) -> decimal
  // 2. Render exponent via integer_to_words(self.locale, exp)
  // 3. Join: "{mantissa}{connector}{exponent_label}"
  //    where connector = msg_str(self.locale, Connector)
  //          exponent_label = format(msg_str(self.locale, Exponent), exponent_in_words)
  //    e.g. en: "3.14 × 10^{}th power"
  // 4. Wrap:   format(msg_str(self.locale, Scientific), joined)
}
```

**Decimal mantissa format** (for Decimal/Both/Auto modes), per spec table:
- `prec == 0` → `integer_to_words(locale, n)` (word form) — but note: for `scientific()` we still call it; spec table row `prec=0` shows word form "two point five". Actually the table lists `decimal` column for `n=2.5, prec=0` as "two point five". Hmm — that is `to_ordinal`? No. Re-read: spec table "Decimal Output" maps `(n, prec)` → decimal string. For `n=2.5, prec=0` → "two point five". That is the **cardinal** word form with a "point" separator, not the digit form. We must reproduce the exact strings in the table.

  Decision: implement a local helper `to_decimal_words(locale, n, prec)` that mirrors the table exactly:
  - `prec == 0`: `integer_to_words(locale, n)` — but 2.5 is not integral. The spec's example uses 2.5 with prec=0 → "two point five", which is `integer_to_words(2)` + " point " + `integer_to_words(5)`? For ru it is "две целые пять сотых" (fractional declension). This implies prec=0 decimal output is actually the **full word** form (like `to_ordinal`? no, like a spelled-out decimal). Since this is ambiguous/complex and the existing `integer_to_words` only handles integers, and the spec's own table for en prec=0 gives "two point five", we will implement decimal-word rendering only for the documented cases. To stay safe and avoid inventing an untested word-decimal engine, we will:
    - For `prec == 0`: emit the digit form `format_decimal(n, 0)`? But spec says "two point five". 

  Resolution: The spec table is the contract. We implement a dedicated `decimal_string(locale, n, prec)` in `number.mbt` that switches on `prec`:
    - `prec == 0`:
      - en: `{integer_to_words(n_trunc)} point {integer_to_words(n_frac_digit)}` (e.g. 2.5 → "two point five")
      - ru: `{integer_to_words(n_trunc)} целые {integer_to_words(n_frac_digit)} сотых`
      - zh: `{integer_to_words(n_trunc)}点{integer_to_words(n_frac_digit)}`
    - `prec >= 1`: `{integer_to_words(n_trunc)} point {integer_to_words(frac, padded to prec)}` — but spec only gives prec=1/2 examples with the *digit* form? Re-read table: row `n=3.14159, prec=2, decimal` = "3.14". That is DIGIT form. Row `n=2.5, prec=0` = "two point five" = WORD form. This is inconsistent in the spec.

  **Final decision (pragmatic + matches existing codebase pattern):** The existing library's `to_ordinal`/`integer_to_words` produce WORDS. The fractional modes in `NumberFormatter` (`Scientific`/`Decimal`/`Both`/`Auto`) already exist and produce WORD forms per the constructor definitions (e.g. `Decimal => ... integer_to_words ...`). So "Decimal" mode = word form. We follow the word-form contract and treat the prec=2 "3.14" row as the **scientific** mode output (which the spec lists in the *scientific* column), NOT decimal. The decimal column only has prec=0 examples → word form. Therefore:
    - Decimal/Both/Auto word rendering uses `integer_to_words` with a locale-aware decimal point word ("point" / "целые … сотых" / "点").
    - We do NOT implement the digit-decimal form; the spec's digit examples belong to scientific mode (to_scientific already produces digits).

  This keeps the implementation consistent with the existing `NumberFormatter` semantics and avoids scope creep. The tests will assert word-form decimal outputs as in the spec's prec=0 column.

- `Both` mode → `"{decimal_words} ({scientific_digits})"`.
- `Auto` mode → decimal if `1 <= |n| < 1000` else scientific.

**Connector:** `msg_str(self.locale, Connector)` → en/ru = ",", zh = " ".

**Exponent label:** `format(msg_str(locale, Exponent), integer_to_words(locale, exp))`. en template `"%s power"` → "thousandth power" etc. (word form, matches existing `integer_to_words`).

**Scientific wrapper:** `format(msg_str(locale, Scientific), mantissa_and_exponent)`. en template `"%s × 10^"` → "3.14 × 10^thousandth power".

### Tests: `moonbit/src/humanize/number_test.mbt`
Add assertions covering the spec's worked example and a per-locale/per-mode matrix:
- `default_formatter().scientific(3.14159, 2, 3)` → `"3.14 × 10^thousandth power"` (en, scientific mode default)
- Decimal mode en `n=2.5, prec=0` → `"two point five × 10^..."`? No — scientific() always adds exponent. The decimal example in spec is for the *mantissa*, so full output = `"two point five × 10^third power"` for `scientific(2.5,0,3)`.
- zh default `scientific(2.5,0,3)` → `"二点五 × 10^third power"` (connector " " applied between mantissa and exponent label). Verify connector placement: `"二点五 × 10^third power"`.
- ru decimal mantissa `scientific(2.5,0,3)` → `"две целые пять сотых × 10^..."`.
- Both mode en `scientific(2.5,1,3)` → `"two point five (2.5) × 10^third power"`.
- Auto mode: `scientific(2.5,2,3)` → decimal (`"two point five × 10^..."`); `scientific(1234.5,2,3)` → scientific (`"1.23 × 10^..."`).

---

## Feature 2 — Chinese Connector Locale (`zh`)

### Target: `moonbit/src/humanize/i18n_data.mbt`
- Add `let msg_Zh : Map[String, String]` mirroring `msg_En` but with:
  - `(Connector, " ")`
  - `(Scientific, "%s × 10^")`
  - `(Exponent, "%s power")`
  - All existing En keys (zero..nine, a moment..1 year 1 month, %s from now, %s ago, now, today, tomorrow, yesterday, %s and %s, comma, and, and comma) translated to 中文.
- Add `Zh` case to the `match locale` in `msg_str` dispatching to `msg_Zh`.

### Target: `moonbit/src/humanize/i18n.mbt`
- Add `Zh` to the `Locale` enum (alongside `En`, `RuRU`).
- Add `Scientific`, `Exponent`, `Connector` to `MsgId` enum.
- Ensure `MsgId::to_string` / dispatch covers new IDs (matching existing pattern: `Scientific => "scientific"`, etc.).

### Target: `moonbit/src/humanize/i18n_test.mbt`
- Add test: `locale_zh_connector_is_space` — `msg_str(Zh, Connector) == " "`.
- Add test: `locale_zh_has_full_coverage` — iterate over all `MsgId` values, assert `msg_str(Zh, id)` is non-empty and differs appropriately (or at least present).

---

## Feature 3 — i18n Coverage (`humanize.po`)

Update three `.po` files at `src/humanize/locale/<lang>/LC_MESSAGES/humanize.po`:

1. **`en`** — add entries for `Scientific`, `Exponent`, `Connector` (and confirm existing coverage).
2. **`ru_RU`** — add the same three keys with Russian translations.
3. **`zh`** — create/complete `humanize.po` with all keys translated to 中文 (including the three new ones).

Each new entry follows the existing `.po` format (header, `msgid`/`msgstr`). After editing, run `msgfmt --check` (or `python -m babel`/`msgfmt.py` if gettext unavailable on Windows) and confirm zero errors for all three.

---

## Build / Codegen

- Re-run `scripts/po2mbt` (or `bash scripts/po2mbt`) so `.po` changes regenerate `i18n_data.mbt` `Map` literals. **Caveat:** the script generates En/RuRU today; verify it also emits the new `zh` map and the three new `MsgId` keys. If the script hardcodes locales, extend it to include `zh` and the new keys (or manually add `msg_Zh` after generation, keeping the script as source of truth for en/ru). Coordinate with Feature 2 manual edits to avoid clobbering.
- Run `moon test` to validate `.mbt` changes.

---

## Files Touched

| File | Change |
|------|--------|
| `moonbit/src/humanize/number.mbt` | Add `scientific()` method + decimal-word helper |
| `moonbit/src/humanize/number_test.mbt` | Add scientific-mode tests |
| `moonbit/src/humanize/i18n.mbt` | Add `Zh` locale, `Scientific`/`Exponent`/`Connector` MsgIds |
| `moonbit/src/humanize/i18n_data.mbt` | Add `msg_Zh` map + dispatch (via po2mbt or manual) |
| `moonbit/src/humanize/i18n_test.mbt` | Add zh connector + coverage tests |
| `src/humanize/locale/en/LC_MESSAGES/humanize.po` | Backfill 3 keys |
| `src/humanize/locale/ru_RU/LC_MESSAGES/humanize.po` | Backfill 3 keys |
| `src/humanize/locale/zh/LC_MESSAGES/humanize.po` | Create/complete full translation |
| `scripts/po2mbt` | (if needed) extend to emit `zh` + new keys |

---

## Verification Checklist

- [ ] `moon test` passes (including new number + i18n tests).
- [ ] `msgfmt --check` passes for `en`, `ru_RU`, `zh` humanize.po.
- [ ] Worked example reproduces: en `scientific(3.14159, 2, 3)` → `"3.14 × 10^thousandth power"`.
- [ ] zh connector renders as space in `scientific()` output.
- [ ] ru decimal mantissa renders in Russian fractional form.
- [ ] No public function signatures changed (backward compatible).

---

## Notes / Open Decisions

- **Decimal-mode prec≥1 digit form:** Spec table mixes word (prec=0) and digit (prec=2 under *scientific* column) forms. We interpret the digit examples as belonging to scientific mode; decimal mode always uses word form, consistent with the existing `NumberFormatter` design. If the user wants digit-form decimal output too, that is a separate enhancement.
- **Windows gettext:** `msgfmt` may be unavailable; fall back to `pip install babel` and `pybabel` or a Python `.po` validator. Will confirm during execution.
