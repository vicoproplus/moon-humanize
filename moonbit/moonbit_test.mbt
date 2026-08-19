// Root-package public API smoke tests for the 20/20 re-export.
// Run with: moon test --target native

test "version is 0.1.2 and consistent" {
  @test.assert_eq(__version__, "0.1.2")
}

test "naturalday re-export" {
  let d = @humanize.Date::{ year: 2026, month: 8, day: 19 }
  @test.assert_eq(naturalday(d, when = d), "today")
  @test.assert_eq(naturalday(@humanize.Date::{ year: 2026, month: 8, day: 20 }, when = d), "tomorrow")
  @test.assert_eq(naturalday(@humanize.Date::{ year: 2026, month: 8, day: 18 }, when = d), "yesterday")
}

test "naturaldate re-export" {
  let d = @humanize.Date::{ year: 2026, month: 8, day: 19 }
  @test.assert_eq(naturaldate(@humanize.Date::{ year: 2026, month: 3, day: 15 }, when = d), "Mar 15 2026")
}

test "naturaldelta re-export" {
  @test.assert_eq(naturaldelta(@humanize.TimeInput::from_seconds(1.0)), "a second")
  @test.assert_eq(naturaldelta(@humanize.TimeInput::from_seconds(30.0)), "30 seconds")
  @test.assert_eq(
    naturaldelta(@humanize.TimeInput::from_delta(@humanize.timedelta(days = 1))),
    "a day",
  )
}

test "naturaltime re-export" {
  @test.assert_eq(naturaltime(@humanize.TimeInput::from_seconds(5.0)), "5 seconds ago")
  @test.assert_eq(
    naturaltime(@humanize.TimeInput::from_delta(@humanize.timedelta(days = 1))),
    "a day ago",
  )
}

test "precisedelta re-export" {
  let pd1 = @humanize.TimeInput::from_delta(@humanize.timedelta(seconds = 176592, microseconds = 5486))
  @test.assert_eq(precisedelta(pd1), "2 days, 1 hour, 3 minutes and 12.01 seconds")
}

test "naturalsize re-export" {
  @test.assert_eq(naturalsize(1000000.0), "1.0 MB")
  @test.assert_eq(naturalsize(1000000.0, binary = true), "976.6 KiB")
}

test "natural_list re-export" {
  @test.assert_eq(natural_list(["a", "b", "c"]), "a, b and c")
  @test.assert_eq(natural_list(["a", "b"], style = "or"), "a or b")
}

test "i18n re-export" {
  // activate returns Some(locale) for a known locale; None for English/unknown.
  @test.assert_eq(activate("ru_RU").is_some(), true)
  @test.assert_eq(activate("en_US").is_none(), true)
  // After deactivate we are back to English separators.
  ignore(activate("ru_RU"))
  deactivate()
  @test.assert_eq(thousands_separator(), ",")
  @test.assert_eq(decimal_separator(), ".")
}
