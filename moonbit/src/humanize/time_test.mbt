// Golden tests for the time humanizers.
// Expected values are generated from the INSTALLED python-humanize library
// (see _gen_golden.py and _golden.txt).

test "naturaldelta seconds" {
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(0.0)), "a moment")
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(1.0)), "a second")
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(23.5)), "23 seconds")
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(30.0)), "30 seconds")
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(-0.1)), "a moment")
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(-1.0)), "a second")
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(-23.5)), "23 seconds")
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(-30.0)), "30 seconds")
}

test "naturaldelta days" {
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=1))), "a day")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=2))), "2 days")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=30))), "a month")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=59))), "2 months")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=60))), "2 months")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=90))), "3 months")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=3000))), "8 years")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=3600))), "9 years")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=7200))), "19 years")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=86400))), "236 years")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=172800))), "473 years")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=8640000))), "23,671 years")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=-1))), "a day")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=-2))), "2 days")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=-365))), "a year")
}

test "naturaldelta seconds delta" {
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(seconds=1))), "a second")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(seconds=360))), "6 minutes")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(seconds=720))), "12 minutes")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(seconds=420))), "7 minutes")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(seconds=480))), "8 minutes")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(seconds=780))), "13 minutes")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(seconds=1100))), "18 minutes")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(seconds=500))), "8 minutes")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(seconds=240))), "4 minutes")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(seconds=660))), "11 minutes")
}

test "naturaldelta months=false" {
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=1)), months=false), "a day")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=2)), months=false), "2 days")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=9)), months=false), "9 days")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=35)), months=false), "35 days")
  @test.assert_eq(naturaldelta(TimeInput::from_delta(timedelta(days=65)), months=false), "65 days")
  @test.assert_eq(
    naturaldelta(TimeInput::from_delta(timedelta(days=400)), months=false),
    "1 year, 35 days",
  )
  @test.assert_eq(
    naturaldelta(TimeInput::from_delta(timedelta(days=500)), months=false),
    "1 year, 135 days",
  )
}

test "naturaltime" {
  @test.assert_eq(naturaltime(TimeInput::from_seconds(22.5)), "22 seconds ago")
  @test.assert_eq(naturaltime(TimeInput::from_seconds(23.5)), "24 seconds ago")
  @test.assert_eq(naturaltime(TimeInput::from_seconds(23.9)), "24 seconds ago")
  @test.assert_eq(naturaltime(TimeInput::from_seconds(30.0)), "30 seconds ago")
  @test.assert_eq(naturaltime(TimeInput::from_delta(timedelta(days=0))), "now")
  @test.assert_eq(naturaltime(TimeInput::from_delta(timedelta(days=1))), "a day ago")
  @test.assert_eq(naturaltime(TimeInput::from_delta(timedelta(days=2))), "2 days ago")
  @test.assert_eq(naturaltime(TimeInput::from_delta(timedelta(days=10000))), "27 years ago")
  @test.assert_eq(naturaltime(TimeInput::from_delta(timedelta(days=-10000))), "27 years from now")
  @test.assert_eq(naturaltime(TimeInput::from_delta(timedelta(days=365))), "a year ago")
  @test.assert_eq(naturaltime(TimeInput::from_delta(timedelta(days=730))), "2 years ago")
  @test.assert_eq(naturaltime(TimeInput::from_delta(timedelta(days=400))), "1 year, 1 month ago")
  @test.assert_eq(naturaltime(TimeInput::from_delta(timedelta(days=100000))), "273 years ago")
}

test "naturaldelta/naturaltime large seconds (Int64 overflow guard)" {
  // 10_000_000 s ~= 115.7 days; 200_000_000 s ~= 2314 days. These must not
  // overflow Int32 (the bug fixed in seconds_to_delta). Expected values come
  // from python-humanize 4.16.0.
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(10_000_000.0)), "4 months")
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(200_000_000.0)), "6 years")
  @test.assert_eq(naturaldelta(TimeInput::from_seconds(10_000_000.0), months=false), "115 days")
  @test.assert_eq(naturaltime(TimeInput::from_seconds(10_000_000.0)), "4 months ago")
  @test.assert_eq(naturaltime(TimeInput::from_seconds(200_000_000.0)), "6 years ago")
}

test "precisedelta" {
  // pd1: 2 days, 1 hour, 3 minutes, 12 seconds, 5486 microseconds
  let pd1 = TimeInput::from_delta(timedelta(seconds=176592, microseconds=5486))
  @test.assert_eq(precisedelta(pd1), "2 days, 1 hour, 3 minutes and 12.01 seconds")
  // pd3 with integer format
  @test.assert_eq(precisedelta(pd1, format="%d"), "2 days, 1 hour, 3 minutes and 12 seconds")
  // pd4: 1 day, 1 hour, 1 minute, 1 second, 1 microsecond
  let pd4 = TimeInput::from_delta(timedelta(seconds=90061, microseconds=1))
  @test.assert_eq(precisedelta(pd4), "1 day, 1 hour, 1 minute and 1 second")
  // pd5: minimum unit hours
  @test.assert_eq(precisedelta(pd4, minimum_unit=TimeUnit::hours()), "1 day and 1.02 hours")
  // pd6: 1 second, 400000 microseconds
  let pd6 = TimeInput::from_delta(timedelta(seconds=1, microseconds=400000))
  @test.assert_eq(precisedelta(pd6), "1.40 seconds")
  // pd7: suppress days (1 day, 2 hours, 3 minutes, 4 seconds, 5 microseconds)
  let pd7 = TimeInput::from_delta(timedelta(seconds=93784, microseconds=5))
  @test.assert_eq(precisedelta(pd7, suppress=[TimeUnit::days()]), "26 hours, 3 minutes and 4 seconds")
  // pd8: suppress seconds and microseconds
  let pd8 = TimeInput::from_delta(timedelta(seconds=93784, microseconds=5))
  @test.assert_eq(
    precisedelta(pd8, suppress=[TimeUnit::seconds(), TimeUnit::microseconds()]),
    "1 day, 2 hours and 3.07 minutes",
  )
  // pd12: 1,800,000,000 seconds
  let pd12 = TimeInput::from_delta(timedelta(seconds=1800000000))
  @test.assert_eq(precisedelta(pd12), "57 years, 28 days and 8 hours")
  // pd13: 1 day, 1 second, min unit microseconds
  let pd13 = TimeInput::from_delta(timedelta(days=1, seconds=1))
  @test.assert_eq(
    precisedelta(pd13, minimum_unit=TimeUnit::microseconds()),
    "1 day and 1 second",
  )
  // pd16: 1,899 years, 227 days, 10h10m10s
  let pd16 = TimeInput::from_delta(timedelta(days=365 * 1899 + 227, seconds=36610))
  @test.assert_eq(
    precisedelta(pd16),
    "1,899 years, 7 months, 13 days, 10 hours, 10 minutes and 10 seconds",
  )
}
