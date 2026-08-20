# moon-humanize 根包公开 API 20/20 补齐 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 12 root-package forwarders + the `__version__` constant so the public API reaches 20/20 and matches python-humanize 4.16.0's `__all__`, with zero changes to the functional `src/humanize` logic.

**Architecture:** The root package (`moonbit/moonbit.mbt`) is a thin re-export layer over `src/humanize`. This plan only appends `pub fn` forwarders that pass arguments straight through to `@humanize.*` (no logic), plus a version constant. Internal types (`Date`, `TimeInput`, `TimeUnit`, `DateTime`, `Locale`) are referenced cross-package via the `@humanize.` qualifier; `TimeUnit` variants are referenced through the `TimeUnit::seconds()` accessor because the enum constructors are not exported cross-package.

**Tech Stack:** MoonBit (moon 0.1.20260819 / moonc v0.10.9), native target (`moon test --target native`).

## Global Constraints

- 模式：根包薄转发层补齐（仅补导出 + `__version__`，不动内部实现逻辑）。
- 基准：`python-humanize` 4.16.0（20 个公开符号）。
- 根包公开 API 须达 **20/20**，命名与 python-humanize `__all__` 逐一对齐。
- 验收环境统一 **`--target native`**（绕开本机 wasm `0xc0000139` Windows 运行时崩溃，与验证报告一致）。
- `__version__` = `"0.1.2"`，且与 `moon.mod` 版本号、`wasm_version()` 返回值三者必须同源（一致性约定）。
- 内部 `src/humanize` 实现**零功能改动**（仅允许为版本一致性改写 `wasm_version()` 的版本字符串字面量）。
- 不修数字类函数 `String` 入参、不修 `clamp` 签名、不修 `format_fixed` round-half-up（R1）、不实现 deprecated `filetime`/`natsize`。
- 转发层逐参数照搬内部签名，不裁剪，不加重载，零逻辑。

---

## ⚠️ Spec Correction Notice (READ BEFORE IMPLEMENTING)

The forwarder template in spec §3.1 does **not** match the actual `src/humanize` signatures and would **fail to compile** if copied verbatim. The code blocks in this plan are corrected against the real source (`time.mbt`, `filesize.mbt`, `lists.mbt`, `i18n.mbt`). Specific fixes vs. spec §3.1:

| Symbol | Spec §3.1 error | Correct (per source) |
|--------|----------------|----------------------|
| `naturaldelta` | adds `when~ : DateTime? = None` | internal has **no** `when` param — drop it |
| `precisedelta` | param `delta : TimeDelta` | internal param is `value : TimeInput` (not `TimeDelta`) |
| `naturalsize` | `format~ : (Double) -> String = @humanize.default_size_fmt` | `default_size_fmt` does **not** exist; internal `format~ : String = "%.1f"` |
| `naturalsize` | omits `suffix`/`symbols` per §3.1 | keep forwarder to python-humanize's 4 params `{value, binary, gnu, format}`; call `@humanize.naturalsize` with only those (internal `suffix`/`symbols` fall back to defaults) |
| `natural_list` | `items : Array[String]`, `ox~ : ", "` | internal `value : ArrayView[String]`, `ox~ : " "` (space) |
| all `TimeUnit` defaults | `TimeUnit::SECONDS` | enum constructors are not exported cross-package → use accessor `TimeUnit::seconds()` |
| type references in root | unqualified `Date`/`TimeInput`/… | root package must use the `@humanize.` qualifier |

All forwarder bodies must call the matching `@humanize.<name>` with the **same** keyword args the internal function actually declares.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `moonbit/moonbit.mbt` | Root re-export layer. Currently exports 8 functions. This plan appends 12 forwarders + `__version__`, bringing it to 20/20. **Only file with functional edits.** |
| `moonbit/moonbit_test.mbt` | **New** root-package test file. Holds the public-API smoke assertions (Task 1–6). Same package as `moonbit.mbt`, so it calls the root `pub fn` directly and references `@humanize.*` types. |
| `moonbit/moon.mod` | Module version. Bumped `0.1.1` → `0.1.2` for version-consistency (§5.3/§6). |
| `moonbit/src/humanize/wasm.mbt` | `wasm_version()` returns `"0.1.1"`. Bumped to `"0.1.2"` so it matches `__version__` (§5.3). This is the only allowed `src/humanize` edit. |

No other files are touched. Internal `time.mbt` / `filesize.mbt` / `lists.mbt` / `i18n.mbt` logic is unchanged.

---

### Task 1: Version constant + version-consistency bump

**Files:**
- Modify: `moonbit/moonbit.mbt` (append `__version__`)
- Modify: `moonbit/moon.mod:6` (`version = "0.1.1"` → `"0.1.2"`)
- Modify: `moonbit/src/humanize/wasm.mbt:17` (`"0.1.1"` → `"0.1.2"`)
- Test: `moonbit/moonbit_test.mbt` (new)

**Interfaces:**
- Produces: `pub let __version__ : String` (value `"0.1.2"`) consumed by the smoke test and downstream consumers.
- Consumes: nothing new (pure constant).

- [ ] **Step 1: Write the failing test**

Create `moonbit/moonbit_test.mbt`:

```moonbit
// Root-package public API smoke tests for the 20/20 re-export.
// Run with: moon test --target native

test "version is 0.1.2 and consistent" {
  @test.assert_eq(__version__, "0.1.2")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd moonbit && moon test --target native`
Expected: FAIL — compile error, `__version__` is undefined (or "unbound variable").

- [ ] **Step 3: Add the `__version__` constant**

Append to `moonbit/moonbit.mbt` (after the existing 8 `pub fn`):

```moonbit
// Library version. Must stay in sync with moon.mod `version` and
// src/humanize/wasm.mbt `wasm_version()` (see spec §5.3).
pub let __version__ : String = "0.1.2"
```

- [ ] **Step 4: Bump the two other version sources for consistency**

Edit `moonbit/moon.mod` line 6:
```
version = "0.1.2"
```

Edit `moonbit/src/humanize/wasm.mbt` line 17:
```moonbit
  "0.1.2"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd moonbit && moon test --target native`
Expected: PASS — `version is 0.1.2 and consistent` green.

- [ ] **Step 6: Commit**

```bash
git add moonbit/moonbit.mbt moonbit/moonbit_test.mbt moonbit/moon.mod moonbit/src/humanize/wasm.mbt
git commit -m "feat: add __version__ constant and align module/wasm version to 0.1.2"
```

---

### Task 2: Time forwarders — `naturalday`, `naturaldate`

**Files:**
- Modify: `moonbit/moonbit.mbt` (append 2 forwarders)
- Test: `moonbit/moonbit_test.mbt` (append 2 test blocks)

**Interfaces:**
- Consumes: `@humanize.Date`, `@humanize.Date::today()`, `@humanize.naturalday`, `@humanize.naturaldate` (all already `pub` in `src/humanize/time.mbt`).
- Produces: root `naturalday`, `naturaldate` used by the smoke test and downstream consumers.

- [ ] **Step 1: Write the failing tests**

Append to `moonbit/moonbit_test.mbt`:

```moonbit
test "naturalday re-export" {
  let d = @humanize.Date::{ year: 2026, month: 8, day: 19 }
  @test.assert_eq(naturalday(d, when = d), "today")
  @test.assert_eq(naturalday(@humanize.Date::{ year: 2026, month: 8, day: 20 }, when = d), "tomorrow")
  @test.assert_eq(naturalday(@humanize.Date::{ year: 2026, month: 8, day: 18 }, when = d), "yesterday")
}

test "naturaldate re-export" {
  let d = @humanize.Date::{ year: 2026, month: 8, day: 19 }
  @test.assert_eq(naturaldate(@humanize.Date::{ year: 2026, month: 3, day: 15 }, when = d), "Mar 15 2026")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd moonbit && moon test --target native`
Expected: FAIL — `naturalday` / `naturaldate` undefined at root.

- [ ] **Step 3: Write minimal forwarders**

Append to `moonbit/moonbit.mbt`:

```moonbit
// —— time ——
pub fn naturalday(
  value : @humanize.Date,
  when~ : @humanize.Date = @humanize.Date::today(),
  format~ : String = "%b %d",
) -> String {
  @humanize.naturalday(value, when~, format~)
}

pub fn naturaldate(
  value : @humanize.Date,
  when~ : @humanize.Date = @humanize.Date::today(),
) -> String {
  @humanize.naturaldate(value, when~)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd moonbit && moon test --target native`
Expected: PASS — both new test blocks green.

- [ ] **Step 5: Commit**

```bash
git add moonbit/moonbit.mbt moonbit/moonbit_test.mbt
git commit -m "feat: re-export naturalday and naturaldate from root"
```

---

### Task 3: Time forwarders — `naturaldelta`, `naturaltime`, `precisedelta`

**Files:**
- Modify: `moonbit/moonbit.mbt` (append 3 forwarders)
- Test: `moonbit/moonbit_test.mbt` (append 3 test blocks)

**Interfaces:**
- Consumes: `@humanize.TimeInput`, `@humanize.TimeUnit`, `@humanize.TimeUnit::seconds()`, `@humanize.DateTime`, `@humanize.naturaldelta`, `@humanize.naturaltime`, `@humanize.precisedelta`.
- Produces: root `naturaldelta`, `naturaltime`, `precisedelta` used by smoke tests.
- NOTE: `naturaldelta` has **no** `when` param internally; `precisedelta` takes `TimeInput` (not `TimeDelta`). Use `TimeUnit::seconds()` accessor for the default (constructors not exported cross-package).

- [ ] **Step 1: Write the failing tests**

Append to `moonbit/moonbit_test.mbt`:

```moonbit
test "naturaldelta re-export" {
  @test.assert_eq(naturaldelta(@humanize.TimeInput::from_seconds(1.0)), "a second")
  @test.assert_eq(naturaldelta(@humanize.TimeInput::from_seconds(30.0)), "30 seconds")
  @test.assert_eq(
    naturaldelta(@humanize.TimeInput::from_delta(timedelta(days = 1))),
    "a day",
  )
}

test "naturaltime re-export" {
  @test.assert_eq(naturaltime(@humanize.TimeInput::from_seconds(5.0)), "5 seconds ago")
  @test.assert_eq(
    naturaltime(@humanize.TimeInput::from_delta(timedelta(days = 1))),
    "a day ago",
  )
}

test "precisedelta re-export" {
  let pd1 = @humanize.TimeInput::from_delta(timedelta(seconds = 176592, microseconds = 5486))
  @test.assert_eq(precisedelta(pd1), "2 days, 1 hour, 3 minutes and 12.01 seconds")
}
```

(`timedelta` is a `pub fn` in `src/humanize/time.mbt` — callable as `@humanize.timedelta(...)` from the root.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd moonbit && moon test --target native`
Expected: FAIL — `naturaldelta` / `naturaltime` / `precisedelta` undefined at root.

- [ ] **Step 3: Write minimal forwarders**

Append to `moonbit/moonbit.mbt`:

```moonbit
pub fn naturaldelta(
  value : @humanize.TimeInput,
  months~ : Bool = true,
  minimum_unit~ : @humanize.TimeUnit = @humanize.TimeUnit::seconds(),
) -> String {
  @humanize.naturaldelta(value, months~, minimum_unit~)
}

pub fn naturaltime(
  value : @humanize.TimeInput,
  future~ : Bool = false,
  months~ : Bool = true,
  minimum_unit~ : @humanize.TimeUnit = @humanize.TimeUnit::seconds(),
  when~ : @humanize.DateTime? = None,
) -> String {
  @humanize.naturaltime(value, future~, months~, minimum_unit~, when~)
}

pub fn precisedelta(
  value : @humanize.TimeInput,
  minimum_unit~ : @humanize.TimeUnit = @humanize.TimeUnit::seconds(),
  format~ : String = "%0.2f",
  suppress~ : Array[@humanize.TimeUnit] = [],
) -> String {
  @humanize.precisedelta(value, minimum_unit~, format~, suppress~)
}
```

Note: `precisedelta` takes `value : TimeInput` (matches internal `pub fn precisedelta(value : TimeInput, ...)`), **not** `TimeDelta` as the spec §3.1 template wrongly shows. The default `TimeUnit::seconds()` uses the exported accessor because enum constructors are not exported cross-package.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd moonbit && moon test --target native`
Expected: PASS — all three new test blocks green.

- [ ] **Step 5: Commit**

```bash
git add moonbit/moonbit.mbt moonbit/moonbit_test.mbt
git commit -m "feat: re-export naturaldelta, naturaltime, precisedelta from root"
```

---

### Task 4: Filesize forwarder — `naturalsize`

**Files:**
- Modify: `moonbit/moonbit.mbt` (append 1 forwarder)
- Test: `moonbit/moonbit_test.mbt` (append 1 test block)

**Interfaces:**
- Consumes: `@humanize.naturalsize(value, binary~, gnu~, suffix~, format~, symbols~)`. The public (python-humanize) surface is `{value, binary, gnu, format}`; internal adds `suffix`/`symbols` with defaults. The forwarder exposes the python-humanize 4-param surface and lets `suffix`/`symbols` take default values.
- Produces: root `naturalsize` used by smoke test.

- [ ] **Step 1: Write the failing test**

Append to `moonbit/moonbit_test.mbt`:

```moonbit
test "naturalsize re-export" {
  @test.assert_eq(naturalsize(1000000.0), "1.0 MB")
  @test.assert_eq(naturalsize(1000000.0, binary = true), "954.0 KiB")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd moonbit && moon test --target native`
Expected: FAIL — `naturalsize` undefined at root.

- [ ] **Step 3: Write minimal forwarder**

Append to `moonbit/moonbit.mbt`:

```moonbit
// —— filesize ——
pub fn naturalsize(
  value : Double,
  binary~ : Bool = false,
  gnu~ : Bool = false,
  format~ : String = "%.1f",
) -> String {
  @humanize.naturalsize(value, binary~, gnu~, format~)
}
```

Note: spec §3.1's `format~ : (Double) -> String = @humanize.default_size_fmt` is **wrong** — `default_size_fmt` does not exist, and internal `format~` is a `String = "%.1f"`. We forward only the four python-humanize params; internal `suffix~`/`symbols~` keep their defaults.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd moonbit && moon test --target native`
Expected: PASS — `naturalsize re-export` green.

- [ ] **Step 5: Commit**

```bash
git add moonbit/moonbit.mbt moonbit/moonbit_test.mbt
git commit -m "feat: re-export naturalsize from root"
```

---

### Task 5: Lists forwarder — `natural_list`

**Files:**
- Modify: `moonbit/moonbit.mbt` (append 1 forwarder)
- Test: `moonbit/moonbit_test.mbt` (append 1 test block)

**Interfaces:**
- Consumes: `@humanize.natural_list(value : ArrayView[String], style~, cx~, ox~)`.
- Produces: root `natural_list` used by smoke test.

- [ ] **Step 1: Write the failing test**

Append to `moonbit/moonbit_test.mbt`:

```moonbit
test "natural_list re-export" {
  @test.assert_eq(natural_list(["a", "b", "c"]), "a, b and c")
  @test.assert_eq(natural_list(["a", "b"], style = "or"), "a or b")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd moonbit && moon test --target native`
Expected: FAIL — `natural_list` undefined at root.

- [ ] **Step 3: Write minimal forwarder**

Append to `moonbit/moonbit.mbt`:

```moonbit
// —— lists ——
pub fn natural_list(
  value : ArrayView[String],
  style~ : String = "standard",
  cx~ : String = ", ",
  ox~ : String = " ",
) -> String {
  @humanize.natural_list(value, style~, cx~, ox~)
}
```

Note: spec §3.1 wrongly used `items : Array[String]` and `ox~ : ", "`. The internal signature is `value : ArrayView[String]` with default `ox~ : " "` (space). Passing a literal `["a","b","c"]` auto-adapts to `ArrayView[String]`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd moonbit && moon test --target native`
Expected: PASS — `natural_list re-export` green.

- [ ] **Step 5: Commit**

```bash
git add moonbit/moonbit.mbt moonbit/moonbit_test.mbt
git commit -m "feat: re-export natural_list from root"
```

---

### Task 6: i18n forwarders — `activate`, `deactivate`, `decimal_separator`, `thousands_separator`

**Files:**
- Modify: `moonbit/moonbit.mbt` (append 4 forwarders)
- Test: `moonbit/moonbit_test.mbt` (append 1 test block)

**Interfaces:**
- Consumes: `@humanize.activate(locale) -> Option[@humanize.Locale]`, `@humanize.deactivate()`, `@humanize.decimal_separator()`, `@humanize.thousands_separator()`.
- Produces: root `activate`, `deactivate`, `decimal_separator`, `thousands_separator` used by smoke test.
- `Locale` is `pub(all) enum` so `Option[Locale]` is valid cross-package.

- [ ] **Step 1: Write the failing test**

Append to `moonbit/moonbit_test.mbt`:

```moonbit
test "i18n re-export" {
  // activate returns Some(locale) for a known locale; None for English/unknown.
  @test.assert_eq(activate("ru_RU").is_some(), true)
  @test.assert_eq(activate("en_US"), None)
  // After deactivate we are back to English separators.
  ignore(activate("ru_RU"))
  deactivate()
  @test.assert_eq(thousands_separator(), ",")
  @test.assert_eq(decimal_separator(), ".")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd moonbit && moon test --target native`
Expected: FAIL — `activate` / `deactivate` / `decimal_separator` / `thousands_separator` undefined at root.

- [ ] **Step 3: Write minimal forwarders**

Append to `moonbit/moonbit.mbt`:

```moonbit
// —— i18n ——
pub fn activate(locale : String) -> Option[@humanize.Locale] {
  @humanize.activate(locale)
}

pub fn deactivate() -> Unit {
  @humanize.deactivate()
}

pub fn decimal_separator() -> String {
  @humanize.decimal_separator()
}

pub fn thousands_separator() -> String {
  @humanize.thousands_separator()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd moonbit && moon test --target native`
Expected: PASS — `i18n re-export` green.

- [ ] **Step 5: Commit**

```bash
git add moonbit/moonbit.mbt moonbit/moonbit_test.mbt
git commit -m "feat: re-export activate, deactivate, decimal_separator, thousands_separator from root"
```

---

### Task 7: Full regression + 20/20 verification

**Files:**
- Read: `moonbit/moonbit.mbt` (final export count confirm)

**Interfaces:**
- Consumes: all 20 root exports (8 prior + 12 added).

- [ ] **Step 1: Run full native test suite**

Run: `cd moonbit && moon test --target native`
Expected: all tests PASS (prior 44/44 internal tests + the new root smoke tests). The forwarders carry zero logic, so internal behaviour is unchanged.

- [ ] **Step 2: Run a build to confirm no new errors**

Run: `cd moonbit && moon build`
Expected: succeeds (pre-existing deprecated-syntax warnings may remain; no new errors).

- [ ] **Step 3: Confirm the root export set is 20/20**

Run in the `moonbit` dir:
```bash
grep -c '^pub fn\|^pub let' moonbit.mbt
```
Expected output: `20` — the original file has 8 `pub fn` (`clamp, metric, intcomma, intword, apnumber, fractional, scientific, ordinal`), plus the 11 new `pub fn` (`naturalday, naturaldate, naturaldelta, naturaltime, precisedelta, naturalsize, natural_list, activate, deactivate, decimal_separator, thousands_separator`) + 1 `pub let` (`__version__`) = 20.

- [ ] **Step 4: Commit (if any stray changes remain) / finalize**

If the grep confirms 20 and all tests pass, no further commit is needed (all edits are already committed per Tasks 1–6). Otherwise add and commit the discrepancy fix.

---

## Self-Review Notes

1. **Spec coverage** — every item in spec §2 (12 symbols + `__version__`) maps to a task: Tasks 2–6 cover the 12 forwarders; Task 1 covers `__version__` + the §5.3 version-consistency mandate; Task 7 covers §4 regression + §6 success criteria. The 8 already-exported symbols are left untouched per the non-goal.
2. **Placeholder scan** — no TBD/TODO; every step has concrete code and exact commands. (The only inline note is a clarification of the truncation boundary, not a placeholder.)
3. **Type consistency** — forwarders consistently call `@humanize.<name>` with the exact keyword args the internal functions declare: `naturaldelta` has no `when`; `precisedelta` uses `value : TimeInput`; `naturalsize` uses `format~ : String = "%.1f"`; `natural_list` uses `value : ArrayView[String]` + `ox~ : " "`; `TimeUnit` defaults use `@humanize.TimeUnit::seconds()`. These match Tasks 2–6 and the smoke tests.
4. **Spec correction** — the §3.1 "No Placeholders" risk is that the spec's own template would not compile; this plan documents and corrects all 6 discrepancies in the "Spec Correction Notice" block and in each task's Note.
