# Design: moon-humanize 与 python-humanize 差异补齐（补齐测试 + 刷文档 + 3 处对齐）

- **模式**: B 派生（补测试 + 刷文档 + 仅修确认 bug）；非严格逐字节对齐
- **基准**: `python-humanize` 4.16.0（已安装，真值来源）
- **实现**: MoonBit `moonbit/src/humanize/*.mbt`
- **状态**: 已批准（2026-08-19，经 brainstorming 共享理解确认门）
- **生成日期**: 2026-08-19

---

## 0. 已核实背景事实

1. 工具链已对齐：`moon 0.1.20260819` / `moonc v0.10.9`（同日）。`moon build` 成功（仅 deprecated 语法警告）。
2. `moon test --target native` 当前 **38/38 全绿**；默认 wasm 目标在本机崩 `0xc0000139`（Windows 运行时已知问题，见 `docs/TOOLCHAIN-WINDOWS-ISSUE.md`，与代码无关）。
3. `get_translation()` **已存在**（`i18n.mbt:192`）——旧 spec/align 文档写"缺失"已过时。
4. 全部 `*_test.mbt` 黄金值已与已安装 python-humanize 4.16.0 实测一致（`scripts/gen_golden.py --mbt` 校验通过）。
5. `format_fixed` 用 round-half-up，Python `%.Nf` 用 round-half-to-even（latent `.5` 边界差异，doc 注 R1）。实测 `metric(1025)` Python → `'1.02 k'`，MoonBit round-half-up → `'1.03 k'`。**本次不修**，仅文档记录。
6. `naturaltime/naturalday/naturaldate` **完全无测试**；MoonBit `naturalday/naturaldate` 默认 `when=2010-02-02`（硬编码占位），Python 默认用真实今天 → MoonBit 永远不会输出 "today"/"yesterday"/"tomorrow"。
7. Python `naturaltime(when=)` 实际是 **`datetime` 参考点**（默认当前时间），对 `timedelta`/秒输入时态由符号判定，`when` 抵消；并非字符串枚举 `'now'/'past'/'future'/'ago'`（早期探测报错的根因）。
8. Python `naturaldate` 五年规则：`abs(value - today).days >= 5*365/12 (=152.08)` 时带年份 `"%b %d %Y"`，否则 `"%b %d"`。
9. `filetime` / `natsize` 在 Python 已 deprecated → 本次不实现。

---

## 1. 范围

### 1.1 本次交付
- **代码（3 处对齐改动）**：
  1. 新增 `Date::today()`（由 `now() : Int64` epoch 秒换算本地日历日）。
  2. `naturalday` / `naturaldate` 默认 `when~` 由硬编码 `Date::{2010,2,2}` 改为 `Date::today()`（修复"永远不输出 today"）。
  3. `naturaldate` 补五年规则：`abs(_date_diff_days(value, when)) >= 152` → `"%b %d %Y"`，否则 `"%b %d"`。
  4. `naturaltime` 新增 `when~ : DateTime? = None` 形参（签名对齐 Python；见 §2.3 语义限制）。
- **测试**：补 naturalday/naturaldate/naturaltime 的 Python 黄金值断言（固定 `when~`，不依赖真实时钟）。
- **文档**：刷新 `docs/spec-align-humanize.md` 与 `docs/specs/2026-08-19-spec-align-humanize.md` 的 stale 表述，补"已知差异"清单。

### 1.2 不交付（YAGNI 红线）
- 不实现 deprecated `filetime` / `natsize`。
- 不修全局舍入（`format_fixed` 维持 round-half-up）。
- 不引入绝对 `datetime` 输入模型（MoonBit `TimeInput` 仅 seconds/delta）。
- 不重构已对齐的 number/filesize/lists/i18n 模块。
- 不解决 Windows wasm `0xc0000139` 崩溃（平台已知问题）。

---

## 2. 组件与函数签名细节

### 2.1 新增 `Date::today()`
```moonbit
// 由 epoch 纳秒换算本地日期，复用 clock_* 的 now() : Int64（纳秒）
pub fn Date::today() -> Date {
  let nanos = now()                          // Int64, UTC epoch 纳秒
  let days_since_epoch = (nanos / 86400_000_000_000L).to_int()
  let (y, m, d) = _gregorian_from_epoch_days(days_since_epoch)
  Date::{ year: y, month: m, day: d }
}
```
- `now()` 返回**纳秒**（`clock_native.mbt: now() = @env.now()毫秒 * 1e6`）；换算天数须除以 `86400_000_000_000L`。
- `_gregorian_from_epoch_days` 与现有 `_days_since_epoch` 互逆（同历法算法，保证 today-relative 一致）；现有 `_days_since_epoch` 以 epoch 天为基准（`era*146097+doe-719468`），故 `_gregorian_from_epoch_days` 解该式还原 Y/M/D。
- `now()` 返回 UTC epoch；WSL/CI 默认 UTC，故 `Date::today()` 在 WSL 下等于 UTC 日历日（与 Python `date.today()` 在 UTC 环境一致）。真实使用时以运行环境时区为准（文档记录）。

### 2.2 `naturalday` / `naturaldate` 默认 `when~` 改 `Date::today()`
```moonbit
pub fn naturalday(
  value : Date,
  when~ : Date = Date::today(),    // 原 2010-02-02
  format~ : String = "%b %d",
) -> String { /* 逻辑不变 */ }

pub fn naturaldate(
  value : Date,
  when~ : Date = Date::today(),    // 原 2010-02-02
) -> String {
  let d = _date_diff_days(value, when)
  if d == 0 { return gettext("today") }
  if d == 1 { return gettext("tomorrow") }
  if d == -1 { return gettext("yesterday") }
  if d.abs() >= 152 {              // 五年规则: 5*365/12 ≈ 152.08
    _format_date(value, "%b %d %Y")
  } else {
    _format_date(value, "%b %d")
  }
}
```

### 2.3 `naturaltime` 加 `when~` 形参（预留）
```moonbit
pub fn naturaltime(
  value : TimeInput,
  future~ : Bool = false,
  months~ : Bool = true,
  minimum_unit~ : TimeUnit = TimeUnit::SECONDS,
  when~ : DateTime? = None,         // 对齐 Python 签名；相对输入下不改变输出
) -> String { /* 函数体不变 */ }
```
**语义限制（必须文档化）**：MoonBit `TimeInput` 无绝对 datetime 变体，仅相对秒/时长。对相对输入，Python 本身也由符号判定时态、`when` 抵消，故 `when~` 在 `TimeInput::Seconds` / `TimeInput::Delta` 路径下**不改变输出**。语义完全生效需后续引入绝对 datetime 输入（YAGNI，本次不做）。保留形参仅为签名对齐与未来扩展。

### 2.4 既有 `_format_date` 已支持 `"%b %d"` 与 `"%b %d %Y"`，无需改动。

---

## 3. 测试与黄金值

### 3.1 真实 diff 采集
在 WSL 跑 Python 4.16.0 产出 naturalday/naturaldate/naturaltime 黄金值，作为断言来源（同 `gen_golden.py` 口径）。所有时间类断言用**固定 `when~`**，保证可重复、不依赖真实时钟。

### 3.2 新增断言（`time_test.mbt`）
- `naturalday`（固定 `when~ = Date::{2026,8,19}`，与 Python `naturalday` 真值对照）：
  - `d==0` → `"today"`；`d==1` → `"tomorrow"`；`d==-1` → `"yesterday"`；`d==2` → `"Aug 21"`；`d==-5` → `"Aug 14"`。
- `naturaldate`（固定 `when~`）：
  - 同年内 +2d → `"Aug 21"`；
  - 跨年且距今天 ≥152 天 → `"<Mon> <DD> <YYYY>"`（五年规则）；
  - 跨年不足 152 天 → `"<Mon> <DD>"`（Python 行为：delta≥152 走 `"%b %d %Y"`，否则 `"%b %d"`）。
- `naturaltime`（相对输入 seconds/delta）：复用现有断言；新增 `naturaltime(..., when~ = None)` 编译/向后兼容用例。文档注明 `when~` 相对输入不改输出（Python 同口径）。

### 3.3 全量回归
- WSL：`moon test --target native` 预期 38 既有 + 新增全绿。
- `python scripts/gen_golden.py --mbt` 与既有断言一致（number/filesize/lists 不动，仅确认未漂移）。

### 3.4 已知差异断言处理
- round-half-up（R1）：不新增 `.5` 边界断言（避免引入与 Python 不一致的测试），仅文档记录。

---

## 4. 错误处理、文档刷新与验收

### 4.1 错误处理
- `naturalday`/`naturaldate` 输入强类型 `Date`，无解析失败路径（与 Python 对 `AttributeError/OverflowError` 返回 `str(value)` 不同，MoonBit 静态类型保证类型安全，属合理差异，文档记录）。
- `Date::today()` 依赖 `now()`，沿用 `clock_*` 现有实现。

### 4.2 文档刷新
- `docs/spec-align-humanize.md`：
  - "工具链不可用 → 待 moon test 实测" → "已验证：`moon test --target native` 38/38 通过（含新增时间函数断言）"。
  - "get_translation 缺失 [差异]" → "已实施（i18n.mbt:192）"。
  - 新增"已知差异"：round-half-up（R1）、`naturaltime(when~)` 对相对输入不改输出、`naturalday/naturaldate` 默认 `Date::today()`、`naturaldate` 五年规则已对齐、跳过 deprecated `filetime`/`natsize`。
- `docs/specs/2026-08-19-spec-align-humanize.md`：Open Questions #2（工具链）更新为已解决；成功标准 ✅。

### 4.3 验收口径（WSL）
- WSL 执行：`moon test --target native` 全绿 + `python scripts/gen_golden.py --mbt` 与断言一致。
- 默认 wasm 目标 Windows `0xc0000139` 记为平台已知问题，不计入本次、不修复。

---

## 5. 成功标准
- [ ] `Date::today()` 已实现，`naturalday`/`naturaldate` 默认 `when~` 为 `Date::today()`，`naturaldate` 五年规则生效。
- [ ] `naturaltime` 已加 `when~` 形参且向后兼容。
- [ ] `time_test.mbt` 含 today/yesterday/tomorrow/格式化/五年规则/五年规则边界 的 Python 黄金值断言，WSL `moon test --target native` 全绿。
- [ ] `docs/spec-align-humanize.md` 与 2026-08-19 spec 的 stale 表述已刷新，"已知差异"清单已补。
- [ ] `filetime`/`natsize` 未实现，仅文档说明跳过。
