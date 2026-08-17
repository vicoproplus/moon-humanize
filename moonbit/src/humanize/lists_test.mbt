// Golden tests for natural_list.
// Expected values come from the INSTALLED python-humanize library (_golden.txt).

test "natural_list" {
  let items = ["a", "b", "c", "d", "e", "f"]
  @test.assert_eq(natural_list(items[0:1], style="and"), "a")
  @test.assert_eq(natural_list(items[0:2], style="and"), "a, b")
  @test.assert_eq(natural_list(items[0:3], style="and"), "a, b and c")
  @test.assert_eq(natural_list(items[0:4], style="and"), "a, b, c and d")
  @test.assert_eq(natural_list(items[0:5], style="and"), "a, b, c, d and e")
  @test.assert_eq(natural_list(items[0:6], style="and"), "a, b, c, d, e and f")
}
