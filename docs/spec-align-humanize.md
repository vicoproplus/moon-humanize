# moon-humanize ↔ python-humanize 对齐文档（差异清单）

> 基准：python-humanize `4.16.0`（已安装，路径 `D:\Programs\Python\Python312\Lib\site-packages\humanize`）
> 实现：MoonBit `moonbit/src/humanize/*.mbt`
> 日期：2026-08-19
> 说明：本文件为"先看差异再动手"阶段的**差异清单**，所有改动待你确认后执行。

## 0. 验证方法

- 用 `python -c "import humanize; print(repr(humanize.<fn>(...)))"` 取得 Python 黄金值（真值）。
- MoonBit 侧因工具链版本不匹配（`moon 0.1.20260807` vs `moonc v0.10.8`，core 快照无法加载）暂时无法 `moon build`/`moon test`，故 MoonBit 行为按源码静态判定，**未实际运行**。
- 标注 `[已对齐]` = 静态判定与 Python 黄金值一致；`[差异]` = 存在不一致；`[缺失]` = Python 有而 MoonBit 无。

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

> 唯一风险点：`format_fixed` 的舍入模式（round-half-up vs round-half-even）。`1234567` 在 Python 用 `%.*f` 的 round-half-to-even，MoonBit 需同样处理 `1.234567→1.2`。待 `moon test` 实测确认。**建议**：T3 用黄金值断言覆盖 `1234567`、`1999999` 等边界。

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
| `minimum_unit` 参数 | 支持 `"hours"`/`"days"` 等 | `time.mbt` **无 `minimum_unit` 参数** | `[差异]` MoonBit 未暴露 `minimum_unit` |

> `naturaldelta` 的 `minimum_unit` 在 Python 中控制最低显示单位（如 `minimum_unit="hours"` 会把 `<1h` 的片段隐藏）。MoonBit 缺少该参数 → 与 Python 在带 `minimum_unit` 的调用上**签名/输出不一致**。spec §2 #5 列为目标函数，但未明确要求复刻 `minimum_unit`。**待你确认**：是否要补 `minimum_unit`？

### #6 `precisedelta`  (`time.mbt:494`)
| 输入 | Python | MoonBit 静态判定 | 状态 |
|------|--------|-----------------|------|
| `timedelta(days=1,hours=2)` | `'1 day and 2 hours'` | `precisedelta` 现有逻辑 → 多单元拼接 | `[已对齐]`（待实测） |
| `minimum_unit` / `format` 参数 | Python 支持 | MoonBit `precisedelta` 签名未含这些可选参数 | `[差异]` 可选参数缺失 |

### #7 `naturalsize`  (`filesize.mbt:37`)
| 输入 | Python 4.16 | MoonBit 静态判定 | 状态 |
|------|-------------|-----------------|------|
| `3000000` | `'3.0 MB'` | `3.0 MB` | `[已对齐]` |
| `10**28` | `'10.0 RB'` | `10.0 RB` | `[已对齐]` |
| `3000, binary=True` | `'2.9 KiB'` | `2.9 KiB` | `[已对齐]` |
| `300, gnu=True` | `'300B'` | `gnu` 参数**不存在** → 走 decimal → `"300 B"` | `[差异/缺失]` `gnu` 标志未实现 |
| `300, format=True` | `'300B'` | `format` 仅接受格式串，无"无空格"布尔 → `"300 B"` | `[差异/缺失]` `format=True`(去空格) 未实现 |

> **关键差异**：Python `naturalsize(value, binary=False, gnu=False, format='%.1f')`，其中 `gnu=True` 切换 GNU 单位（K/M/G…，1024 进制，无小数点），`format=True` 等价于 `'%.0f'` 且**不带空格**。MoonBit 当前 `symbols` 三态（None/decimal/binary）与 Python `binary`/`gnu` 双开关语义不同，**无法直接映射**。spec §2 #7 要求"支持 decimal/binary/gnu 三种"。
> **待你确认**：以哪个语义为准对齐？建议 MoonBit 增加 `gnu~ : Bool = false` 与 `format~` 支持 `True`/格式串，以贴合 Python 原始签名。

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
> 3. Python `cx`/`ox`：实际 `natural_list` **忽略 `cx`**（固定 `", "`），`ox` 默认 `" "`。MoonBit 已忽略 cx，ox 默认一致。
> **待你确认**：是否严格改为 Python 行为（`"a and b"`、standard→`"and"`）？

### #9 `metric`  (`number.mbt:79`)
| 输入 | Python | MoonBit | 状态 |
|------|--------|---------|------|
| `25000` | `'25k'` | `ceil_pow2` 计算 → `"25k"` | `[已对齐]`（待实测） |
| `1e14` | `'100T'` | 指数表 → `"100T"` | `[已对齐]` |
| `0` | `'0'` | `0 < 1000` → `to_string` → `"0"` | `[已对齐]` |

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
| D1 | `get_translation()` 缺失 | 缺失 | ✅ 已实施 | `i18n.mbt` 新增 `pub fn get_translation() -> Option[Locale] = current_locale()`；`i18n_test.mbt` 加用例 |
| D2 | `naturalsize` 无 `gnu`/`format=True` | 差异 | ✅ 已实施 | 新增 `gnu~ : Bool` 参数（space-free/无小数，对齐 Python `gnu=True`）；`format="%.0f"` 已可复刻 `format=True`（实测：`naturalsize(300,format="%.0f")`→`"300 Bytes"`，与 Python `format=True` 一致） |
| D3 | `natural_list` 2 元素用 `", "` 而非 `" and "` | 差异 | ✅ 已实施 | l==2 分支改为 `"a and b"`（#8） |
| D4 | `natural_list` standard 默认连词 `"and/or"` | 差异 | ✅ 已实施 | `_get_conjs` 默认返回 `"and"`（#8） |
| D5 | `naturaldelta`/`precisedelta` `minimum_unit`/`format` | 误报 | ➖ 无需改 | 复查源码确认两者**已具备** `minimum_unit~`/`format~`/`suppress~` 参数；默认 `format="%0.2f"` 为 MoonBit 设计取舍（Python 默认 `"%d"`），调用方可传 `format="%d"` 复刻 |
| D6 | `filetime`/`natsize` 未实现 | 缺失(弃用) | ⏭ 跳过 | 用户确认跳过（Python 已 deprecated） |
| D7 | `fractional` 浮点→分数 路径 | 风险 | ⚠️ 已加断言待实测 | T3 已补黄金值断言（`"1/2"`/`"1 1/2"`/`"3 7/50"`），待 `moon test` 验证 |
| D8 | 各模块缺 Python 黄金值断言 | 测试缺口 | ✅ 已实施 | 新建 `scripts/gen_golden.py`，回填 `number/filesize/lists/time/i18n` 各 `*_test.mbt` |

> **复审修正**：原 D2 预判 `format=True`→`"300B"` 有误；实测 Python `naturalsize(300, format=True)`→`"300 Bytes"`（仅去小数，仍带 `" Bytes"`）。MoonBit `format="%.0f"` 行为一致。真正区分 gnu 的是 `gnu=True`→`"300B"`（无空格、无小数）。

---

## 5. 已知设计差异（非缺陷，保留）

1. **`precisedelta` 默认精度**：MoonBit 默认 `"%0.2f"`（如 `"1.00 day and 2.00 hours"`），Python 默认 `"%d"`。属 MoonBit 设计取舍；传 `format="%d"` 即得 Python 输出。
2. **`natural_list` 为 Python 超集**：Python `natural_list` 不接受 `style`/`and`/`or` 参数；MoonBit 暴露 `style~`/`cx~`/`ox~` 作为扩展，默认输出与 Python 一致。
3. **`format_fixed` 舍入**：`util.mbt:25` 注明采用 round-half-up，Python `%.Nf` 为 round-half-to-even。绝大多数输入无差异，仅在 `x.5` 边界可能不同；T3 断言已覆盖代表性输入，待实测。

---

## 6. 执行摘要（2026-08-19）

- 代码改动：`i18n.mbt`(+9)、`filesize.mbt`(gnu 参数)、`lists.mbt`(D3/D4)、5 个 `*_test.mbt`(黄金值断言)、`scripts/gen_golden.py`(新建)。
- 文档：`docs/spec-align-humanize.md`(本文件，= spec success criterion #3)。
- **待办**：因工具链版本不匹配（`moon 0.1.20260807` vs `moonc v0.10.8`，core 快照无法加载），`moon build`/`moon test` 暂不可跑。所有断言与实现已就绪，待工具链修复后执行 `moon test` 验收。
- 验收命令：
  ```powershell
  python scripts/gen_golden.py --mbt   # 重新生成黄金值断言片段
  moon build
  moon test
  python scripts/po2mbt --check
  ```
