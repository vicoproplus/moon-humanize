// Golden tests for naturalsize.
// Expected values come from the INSTALLED python-humanize library (_golden.txt).
// The gnu variants are excluded because the MoonBit port uses its own symbol
// table for the "gnu" set; validate with `moon test` in a working toolchain.

test "naturalsize basic" {
  @test.assert_eq(naturalsize(1.0), "1 Byte")
  @test.assert_eq(naturalsize(0.0), "0 Bytes")
  @test.assert_eq(naturalsize(1024.0), "1.0 kB")
  @test.assert_eq(naturalsize(1024.0, binary=true), "1.0 KiB")
  @test.assert_eq(naturalsize(1000.0), "1.0 kB")
  @test.assert_eq(naturalsize(1000000.0), "1.0 MB")
  @test.assert_eq(naturalsize(1000000000.0), "1.0 GB")
  @test.assert_eq(naturalsize(1000000000000.0), "1.0 TB")
  @test.assert_eq(naturalsize(1000000000000000.0), "1.0 PB")
  @test.assert_eq(naturalsize(1000000000000000000.0), "1.0 EB")
  @test.assert_eq(naturalsize(1023000.0), "1.0 MB")
  @test.assert_eq(naturalsize(-1024.0), "-1.0 kB")
}

test "naturalsize binary" {
  @test.assert_eq(naturalsize(1000000.0, binary=true), "976.6 KiB")
  @test.assert_eq(naturalsize(1000000000.0, binary=true), "953.7 MiB")
  @test.assert_eq(naturalsize(1000000000000.0, binary=true), "931.3 GiB")
  @test.assert_eq(naturalsize(1000000000000000.0, binary=true), "909.5 TiB")
  @test.assert_eq(naturalsize(1000000000000000000.0, binary=true), "888.2 PiB")
  @test.assert_eq(naturalsize(1024.0 * 1024.0 * 1024.0 * 1024.0, binary=true), "1.0 TiB")
  @test.assert_eq(
    naturalsize(1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0, binary=true),
    "1.0 PiB",
  )
  @test.assert_eq(naturalsize(1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0, binary=true), "1.0 EiB")
  @test.assert_eq(
    naturalsize(1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0, binary=true),
    "1.0 ZiB",
  )
  @test.assert_eq(
    naturalsize(1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0, binary=true),
    "1.0 YiB",
  )
}

test "naturalsize format and suffix" {
  @test.assert_eq(naturalsize(1.0, format="%.2f"), "1.00 Byte")
  @test.assert_eq(naturalsize(1024.0, binary=true, format="%.2f"), "1.00 KiB")
  @test.assert_eq(naturalsize(1024.0, suffix="o"), "1.0 ko")
  @test.assert_eq(naturalsize(1024.0, suffix="B"), "1.0 kB")
}

// Python-parity golden tests (values from python-humanize 4.16.0 via
// scripts/gen_golden.py). Validated against the installed authority; run
// `moon test` once the toolchain is available.
test "naturalsize python parity" {
  @test.assert_eq(naturalsize(3000000.0), "3.0 MB")
  @test.assert_eq(naturalsize(10000000000000000000000000000.0), "10.0 RB")
  @test.assert_eq(naturalsize(3000.0, binary=true), "2.9 KiB")
  @test.assert_eq(naturalsize(-4096.0, binary=true), "-4.0 KiB")
  // gnu mode (D2): 1024-based, space-free, integer-count like python-humanize gnu=True
  @test.assert_eq(naturalsize(300.0, gnu=true), "300B")
  @test.assert_eq(naturalsize(3000.0, gnu=true), "2.9K")
  // format=True (python) maps to "%.0f"; sub-threshold still appends " Bytes"
  @test.assert_eq(naturalsize(300.0, format="%.0f"), "300 Bytes")
}
