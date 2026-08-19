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
