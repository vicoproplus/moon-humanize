# 实现计划：将 python-humanize 移植到 MoonBit

> 本文件为 **living document（活文档）**，记录从 `python-humanize` 项目到 MoonBit 的移植计划与进度。
> 源规范：`docs/specs/port-to-moonbit.md`
> 当前 MoonBit 工具链：`moon 0.1.20260807`（注意：与规范中声称的 `0.1.20260629` 不一致，以实际版本为准）
> 仓库现状：MoonBit 侧仅有 Phase 1 起手骨架（根 `moonbit.mbt` 的 `intcomma`、子包 `humanize/*` 的占位/空文件），尚未实现任何真实逻辑。

---

## 0. 范围与原则（来自规范 §9）

| 保留范围 | 暂不移植（范围外） |
|---|---|
| 数值：`intcomma, ordinal, apnumber, intword, scientific, clamp, metric, fractional` | i18n / 本地化（如 `de, en, pt_BR` 等 locale 模块） |
| 时间：`naturaltime, naturalday, naturaldelta, precisedelta` | `i18n.py`、`locale/*.py` |
| 文件大小：`naturalsize` | 测试中的 locale 特定断言 |
| 列表：`natural_list` | |

**质量标准**：每个函数至少 3 个测试用例（含边界/异常），作为黄金值对比 Python 参考实现。

---

## 1. 关键发现与待核实项（P0 — 执行前必须先解决）

在执行 Phase 1 之前，必须验证 MoonBit 标准库是否提供以下能力，因为 `number.py` 重度依赖它们。这些都是**已知移植缺口**，需要逐个确认并有 fallback：

| # | 需求（Python 来源） | MoonBit 候选 | 风险 | 状态 |
|---|---|---|---|---|
| G1 | `Int` 分组/千位分隔（intcomma） | 字符串遍历手动插入 `,` | 低，纯算法 | ⬜ 待实现 |
| G2 | `Double` 定点格式化（`"%.Nf"`） | 规范称 `Double::to_string` 不支持精度 → 需**自实现** `format_fixed` | 中，`util.mbt` 已占位 | ⬜ 待实现 |
| G3 | `round()` 四舍五入、`math.floor`、`math.log10` | `math` 包：`math.floor`? `math.log10`? 需确认 | 中 | ⬜ 待核实 |
| G4 | `fractions.Fraction`（fractional、precisedelta） | MoonBit 无原生有理数类型 → 需**自实现有理数**（分子/分母 + gcd） | **高**，代表性缺口 | ⬜ 待核实/自实现 |
| G5 | `decimal.Decimal`（scientific 高精度指数） | 可用 `Double` 近似；超高精度需自实现 | 中 | ⬜ 待定 |
| G6 | `datetime`（time.py） | `moonbitlang/core/time`：是否有 `DateTime`/时间戳？ | **高**，需确认 | ⬜ 待核实 |
| G7 | `datetime.timedelta` 相减得到天数 | 时间差运算 | 高 | ⬜ 待核实 |
| G8 | `Map[Char,Char]` 字符映射（scientific 上标） | `util.mbt` 已用 `Map[Char,Char]` | 低 | ✅ 已就绪 |
| G9 | `str.format` / f-string | 字符串拼接 | 低 | ⬜ 待实现 |

**执行第一项动作**：在 Phase 1 启动前，运行 `moon doc` 或查阅 `moonbitlang/core` 源码，确认 G3、G4、G6、G7 的真实可用性，并在本文件记录结论。

### 已知移植缺口（规范 R1）
- **定点/精度格式化**（G2）：MoonBit `Double` 转字符串无精度控制，需自实现 `format_fixed`（四舍五入 + 小数部分补零）。
- **有理数**（G4）：`fractional` / `precisedelta` 需要精确分数运算，建议新增 `moonbit/src/humanize/rational.mbt`（或 `util` 内）实现 `Fraction` 类型（`normalize` 用欧几里得 gcd）。
- **时间类型**（G6/G7）：若 `core/time` 不支持足够的时间运算，需设计最小 `DateTime`/`Duration` 抽象或约束 API 接受"自纪元起的秒数"。

---

## 2. 目录结构（目标）

```
moonbit/
├── moon.mod
├── moon.pkg
├── moonbit.mbt                 # 包根：重新导出 humanize 公共 API（intcomma 等）
└── src/
    └── humanize/
        ├── moon.pkg            # 当前 import core/math
        ├── number.mbt          # intcomma, ordinal, apnumber, intword, scientific, clamp, metric, fractional
        ├── time.mbt            # naturaltime, naturalday, naturaldelta, precisedelta
        ├── filesize.mbt        # naturalsize
        ├── lists.mbt           # natural_list
        ├── util.mbt            # format_fixed, superscript map, 以及新增 rational/helpers
        └── rational.mbt        # [新增] 最小有理数类型（支撑 fractional/precisedelta）
```

---

## 3. 分阶段实现计划

### Phase 1 — number.mbt（数值类）
**目标函数**：`intcomma, ordinal, apnumber, intword, scientific, clamp, metric, fractional`
**依赖**：G2（format_fixed 完善）、G3（floor/log10）、G4（rational，fractional 需要）

步骤：
1. 完善 `util.mbt::format_fixed`：实现 `Double` 定点四舍五入（用 `math.floor` 或自实现 round）。
2. 实现 `intcomma`：将 `Int` 绝对值按 3 位分组插入逗号（参考测试：`1234567 → "1,234,567"`，`-10311 → "-10,311"`）。
3. 实现 `ordinal`：英文序数后缀（1st/2nd/3rd/4th…11th/12th/13th，以及 21st 等）。
4. 实现 `apnumber`：1–9 返回英文单词，≥10 返回数字字符串。
5. 实现 `intword`：按 10³ 幂映射（thousand/million/billion…），测试：`123456789 → "123.5 million"`；`-1234567 → "-1.2 million"`。
6. 实现 `scientific`：用 `format_fixed` + 上标 map（`util.superscript`）输出 `1.23×10⁹` 风格（测试：`12345 → "1.23×10⁴"`）。
7. 实现 `clamp`：`min ≤ x ≤ max` 钳制。
8. 实现 `metric`：SI 前缀（k/M/G/T…），测试：`1234567 → "1.2M"`；`-1234567 → "-1.2M"`。
9. 实现 `fractional`：用 `rational.mbt` 将小数部分转分数（测试：`1.5 → "1 1/2"`；`1.25 → "1 1/4"`；`1.3 → "1 3/10"`）。
10. **验证**：`moon test` 全部通过；在 `tests/` 下建立 MoonBit 测试或对照 Python 黄金值。

### Phase 2 — time.mbt（时间类）
**目标函数**：`naturaltime, naturalday, naturaldelta, precisedelta`
**依赖**：G6/G7（时间类型），G4（rational，precisedelta 需要）
步骤：
1. 确认 `core/time` 能力；若不足，定义最小 `DateTime`/`Duration` 抽象（API 接受时间戳，避免依赖 Python datetime）。
2. `naturaldelta`：将时长转人类语言（"3 days, 4:10:01" / "a day"）。
3. `precisedelta`：用有理数输出精确分量（"1 month, 2 days"）。
4. `naturalday`：相对今天（"today/yesterday/tomorrow" 或日期）。
5. `naturaltime`：相对时间（"3 minutes ago" / "5 hours from now"）。
6. 注意 `naturaltime` 的 `when` 参数与 docstring 限制的偏差（规范 §"naturaltime"段注明），按参考库实际行为实现。

### Phase 3 — filesize.mbt + lists.mbt
**filesize — `naturalsize`**：
- 二进制（1024）与十进制（1000）两种模式（测试：`1024 → "1.0 KiB"`；`123456789 → "117.7 MB"` 二进制，`"123.5 MB"` 十进制）。
- 支持 `gnu` 格式、自定义 `pow`、自定义后缀。
**lists — `natural_list`**：
- 逗号/&/oxford 风格（测试：`["a","b","c"] → "a, b, and c"`；`["a"] → "a"`；`["a","b"] → "a and b"`）。

### Phase 4 — 集成与质量闸
1. `moonbit.mbt` 根包重新导出 `humanize` 公共函数。
2. 全量 `moon test`（每函数 ≥3 用例）。
3. `moon check` 通过、`moon fmt` 已格式化。
4. 对照 Python 黄金值建立对照表（见 §4）。

---

## 4. 黄金值对照表（来自 `tests/test_*.py`）

| 函数 | 输入 | 期望输出 | 来源测试 |
|---|---|---|---|
| intcomma | `1234567` | `"1,234,567"` | test_number.py |
| intcomma | `-10311` | `"-10,311"` | test_number.py |
| ordinal | `1,2,3,4,11,12,13,21,100` | `1st,2nd,3rd,4th,11th,12th,13th,21st,100th` | test_number.py |
| apnumber | `1,9,10` | `one,nine,10` | test_number.py |
| intword | `123456789` | `"123.5 million"` | test_number.py |
| intword | `-1234567` | `"-1.2 million"` | test_number.py |
| intword | `1234567890` | `"1.2 billion"` | test_number.py |
| scientific | `12345` | `"1.23×10⁴"` | test_number.py |
| clamp | `0,bytes=1` | `1` | test_number.py |
| clamp | `5,bytes=4` | `4` | test_number.py |
| metric | `1234567` | `"1.2M"` | test_number.py |
| metric | `-1234567` | `"-1.2M"` | test_number.py |
| fractional | `1.5` | `"1 1/2"` | test_number.py |
| fractional | `1.25` | `"1 1/4"` | test_number.py |
| fractional | `1.3` | `"1 3/10"` | test_number.py |
| naturalsize | `1024` | `"1.0 KiB"` | test_filesize.py |
| naturalsize | `123456789` | `"117.7 MB"` (binary) / `"123.5 MB"` (decimal) | test_filesize.py |
| naturalsize | `987` | `"987 B"` | test_filesize.py |
| natural_list | `["Claude","Pongo","Judith"]` | `"Claude, Pongo, and Judith"` | test_lists.py |
| natural_list | `["Claude"]` | `"Claude"` | test_lists.py |
| natural_list | `["Claude","Pongo"]` | `"Claude and Pongo"` | test_lists.py |

---

## 5. 进度追踪

| Phase | 状态 | 备注 |
|---|---|---|
| P0 能力核实（G1–G9） | ⬜ 待开始 | 阻塞 Phase 1/2 |
| Phase 1 number | ⬜ 待开始 | |
| Phase 2 time | ⬜ 待开始 | |
| Phase 3 filesize+lists | ⬜ 待开始 | |
| Phase 4 集成/测试 | ⬜ 待开始 | |

---

## 6. 风险与决策记录

- **R1 定点格式化**：见 §1 G2，自实现 `format_fixed`。
- **R2 有理数**：见 §1 G4，新增 `rational.mbt`。
- **R3 时间 API 形态**：`naturaltime` 等若依赖完整 datetime，可能需调整 API 设计为接受"自纪元秒数"，以保持 MoonBit 端自洽（规范未强制 API 完全一致，仅要求行为对照）。
- **R4 工具链版本**：实际 `0.1.20260807` ≠ 规范声称 `0.1.20260629`；实现时以其实际提供能力为准，不假设规范列出的特性均可用。
- **R5 范围外**：i18n/locale 模块不移植；任何需要 locale 数据的函数按 `en` 默认行为实现。
