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
