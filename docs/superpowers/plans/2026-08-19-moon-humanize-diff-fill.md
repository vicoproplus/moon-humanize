# moon-humanize 差异补齐 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐 moon-humanize 相对 python-humanize 4.16.0 在时间函数上的差异：补 `naturalday`/`naturaldate`/`naturaltime` 的 Python 黄金值测试，把 `naturalday`/`naturaldate` 默认参考日改为真实今天，补 `naturaldate` 五年规则，给 `naturaltime` 加 `when~` 形参，并刷新 stale 文档。

**Architecture:** 仅改动 `moonbit/src/humanize/time.mbt`（新增 `Date::today()`，改 `naturalday`/`naturaldate` 默认 `when~`，补 `naturaldate` 五年规则，给 `naturaltime` 加 `when~`）。`Date::today()` 复用现有 `now()`（返回纳秒 epoch）换算本地日历日。测试全部用固定 `when~`，不依赖真实时钟。验证在 WSL 用 `moon test --target native`。

**Tech Stack:** MoonBit（moon 0.1.20260819 / moonc v0.10.9）；python-humanize 4.16.0（黄金值真值，已安装）；WSL（Linux 子系统，UTC）。

## Global Constraints

- 基准：`python-humanize` 4.16.0 真实输出（用 `python -c "import humanize; ..."` 或 `scripts/gen_golden.py` 取真值）。
- 验收：在 **WSL** 执行 `moon test --target native` 全绿 + `python scripts/gen_golden.py --mbt` 与既有断言一致；默认 wasm 目标的 Windows `0xc0000139` 崩溃**不修复**，记为平台已知问题。
- `now()` 返回 **纳秒** epoch（`clock_native.mbt: now() = @env.now()毫秒 * 1e6`），`Date::today()` 换算天数须除以 `86400_000_000_000L`。
- 舍入模式 `format_fixed` 维持 round-half-up（已知与 Python round-half-to-even 的 `.5` 边界差异，**不修**，仅文档记录）。
- 不实现 deprecated `filetime` / `natsize`；不引入绝对 datetime 输入（MoonBit `TimeInput` 仅 `Seconds`/`Delta`）；不重构已对齐的 number/filesize/lists/i18n。
- 提交信息用中文自然句 + 末尾 `Co-Authored-By: AtomCode (code) <noreply@atomgit.com>`。

---

## 文件结构

| 文件 | 动作 | 责任 |
|------|------|------|
| `moonbit/src/humanize/time.mbt` | Modify | 新增 `Date::today()`；`naturalday`/`naturaldate` 默认 `when~` 改 `Date::today()`；`naturaldate` 补五年规则；`naturaltime` 加 `when~` 形参 |
| `moonbit/src/humanize/time_test.mbt` | Modify | 补 naturalday/naturaldate/naturaltime 的 Python 黄金值断言（固定 `when~`） |
| `docs/spec-align-humanize.md` | Modify | 刷新 stale 表述（工具链可用、get_translation 已存在）、补"已知差异"清单 |
| `docs/specs/2026-08-19-spec-align-humanize.md` | Modify | Open Questions #2 更新为已解决；成功标准 ✅ |

既有可复用符号（`time.mbt`）：
- `struct Date { year : Int, month : Int, day : Int }`
- `fn _date_diff_days(value : Date, when : Date) -> Int`（已存在）
- `fn _days_since_epoch(d : Date) -> Int`（已存在，`era*146097 + doe - 719468`）
- `fn _format_date(d : Date, format : String) -> String`（已支持 `"%b %d"` 与 `"%b %d %Y"`）
- `pub fn now() -> Int64`（native/wasm 各自实现，纳秒）

---

### Task 1: 新增 `Date::today()` 与反向历法函数

**Files:**
- Modify: `moonbit/src/humanize/time.mbt`（在 `Date` struct 与 `_days_since_epoch` 附近新增）
- Test: `moonbit/src/humanize/time_test.mbt`

**Interfaces:**
- Produces: `pub fn Date::today() -> Date`（Task 2/3 的默认 `when~` 依赖它）

- [ ] **Step 1: 写失败测试**
```moonbit
test "date today inverse" {
  // _days_since_epoch(Date::today()) 必须等于 today 的真实 epoch 天；
  // 因确定性难控，改测互逆：构造任意 Date，days_since_epoch -> today 路径不直接验；
  // 这里仅验证 today() 返回合法日历日（月 1-12，日 1-31）。
  let t = Date::today()
  @test.assert_eq(t.month >= 1 && t.month <= 12, true)
  @test.assert_eq(t.day >= 1 && t.day <= 31, true)
  @test.assert_eq(t.year > 1970, true)
}
```

- [ ] **Step 2: 跑测试确认失败**
Run: `cd moonbit && moon test --target native time_test 2>&1 | tail -20`
Expected: 编译失败（`Date::today` 未定义）

- [ ] **Step 3: 实现最小代码**（在 `naturalday` 定义之前插入）
```moonbit
/// Current local calendar day, derived from `now()` (nanosecond epoch).
pub fn Date::today() -> Date {
  let nanos = now()
  let days_since_epoch = (nanos / 86400_000_000_000L).to_int()
  let (y, m, d) = _gregorian_from_epoch_days(days_since_epoch)
  Date::{ year: y, month: m, day: d }
}

/// Inverse of `_days_since_epoch`: recover (year, month, day) from days since
/// the proleptic-Gregorian epoch (same origin as `_days_since_epoch`).
fn _gregorian_from_epoch_days(z : Int) -> (Int, Int, Int) {
  let days = if z >= 0 { z } else { z - 146096 }
  let era = (days / 146097)
  let doe = days - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let m = if mp < 10 { mp + 3 } else { mp - 9 }
  let d = doy - (153 * mp + 2) / 5 + 1
  let year = if m <= 2 { y + 1 } else { y }
  (year, m, d)
}
```

- [ ] **Step 4: 跑测试确认通过**
Run: `cd moonbit && moon test --target native time_test 2>&1 | tail -20`
Expected: PASS（含 `date today inverse`）

- [ ] **Step 5: 提交**
```bash
git add moonbit/src/humanize/time.mbt moonbit/src/humanize/time_test.mbt
git commit -m "feat(time): 新增 Date::today() 由 now() 纳秒换算本地日历日

提供 today-relative 基准，供 naturalday/naturaldate 默认 when~ 使用。

Co-Authored-By: AtomCode (code) <noreply@atomgit.com>"
```

---

### Task 2: `naturalday`/`naturaldate` 默认 `when~` 改 `Date::today()`

**Files:**
- Modify: `moonbit/src/humanize/time.mbt`（`naturalday` ~L399、`naturaldate` ~L419）
- Test: `moonbit/src/humanize/time_test.mbt`

**Interfaces:**
- Consumes: `pub fn Date::today() -> Date`（Task 1）
- Produces: 默认 `when~` 行为（不再硬编码 2010-02-02）

- [ ] **Step 1: 写失败测试**（固定 `when~` 隔离真实时钟；Python 真值对照 `naturalday(value, when=today)`）
```moonbit
test "naturalday fixed when" {
  let today = Date::{ year: 2026, month: 8, day: 19 }
  @test.assert_eq(naturalday(Date::{ year: 2026, month: 8, day: 19 }, when~ = today), "today")
  @test.assert_eq(naturalday(Date::{ year: 2026, month: 8, day: 20 }, when~ = today), "tomorrow")
  @test.assert_eq(naturalday(Date::{ year: 2026, month: 8, day: 18 }, when~ = today), "yesterday")
  @test.assert_eq(naturalday(Date::{ year: 2026, month: 8, day: 21 }, when~ = today), "Aug 21")
  @test.assert_eq(naturalday(Date::{ year: 2026, month: 8, day: 14 }, when~ = today), "Aug 14")
}

test "naturaldate fixed when" {
  let today = Date::{ year: 2026, month: 8, day: 19 }
  @test.assert_eq(naturaldate(Date::{ year: 2026, month: 8, day: 21 }, when~ = today), "Aug 21")
  // 跨年但不足 152 天（d=-159 才触发，本例同年）走 "%b %d"
  @test.assert_eq(naturaldate(Date::{ year: 2026, month: 3, day: 15 }, when~ = today), "Mar 15")
}
```

- [ ] **Step 2: 跑测试确认失败**
Run: `cd moonbit && moon test --target native time_test 2>&1 | tail -25`
Expected: 现有 `naturalday`/`naturaldate` 用 `when~ = 2010-02-02`，以上新断言（尤其 `when~ = today=2026-08-19` 下 value=2026-08-19 应得 "today"）与旧默认不符 → 部分 FAIL

- [ ] **Step 3: 改默认 `when~`**
把两处签名 `when~ : Date = Date::{ year: 2010, month: 2, day: 2 }` 改为 `when~ : Date = Date::today()`：
```moonbit
pub fn naturalday(
  value : Date,
  when~ : Date = Date::today(),
  format~ : String = "%b %d",
) -> String {
  let d = _date_diff_days(value, when)
  if d == 0 { return gettext("today") }
  if d == 1 { return gettext("tomorrow") }
  if d == -1 { return gettext("yesterday") }
  _format_date(value, format)
}

pub fn naturaldate(
  value : Date,
  when~ : Date = Date::today(),
) -> String {
  let d = _date_diff_days(value, when)
  if d == 0 { return gettext("today") }
  if d == 1 { return gettext("tomorrow") }
  if d == -1 { return gettext("yesterday") }
  if d.abs() >= 152 {
    _format_date(value, "%b %d %Y")
  } else {
    _format_date(value, "%b %d")
  }
}
```

- [ ] **Step 4: 跑测试确认通过**
Run: `cd moonbit && moon test --target native time_test 2>&1 | tail -25`
Expected: PASS（含 `naturalday fixed when` / `naturaldate fixed when`）；原有测试不受影响

- [ ] **Step 5: 提交**
```bash
git add moonbit/src/humanize/time.mbt moonbit/src/humanize/time_test.mbt
git commit -m "feat(time): naturalday/naturaldate 默认 when~ 改 Date::today()

修复硬编码 2010-02-02 导致永远不输出 today/yesterday/tomorrow 的问题；
naturaldate 同步补五年规则（abs(diff)>=152 带年份）。

Co-Authored-By: AtomCode (code) <noreply@atomgit.com>"
```

---

### Task 3: `naturaltime` 加 `when~` 形参（签名对齐占位）

**Files:**
- Modify: `moonbit/src/humanize/time.mbt`（`naturaltime` ~L362）
- Test: `moonbit/src/humanize/time_test.mbt`

**Interfaces:**
- Consumes: `TimeInput::from_seconds` / `TimeInput::from_delta`（已存在）
- Produces: `pub fn naturaltime(value : TimeInput, future~ : Bool, months~ : Bool, minimum_unit~ : TimeUnit, when~ : DateTime? = None) -> String`

> **语义约束（必须写入代码注释与文档）**：MoonBit `TimeInput` 仅相对输入（Seconds/Delta）。对相对输入，Python 也由符号判定时态、`when` 抵消，故 `when~` 在此路径下不改变输出。完全生效需后续引入绝对 datetime 输入（本次不做）。

- [ ] **Step 1: 写失败测试**（签名编译向后兼容 + `when~` 不破坏相对输入）
```moonbit
test "naturaltime when param compat" {
  // 相对输入（seconds）下，when~ 不影响输出（与无 when~ 一致）
  @test.assert_eq(
    naturaltime(TimeInput::from_seconds(22.5), when~ = None),
    "22 seconds ago",
  )
  @test.assert_eq(
    naturaltime(TimeInput::from_seconds(22.5)),
    "22 seconds ago",
  )
  @test.assert_eq(
    naturaltime(TimeInput::from_delta(timedelta(days=1)), when~ = None),
    "a day ago",
  )
}
```

- [ ] **Step 2: 跑测试确认失败**
Run: `cd moonbit && moon test --target native time_test 2>&1 | tail -20`
Expected: 编译失败（`naturaltime` 无 `when~` 形参）

- [ ] **Step 3: 加 `when~` 形参（函数体不变）**
```moonbit
pub fn naturaltime(
  value : TimeInput,
  future~ : Bool = false,
  months~ : Bool = true,
  minimum_unit~ : TimeUnit = TimeUnit::SECONDS,
  when~ : DateTime? = None,
) -> String {
  // NOTE: MoonBit `TimeInput` has no absolute-datetime variant, so for
  // Seconds/Delta inputs `when~` does not change the output (Python also
  // derives tense from sign and cancels `when` for timedelta/float inputs).
  // Full effect requires an absolute datetime input, deferred (YAGNI).
  let (delta, is_future) = match value {
    TimeInput::Delta(d) => (d, d.is_neg)
    TimeInput::Seconds(s) => {
      let rounded = round_half_even(s)
      (seconds_to_delta(rounded), false)
    }
  }
  let base = naturaldelta(TimeInput::Delta(delta), months~, minimum_unit~)
  if base == gettext("a moment") {
    return gettext("now")
  }
  if is_future || future {
    base + gettext(" from now")
  } else {
    base + gettext(" ago")
  }
}
```

- [ ] **Step 4: 跑测试确认通过**
Run: `cd moonbit && moon test --target native time_test 2>&1 | tail -20`
Expected: PASS（含 `naturaltime when param compat`）；原有 naturaltime 测试不变

- [ ] **Step 5: 提交**
```bash
git add moonbit/src/humanize/time.mbt moonbit/src/humanize/time_test.mbt
git commit -m "feat(time): naturaltime 新增 when~ 形参（签名对齐 Python）

相对输入下 when~ 不改变输出；绝对 datetime 语义留待后续引入输入模型。

Co-Authored-By: AtomCode (code) <noreply@atomgit.com>"
```

---

### Task 4: 补 naturaldate 五年规则边界断言 + 全量回归

**Files:**
- Test: `moonbit/src/humanize/time_test.mbt`
- Run: WSL `moon test --target native`

**Interfaces:**
- Consumes: `naturaldate(value : Date, when~ : Date)`（Task 2 已具五年规则）

- [ ] **Step 1: 写边界断言**（Python 真值：`abs(diff)>=152` 带年份）
```moonbit
test "naturaldate five month rule" {
  let today = Date::{ year: 2026, month: 8, day: 19 }
  // diff = -200 天（跨年且 >=152）：带年份
  @test.assert_eq(naturaldate(Date::{ year: 2026, month: 2, day: 1 }, when~ = today), "Feb 01 2026")
  // diff = -100 天（<152）：不带年份
  @test.assert_eq(naturaldate(Date::{ year: 2026, month: 5, day: 11 }, when~ = today), "May 11")
  // diff = -152 天（边界，>=152）：带年份
  @test.assert_eq(naturaldate(Date::{ year: 2026, month: 3, day: 20 }, when~ = today), "Mar 20 2026")
}
```
> 注：以上 Y/M/D 为相对 2026-08-19 的近似边界；执行前用 Python 核对真值：
> `python -c "import humanize,datetime; t=datetime.date(2026,8,19); print(humanize.naturaldate(datetime.date(2026,2,1), datetime.date(2026,8,19)))"` 等，确认真值后再固定断言。

- [ ] **Step 2: 用 Python 真值校验并修正断言**
Run:
```bash
cd /path/to/repo && python -c "
import humanize, datetime
t = datetime.date(2026, 8, 19)
for v in [(2026,2,1),(2026,5,11),(2026,3,20)]:
    print(v, repr(humanize.naturaldate(datetime.date(*v), t)))
"
```
Expected: 输出与 Step 1 断言一致（不一致则按真值改断言）

- [ ] **Step 3: 跑全量 native 测试**
Run: `cd moonbit && moon test --target native 2>&1 | tail -8`
Expected: `Total tests: N, passed: N, failed: 0`（既有 38 + Task 1-4 新增全绿）

- [ ] **Step 4: 跑黄金值生成器确认未漂移**
Run: `python scripts/gen_golden.py --mbt 2>&1 | head -5`（人工比对既有 number/filesize/lists 断言未变）
Expected: 输出与现有 `*_test.mbt` 黄金值一致

- [ ] **Step 5: 提交**
```bash
git add moonbit/src/humanize/time_test.mbt
git commit -m "test(time): 补 naturaldate 五年规则边界黄金值断言

固定 when~ 隔离真实时钟；用 python-humanize 4.16.0 真值校验。

Co-Authored-By: AtomCode (code) <noreply@atomgit.com>"
```

---

### Task 5: 刷新 stale 文档

**Files:**
- Modify: `docs/spec-align-humanize.md`
- Modify: `docs/specs/2026-08-19-spec-align-humanize.md`

**Interfaces:**
- Consumes: 本 plan 全部代码改动（Task 1-4）

- [ ] **Step 1: 改 `docs/spec-align-humanize.md`**
  - 将 §0 "MoonBit 行为按源码静态判定，未实际运行" / "待工具链修复后运行" 类表述改为："`moon test --target native` 已通过（38/38 + 时间函数新增断言），工具链 moon 0.1.20260819 / moonc v0.10.9 已对齐"。
  - 将 §4 差异汇总表中 `get_translation` 的"[差异]/缺失" 行改为 "✅ 已实施（i18n.mbt:192）"。
  - 在 §5 "已知设计差异" 末尾新增条目：
    1. `Date::today()`：naturalday/naturaldate 默认 `when~` 改为真实今天（由 `now()` 纳秒换算）；测试用固定 `when~` 规避真实时钟依赖。
    2. `naturaltime(when~)`：MoonBit `TimeInput` 仅相对输入，对 seconds/delta 输入 `when~` 不改变输出（与 Python timedelta/float 路径同口径）；绝对 datetime 语义留待后续。
    3. `naturaldate` 五年规则已对齐（abs(diff)>=152 带年份）。
    4. 舍入 `format_fixed` 仍 round-half-up（R1），与 Python round-half-to-even 的 `.5` 边界差异属已知、不修。
    5. `filetime`/`natsize`（Python deprecated）未实现，建议用 `naturalsize`。

- [ ] **Step 2: 改 `docs/specs/2026-08-19-spec-align-humanize.md`**
  - Open Questions #2（工具链）：改为 "已解决：moon 0.1.20260819 / moonc v0.10.9 已对齐，`moon test --target native` 可用"。
  - 成功标准区追加 ✅：get_translation 已实施（D1 实际已完成）、时间函数黄金值断言已补、naturalday/naturaldate 默认 today、naturaldate 五年规则、naturaltime when~ 形参。

- [ ] **Step 3: 提交**
```bash
git add docs/spec-align-humanize.md docs/specs/2026-08-19-spec-align-humanize.md
git commit -m "docs: 刷新 moon-humanize 差异补齐的 stale 表述与已知差异清单

工具链已可用、get_translation 已存在、时间函数已对齐；wasm 0xc0000139 记为平台已知。

Co-Authored-By: AtomCode (code) <noreply@atomgit.com>"
```

---

## Self-Review（计划自检）

1. **Spec 覆盖**：§2.1 Date::today → Task 1；§2.2 naturalday/naturaldate 默认 today → Task 2；§2.3 naturaltime when~ → Task 3；§2.2 五年规则 → Task 2 + Task 4 边界；§3 测试 → Task 1-4；§4.2 文档刷新 → Task 5；YAGNI 红线（filetime/natsize、舍入、绝对 datetime）→ 文档记录，无实现任务。全覆盖。
2. **占位符扫描**：无 TBD/TODO/"similar to"；每个代码 Step 均含可粘贴代码；测试 Step 含断言与 Python 真值校验命令。
3. **类型一致性**：`Date::today() -> Date` 在 Task 1 定义、Task 2 用作默认 `when~`；`naturaltime(... when~ : DateTime? = None)` 在 Task 3 定义、Task 4 测试用 `when~ = None`；`naturaldate(value, when~)` 在 Task 2 定义、Task 4 用固定 `when~`。命名与类型跨任务一致。
4. **单位修正**：`Date::today()` 已用纳秒换算（`/ 86400_000_000_000L`），与 `now()` 实际返回一致（spec 已同步修正）。
