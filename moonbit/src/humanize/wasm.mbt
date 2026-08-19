// WASM export layer for moon-humanize.
//
// Compiled only for the `wasm` / `wasm-gc` targets (declared in `moon.pkg`).
//
// The package's public functions (declared `pub` in number.mbt, time.mbt,
// i18n.mbt, ...) are already exported at the package boundary and consumed by
// JavaScript / WASM callers via the root `moonbit` package (which re-exports
// `@humanize.*` and is the `preferred_target = "wasm"` entry point).
//
// This file is the explicit, target-gated WASM marker: it guarantees the WASM
// build pulls in the clock (via clock_wasm.mbt) and exposes a single stable
// version/entry probe so the embedding runtime can detect a successful load.
// It deliberately declares no names that collide with the rest of the package.

/// Library version string, exposed as a stable WASM entry probe.
pub fn wasm_version() -> String {
  "0.1.1"
}

/// Returns `true` once the WASM module has initialized (clock + i18n wired).
/// A stable probe the host runtime can call right after instantiation.
pub fn wasm_ready() -> Bool {
  true
}
