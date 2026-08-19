# Spec: moon-humanize ↔ python-humanize 严格对齐补齐

- **模式**: A — 严格对齐（以 `python-humanize` / `jmoiron/humanize` 为唯一基准）
- **目标**: 补齐 MoonBit `moon-humanize` 相对 Python `humanize` 的公开 API 缺口，并使同名函数输出逐字节对齐 Python 黄金值。
- **状态**: DRAFT（待执行）
- **生成日期**: 2026-08-18

---

## 1. Verified facts（已核实证据）

### 1.1 Python 源侧公开 API
枚举命令（在已安装 `python-humanize` 环境执行）:

```powershell
python -c "import humanize, inspect; print('\n'.join(sorted(n for n in dir(humanize) if not n.startswith('_'))))"
```

源文件: `D:\Programs\Python\Python312\Lib\site-packages\humanize\__init__.py`

**顶层公开函数（20）**:
`activate, apnumber, clamp, deactivate, decimal_separator, fractional, intcomma, intword, metric, natural_list, naturaldate, naturalday, naturaldelta, naturalsize, naturaltime, ordinal, precisedelta, scientific, thousands_separator`

**子模块独有公开项（1）**:
- `humanize.i18n.get_translation()` → 返回 `_TRANSLATIONS.get(locale, _TRANSLATIONS[None])`（当前 locale 的 `NullTranslations` 对象）

> 注: Python 顶层**不**直接暴露 `gettext`/`ngettext`/`pgettext`；这些仅存在于 `humanize.i18n` 且由内部 `_gettext` 调用。MoonBit 将其提升为顶层 `pub fn` 属扩展（非强制对齐）。

### 1.2 MoonBit 目标侧现状
文件:`moonbit/src/humanize/*.mbt`

| 模块 | 已实现 pub fn |
|---|---|
| `number.mbt` | `clamp, metric, intcomma, intword, apnumber, fractional, scientific, ordinal` |
| `time.mbt` | `naturaldate, naturalday, naturaldelta, naturaltime, precisedelta` |
| `filesize.mbt` | `naturalsize` |
| `lists.mbt` | `natural_list` |
| `i18n.mbt` | `activate, deactivate, thousands_separator, decimal_separator, gettext, ngettext, pgettext, current_locale` |

**缺失**: 无 `get_translation` 公开函数。

---

## 2. Gap Table（缺口表）

标记说明:
- `[ALIGN]` 强制补齐（Python 有 / MoonBit 无，或语义不一致）
- `[EXT]` 扩展（MoonBit 有 / Python 无，仅记录，不补）
- `[OK]` 已对齐（函数存在，待黄金值测试确认语义）

| # | Python 函数 | MoonBit 对应 | 状态 | 缺口类型 | 备注 |
|---|---|---|---|---|---|
| 1 | `i18n.get_translation()` | — (仅有 `current_locale()`) | **缺口** | `[ALIGN]` | 需新增公开 `get_translation()` 封装 |
| 2 | `naturaltime` | `time.mbt` | `[OK]` | — | 待黄金值测试 |
| 3 | `naturalday` | `time.mbt` | `[OK]` | — | 待黄金值测试 |
| 4 | `naturaldate` | `time.mbt` | `[OK]` | — | 待黄金值测试 |
| 5 | `naturaldelta` | `time.mbt` | `[OK]` | — | 格式串对齐（含 `minimum_unit`） |
| 6 | `precisedelta` | `time.mbt` | `[OK]` | — | 格式串对齐 |
| 7 | `naturalsize` | `filesize.mbt` | `[OK]` | — | 单位/精度对齐 |
| 8 | `natural_list` | `lists.mbt` | `[OK]` | — | 分隔符（`,`/`and`/`oxford`）对齐 |
| 9 | `intcomma` | `number.mbt` | `[OK]` | — | 千分位对齐 |
| 10 | `intword` | `number.mbt` | `[OK]` | — | 词表（thousand/million/.../quadrillion）对齐 |
| 11 | `apnumber` | `number.mbt` | `[OK]` | — | 1–9 文字化对齐 |
| 12 | `ordinal` | `number.mbt` | `[OK]` | — | 后缀（st/nd/rd/th）+ pgettext 上下文对齐 |
| 13 | `fractional` | `number.mbt` | `[OK]` | — | 分数词表对齐 |
| 14 | `scientific` | `number.mbt` | `[OK]` | — | 指数格式对齐 |
| 15 | `metric` | `number.mbt` | `[OK]` | — | 公制前缀（k/M/G/...）对齐 |
| 16 | `clamp` | `number.mbt` | `[OK]` | — | min/max 边界对齐 |
| 17 | `activate` | `i18n.mbt` | `[OK]` | — | locale 识别对齐 |
| 18 | `deactivate` | `i18n.mbt` | `[OK]` | — | — |
| 19 | `thousands_separator` | `i18n.mbt` | `[OK]` | — | 按 locale 对齐 |
| 20 | `decimal_separator` | `i18n.mbt` | `[OK]` | — | 按 locale 对齐 |

### 2.1 扩展项（记录，不补）
| MoonBit 独有 | 类型 |
|---|---|
| `rational.mbt` (`Rational`) | `[EXT]` |
| `i18n.gettext / ngettext / pgettext` (顶层导出) | `[EXT]` |
| `wasm_version`, `TimeUnit` 枚举等 | `[EXT]` |

---

## 3. 补齐任务（Execution Plan）

### T1 — 补齐 `get_translation()`  `[ALIGN]`
- **文件**: `moonbit/src/humanize/i18n.mbt`
- **签名**: `pub fn get_translation() -> Option[Locale]`
- **语义**: 返回 `current_locale()` 结果（等价于 Python 返回当前 locale 的 Translation 句柄；MoonBit 以 `Locale` 作为翻译表句柄）。
- **测试**: `i18n_test.mbt` 新增用例:
  ```text
  deactivate(); assert_eq(get_translation(), None)
  activate("fr_FR"); assert_eq(get_translation(), Some(FrFR))
  ```

### T2 — 建立黄金值对照测试框架  `[ALIGN]`
- **方案**: 用 Python 实时生成黄金值，写入 MoonBit 测试做 `assert_eq`。
- **生成命令**（PowerShell）:
  ```powershell
  python -c "
  import humanize, datetime
  print(humanize.intword(1234567))
  print(humanize.naturaltime(datetime.datetime.now() - datetime.timedelta(days=1)))
  # ... 对每个函数输出黄金值
  "
  ```
- **落地**: 在每个 `*_test.mbt` 中补充与 Python 输出逐字节一致的断言；发现偏差即开子任务修正。

### T3 — 逐函数语义校准  `[ALIGN]`
对 Gap Table #2–#20 每个 `[OK]` 项执行 T2 对照，记录偏差并修正。重点校准:
- `intword` 词表边界值
- `ordinal` 的 `pgettext` 上下文（如 `fr` locale）
- `naturaldelta` / `precisedelta` 的格式串与 `minimum_unit`
- `metric` 前缀表与小数位

---

## 4. 验证命令（可重复）

```powershell
# 1. Python 侧重新枚举公开 API（确认基准未变）
python -c "import humanize,inspect;print('\n'.join(sorted(n for n in dir(humanize) if not n.startswith('_'))))"

# 2. MoonBit 缺口函数确认
#    grep i18n.mbt 确认无 get_translation（补齐后此步应失败=已补）

# 3. 构建 + 测试（注: 当前工具链版本不匹配，见 Open Questions）
moon build
moon test
```

---

## 5. Open Questions / Dependencies
1. **测试黄金值来源**: Python wheel 不含 `tests/`，官方黄金值在 GitHub `jmoiron/humanize/tests/`。采用"实时运行 Python 生成快照"方案，具体由 `scripts/gen_golden.py` 实现（输出合法 MoonBit 断言）。
2. **工具链**: 已解决——`moon 0.1.20260819` / `moonc v0.10.9` 已对齐，`moon build` 成功、`moon test --target native` 可运行并全绿（44/44）。默认 wasm 目标在本机崩 `0xc0000139`（Windows 运行时已知问题，见 `docs/TOOLCHAIN-WINDOWS-ISSUE.md`），记为平台已知、不计入验收。
3. `get_translation` 返回类型: 采用 `Option[Locale]`（复用 `current_locale()`），不引入新的 Translation 句柄类型，保持最小改动。如需返回翻译表句柄供高级用途，后续可扩展。

---

## 6. 成功标准
- [x] `i18n.get_translation()` 公开函数已添加且测试通过（`i18n.mbt:192`）。
- [x] Gap Table #2–#20 全部经 Python 黄金值对照测试（`moon test --target native` 44/44 通过），已知差异已记录（见 `docs/spec-align-humanize.md` §5）。
- [x] 文档 `docs/spec-align-humanize.md` 与实际实现对齐，并补充本轮时间函数对齐（Date::today 默认、naturaldate 五年规则、naturaltime when~ 语义限制、filetime/natsize 跳过）。
