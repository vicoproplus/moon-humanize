# Plan: moon-humanize ↔ python-humanize 严格对齐补齐

- **Spec**: `docs/specs/2026-08-19-spec-align-humanize.md` (Mode A — 严格对齐, python-humanize 唯一基准)
- **Plan date**: 2026-08-19
- **Authority source**: python-humanize `4.16.0` (已确认安装, `D:\Programs\Python\Python312\Lib\site-packages\humanize`)
- **Toolchain caveat**: 本地 `moon`/`moonc` 版本不匹配 (`moon 0.1.20260807` vs `moonc v0.10.8`)，`moon build`/`moon test` 暂不可用。代码先行，测试待工具链修复后补跑。

## Plan Document Header

- **Goal**: 以 python-humanize 为唯一基准，补齐 MoonBit `moon-humanize` 的公开 API 缺口（`get_translation`），并通过"Python 实时生成黄金值 → MoonBit `assert_eq`"对照框架，逐函数校准 #2–#20 的输出，使其与 Python 逐字节一致。
- **Architecture**: 纯 MoonBit 库 (`moonbit/src/humanize/*.mbt`)，分层：`number.mbt` / `time.mbt` / `filesize.mbt` / `lists.mbt` / `i18n.mbt`，测试文件 `*_test.mbt` 同目录。黄金值由外部 Python 脚本生成（不进仓库，仅用于生成断言）。
- **Tech Stack**: MoonBit SDK（版本见 Open Questions，需对齐）；python-humanize 4.16.0（黄金值基准，仅开发期依赖）。无新增第三方库。
- **Global Constraints**: 最小改动原则；`get_translation` 返回 `Option[Locale]` 复用 `current_locale()`，不引入新句柄类型（spec §5.3）。扩展项 (`rational`、`gettext`/`ngettext`/`pgettext` 顶层导出、`TimeUnit`) 仅记录不补（spec §2.1）。
- **Acceptance & Verification Commands (MANDATORY)**:
  ```powershell
  # 生成黄金值快照（开发期，对照用，不入库）
  python scripts/gen_golden.py > docs/superpowers/plans/2026-08-19-golden-values.txt
  # 待工具链修复后跑：
  moon build
  moon test
  # 文档一致性
  python scripts/po2mbt --check
  ```

## Endpoint Alignment

N/A — this plan touches no HTTP/RPC endpoints. All work is in a library module's public functions and unit tests.

## File-Structure

| 文件 | 职责 | 改动 |
|---|---|---|
| `moonbit/src/humanize/i18n.mbt` | i18n 状态与翻译；新增 `get_translation()` 封装 | 新增 1 个 `pub fn` (T1) |
| `moonbit/src/humanize/i18n_test.mbt` | i18n 测试；新增 `get_translation` 用例 | 新增 1 个 test (T1) |
| `moonbit/src/humanize/number_test.mbt` | number 模块黄金值对照 | 新增黄金值断言 (T3) |
| `moonbit/src/humanize/time_test.mbt` | time 模块黄金值对照 | 新增黄金值断言 (T3) |
| `moonbit/src/humanize/filesize_test.mbt` | filesize 模块黄金值对照 | 新增黄金值断言 (T3) |
| `moonbit/src/humanize/lists_test.mbt` | lists 模块黄金值对照 | 新增黄金值断言 (T3) |
| `scripts/gen_golden.py` (NEW) | 用 python-humanize 生成黄金值快照脚本 | 新建 |
| `docs/spec-align-humanize.md` (NEW) | 对齐文档（success criterion #3） | 新建 |

遵循 spec 布局与仓库既有模式（`*_test.mbt` 与实现同目录），不引入新布局。

## Authority Alignment (python-humanize 4.16.0)

> 逐函数"与权威源一致"的断言，必须在 plan 末尾对齐表逐项列出权威位置（`humanize/<module>.py:行号:函数`）。下表为实施前的权威源映射，执行时回读核实后填入行号。

| 决策点 | 权威位置（待回读填行号） | plan 结论 |
|---|---|---|
| `get_translation` 语义 | `humanize/i18n.py: get_translation()` 等价于 `_CURRENT` locale → `_get_translation()` 返回 `NullTranslations` | MoonBit 返回 `current_locale()` 的 `Option[Locale]`（spec §3 T1） |
| `intword` 词表 | `humanize/number.py: intword()` + `pow10` 表 | 校验 thousand..googol 边界（spec §3 T3） |
| `ordinal` pgettext | `humanize/number.py: ordinal()` 用 `pgettext(f"{n%10} (male)", suffix)` | MoonBit 现状已对齐，仅对照（spec §2 #12） |
| `naturaldelta`/`precisedelta` 格式串 + minimum_unit | `humanize/time.py` | 对照格式串与 minimum_unit（spec §2 #5/#6） |
| `metric` 前缀表 | `humanize/number.py: metric()` | 校验 SI 前缀与小数位（spec §2 #15） |
| `naturalsize` 单位/精度 | `humanize/filesize.py: naturalsize()` | 校验 decimal/binary/gnu（spec §2 #7） |
| `natural_list` 分隔符 | `humanize/lists.py: natural_list()` | 校验 `,`/`and`/`standard`/`oxford`（spec §2 #8） |

## Task-Structure

### T1 — 补齐 `get_translation()` 封装  `[ALIGN]` (spec §3 T1)
- **Files**: `moonbit/src/humanize/i18n.mbt`, `moonbit/src/humanize/i18n_test.mbt`
- **Interfaces**: `pub fn get_translation() -> Option[Locale]`（复用 `current_locale()`，位于 `i18n.mbt:184` `pub fn current_locale()`）
- **Steps**:
  1. 在 `i18n.mbt` 中 `current_locale()` 定义之后新增：
     ```moonbit
     /// Return the current translation handle (the active `Locale`), or `None`
     /// for no translation (English). Mirrors python-humanize's
     /// `humanize.i18n.get_translation()` returning the current locale's
     /// `NullTranslations` object.
     pub fn get_translation() -> Option[Locale] {
       current_locale()
     }
     ```
  2. 在 `i18n_test.mbt` 末尾新增 test（spec §3 T1 用例）:
     ```moonbit
     test "i18n get_translation mirrors current_locale" {
       deactivate()
       assert_eq(get_translation(), None)
       ignore(activate("fr_FR"))
       assert_eq(get_translation(), Some(FrFR))
       deactivate()
     }
     ```
  3. 待工具链修复后 `moon test` 验证该用例通过。

### T2 — 建立 Python 黄金值对照测试框架  `[ALIGN]` (spec §3 T2)
- **Files**: `scripts/gen_golden.py` (NEW)
- **Interfaces**: 无新增库 API；脚本输出纯文本黄金值。
- **Steps**:
  1. 新建 `scripts/gen_golden.py`，用已安装的 python-humanize 4.16.0 对每个目标函数输出黄金值，覆盖代表性输入（含边界值）。命令示例（PowerShell 用 `;` 分隔，不加 `| cat`）:
     ```python
     import humanize, datetime
     print("intword 1234567:", humanize.intword(1234567))
     print("intword 100:", humanize.intword(100))
     print("naturaltime 1 day:", humanize.naturaltime(datetime.timedelta(days=1)))
     print("naturaldelta 5s:", humanize.naturaldelta(datetime.timedelta(seconds=5)))
     print("precisedelta:", humanize.precisedelta(datetime.timedelta(days=1, hours=2)))
     print("naturalsize 1024:", humanize.naturalsize(1024))
     print("natural_list:", humanize.natural_list(["a","b","c"]))
     # ... 对每个 #2-#20 函数枚举输入
     ```
  2. 运行脚本，将输出保存为 `docs/superpowers/plans/2026-08-19-golden-values.txt` 作为对照基线。
  3. 对每个黄金值，在对应 `*_test.mbt` 中补充 `assert_eq`(MoonBit 输出, 黄金值字符串)。注意 python-humanize 4.16 用 `a day ago`/`1.2 million` 这类英文输出；MoonBit 默认 locale=English 时须一致。

### T3 — 逐函数语义校准（#2–#20）  `[ALIGN]` (spec §3 T3)
- **Files**: `number_test.mbt`, `time_test.mbt`, `filesize_test.mbt`, `lists_test.mbt`（必要时修正 `number.mbt`/`time.mbt`/`filesize.mbt`/`lists.mbt` 实现）
- **Interfaces**: 仅测试 + 逐字节对齐修正；不改签名。
- **Steps**（对每个 #2–#20 函数，以黄金值为准）：
  1. 在对应 test 文件加 `assert_eq` 断言（来自 T2 黄金值）。
  2. 若断言失败，回读 python-humanize 对应 `humanize/<module>.py` 源码，定位偏差分支，**仅修正实现使其对齐**，不改公开签名。
  3. 重点校准（spec §3 T3 列示）:
     - `intword` 词表边界值（thousand=1e3 .. googol=1e100，`number.mbt:205` 表）
     - `ordinal` pgettext 上下文 (`number.mbt:566`)
     - `naturaldelta`/`precisedelta` 格式串与 `minimum_unit` (`time.mbt:214`/`494`)
     - `metric` 前缀表与小数位 (`number.mbt:79`)
     - `naturalsize` 单位/精度 (`filesize.mbt:37`)
     - `natural_list` 分隔符 (`lists.mbt:11`)
  4. 偏差若属已知差异（如 python-humanize 4.16 与 MoonBit 设计取舍），记录到 `docs/spec-align-humanize.md` 的"已知差异"表并获确认，不强行改。

### T4 — 对齐文档  `[OK]` (spec §6 success criterion #3)
- **Files**: `docs/spec-align-humanize.md` (NEW)
- **Steps**:
  1. 新建 `docs/spec-align-humanize.md`，含：Gap Table 状态汇总、每条 #2–#20 的对照结论（一致/已修正/已知差异）、T1 实现说明、已知差异表。
  2. 确认文档与实际实现一致。

## Equivalence-Gate

本计划含权威源（python-humanize）等价性任务（T1/T2/T3），启用等价性门禁。验收以 Python 黄金值真值表逐条 `assert_eq` 断言，禁止以"不 panic"替代语义等价。T1 按"先写失败测试 → 确认 FAIL → 实现 → 确认 PASS"；因工具链暂不可用，T1 测试先写出，待工具链修复后跑（标注 pending）。

## Self-Review

- [x] spec 每条需求（T1/T2/T3 + 文档）均有对应步骤
- [x] 无占位符/模糊措辞（除工具链 pending 标注）
- [x] `get_translation` 签名 `Option[Locale]` 与 spec §3 T1 一致
- [x] 无端点 → Endpoint Alignment 声明 N/A
- [x] 权威源映射表已列，执行时回读填行号
- [x] 验收命令含可执行命令（python 生成 + moon test + po2mbt --check）

## Spec vs Plan Discrepancies

- spec §4 验证命令 `moon build`/`moon test` 当前因工具链版本不匹配不可用（spec §5.2 已知）。Plan 照实标注 pending，不静默偏离；代码先行，测试待修复后补跑。裁决：ALIGN-SPEC（spec 已承认该限制）。

## Execution-Handoff

计划保存于 `docs/superpowers/plans/2026-08-19-spec-align-humanize.md`。待用户确认执行方式（见 CHECKPOINT）。
