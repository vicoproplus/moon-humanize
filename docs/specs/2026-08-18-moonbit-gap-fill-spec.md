# MoonBit 补齐 Spec —— 对齐 Python humanize 缺失能力与交付形态缺口

- **日期**: 2026-08-18
- **目标**: 在已完成的 MoonBit 移植基础上，补齐下列缺口，使 MoonBit 侧在**功能**与**交付形态**上完全对齐 Python `humanize`。
- **覆盖范围核实（审查 2026-08-18 更正）**:
  - Python `humanize` 公共 API（`src/humanize/__init__.py` `__all__`）共 **19** 个导出：
    `activate, apnumber, clamp, deactivate, decimal_separator, fractional, intcomma, intword, metric, natural_list, naturaldate, naturalday, naturaldelta, naturalsize, naturaltime, ordinal, precisedelta, scientific, thousands_separator`。
  - 经代码级核对，MoonBit `humanize` 已覆盖上述全部 19 个（含 i18n 的 `activate`/`deactivate`/`decimal_separator`/`thousands_separator` 与 `number` 的 `clamp`/`metric` 扩展）。**函数级 API 已 100% 对齐。**
  - 因此"对齐 Python"的剩余缺口仅余两类：**(a) i18n 接线完整性** 与 **(b) 交付形态**。`lists` 的 `oxford`/`rangelist` **在 Python 中并不存在**（见 1.1 更正），不属于对齐缺口。
- **三类补齐项**：
  1. ~~`lists` 的 `oxford`/`rangelist`（原误判为 Python 已有；审查发现 Python 无此二函数，已降级为可选扩展，见 §1）~~
  2. `number` 模块 4 个函数的 i18n 接线（硬编码英语，未走 `gettext`，非 EN locale 不本地化）
  3. 交付形态缺口：`clock` 的 native 实现缺失 + `wasm.mbt` 导出层缺失
- **状态基线**: 见 `2026-08-18-moonbit-port-gap-spec.md`（已代码级复验）

---

## 0. 范围与验收口径

- 功能对齐 = MoonBit 公共 API 行为与 Python 等义（含边界、i18n、子形态）。
- 交付对齐 = `moon test` 在 native 与 wasm/wasm-gc 下均可全绿；Web 侧有统一导出桥；CI 能阻止表漂移。
- 本 spec 主线（§2、§3）不新增 Python 没有的能力。§1 的 `oxford`/`rangelist` 经审查确认 Python 无此函数，已降级为可选扩展，不在主线对齐范围内。

---

## 1. `lists` 模块：`oxford` 与 `rangelist`（**可选扩展，非 Python 对齐项**）

> **⚠️ 审查更正（2026-08-18）**：
> 原 spec 将 `oxford`/`rangelist` 列为"Python `lists.py` 有、MoonBit 缺的对齐缺口"。
> 经代码级核实，**这是错误的**：
> - `src/humanize/lists.py` 全文仅 39 行，`__all__ = ["natural_list"]`，**只有 `natural_list` 一个函数**。
> - 对 `src/` 全树搜索 `oxford`/`rangelist`/`def rangelist` 结果为 **0 匹配**。
> - 即 Python 版 `humanize` 的 `lists` 模块**不存在** `oxford` 与 `rangelist`。
> 因此本节**不能**作为"对齐 Python"的缺口。以下保留为**可选的 MoonBit 增值扩展**，默认**不在补齐范围内**，除非产品明确需要。

### 1.1 现状（已核实）
- `moonbit/src/humanize/lists.mbt` 仅含 `natural_list(Array[String], ?glue=) -> String`，无 `oxford`、无 `rangelist`。
- Python `src/humanize/lists.py` **仅含** `natural_list(items) -> str`（无 oxford 形参、无 rangelist）。

### 1.2 若决定实现（可选扩展，非对齐要求）
文件：`moonbit/src/humanize/lists.mbt`

```moonbit
/// 牛津逗号风格。oxford=true 时末项前加 ", and"/"，和"（走当前 locale）。
pub fn oxford(
  items : Array[String],
  glue : String = ", ",
  oxford_comma : Bool = true,
) -> String

/// 范围列表：连续整数序列压缩，如 [1,2,3,4,7] -> "1-4, 7"。
/// 仅当元素全部可解析为 Int 时执行压缩，否则退化为 natural_list。
pub fn rangelist(
  items : Array[String],
  glue : String = ", ",
) -> String
```

### 1.3 行为契约（**仅供可选实现参考**，非对齐验收）
| 输入 | `natural_list` | `oxford(,,oxford=true)` | `oxford(,,oxford=false)` | `rangelist` |
|---|---|---|---|---|
| `[]` | `""` | `""` | `""` | `""` |
| `["a"]` | `"a"` | `"a"` | `"a"` | `"a"` |
| `["a","b"]` | `"a and b"` | `"a, and b"` | `"a and b"` | `"a, b"` |
| `["a","b","c"]` | `"a, b, and c"` | `"a, b, and c"` | `"a, b and c"` | `"a, b, c"` |
| `[1,2,3,4,7]` | — | — | — | `"1-4, 7"` |

- `oxford` 的连接词（`"and"`/`"和"`）须走当前 locale 的 `gettext`。
- `rangelist` 仅对全整数元素压缩；含非整数时退化为 `natural_list` 行为。
- **注意**：以上契约的参考对象不是当前 Python `humanize`（其无此二函数），仅为 API 形态示例。

### 1.4 测试（仅当实现时）
文件：`moonbit/src/humanize/lists_test.mbt` 新增用例覆盖上表所有单元格。因非对齐项，不建议占用 i18n 本地化测试资源。

---

## 2. `number` 模块 i18n 接线补齐

### 2.1 现状（已核实）
- `intword`(228)、`naturaldelta`、`naturaltime`、`naturalday`、`naturaldate`、`precisedelta` 均已走 `gettext`/`ngettext`。
- 下列 4 个函数**硬编码英语**，**未走 i18n**：
  - `apnumber`：`number.mbt:297` `"zero".."nine"` 硬编码。
  - `ordinal`：序数后缀（`st`/`nd`/`rd`/`th`）及特例词硬编码。
  - `fractional`：分数词（`half`/`quarter`/`third`…）硬编码。
  - `scientific`：指数词（`million`/`billion`…）硬编码（211 行表亦需本地化）。

### 2.2 待实现
- `apnumber`：0-9 数字词改走 `ngettext`/`gettext`，与 Python `i18n.py` 的 `ap_number` 表对齐（需向 `i18n_data.mbt` 注入对应条目）。
- `ordinal`：`_ordinal` 后缀依据 locale 的后缀规则；英语规则保留，非英语走 locale 表。
- `fractional`：分数词走 `gettext`（与 Python `i18n.py` 的 `fractional` 表对齐）。
- `scientific`：量级词（`million` 等）走 `ngettext`/`gettext`。

### 2.3 验收
- `activate("ru")` 后调用 `apnumber(1)`/`ordinal(2)`/`fractional(0.5)`/`scientific(1e6)` 返回俄语本地化结果（与 Python 同 locale 行为一致）。
- `deactivate()` 后回落英语（与现状一致）。

### 2.4 i18n 数据
- 扩展 `i18n_data.mbt`（通过 `scripts/po2mbt.py` 重新生成）纳入 `ap_number`/`fractional`/序数后缀/量级词条目。
- `scripts/po2mbt.py` 须能从 Python `src/humanize/locale/*.po` 抽取上述新条目；加 `--check` 校验生成表与源 po 一致（CI 阻断漂移）。

---

## 3. 交付形态缺口补齐

### 3.1 `clock` native 实现
- **现状**：仅 `clock_wasm.mbt` 提供 `pub fn now() -> Int64`（wasm/wasm-gc 编译），无 native 时钟文件。native 下 `moon test` 若触达 `naturaltime` 无 `when~` 注入会链接失败/未定义。
- **要求**：
  - 新增 `clock_native.mbt`（编译条件 `target="native"`），`now()` 用 `time_now()` FFI 或 `os` 系统时间。
  - 在 `moon.pkg`（humanize 包）按 target 条件包含 `clock_wasm.mbt` / `clock_native.mbt`（MoonBit 的 `target` 字段机制）。
  - 当 `naturaltime` 调用且无 `now~` 注入且 native 无可用时钟时，**panic 报错**（错误信息提示"未注入时钟"），与 gap-spec 1.4 要求一致。
- **验收**：`moon test -target native` 与 `moon test -target wasm` 均全绿。

### 3.2 `wasm.mbt` 导出层
- **现状**：`wasm.mbt` 不存在；JS 侧无统一 API 桥。
- **要求**：新增 `moonbit/src/humanize/wasm.mbt`（编译条件 wasm/wasm-gc），提供 `wasm_*` 前缀导出函数，桥接：
  - `wasm_naturalsize` / `wasm_naturaltime` / `wasm_naturaldelta` / `wasm_naturalday` / `wasm_naturaldate` / `wasm_natural_list` / `wasm_intcomma` / `wasm_intword` / `wasm_apnumber` / `wasm_ordinal` / `wasm_fractional` / `wasm_scientific` / `wasm_metric` / `wasm_clamp` / `wasm_activate` / `wasm_deactivate` / `wasm_set_decimal_separator` / `wasm_set_thousands_separator`。
  - （`wasm_oxford` / `wasm_rangelist` 仅当 §1 可选扩展被采纳时才加入。）
  - 字符串走 `Bytes`/`String` 互转，时间注入走 `now~` 包装。
- **验收**：可在浏览器/demo 中经 JS 调用上述 API，行为对齐 Python。

### 3.3 CI 与文档
- 在 `tox.ini`/CI 增加：`moon test -target native` 与 `moon test -target wasm-gc`。
- 增加 `po2mbt --check` 步骤，阻止 i18n 表漂移。
- 更新 `mkdocs.yml` / README 的"功能完成度"小节，移除旧虚报，标注本 spec 补齐项。

---

## 4. 实施顺序与里程碑

| 阶段 | 内容 | 验收 |
|---|---|---|
| M1 | `number` 4 函数 i18n 接线 + `i18n_data.mbt` 重生成 + `po2mbt --check` | `activate("ru")` 下 4 函数本地化 |
| M2 | `clock_native.mbt` + moon.pkg target 条件 | native/wasm `moon test` 均绿 |
| M3 | `wasm.mbt` 导出层 + demo | JS 侧可调通 |
| M4 | CI 扩展 + 文档修正 | CI 阻断漂移，文档与实际一致 |
| ~~M5~~ | `lists.oxford`/`rangelist`（**可选扩展，非对齐项，默认不做**） | — |

## 5. 风险与备注
- i18n 接线需保证**英语为 fallback**，避免 locale 缺条目时报错。
- 主线（§2、§3）所有新增导出须保持与 Python 同名函数的语义等义，不引入 Python 没有的形参。
- §1 的 `oxford`/`rangelist` 若实施，属 MoonBit 自有扩展，不要求与 Python 对齐（因 Python 无此二函数）；其测试向量自行定义即可。
- `clock` native 实现须确认 MoonBit `target` 条件编译语法（当前 `clock_wasm.mbt` 用 `target="wasm"`/`wasm-gc`），新增 `clock_native.mbt` 须与之对应，避免双 target 下符号冲突。
