// Tests for number.mbt — golden values derived from python-humanize.

test "clamp" {
  @test.assert_eq(clamp(1.5, 0.0, 1.0), 1.0)
  @test.assert_eq(clamp(-1.0, 0.0, 1.0), 0.0)
  @test.assert_eq(clamp(0.5, 0.0, 1.0), 0.5)
}

test "intcomma" {
  @test.assert_eq(intcomma("100"), "100")
  @test.assert_eq(intcomma("1000"), "1,000")
  @test.assert_eq(intcomma("1000000"), "1,000,000")
  @test.assert_eq(intcomma("-1000000"), "-1,000,000")
  @test.assert_eq(intcomma("1234.56"), "1,234.56")
  @test.assert_eq(intcomma("0"), "0")
}

test "apnumber" {
  @test.assert_eq(apnumber(1), "one")
  @test.assert_eq(apnumber(9), "nine")
  @test.assert_eq(apnumber(0), "zero")
  @test.assert_eq(apnumber(10), "10")
  @test.assert_eq(apnumber(100), "100")
}

test "ordinal" {
  @test.assert_eq(ordinal(1), "1st")
  @test.assert_eq(ordinal(2), "2nd")
  @test.assert_eq(ordinal(3), "3rd")
  @test.assert_eq(ordinal(4), "4th")
  @test.assert_eq(ordinal(11), "11th")
  @test.assert_eq(ordinal(12), "12th")
  @test.assert_eq(ordinal(13), "13th")
  @test.assert_eq(ordinal(21), "21st")
  @test.assert_eq(ordinal(22), "22nd")
  @test.assert_eq(ordinal(100), "100th")
  @test.assert_eq(ordinal(101), "101st")
  @test.assert_eq(ordinal(111), "111th")
  @test.assert_eq(ordinal(1003), "1003rd")
}

test "scientific" {
  @test.assert_eq(scientific(12345, 2), "1.23e+04")
  @test.assert_eq(scientific(0, 2), "0.00e+00")
  @test.assert_eq(scientific(123, 2), "1.23e+02")
  @test.assert_eq(scientific(299792458, 2), "3.00e+08")
  @test.assert_eq(scientific(-12345, 2), "-1.23e+04")
}

test "format_frac" {
  @test.assert_eq(format_frac(1234.567, 2), "1234.57")
  @test.assert_eq(format_frac(0.5, 2), "0.50")
  @test.assert_eq(format_frac(1.0, 0), "1")
}

test "intword" {
  @test.assert_eq(intword(@bigint.BigInt::from_int(1000000)), "1.0 million")
  @test.assert_eq(intword(@bigint.BigInt::from_int(1200000)), "1.2 million")
  @test.assert_eq(intword(@bigint.BigInt::from_int(1000)), "1.0 thousand")
  @test.assert_eq(intword(@bigint.BigInt::from_int(999)), "999")
  @test.assert_eq(intword(@bigint.BigInt::from_int(0)), "0")
  @test.assert_eq(
    intword(@bigint.BigInt::from_int(1234567890)),
    "1.2 billion",
  )
}

test "fractional" {
  @test.assert_eq(fractional(@bigint.BigInt::from_int(1), 4), "one quarter")
  @test.assert_eq(fractional(@bigint.BigInt::from_int(1), 2), "one half")
  @test.assert_eq(fractional(@bigint.BigInt::from_int(1), 3), "one third")
  @test.assert_eq(fractional(@bigint.BigInt::from_int(3), 4), "three quarters")
  @test.assert_eq(fractional(@bigint.BigInt::from_int(1), 10), "one tenth")
  @test.assert_eq(fractional(@bigint.BigInt::from_int(1), 100), "one hundredth")
}
