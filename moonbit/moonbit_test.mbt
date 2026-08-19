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
