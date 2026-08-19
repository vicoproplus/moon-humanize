// Root-package public API smoke tests for the 20/20 re-export.
// Run with: moon test --target native

test "version is 0.1.2 and consistent" {
  @test.assert_eq(__version__, "0.1.2")
}
