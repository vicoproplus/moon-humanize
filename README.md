# moon-humanize

[![GitHub](https://img.shields.io/badge/repo-vicoproplus%2Fmoon--humanize-blue)](https://github.com/vicoproplus/moon-humanize)
[![mooncakes](https://img.shields.io/badge/mooncakes-vicoproplus%2Fmoon--humanize-orange)](https://mooncakes.io/#/package/vicoproplus/moon-humanize)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENCE)
[![Version](https://img.shields.io/badge/version-0.1.2-blue)](moonbit/moon.mod)

`moon-humanize` 是 [python-humanize](https://github.com/python-humanize/humanize) 的 **MoonBit** 移植版本：一套把数字、时间、文件大小等转换为人类可读文本的工具函数，可在 MoonBit 的 native 与 wasm / wasm-gc 后端运行。函数命名与行为尽量对齐 Python 原版，便于复用相同的人文化能力。

- **数字人文化**：`clamp` / `metric` / `intcomma` / `intword` / `apnumber` / `fractional` / `scientific` / `ordinal` / `integer_to_words` / `to_scientific` / `to_decimal`
- **时间与日期人文化**：`naturalday` / `naturaldate` / `naturaldelta` / `naturaltime` / `precisedelta`
- **文件大小人文化**：`naturalsize`
- **列表枚举人文化**：`natural_list`
- **多语言本地化**：内置 gettext / ngettext / pgettext 体系，支持数十种语言区域（未配置语言区域自动回退为英文）
- **跨平台 / WASM 友好**：可编译到浏览器、边缘计算与嵌入式等无 Python 运行时的环境

## 支持的语言区域

`ar`、`bn_BD`、`ca_ES`、`da_DK`、`de_DE`、`el_GR`、`eo`、`es_ES`、`eu`、`fa_IR`、`fi_FI`、`fr_FR`、`he_IL`、`hu_HU`、`id_ID`、`it_IT`、`ja_JP`、`ko_KR`、`lv`、`nb`、`nl_NL`、`pl_PL`、`pt_BR`、`pt_PT`、`ru_RU`、`si_LK`、`sk_SK`、`sl_SI`、`sv_SE`、`tlh`、`tr_TR`、`uk_UA`、`uz`、`vi_VN`、`zh`、`zh_CN`、`zh_HK`。

翻译数据来自 `src/humanize/locale/*/LC_MESSAGES/humanize.po`；未在列表中的语言区域（包括所有 `en*`）回退为英文。

<!-- usage-start -->

## 安装

### 作为 MoonBit 依赖

```bash
moon add vicoproplus/moon-humanize
```

包已发布到 [mooncakes.io](https://mooncakes.io/#/package/vicoproplus/moon-humanize)。

在 MoonBit 代码中引用：

```moonbit
import "vicoproplus/moon-humanize"                      // 根包：直接提供便捷函数
import "vicoproplus/moon-humanize/src/humanize" as humanize  // 内部模块：类型与扩展 API
```

## 用法

### 数字人文化（Number）

```moonbit
import "vicoproplus/moon-humanize"

intcomma(12345.to_string())        // "12,345"
intword(123455913.to_string())     // "123.5 million"
apnumber(4.to_string())            // "four"
fractional(1.5.to_string())        // "1 1/2"
scientific(500.to_string())        // "5.00 x 10²"
ordinal(123.to_string())           // "123rd"
metric(1234.0)                     // "1.23 k"
clamp(-5.0, floor=0.0)             // "<0"
```

MoonBit 还提供 locale 感知的科学计数法重载，以及纯数值辅助函数：

```moonbit
import "vicoproplus/moon-humanize/src/humanize" as humanize

// 本地化科学计数法（连接符随激活的语言区域变化）
humanize.scientific_localized(3.14159, precision=2, exponent=3)
//   en:     "3.14 x 10^3"
//   ru_RU: "3.14 × 10^3"
//   zh:    "3.14×10^3"

// 纯数值辅助（locale 中性）
humanize.to_scientific(3.14159, 2, 3)          // "3.14 x 10^3"
humanize.to_decimal(1234567.891, decimals=2)   // "1,234,567.89"
humanize.integer_to_words(123)                 // "one hundred and twenty-three"
```

### 时间与日期人文化（Time & date）

```moonbit
import "vicoproplus/moon-humanize"
import "vicoproplus/moon-humanize/src/humanize" as humanize

// 相对日期（与今天比较）
let today = humanize.Date::today()
naturalday(today)                       // "today"（当天）
naturaldate(today)                      // "Aug 20 2026"

// 时长 / 精确时长
let d = humanize.timedelta(days=2, seconds=3633)
naturaldelta(humanize.TimeInput::from_delta(d))   // "2 days and 1 hour"
precisedelta(humanize.TimeInput::from_delta(d))   // "2 days, 1 hour and 33 seconds"
naturaldelta(humanize.TimeInput::from_seconds(1001.0))  // "16 minutes"

// 相对时间
naturaltime(humanize.TimeInput::from_seconds(3600.0))   // "an hour ago"
```

> 时间函数的输入用 `TimeInput` 枚举区分「秒数」与「显式时长 `TimeDelta`」（`naturaltime` 的秒数输入会四舍五入到整秒，与 Python 一致）。`TimeUnit`（microseconds … years）用于 `minimum_unit` / `suppress`。

### 文件大小人文化（File size）

```moonbit
import "vicoproplus/moon-humanize"

naturalsize(1_000_000.0)                 // "1.0 MB"
naturalsize(1_000_000.0, binary=true)   // "976.6 KiB"
naturalsize(1_000_000.0, gnu=true)      // "976.6K"
```

### 列表枚举人文化（Lists）

```moonbit
import "vicoproplus/moon-humanize"

natural_list(["a", "b", "c"])            // "a, b and c"
natural_list(["a", "b"], style="or")     // "a or b"
natural_list(["a"])                      // "a"
```

### 本地化（Localization）

运行时切换语言区域：

```moonbit
import "vicoproplus/moon-humanize"
import "vicoproplus/moon-humanize/src/humanize" as humanize

activate("ru_RU")
naturaltime(humanize.TimeInput::from_seconds(3.0))  // "3 секунды назад"
deactivate()
naturaltime(humanize.TimeInput::from_seconds(3.0))  // "3 seconds ago"
```

`activate` 仅接受 `src/humanize/locale/` 下已有的语言区域目录名（如 `zh_CN`、`pt_BR`）；其余未知或 `en*` 语言区域等价于 `deactivate()`（回退为英文）。

<!-- usage-end -->

## 已移植的 API 对照

| python-humanize | moon-humanize（根包，等价于 `@humanize.*`） | 说明 |
| --- | --- | --- |
| `humanize.clamp(value, floor, ceil, floor_token, ceil_token, format)` | `clamp(value, ~floor, ~ceil, ~floor_token, ~ceil_token, ~format)` | 将数值钳制到区间。 |
| `humanize.metric(value, unit, precision)` | `metric(value : Double, ~unit, ~precision)` | SI 公制前缀格式化。 |
| `humanize.intcomma(value, ndigits)` | `intcomma(value : String, ~ndigits)` | 千分位分隔符；入参为字符串。 |
| `humanize.intword(value, format)` | `intword(value : String, ~format)` | 大数友好量级表达（如 `"123.5 million"`）。 |
| `humanize.apnumber(value)` | `apnumber(value : String)` | 0–9 转为英文单词，其余保持数字串。 |
| `humanize.fractional(value)` | `fractional(value : String)` | 浮点转分数 / 带分数。 |
| `humanize.scientific(value, precision)` | `scientific(value : String, ~precision)` | 科学计数法，指数用上标渲染（`10ⁿ`）。 |
| `humanize.ordinal(value)` | `ordinal(value : String)` | 英文序数后缀（`1st` / `2nd` / `3rd` …）。 |
| `humanize.naturalday(value, when, format)` | `naturalday(value : Date, ~when, ~format)` | 相对日期（今天 / 昨天 / 具体日期）。 |
| `humanize.naturaldate(value, when)` | `naturaldate(value : Date, ~when)` | 相对日期（含年份）。 |
| `humanize.naturaldelta(value, months, minimum_unit)` | `naturaldelta(value : TimeInput, ~months, ~minimum_unit)` | 时长人文化。 |
| `humanize.naturaltime(value, future, months, minimum_unit, when)` | `naturaltime(value : TimeInput, ~future, ~months, ~minimum_unit, ~when)` | 相对时间（"an hour ago"）。 |
| `humanize.precisedelta(value, minimum_unit, format, suppress)` | `precisedelta(value : TimeInput, ~minimum_unit, ~format, ~suppress)` | 精确时长枚举。 |
| `humanize.naturalsize(value, binary, gnu, format, suffix, symbols)` | `naturalsize(value : Double, ~binary, ~gnu, ~format)`（根包）；`@humanize.naturalsize` 另含 `~suffix` / `~symbols` | 字节数转友好大小字符串。 |
| `humanize.natural_list(value, style)` | `natural_list(value : ArrayView[String], ~style, ~cx, ~ox)` | 列表自然语言枚举。 |
| `humanize.activate` / `humanize.deactivate` | `activate(locale)` / `deactivate()` | 激活 / 取消语言区域。 |
| — | `to_scientific` / `to_decimal` / `integer_to_words` / `scientific_localized` | MoonBit 扩展的纯数值 / 本地化辅助函数。 |

## 项目结构

```text
moon-humanize/
├── moonbit/                 # MoonBit 源码（移植核心）
│   ├── moon.mod             # 包元数据（name / version / license）
│   ├── moonbit.mbt          # 根包，对外再导出 @humanize 的全部公共函数
│   └── src/humanize/
│       ├── moon.pkg         # 包依赖与编译目标配置（wasm / native 双后端）
│       ├── number.mbt       # 数字：clamp/metric/intcomma/intword/apnumber/fractional/scientific/ordinal/to_scientific/to_decimal/integer_to_words
│       ├── time.mbt         # 时间：naturalday/naturaldate/naturaldelta/naturaltime/precisedelta + TimeInput/TimeDelta/TimeUnit/Date/DateTime
│       ├── filesize.mbt     # 文件大小：naturalsize
│       ├── lists.mbt        # 列表枚举：natural_list
│       ├── i18n.mbt         # 本地化：activate/deactivate/gettext/ngettext/pgettext + 分隔符查询
│       ├── i18n_data.mbt    # 由 .po 生成的翻译数据（自动生成，勿手改）
│       ├── rational.mbt     # 有理数辅助（fractional / precisedelta 使用）
│       ├── util.mbt         # 上标映射、定点格式化等辅助
│       ├── clock_wasm.mbt   # wasm / wasm-gc 后端的 now()
│       ├── clock_native.mbt # native 后端的 now()
│       └── wasm.mbt         # wasm 导出层（wasm_version / wasm_ready）
├── src/humanize/locale/     # 原 Python .po 翻译文件（翻译数据来源）
├── scripts/po2mbt          # .po -> i18n_data.mbt 代码生成器
├── docs/                    # 设计文档、移植规格说明
└── README.md
```

## 构建与测试

MoonBit 部分使用 MoonBit 工具链构建：

```bash
# 需要已安装 MoonBit 工具链（moon）
cd moonbit
moon build
moon test
```

## 本地化（翻译数据维护）

翻译数据来自原 Python 仓库的 `.po` 文件，并由 `scripts/po2mbt` 生成为 `moonbit/src/humanize/i18n_data.mbt`。CI 通过 `scripts/po2mbt --check` 确保二者同步（修改 `.po` 后需重新运行生成器）。

向已有语言区域补充新短语：

```sh
# 1) 抽取新短语到 .pot
xgettext --from-code=UTF-8 -o humanize.pot -k'_' -k'N_' -k'P_:1c,2' -k'NS_:1,2' -k'_ngettext:1,2' -l python src/humanize/*.py
# 2) 合并到目标语言区域文件
msgmerge -U src/humanize/locale/ru_RU/LC_MESSAGES/humanize.po humanize.pot
# 3) 重新生成 MoonBit 翻译数据
python scripts/po2mbt
```

新增语言区域：

```sh
msginit -i humanize.pot -o src/humanize/locale/<locale>/LC_MESSAGES/humanize.po --locale <locale>
```

其中 `<locale>` 是语言区域缩写，例如 `en_GB`、`pt_BR`，或简写为 `ru`、`fr` 等；并请在本文「支持的语言区域」列表中补充。

> 科学计数法本地化：已新增 `scientific_tmpl`（连接符模板）与 `EXPword1`–`EXPword6`（量级词）两条消息键，目前在 `en`、`ru_RU`、`zh`、`zh_CN` 四个语言区域中提供，其余语言区域自动回退到英文模板。新增语言区域时若需本地化科学计数法，请在其 `.po` 中补充这两个键。

## 与 Python 版本的主要差异（已知移植差距）

1. **入参类型**：Python 接受 `int` / `float` / `str` 等多种类型；MoonBit 的数字函数普遍接受 `String`（数字需先 `to_string()`），`clamp` / `metric` / `naturalsize` 等接受 `Double`。
2. **时间输入建模**：Python 的时间函数接受 `timedelta` / 秒数 / `datetime` 多态入参；MoonBit 用 `TimeInput` 枚举（`Seconds(Double)` / `Delta(TimeDelta)`）显式区分。`naturaltime` 的 `when` 完全语义依赖绝对时间输入，部分场景尚未完全对齐（YAGNI 推迟）。
3. **本地化（i18n）**：MoonBit 移植已完整接入 `gettext` / `ngettext` / `pgettext` 体系，`apnumber` / `fractional` / `scientific` / `ordinal` / 时间函数等用户可见文案已通过 `gettext` 路由，可由 `.po` 提供多语言翻译；英文与未配置语言区域自动回退为英文。
4. **定点格式化**：MoonBit 的 `Double::to_string` 不支持精度说明符，本项目自实现了 `format_fixed`（四舍五入 half-up）以近似 Python 的 `"%.Nf"`（已知差距 R1）。

详细的移植计划与阶段进度见 `docs/specs/port-to-moonbit.md` 及各模块设计文档（`docs/number.md`、`docs/time.md`、`docs/filesize.md`、`docs/i18n.md`、`docs/lists.md`）。

## 许可证

本项目以 MIT 许可证发布，详见 [LICENCE](LICENCE)。其移植的上游项目 [python-humanize](https://github.com/python-humanize/humanize) 同样以 MIT 许可证发布。
