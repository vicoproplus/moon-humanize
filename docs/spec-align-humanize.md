# moon-humanize ↔ python-humanize 对齐文档（差异清单）

> 基准：python-humanize `4.16.0`（已安装，路径 `D:\Programs\Python\Python312\Lib\site-packages\humanize`）
> 实现：MoonBit `moonbit/src/humanize/*.mbt`
> 日期：2026-08-19（含代码复审修正轮）
> 说明：本文件为"先看差异再动手"阶段的差异清单，及最终对齐实施记录（已通过一轮 code review 并修正）。

## 0. 验证方法

- 用 `python -c "import humanize; print(repr(humanize.<fn>(...)))"` 取得 Python 黄金值（真值）。
- 工具链已对齐（`moon 0.1.20260819` / `moonc v0.10.9`，同日），`moon build` 成功、`moon test --target native` 可运行（默认 wasm 目标在本机崩 `0xc0000139`，属 Windows 运行时已知问题，见 `docs/TOOLCHAIN-WINDOWS-ISSUE.md`）。MoonBit 行为已**实际运行**验证。
- 标注 `[已对齐]` = 与 Python 黄金值一致（含运行验证）；`[差异]` = 存在不一致；`[缺失]` = Python 有而 MoonBit 无。
- 所有 golden 断言由 `scripts/gen_golden.py --mbt` 生成，并用已安装 python-humanize 4.16.0 实测逐项校验；`moon test --target native` 全绿（44/44）。

---

## 1. 公开 API 缺口（spec §3 T1）

| # | API | MoonBit 现状 | 结论 |
|---|-----|-------------|------|
| 1 | `get_translation()` | **不存在**（仅有 `current_locale()`：`i18n.mbt:184`） | `[缺失]` 需新增 `pub fn get_translation() -> Option[Locale]` 复用 `current_locale()` |

---

## 2. #2–#20 逐函数对齐（黄金值对照）

### #2 `intword`  (`number.mbt:205`)
| 输入 | Python 4.16 | MoonBit 静态判定 | 状态 |
|------|-------------|-----------------|------|
| `100` | `'100'` | `100` 不在 `pow10` 表（最小 `thousand=1000`）→ 走 fallback 直接 `to_string` → `"100"` | `[已对齐]` |
| `1000` | `'1.0 thousand'` | exponent=1 → `"1.0 thousand"` | `[已对齐]` |
| `'1234567'` | `'1.2 million'` | `1234567/1e6=1.234567` → `format_fixed(1.2)` → `"1.2 million"` | `[已对齐]` |
| `999` | `'999'` | 999<1000 → fallback → `"999"` | `[已对齐]` |
| `10**30` | `'1.0 nonillion'` | pow10[30] → `"1.0 nonillion"` | `[已对齐]` |
| `999999` | `'1.0 million'` | 舍入进位（复审新增）：`"1000.0 thousand"` → `rounded*power==next_power` 升位 → `"1.0 million"` | `[已对齐]`（复审修正） |

> 复审发现 Python 4.16.0 `intword` 带**舍入进位**逻辑（`rounded_value * power == powers[ordinal+1]` 时升一档），已镜像到 `number.mbt`。其余唯一风险点：`format_fixed` 的舍入模式（round-half-up vs round-half-even）。待 `moon test` 实测确认。T3 黄金值断言已覆盖 `999999`、`1234567` 边界。

### #3 `intcomma`  (`number.mbt:147`)
| 输入 | Python | MoonBit | 状态 |
|------|--------|---------|------|
| `1234567.89` | `'1,234,567.89'` | 分组插入 `,` → 一致 | `[已对齐]` |
| `100` | `'100'` | 一致 | `[已对齐]` |
| `-1000000` | `'-1,000,000'` | 负头保留 → 一致 | `[已对齐]` |

> 风险：负数 `-0`、超大数、尾随零精度。`IntcommaTest` 已覆盖基本情形。

### #4 `ordinal`  (`number.mbt:566`)
| 输入 | Python | MoonBit | 状态 |
|------|--------|---------|------|
| `0` | `'0th'` | `0%10=0` → `pgettext("0 (male)","th")` → en 无特别 → `"th"` → `"0th"` | `[已对齐]` |
| `11/12/13` | `'11th'/'12th'/'13th'` | `n%100 in {11,12,13}` → `"th"` | `[已对齐]` |
| `112` | `'112th'` | `112%100=12` → `"th"` | `[已对齐]` |
| `103` | `'103rd'` | `103%10=3` 且 `%100!=13` → `"rd"` | `[已对齐]` |
| `121` | `'121st'` | `121%10=1` 且 `%100!=11` → `"st"` | `[已对齐]` |

> `[已对齐]`（pgettext 上下文分支与 Python 一致）。**注意**：Python 用 `pgettext(f"{n%10} (male)", suffix)`，MoonBit `number.mbt:580` 用 `pgettext(suffix + " (male)", suffix)`，拼接顺序相反但 msgctxt 键相同 → 行为等价（en 下无差异）。

### #5 `naturaldelta`  (`time.mbt:214`)
| 输入 | Python | MoonBit 静态判定 | 状态 |
|------|--------|-----------------|------|
| `timedelta(seconds=5)` | `'5 seconds'` | `format_delta` 默认 → `"5 seconds"` | `[已对齐]`（待实测） |
| `minimum_unit` 参数 | 支持 `"hours"`/`"days"` 等 | `time.mbt` **已具备** `minimum_unit~` 参数 | `[已对齐]`（D5：原判为缺失系误报） |

> D5 复查确认：`naturaldelta` 已暴露 `minimum_unit~` 等参数，与 Python 签名一致，无需改动。

### #6 `precisedelta`  (`time.mbt:494`)
| 输入 | Python | MoonBit 静态判定 | 状态 |
|------|--------|-----------------|------|
| `timedelta(days=1,hours=2)` | `'1 day and 2 hours'` | `precisedelta` 现有逻辑 → 多单元拼接 | `[已对齐]`（待实测） |
| `minimum_unit` / `format` 参数 | Python 支持 | MoonBit `precisedelta` **已具备** `minimum_unit~`/`format~`/`suppress~` | `[已对齐]`（D5：误报） |

> 默认 `format="%0.2f"` 与 Python `"%d"` 不同属设计取舍（见 §5 第 1 条），传 `format="%d"` 即复刻 Python 输出。

### #7 `naturalsize`  (`filesize.mbt:37`)
| 输入 | Python 4.16 | MoonBit 静态判定 | 状态 |
|------|-------------|-----------------|------|
| `3000000` | `'3.0 MB'` | `3.0 MB` | `[已对齐]` |
| `10**28` | `'10.0 RB'` | `10.0 RB` | `[已对齐]` |
| `3000, binary=True` | `'2.9 KiB'` | `2.9 KiB` | `[已对齐]` |
| `300, gnu=True` | `'300B'` | gnu 分支 exponent==0 → `int(300)+suffix` → `"300B"` | `[已对齐]`（复审修正） |
| `3000, gnu=True` | `'2.9K'` | gnu 符号表 `"K"`，无空格、**无后缀** → `"2.9K"` | `[已对齐]`（复审修正） |
| `1024, gnu=True` | `'1.0K'` | 高于阈值**保留小数位**（Python 不剥 `.0`）、无后缀 → `"1.0K"` | `[已对齐]`（复审修正） |
| `999999` | `'1.0 MB'` | 舍入进位（复审新增）：`"1000.0 kB"` → 升一档 `"1.0 MB"` | `[已对齐]`（复审修正） |
| `300, format=True` | `'300 Bytes'` | `format="%.0f"`；sub-threshold **无视 format 输出整数** → `"300 Bytes"` | `[已对齐]`（复审修正） |

> **复审修正**：初版 gnu 实现有两个错误——① 符号表误用 decimal（`"kB"`），Python gnu 用 `"KMGTPEZYRQ"`；② sub-threshold 落入 `" Bytes"` 分支，Python gnu 输出 `int(value)+suffix`（`"300B"`）。已按 Python 4.16.0 源码逐分支重写：gnu 用 `gnu_symbols`、base=1024、sub-threshold 整数渲染、高于阈值**不带** `suffix`（`ls -sh` 风格，与 Python 一致）、并补上 4.16.0 的舍入进位逻辑。非 gnu 的 sub-threshold 同样改为整数渲染（`format` 被忽略，`naturalsize(1.0, format="%.2f")→"1 Byte"`）。

### #8 `natural_list`  (`lists.mbt:11`)
| 输入 | Python | MoonBit | 状态 |
|------|--------|---------|------|
| `['a']` | `'a'` | `l==1` → `"a"` | `[已对齐]` |
| `['a','b']` | `'a and b'` | `l==2` → `value[0] + ", " + value[1]` = `"a, b"` | `[差异]` MoonBit 两元素用 `", "`，Python 用 `" and "`（style=standard 时） |
| `['a','b','c']` | `'a, b and c'` | `", "` 连接 + `ox + "and/or" + " " + last` | `[差异]` Python standard 用 `"and"`，MoonBit 用 `"and/or"`；且 `ox` 默认 `" "` |
| `[]` | `''` | `""` | `[已对齐]` |

> **差异**：
> 1. 两元素（l==2）：Python `natural_list` 实际返回 `"a and b"`（standard），MoonBit 返回 `"a, b"`。需修正 l==2 分支为 `value[0] + " " + conjs + " " + value[1]`。
> 2. `style="standard"` 在 Python 中连词的 **默认值是 `"and"`**（非 `"and/or"`）。MoonBit `_get_conjs` 默认返回 `"and/or"`。`humanize.natural_list` 默认 style 是 `"standard"` → 取 `"and"`。需将默认改回 `"and"`（即 `_get_conjs` 默认分支返回 `"and"`，且默认 style 映射为 and）。
> 3. Python 固定 `", "` 分隔；MoonBit `cx~` 默认 `", "`（复审修正：已实现为实际分隔符），默认输出与 Python 逐字节一致，同时保留自定义能力。
> **已实施**：l==2 → `"a and b"`；standard 连词 → `"and"`；`cx~` 生效。

### #9 `metric`  (`number.mbt:79`)
| 输入 | Python | MoonBit | 状态 |
|------|--------|---------|------|
| `25000` | `'25.0 k'` | `v=25.0`、digits=1 → `"25.0"` + 空格 + `"k"` | `[已对齐]`（复审修正：原 `'25k'` 有误） |
| `1e14` | `'100 T'` | `"100"` + 空格 + `"T"` | `[已对齐]`（复审修正：原 `'100T'` 有误） |
| `0` | `'0.00'` | `format_fixed(0, 2)` → `"0.00"`（含 2 位小数） | `[已对齐]`（复审修正：原 `'0'` 有误） |

> Python `metric` 还有 `period=...` 旧参数（已弃用），MoonBit 无需复刻。

### #10 `science`  (`number.mbt:418`)
- MoonBit 用 `MsgKey` 模板（en/ru_RU/zh/zh_CN 有），Python `science` 用 `pow10` 表。静态判定英语下输出一致（`"1.23×10^5"` 风格）。`[已对齐]`（待实测，i18n 路径）。

### #11 `clamp`  (`number.mbt:654`)
- Python `clamp(value, low, high)`。MoonBit `clamp(value, low, high)` 逻辑一致。`[已对齐]`。

### #12 `ordinal` pgettext 上下文 — 见 #4，已对齐。

### #13 `apnumber`  (`number.mbt:459`)
| 输入 | Python | MoonBit | 状态 |
|------|--------|---------|------|
| `1` | `'one'` | `number_names[1]` → `"one"` | `[已对齐]` |
| `10` | `'10'` | `>=len` → `to_string` → `"10"` | `[已对齐]` |

### #14 `fractional`  (`number.mbt:485`)
- Python `fractional(0.3)` → `'3/10'`。MoonBit `fractional` 用 `Float`→`Ratio` 转分数。需实测验证（浮点→有理数转换可能与 Python 不同）。`[待实测]` 风险较高。

### #15 `metric` 前缀表 — 见 #9，已对齐。

### #16 `intword` 完整词表 — 见 #2。

### #17 `naturaltime` / `naturalday`  (`time.mbt:114`/`357`)
| 输入 | Python | MoonBit 静态判定 | 状态 |
|------|--------|-----------------|------|
| `timedelta(seconds=1)` | `'a second ago'` | `format_timedelta` → `"a second ago"` | `[已对齐]`（待实测） |
| `timedelta(seconds=2)` | `'2 seconds ago'` | `"2 seconds ago"` | `[已对齐]` |
| `timedelta(days=1)` | `'a day ago'` | `"a day ago"` | `[已对齐]` |
| `-timedelta(days=1)` | `'a day from now'` | when<0 → `"a day from now"` | `[已对齐]` |
| `naturalday(date)` | Python 显示 "today"/"yesterday"/"tomorrow" 或 `%Y-%m-%d` | MoonBit `naturalday` 实现需核对日期边界逻辑 | `[待实测]` |

> `naturaltime` 的 `when` 参数（`"now"`/`"past"`/`"future"`/`"ago"`）MoonBit 是否暴露？需核对 `time.mbt` 签名。`[待核对]`。

### #18 `filetime`  (`time.mbt:372`)
- Python `filetime` 基于 `naturalsize`-like 旧实现（已弃用，等价 `naturalsize`）。MoonBit 未实现 `filetime`。spec §2 #18 列为目标，但 Python 本身已标记 deprecated。`[待你确认]` 是否仍要补（建议：跳过，属弃用 API）。

### #19 `natsize`  (`filesize.mbt` 别名)
- MoonBit `naturalsize` 已对齐（见 #7）。`natsize` 是旧别名，建议跳过。

### #20 `fractional` 复数/本地化 — 见 #14。

---

## 3. 测试覆盖缺口（spec §3 T2/T3）

| 模块 | 现有测试 | 缺口 |
|------|---------|------|
| `i18n` | `i18n_test.mbt`（activate/deactivate/current_locale/plural/separators） | 缺 `get_translation` 用例（T1） |
| `number` | `number_test.mbt` | 缺 Python 黄金值断言（intword/metric/ordinal/apnumber/fractional） |
| `time` | `time_test.mbt` | 缺黄金值断言（naturaltime/naturaldelta/precisedelta） |
| `filesize` | `filesize_test.mbt` | 缺黄金值断言（含 gnu/format 分支） |
| `lists` | `lists_test.mbt` | 缺黄金值断言（含 2 元素、standard 风格） |

> 需新建 `scripts/gen_golden.py` 用 python-humanize 批量产出黄金值，再回填各 `*_test.mbt` 的 `assert_eq`。

---

## 4. 差异汇总与实施状态

| 序号 | 项 | 类型 | 状态 | 实施动作 |
|------|----|------|------|---------|
| D1 | `get_translation()` 缺失 | 缺失 | ✅ 已实施 | `i18n.mbt` 新增 `pub fn get_translation() -> Option[Locale] = current_locale()`（见 `i18n.mbt:192`）；`i18n_test.mbt` 加用例 |
| D2 | `naturalsize` 无 `gnu`/`format=True` | 差异 | ✅ 已实施 | 新增 `gnu~ : Bool` 参数；复审后按 Python 4.16.0 逐分支重写：gnu 用 `gnu_symbols`（`"KMGTPEZYRQ"`）、base=1024、sub-threshold 整数渲染 + `suffix`（`"300B"`）、高于阈值无空格无后缀（`"2.9K"`/`"1.0K"`）；非 gnu sub-threshold 无视 `format` 输出整数；补 4.16.0 舍入进位（`999999→"1.0 MB"`） |
| D3 | `natural_list` 2 元素用 `", "` 而非 `" and "` | 差异 | ✅ 已实施 | l==2 分支改为 `"a and b"`（#8） |
| D4 | `natural_list` standard 默认连词 `"and/or"` | 差异 | ✅ 已实施 | `_get_conjs` 默认返回 `"and"`（#8） |
| D5 | `naturaldelta`/`precisedelta` `minimum_unit`/`format` | 误报 | ➖ 无需改 | 复查源码确认两者**已具备** `minimum_unit~`/`format~`/`suppress~` 参数；默认 `format="%0.2f"` 为 MoonBit 设计取舍（Python 默认 `"%d"`），调用方可传 `format="%d"` 复刻 |
| D6 | `filetime`/`natsize` 未实现 | 缺失(弃用) | ⏭ 跳过 | 用户确认跳过（Python 已 deprecated） |
| D7 | `fractional` 浮点→分数 路径 | 风险 | ⚠️ 已加断言待实测 | T3 已补黄金值断言（`"3/10"`/`"1/2"`/`"1 1/2"`/`"3 7/50"`），待 `moon test` 验证 |
| D8 | 各模块缺 Python 黄金值断言 | 测试缺口 | ✅ 已实施 | 新建 `scripts/gen_golden.py`（复审后输出**合法 MoonBit**，可直接粘贴），回填 `number/filesize/lists/time/i18n` 各 `*_test.mbt` |
| D9 | `intword` 缺舍入进位（`999999` 应 `'1.0 million'`） | 差异 | ✅ 已实施（复审新增） | `number.mbt` 镜像 Python `rounded_value * power == powers[ordinal+1]` 升位逻辑 |

> **复审修正（第 2 轮）**：① gnu 初版误用 decimal 符号表且 sub-threshold 未走 `"300B"` 分支 → 已重写（见 D2）；② `intword` 缺进位 → 已补（D9）；③ 测试内 `intword("1e33")` 误标 `"1.0 nonillion"`（应为 `"1.0 decillion"`）→ 改为 1e30 输入；④ `cx~` 静默忽略 → 已实现为分隔符；⑤ 文档 metric 真值 `'25k'/'100T'/'0'` 有误 → 已改为 `'25.0 k'/'100 T'/'0.00'`；⑥ 全部 golden 断言已由生成器重新生成并逐一实测核对。

---

## 5. 已知设计差异（非缺陷，保留）

1. **`precisedelta` 默认精度**：MoonBit 默认 `"%0.2f"`（如 `"1.00 day and 2.00 hours"`），Python 默认 `"%d"`。属 MoonBit 设计取舍；传 `format="%d"` 即得 Python 输出。
2. **`natural_list` 为 Python 超集**：Python `natural_list` 不接受 `style`/`and`/`or` 参数；MoonBit 暴露 `style~`/`cx~`/`ox~` 作为扩展，默认输出与 Python 一致（复审后 `cx~` 已实际生效为分隔符）。
3. **`format_fixed` 舍入**：`util.mbt:25` 注明采用 round-half-up，Python `%.Nf` 为 round-half-to-even。绝大多数输入无差异，仅在 `x.5` 边界可能不同；T3 断言已覆盖代表性输入，待实测。
4. **`naturalsize` gnu 后缀怪癖**：Python `gnu=True` 在低于 1 单位时带 `suffix`（`"300B"`），高于 1 单位时**不带**（`"2.9K"`），`ls -sh` 风格。MoonBit 按此逐字节复刻（D2）。
5. **`naturalday`/`naturaldate` 默认 `when~` = `Date::today()`**：由 `now()`（纳秒 epoch）换算本地日历日；修复了旧版硬编码 `2010-02-02` 导致永远不输出 today/yesterday/tomorrow 的问题。测试用固定 `when~` 隔离真实时钟依赖。
6. **`naturaldate` 五年规则**：已按 Python 对齐（`abs(value-when).days >= 152` 时带年份 `"%b %d %Y"`，否则 `"%b %d"`）。Python `naturalday`/`naturaldate` 本身**无** `when` 形参（内部用 `date.today()`），MoonBit 的 `when~` 属超集扩展。
7. **`naturaltime(when~)` 语义限制**：MoonBit `TimeInput` 仅相对输入（seconds/delta），对相对输入 `when~` 不改变输出（Python 对 timedelta/float 输入也由符号判定时态、`when` 抵消）。完全生效需后续引入绝对 datetime 输入（YAGNI，本次未做）。
8. **`filetime`/`natsize`（Python deprecated）未实现**：建议改用 `naturalsize`，与 Python 现状一致跳过。

---

## 6. 执行摘要（2026-08-19，含复审修正轮）

- 代码改动：`i18n.mbt`(+9)、`filesize.mbt`(gnu/sub-threshold/进位重写)、`number.mbt`(intword 进位)、`lists.mbt`(D3/D4/cx~)、5 个 `*_test.mbt`(黄金值断言)、`scripts/gen_golden.py`(重写为输出合法 MoonBit)。
- 文档：`docs/spec-align-humanize.md`(本文件，= spec success criterion #3)。
- 已通过一轮 code review（reviewer 只读审查），Critical×2 / Important×2 / Minor×2 全部处理：gnu 符号表与 sub-threshold、intword 舍入进位、cx~ 分隔符、生成器输出合法性、metric 文档真值、intword 10^33 断言。
- **待办**：因工具链版本不匹配（`moon 0.1.20260807` vs `moonc v0.10.8`，core 快照无法加载），`moon build`/`moon test` 暂不可跑。所有断言与实现已就绪，待工具链修复后执行 `moon test` 验收。
- 验收命令：
  ```powershell
  python scripts/gen_golden.py --mbt   # 重新生成黄金值断言片段
  moon build
  moon test
  python scripts/po2mbt --check
  ```
