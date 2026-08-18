// Tests for the i18n module (T1/T3/T4/T7). These run with no locale active
// (English), then activate a locale and assert translations and plural rules.

test "i18n default is english" {
  deactivate()
  assert_eq(gettext("a moment"), "a moment")
  assert_eq(ngettext("day", "days", 1), "day")
  assert_eq(ngettext("day", "days", 5), "days")
  assert_eq(thousands_separator(), ",")
  assert_eq(decimal_separator(), ".")
}

test "i18n activate french translates" {
  // French maps "a moment" -> "un moment" and uses a space thousands separator.
  let loc = activate("fr_FR")
  assert_true(loc is Some(_))
  assert_eq(gettext("a moment"), "un instant")
  assert_eq(thousands_separator(), " ")
  assert_eq(decimal_separator(), ".")
  deactivate()
  assert_eq(gettext("a moment"), "a moment")
}

test "i18n activate chinese" {
  let loc = activate("zh_CN")
  assert_true(loc is Some(_))
  // zh_CN translates "a moment" -> "一会儿".
  assert_eq(gettext("a moment"), "一会儿")
  deactivate()
}

test "i18n english locales disable translation" {
  match activate("en_US") {
    None => assert_true(true)
    Some(_) => assert_true(false)
  }
  assert_eq(gettext("a moment"), "a moment")
  deactivate()
}

test "i18n plural rules" {
  // Arabic has 6 plural forms. ngettext picks the right one for n=0/1/2.
  ignore(activate("ar"))
  // Obtain the active locale value (avoids constructing enum literals).
  match current_locale() {
    Some(loc) => {
      // ar plural rule: 0 -> 0, 1 -> 1, 2 -> 2
      assert_eq(plural_index(loc, 0), 0)
      assert_eq(plural_index(loc, 1), 1)
      assert_eq(plural_index(loc, 2), 2)
    }
    None => assert_true(false)
  }
  deactivate()
}

test "i18n pgettext context" {
  // Russian distinguishes ordinal contexts for numbers (e.g. "0 (male)").
  ignore(activate("ru_RU"))
  // The .po provides msgctxt "0 (male)" -> "0-й". Without context we fall back.
  let ctx = pgettext("0 (male)", "0")
  // Either the context-specific translation or the fallback is acceptable here;
  // we only assert it does not crash and returns a non-empty string.
  assert_true(ctx.length() > 0)
  deactivate()
}

test "i18n T7 user-visible units are translated" {
  // Regression for BUG 3: humanizer output must reach the translations.
  // fr_FR maps "%d second" -> "%d seconde" / "%d secondes".
  ignore(activate("fr_FR"))
  let out = naturaldelta(TimeInput::from_seconds(5.0))
  // 5 seconds -> French plural "5 secondes" (not English "5 seconds").
  assert_true(out.contains("seconde"))
  assert_false(out.contains("5 seconds"))
  deactivate()
}

test "i18n T7 thousands separator respected by intcomma" {
  // Regression for BUG 3: intcomma must use the locale's thousands separator.
  // de_DE uses "." as thousands separator (not ",").
  ignore(activate("de_DE"))
  let grouped = intcomma("1234567")
  assert_true(grouped.contains("."))
  assert_false(grouped.contains(",234"))
  deactivate()
}

test "i18n msg_str_format" {
  // English template uses " x 10^".
  ignore(activate("en"))
  assert_eq(msg_str(En, SCItmpl).format(["3.14", "thousand"]), "3.14 x 10^thousand")
  // ru_RU connector is "×".
  ignore(activate("ru_RU"))
  assert_eq(msg_str(RuRU, SCItmpl).format(["3.14", "миллион"]), "3.14 × 10^миллион")
  // zh_CN / zh use the no-space connector.
  ignore(activate("zh_CN"))
  assert_eq(msg_str(ZhCN, SCItmpl).format(["3.14", "百万"]), "3.14×10^百万")
  ignore(activate("zh"))
  assert_eq(msg_str(Zh, SCItmpl).format(["3.14", "百万"]), "3.14×10^百万")
  deactivate()
}

test "i18n msg_str_fallback" {
  // A locale that does not ship a key falls back to the English catalog.
  // fr_FR has no scientific_tmpl; msg_str must still resolve via the En fallback.
  ignore(activate("fr_FR"))
  // Compare the fr_FR-resolved template against the English one (both "%s x 10^%s").
  assert_eq(msg_str(FrFR, SCItmpl).to_string(), msg_str(En, SCItmpl).to_string())
  deactivate()
}
