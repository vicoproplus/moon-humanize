// Tests for number.mbt — golden values verified against python-humanize.

test "clamp" {
  @test.assert_eq(clamp(123.456), "123.456")
  @test.assert_eq(clamp(123.456, floor=Some(1000.0)), "<1000")
  @test.assert_eq(clamp(123.456, ceil=Some(1.0)), ">1")
  @test.assert_eq(clamp(123.456, floor=Some(1000.0), floor_token="~"), "~1000")
}

test "metric" {
  @test.assert_eq(metric(1500.0, unit="V"), "1.50 kV")
  @test.assert_eq(metric(2.0e8, unit="W"), "200 MW")
  @test.assert_eq(metric(220.0e-6, unit="F"), "220 μF")
  @test.assert_eq(metric(1.0e-14, unit="", precision=4), "10.00 f")
  @test.assert_eq(metric(1.0e40), "1.00 x 10⁴⁰")
  @test.assert_eq(metric(1234.0), "1.23 k")
}

test "intcomma" {
  @test.assert_eq(intcomma("100"), "100")
  @test.assert_eq(intcomma("1000"), "1,000")
  @test.assert_eq(intcomma("1000000"), "1,000,000")
  @test.assert_eq(intcomma("1234567.25"), "1,234,567.25")
  @test.assert_eq(intcomma("1234.5454545", ndigits=Some(2)), "1,234.55")
  @test.assert_eq(intcomma("14308.40", ndigits=Some(1)), "14,308.4")
}

test "intword" {
  @test.assert_eq(intword("100"), "100")
  @test.assert_eq(intword("12400"), "12.4 thousand")
  @test.assert_eq(intword("1000000"), "1.0 million")
  @test.assert_eq(intword("1200000000"), "1.2 billion")
  @test.assert_eq(intword("8100000000000000000000000000000000"), "8.1 decillion")
  @test.assert_eq(intword("1234000", format="%0.3f"), "1.234 million")
}

test "apnumber" {
  @test.assert_eq(apnumber("0"), "zero")
  @test.assert_eq(apnumber("5"), "five")
  @test.assert_eq(apnumber("10"), "10")
  @test.assert_eq(apnumber("7"), "seven")
  @test.assert_eq(apnumber("foo"), "foo")
}

test "fractional" {
  @test.assert_eq(fractional("0.3"), "3/10")
  @test.assert_eq(fractional("1.3"), "1 3/10")
  @test.assert_eq(fractional("1"), "1")
  @test.assert_eq(fractional("0.3333333333"), "1/3")
  @test.assert_eq(fractional("ten"), "ten")
}

test "scientific" {
  @test.assert_eq(scientific("0.3"), "3.00 x 10⁻¹")
  @test.assert_eq(scientific("500"), "5.00 x 10²")
  @test.assert_eq(scientific("-1000"), "-1.00 x 10³")
  @test.assert_eq(scientific("1000", precision=1), "1.0 x 10³")
  @test.assert_eq(scientific("1000", precision=3), "1.000 x 10³")
  @test.assert_eq(scientific("99"), "9.90 x 10¹")
  @test.assert_eq(scientific("foo"), "foo")
}

test "ordinal" {
  @test.assert_eq(ordinal("1"), "1st")
  @test.assert_eq(ordinal("2"), "2nd")
  @test.assert_eq(ordinal("3"), "3rd")
  @test.assert_eq(ordinal("4"), "4th")
  @test.assert_eq(ordinal("11"), "11th")
  @test.assert_eq(ordinal("12"), "12th")
  @test.assert_eq(ordinal("13"), "13th")
  @test.assert_eq(ordinal("100"), "100th")
  @test.assert_eq(ordinal("102"), "102nd")
  @test.assert_eq(ordinal("111"), "111th")
  @test.assert_eq(ordinal("112"), "112th")
  @test.assert_eq(ordinal("23"), "23rd")
  @test.assert_eq(ordinal("foo"), "foo")
}
