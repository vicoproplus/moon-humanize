// Current-time source for the wasm target, mirroring python-humanize's
// `clock._now()`. Returns the current Unix time as nanoseconds since the epoch.
//
// This file is compiled only for the `wasm`/`wasm-gc` targets (declared in
// `moon.pkg`), the primary deployment target for moon-humanize. The native
// target does not currently expose a wall-clock (no `link`/FFI wiring in this
// build setup); `now()` is only required by the in-browser humanizers, which
// always run on wasm.
//
// We use `@env.now()` (current time in milliseconds) from moonbitlang/core/env
// rather than depending on the unpublished `moonbitlang/web` package, so the
// package builds with no extra dependencies.

/// Current time in nanoseconds since the Unix epoch.
pub fn now() -> Int64 {
  // @env.now() returns milliseconds since the Unix epoch (as UInt64).
  // For realistic timestamps this is a small positive value, so a bit
  // reinterpret to Int64 preserves the numeric value.
  let ms : Int64 = @env.now().reinterpret_as_int64()
  ms * 1000000L
}
