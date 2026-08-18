# Plan: 科学计数法扩展 + 中文连接符 + i18n 补全

**Source spec:** `docs/specs/2026-08-18-scientific-connector-i18n-spec.md`
**Status:** Ready to implement (spec 假设与代码现状有出入，已校正)
**用户修订：** (1) 增加数字形 decimal 输出作为独立增强；(2) 添加 msgfmt 降级机制。

---

## 关键现状校正（实现前必读）

经核查代码库，spec 中多处"已存在设施"实际尚未实现，本计划据此修正：

| Spec 假设 | 代码现状 | 处理 |
|-----------|----------|------|
| `NumberFormatter` 已存在 | 不存在；仅有独立 `scientific(value: String)`（数字形） | **新建** `NumberFormatter` struct |
| `MsgId` / `msg_str(locale, id)` 已存在 | 不存在；仅有 `gettext`/`pgettext`/`ngettext` 文本 API | **新建** `MsgId` 枚举 + `msg_str` |
| `integer_to_words(locale, n)` 已存在 | 不存在 | **新建** 整数→单词（en/ru/zh） |
| `to_scientific` / `to_superscript` 已存在 | `to_superscript` 在 `util.mbt` 存在；无 `to_scientific` | 新增 `to_scientific`，复用 `to_superscript` |
| `zh` locale 已存在 | 仅有 `ZhCN`(`zh_CN`)；无 `Zh` | **新增** `Zh`(`zh`) locale 构造 |
| `humanize.po` 的 `en`/`ru_RU` 已覆盖 | `en`/`ru_RU` 已存在但不含新键 | 补全；**新建** `zh/humanize.po` |

无公开 API 破坏性改动；`NumberFormatter` 等均为新增公开符号。

---

## Feature 1 — 科学计数法（含数字形 decimal 增强）

### 1a. 新增 `NumberFormatter`（`moonbit/src/humanize/number.mbt`）

```moonbit
pub enum FractionMode {
  Scientific
  Decimal
  Both
  Auto
}

pub struct NumberFormatter {
  locale : Locale
  fraction_mode : FractionMode
}

pub fn NumberFormatter::new(locale~ : Locale = En, mode~ : FractionMode = Decimal) -> NumberFormatter {
  { locale, fraction_mode: mode }
}

pub fn default_formatter() -> NumberFormatter {
  NumberFormatter::new()
}
```

### 1b. 新增 `to_scientific`（`util.mbt` 或 `number.mbt`）

复用现有 `pow10_double` / `ilog10` / `format_fixed` / `to_superscript`：

```moonbit
fn to_scientific(n : Double, prec : Int) -> String {
  // 与现有顶层 scientific() 同算法，但接受 Double 并返回 "z.wq x 10ⁿ" 数字形
  // （不从 String 解析，供 NumberFormatter 内部调用）
}
```

### 1c. 新增 `integer_to_words`（`moonbit/src/humanize/i18n.mbt` 或 `number.mbt`）

en/ru/zh 三语整数→单词（0–9999 足以覆盖 spec 示例；超出则回退数字串）：

- en: 复用 `apnumber` 思路（0–9 单词；10+ 数字串） + 千位 "thousand" 等（spec 示例只需 thousand/third 这类序数/基数，按 `integer_to_words` 返回基数词："thousand", "five", "two"）。
- ru: 基数词俄语（две, пять, тысяча …）。
- zh: 中文数字（二, 五, 千 …）。
- 负数、0 处理；非有限值回退 `n.to_string()`。

> 注：spec 示例 `exp=3` → "thousandth power" 用的是**序数**词尾。本计划让 `integer_to_words` 返回基数词，序数词尾由 `Exponent` 模板承载（en: `"%s power"` 已含 "power"，但 "thousandth" 是序数）。为满足 spec 精确字符串 `"thousandth power"`，`integer_to_words` 对 en 需返回序数词（thousandth, fifth …）。**决定**：`integer_to_words(locale, n)` 返回该 locale 的"幂次读数"——en 用序数词（thousandth/fifth），ru 用属格（тысячи/пятой），zh 用基数（千/五）。即在 `integer_to_words` 内按 locale 选择序数/属格/基数形态，集中处理，避免分散。

### 1d. 新增数字形 decimal 渲染（`number.mbt`）—— **用户决策 (1)**

为满足 spec decimal 表的数字形示例（`n=3.14159, prec=2` → `"3.14"`），`Decimal`/`Both`/`Auto` 模式在 `prec >= 1` 时**输出数字形**，而非词形：

```moonbit
fn to_decimal(locale : Locale, n : Double, prec : Int) -> String {
  // prec == 0: 词形 decimal（"two point five" / "две целые пять сотых" / "二点五"）
  // prec >= 1: 数字形（format_fixed(n, prec)，带 locale 小数/千分分隔符）
}
```

即 decimal 模式同时支持**词形（prec=0）与数字形（prec≥1）**两种输出，覆盖 spec 表全部行。这是对 spec 的增强（独立可测）。

### 1e. 新增 `scientific` 方法（`number.mbt`）

```moonbit
pub fn scientific(self : NumberFormatter, n : Double, prec : Int, exp : Int) -> String {
  let mant = match self.fraction_mode {
    Scientific => to_scientific(n, prec)                       // 数字形尾数
    Decimal    => to_decimal(self.locale, n, prec)             // 词形(prec=0)/数字形(prec>=1)
    Both       => to_decimal(...) + " (" + to_scientific(n, prec) + ")"
    Auto       => if 1.0 <= n.abs() && n.abs() < 1000.0 { to_decimal(...) } else { to_scientific(...) }
  }
  let exp_words = integer_to_words(self.locale, exp)
  let connector = msg_str(self.locale, Connector)              // en/ru=","  zh=" "
  let exp_label = format(msg_str(self.locale, Exponent), exp_words)  // en "%s power"
  let joined = mant + connector + exp_label
  format(msg_str(self.locale, Scientific), joined)             // en "%s × 10^"
}
```

**输出示例（en, Scientific 模式）：** `scientific(3.14159, 2, 3)` → `"3.14 × 10^thousandth power"` ✓

---

## Feature 2 — 中文连接符 locale `Zh`

### 2a. `Locale` 枚举新增 `Zh`（`i18n.mbt`）
- 枚举加 `Zh`；`from_string` 加 `"zh" => Some(Zh)`；`to_dir` 加 `Zh => "zh"`。
- `po2mbt` 的 `LOCALE_CTORS` 加 `"zh": "Zh"`，`THOUSANDS_SEP`/`DECIMAL_SEP` 可不加（zh 用默认 `,`/`.`）。

### 2b. `MsgId` 枚举 + `msg_str`（`i18n.mbt`）
新建枚举（非生成），映射 spec 用到的键：

```moonbit
pub enum MsgId {
  Scientific
  Exponent
  Connector
  // 未来可扩展其它键
}
pub fn msg_str(loc : Locale, id : MsgId) -> String {
  let key = match id {
    Scientific => "scientific_tmpl"
    Exponent  => "exponent_tmpl"
    Connector => "connector"
  }
  lookup_message(loc, key, fallback(key))   // fallback 用 en 默认串
}
```

> `lookup_message` 已由 `po2mbt` 生成，`msg_str` 仅做 `MsgId`→msgid 字符串的路由 + 缺省回退。

### 2c. `msg_Zh` 生成（`i18n_data.mbt` via `po2mbt`）
新建 `src/humanize/locale/zh/LC_MESSAGES/humanize.po`，含全部键（含 `scientific_tmpl`/`exponent_tmpl`/`connector` 与现有 en 键的中文翻译）。`po2mbt` 自动产出 `msg_Zh`；`lookup_message` 的 `match loc` 分支自动加入 `Zh => ...`。

### 2d. 测试（`i18n_test.mbt`）
- `zh connector is space`：`msg_str(Zh, Connector) == " "`（直接构造 `Zh` 或 `activate("zh")` 后走 `lookup_message`）。
- `zh has full coverage`：遍历所有 `MsgId`，`lookup_message(Zh, key, "") != ""`。

---

## Feature 3 — i18n 覆盖补全（含降级机制）

### 3a. 三个 `.po` 文件
- `en/humanize.po`：新增 `scientific_tmpl`=`"%s × 10^"`、`exponent_tmpl`=`"%s power"`、`connector`=`,`。
- `ru_RU/humanize.po`：同上三键俄语（`"%s × 10^"` / `"%s степень"` / `","`）。
- `zh/humanize.po`：**新建**，含 en 全部现有键 + 上述三键中文（`"%s × 10^"` / `"%s 次方"` / `" "`）。

### 3b. 校验降级机制 —— **用户决策 (2)**
Windows 常无 GNU `msgfmt`。新增 `scripts/check_po.py`（或并入 `po2mbt --check`）：
- 优先调用 `msgfmt --check`；若 `shutil.which("msgfmt")` 为 `None`，降级到纯 Python 校验：
  - 复用 `po2mbt` 的 `read_po` 解析每个 `.po`；
  - 校验：无重复 `msgid`、msgstr 非空（非 header）、`%` 占位符数量与 msgid 一致、UTF-8 可读；
  - 对 `en`/`ru_RU`/`zh` 三语分别报告通过/失败，退出码非零即失败。
- 封装为 `scripts/check_i18n.sh`（bash，CI 用）：`msgfmt --check *.po || python scripts/check_po.py`。

> 同时在 `po2mbt` 增加 `--check` 已存在，但仅比对生成文件是否过期，不校验 `.po` 完整性。新的 `check_po.py` 专司 `.po` 内容校验与降级。

---

## 文件改动清单

| 文件 | 改动 |
|------|------|
| `moonbit/src/humanize/number.mbt` | 新增 `NumberFormatter`/`FractionMode`、`to_scientific`、`integer_to_words`、`to_decimal`(数字形增强)、`scientific` 方法 |
| `moonbit/src/humanize/number_test.mbt` | 新增 scientific/decimal 词形+数字形/auto/both 测试矩阵 |
| `moonbit/src/humanize/i18n.mbt` | 新增 `Zh` locale（`from_string`/`to_dir`）；新增 `MsgId` + `msg_str` |
| `moonbit/src/humanize/i18n_data.mbt` | 由 `po2mbt` 重新生成，含 `msg_Zh` + `Zh` 分支 |
| `moonbit/src/humanize/i18n_test.mbt` | 新增 zh connector / zh 全覆盖测试 |
| `src/humanize/locale/en/LC_MESSAGES/humanize.po` | 补全 3 键 |
| `src/humanize/locale/ru_RU/LC_MESSAGES/humanize.po` | 补全 3 键 |
| `src/humanize/locale/zh/LC_MESSAGES/humanize.po` | **新建** 完整中文翻译 |
| `scripts/po2mbt` | `LOCALE_CTORS` 加 `"zh": "Zh"` |
| `scripts/check_po.py` | **新建** Python 降级校验器 |
| `scripts/check_i18n.sh` | **新建** CI 入口（msgfmt 优先，否则降级） |

---

## 验证清单
- [ ] `moon test` 通过（含新 number + i18n 测试）
- [ ] `scripts/check_i18n.sh` 对 en/ru_RU/zh 三者通过（msgfmt 或 Python 降级）
- [ ] 示例复现：`default_formatter().scientific(3.14159, 2, 3)` → `"3.14 × 10^thousandth power"`
- [ ] 数字形 decimal 增强：`Decimal` 模式 `prec>=1` 输出 `"3.14"` 等数字串
- [ ] zh connector 在 `scientific()` 中以空格拼接：`"二点五 × 10^..."` 形态
- [ ] ru decimal 词形（prec=0）呈俄语分数形
- [ ] 无公开 API 破坏性改动

---

## 执行顺序
1. `scripts/po2mbt` 加 `zh` → 新建 `zh/humanize.po` + 补全 en/ru → 重新生成 `i18n_data.mbt`
2. `i18n.mbt`：加 `Zh` locale + `MsgId` + `msg_str`
3. `number.mbt`：加 `NumberFormatter`/`to_scientific`/`integer_to_words`/`to_decimal`/`scientific`
4. 测试：`number_test.mbt` + `i18n_test.mbt`
5. `scripts/check_po.py` + `check_i18n.sh`，运行校验
6. `moon test` 全量通过
