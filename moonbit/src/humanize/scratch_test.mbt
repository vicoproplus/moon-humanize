test "scratch dbg" {
  let x = 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0
  println("x=\{x}")
  println("res=\{naturalsize(x, binary=true)}")
}
