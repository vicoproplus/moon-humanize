// Current-time source for the native target, mirroring python-humanize's
// `clock._now()`. Returns the current Unix time as nanoseconds since the epoch.
//
// This file is compiled only for the `native` target (declared in `moon.pkg`).
// It reuses `@env.now()` (current time in milliseconds) from
// moonbitlang/core/env, the same primitive the wasm build relies on, so the
// native build links and the in-browser humanizers have a clock on every
// target. Previously the native target had no `now()`, which caused a link-time
// failure ("undefined symbol: humanize/clock.now") and a runtime panic
// ("时钟未注入"). Providing it here closes that gap.

/// Current time in nanoseconds since the Unix epoch.
pub fn now() -> Int64 {
  // @env.now() returns milliseconds since the Unix epoch (as UInt64).
  // For realistic timestamps this is a small positive value, so a bit
  // reinterpret to Int64 preserves the numeric value.
  let ms : Int64 = @env.now().reinterpret_as_int64()
  ms * 1000000L
}
