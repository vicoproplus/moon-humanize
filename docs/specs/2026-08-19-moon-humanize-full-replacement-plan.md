# 规划 Spec：moon-humanize 完全替代 python-humanize（公开 API 20/20 对齐）

- **模式**：根包薄转发层补齐（仅补导出 + `__version__`，不动内部实现）
- **基准**：`python-humanize` 4.16.0（20 个公开符号）
- **依赖文档**：`docs/specs/2026-08-19-moon-humanize-replacement-verification.md`（验证报告，锁定阻断项）
- **生成日期**：2026-08-19
- **状态**：已批准（经 brainstorming 共享理解确认门 + present-design 逐节确认）
- **交付物**：本规划 spec（不实现代码）

---

## 0. 背景与验证结论引用

来自验证报告（`2026-08-19-moon-humanize-replacement-verification.md`）的已确认事实：
- 内部实现率 **19/20**（仅 `__version__` 缺失），`moon test --target native` **44/44 全绿**。
- 根包可替代率 **8/20 = 40%**：根包 `moonbit.mbt` 仅导出 8 个，12 个已实现符号未外露。
- 阻断项（已实现但未导出）= 6 时间函数 + `natural_list` + 4 i18n 函数（共 11）+ `__version__` 缺失（1）。

本规划 spec 目标：**消除上述阻断项，使根包公开 API 达 20/20**，兑现"完全替代"。

---

## 1. 目标与范围

### 1.1 目标
- 在根包 `moonbit/moonbit.mbt` 补导出验证报告锁定的 **12 个符号**，并实现缺失的 `__version__`。
- 使根包公开 API 与 `python-humanize` 20 个 `__all__` 符号**逐一对齐**（数量 + 命名）。

### 1.2 非目标（YAGNI 红线）
- 不修数字类函数 `String` 入参（接受为静态强类型取舍）。
- 不修 `clamp` 签名差异。
- 不修 `format_fixed` round-half-up（R1 已知差异）。
- 不实现 deprecated `filetime` / `natsize`（Python 亦弃用）。
- 不改动 `src/humanize` 内部实现（仅根包导出层 + 常量）。
- 不写代码（本交付物为规划 spec，仅出文档）。

---

## 2. 改动集清单（核心，13 项）

| # | 类别 | 符号 | 内部来源（已确认存在） |
|---|------|------|----------------------|
| 1 | 时间 | `naturalday` | `time.mbt:481` |
| 2 | 时间 | `naturaldate` | `time.mbt:501` |
| 3 | 时间 | `naturaldelta` | `time.mbt:214` |
| 4 | 时间 | `naturaltime` | `time.mbt:362` |
| 5 | 文件 | `naturalsize` | `filesize.mbt:41` |
| 6 | 时间 | `precisedelta` | `time.mbt:614` |
| 7 | 列表 | `natural_list` | `lists.mbt:11` |
| 8 | i18n | `activate` | `i18n.mbt:172` |
| 9 | i18n | `deactivate` | `i18n.mbt:179` |
| 10 | i18n | `decimal_separator` | `i18n.mbt:237` |
| 11 | i18n | `thousands_separator` | `i18n.mbt:245` |
| 12 | 版本 | `__version__` | 根包新增常量 |
| — | （已有 8） | clamp/metric/intcomma/intword/apnumber/fractional/scientific/ordinal | 已导出，不动 |

补导出后根包导出 = 8（既有）+ 12（新增）= **20/20**。

---

## 3. 根包薄转发层结构

### 3.1 追加位置与写法
在 `moonbit/moonbit.mbt` 现有 8 个 `pub fn` 之后，按模块分组追加。模板与既有一致，**仅做参数透传，零逻辑、不加重载**：

```moonbit
// —— time（#1–#4, #6）——
pub fn naturalday(value : Date, when~ : Date = Date::today(), format~ : String = "%b %d") -> String {
  @humanize.naturalday(value, when~, format~)
}
pub fn naturaldate(value : Date, when~ : Date = Date::today()) -> String {
  @humanize.naturaldate(value, when~)
}
pub fn naturaldelta(
  value : TimeInput, when~ : DateTime? = None, months~ : Bool = true,
  minimum_unit~ : TimeUnit = TimeUnit::SECONDS,
) -> String {
  @humanize.naturaldelta(value, when~, months~, minimum_unit~)
}
pub fn naturaltime(
  value : TimeInput, future~ : Bool = false, months~ : Bool = true,
  minimum_unit~ : TimeUnit = TimeUnit::SECONDS, when~ : DateTime? = None,
) -> String {
  @humanize.naturaltime(value, future~, months~, minimum_unit~, when~)
}
pub fn precisedelta(
  delta : TimeDelta, minimum_unit~ : TimeUnit = TimeUnit::SECONDS,
  format~ : String = "%0.2f", suppress~ : Array[TimeUnit] = [],
) -> String {
  @humanize.precisedelta(delta, minimum_unit~, format~, suppress~)
}
// —— filesize（#5）——
pub fn naturalsize(
  value : Double, binary~ : Bool = false, gnu~ : Bool = false,
  format~ : (Double) -> String = @humanize.default_size_fmt,
) -> String {
  @humanize.naturalsize(value, binary~, gnu~, format~)
}
// —— lists（#7）——
pub fn natural_list(
  items : Array[String], style~ : String = "standard",
  cx~ : String = ", ", ox~ : String = ", ",
) -> String {
  @humanize.natural_list(items, style~, cx~, ox~)
}
// —— i18n（#8–#11）——
pub fn activate(locale : String) -> Option[Locale] { @humanize.activate(locale) }
pub fn deactivate() -> Unit { @humanize.deactivate() }
pub fn decimal_separator() -> String { @humanize.decimal_separator() }
pub fn thousands_separator() -> String { @humanize.thousands_separator() }
// —— 版本（#12）——
pub let __version__ : String = "0.1.2"
```

### 3.2 可见性依赖（须满足的前提）
1. `Date` / `TimeInput` / `TimeDelta` / `DateTime` / `TimeUnit`：定义于 `src/humanize/time.mbt`；根包经 `@humanize` 引用其构造器（`Date::today()` 等）。根 `moon.pkg` 已 `import "vicoproplus/moon-humanize/src/humanize"`，满足。
2. `Locale`：内部 `pub(all) enum Locale`（`i18n.mbt:14`），`pub(all)` 保证跨包可见，`activate` 返回 `Option[Locale]` 合法。
3. 命名参数：转发时**逐参数照搬**内部签名（含 `when~`/`future~`/`minimum_unit~`/`format~`/`suppress~`/`style~`/`cx~`/`ox~`/`binary~`/`gnu~`），不裁剪，以对齐 Python 公开签名。

---

## 4. 测试与回归

- **既有回归**：补导出后重跑 `moon test --target native`，预期仍为 **44/44 全绿**（转发层零逻辑，不触及内部实现）。
- **新导出冒烟断言**（在 `moonbit_test.mbt` 或复用现有 `*_test.mbt` 追加）：
  - `naturaltime(TimeInput::from_seconds(5))` 编译通过且返回非空前串。
  - `activate("ru_RU")` 返回 `Some(...)`；`deactivate()` 后回到英语。
  - `natural_list(["a","b","c"])` 返回 `"a, b and c"`（对齐 Python standard）。
  - `naturalsize(1000000.0)` 返回 `"1.0 MB"`。
  - `__version__` 常量 == `"0.1.2"`。
- `moon build` 须无新增错误（既有 deprecated 语法警告可保留）。
- **验收环境**：统一 `--target native`（绕开本机 wasm `0xc0000139`，与验证报告一致）。

---

## 5. 已知差异与迁移指南

### 5.1 接受为设计取舍（不修）
| 差异 | 说明 | 处理 |
|------|------|------|
| 数字类入参 `String` | 静态强类型取舍（Python 接受 int/float/str 多态） | 接受；迁移指南注明 |
| `clamp` 签名 | MoonBit `clamp(Double, floor~/ceil~/..., format~:函数)` vs Python `clamp(value, low, high, format=字符串)` | 接受；指南注明 |
| round-half-up | `format_fixed` round-half-up vs Python round-half-even（`.5` 边界，R1） | 接受；引用验证报告 |
| `filetime`/`natsize` 缺失 | 两边均 deprecated | 不纳入；指南注明跳过 |

### 5.2 迁移指南要点（写入本 spec，供实现阶段复用）
1. 安装：`moon add vicoproplus/moon-humanize`；`import "vicoproplus/moon-humanize"` 后可用 20/20 公开函数。
2. 数字入参：Python `intword(1234567)` → MoonBit `intword("1234567")`（String）。
3. 时间类：入参为 `TimeInput`/`Date`（`Date::today()` 等），非 Python `datetime`，属类型建模差异，指南举例。
4. i18n：`activate("ru_RU")` 返回 `Option[Locale]`，失败时 `None`（Python 抛 `FileNotFoundError`），指南注明错误处理差异。

### 5.3 版本一致性约定（防历史错配）
- `__version__` = `"0.1.2"`（本次指定）。
- **强制约定**：根包 `__version__`、`moon.mod` 版本号、`wasm_version()` 返回值三者必须同源（建议统一从 `moon.mod` 读取或单一常量），避免历史 `d7c2041` 修过的 0.1.0→0.1.1 式错配复发。
- 成功标准列入该一致性检查。

---

## 6. 成功标准
- [ ] 根包 `moonbit.mbt` 导出符号 8 → **20/20**，覆盖验证报告全部 12 阻断项 + `__version__`。
- [ ] 12 符号经 `moon add` 后 consumer 可直接调用，签名与 `src/humanize` 内部一致。
- [ ] `__version__` = `"0.1.2"`，与 `moon.mod` / `wasm_version()` 版本约定一致。
- [ ] `moon test --target native` **44/44 全绿**，新增冒烟断言通过。
- [ ] 内部 `src/humanize` 实现**零改动**（仅根包导出层 + 常量）。
- [ ] deprecated `filetime`/`natsize` 仍未实现，迁移指南注明跳过。

---

## 7. 后续建议（可选增强，仅记录不实现）
- **B 级（调用兼容）**：数字类函数加 `Int`/`Double` 重载、修 `clamp` 签名以逼近 Python 调用方零改动迁移。
- **C 级（全量对等）**：修 round-half-up 至 round-half-even、逐语言追平本地化 36。
- 以上超出本轮"接受签名分歧"决定，列为后续可选，不纳入本 spec 实现范围。
