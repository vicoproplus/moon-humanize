// Golden tests for natural_list.
// Expected values come from the INSTALLED python-humanize library (_golden.txt).

test "natural_list" {
  let items = ["a", "b", "c", "d", "e", "f"]
  @test.assert_eq(natural_list(items[0:1], style="and"), "a")
  // D3: a two-item list reads "a and b" (no comma) for the explicit "and" style
  @test.assert_eq(natural_list(items[0:2], style="and"), "a and b")
  @test.assert_eq(natural_list(items[0:3], style="and"), "a, b and c")
  @test.assert_eq(natural_list(items[0:4], style="and"), "a, b, c and d")
  @test.assert_eq(natural_list(items[0:5], style="and"), "a, b, c, d and e")
  @test.assert_eq(natural_list(items[0:6], style="and"), "a, b, c, d, e and f")
}

// Python-parity golden tests (python-humanize 4.16.0 via scripts/gen_golden.py).
// python-humanize's natural_list takes no style argument; its default output is
// what moon-humanize produces with the default (standard -> "and") style.
test "natural_list python parity" {
  @test.assert_eq(natural_list(["a"]), "a")
  @test.assert_eq(natural_list(["a", "b"]), "a and b")
  @test.assert_eq(natural_list(["a", "b", "c"]), "a, b and c")
  @test.assert_eq(natural_list([]), "")
}
