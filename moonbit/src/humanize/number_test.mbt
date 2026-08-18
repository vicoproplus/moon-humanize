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

// Python-parity golden tests (python-humanize 4.16.0 via scripts/gen_golden.py).
// Re-generate with `python scripts/gen_golden.py --mbt`; run `moon test` once the
// toolchain is available to confirm byte-for-byte parity.
test "number python parity" {
  // intword
  @test.assert_eq(intword("100"), "100")
  @test.assert_eq(intword("999"), "999")
  @test.assert_eq(intword("1000"), "1.0 thousand")
  @test.assert_eq(intword("1234567"), "1.2 million")
  @test.assert_eq(intword("999999"), "1.0 million")
  @test.assert_eq(intword("1000000000000000000000000000000"), "1.0 nonillion")
  @test.assert_eq(intword("8100000000000000000000000000000000"), "8.1 decillion")
  // intcomma
  @test.assert_eq(intcomma("1234567.89"), "1,234,567.89")
  @test.assert_eq(intcomma("100"), "100")
  @test.assert_eq(intcomma("-1000000"), "-1,000,000")
  // ordinal
  @test.assert_eq(ordinal("0"), "0th")
  @test.assert_eq(ordinal("1"), "1st")
  @test.assert_eq(ordinal("2"), "2nd")
  @test.assert_eq(ordinal("11"), "11th")
  @test.assert_eq(ordinal("12"), "12th")
  @test.assert_eq(ordinal("13"), "13th")
  @test.assert_eq(ordinal("112"), "112th")
  @test.assert_eq(ordinal("103"), "103rd")
  @test.assert_eq(ordinal("121"), "121st")
  // metric
  @test.assert_eq(metric(0.0), "0.00")
  @test.assert_eq(metric(25000.0), "25.0 k")
  @test.assert_eq(metric(100000000000000.0), "100 T")
  @test.assert_eq(metric(999.0), "999")
  // apnumber
  @test.assert_eq(apnumber("1"), "one")
  @test.assert_eq(apnumber("9"), "nine")
  @test.assert_eq(apnumber("10"), "10")
  @test.assert_eq(apnumber("100"), "100")
  // fractional
  @test.assert_eq(fractional("0.3"), "3/10")
  @test.assert_eq(fractional("0.5"), "1/2")
  @test.assert_eq(fractional("1.5"), "1 1/2")
  @test.assert_eq(fractional("3.14"), "3 7/50")
}

test "to_scientific" {
  @test.assert_eq(to_scientific(3141.59, precision=2, exponent=3), "3.14 x 10^3")
  @test.assert_eq(to_scientific(500.0, precision=2, exponent=2), "5.00 x 10^2")
  @test.assert_eq(to_scientific(0.789, precision=2, exponent=-3), "0.79 x 10^-3")
}

test "to_decimal" {
  @test.assert_eq(to_decimal(1234567.891, decimals=2), "1,234,567.89")
  @test.assert_eq(to_decimal(1234.5, decimals=0), "1,235")
  @test.assert_eq(to_decimal(-0.5, decimals=1), "-0.5")
  @test.assert_eq(to_decimal(100.0, decimals=2), "100.00")
}

test "integer_to_words" {
  @test.assert_eq(integer_to_words(0), "zero")
  @test.assert_eq(integer_to_words(123), "one hundred and twenty-three")
  @test.assert_eq(integer_to_words(1000000), "one million")
  @test.assert_eq(integer_to_words(-45), "negative forty-five")
  @test.assert_eq(integer_to_words(1234567), "one million two hundred and thirty-four thousand five hundred and sixty-seven")
}

test "scientific_double_localized" {
  // default (no locale) falls back to English template "%s x 10^%s"
  @test.assert_eq(scientific_localized(3141.59, precision=2, exponent=3), "3.14 x 10^3")
  // ru_RU uses the "×" connector
  ignore(activate("ru_RU"))
  @test.assert_eq(scientific_localized(3141.59, precision=2, exponent=3), "3.14 × 10^3")
  // zh_CN / zh use the no-space connector
  ignore(activate("zh_CN"))
  @test.assert_eq(scientific_localized(3141.59, precision=2, exponent=3), "3.14×10^3")
  ignore(activate("zh"))
  @test.assert_eq(scientific_localized(3141.59, precision=2, exponent=3), "3.14×10^3")
  deactivate()
}
