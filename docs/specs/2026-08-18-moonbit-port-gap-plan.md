# 实现计划：补全 MoonBit 移植缺口（i18n / clock / wasm / 连接）

- 来源 spec：`docs/specs/2026-08-18-moonbit-port-gap-spec.md`
- 权威参考源：Python `humanize`（仓库 `src/humanize/*.py` + 36 个 `locale/*/LC_MESSAGES/humanize.po`）
- 状态：spec 缺口判断经核实准确。已与用户确认 3 项决策（见 §0）。
- 目标：`moon test` 与 `moon build --target wasm` 均通过，且 i18n/clock 行为与 Python 权威源等价。

---

## §0 已确认决策（用户裁决，不再静默拍板）

1. **Locale 枚举不含 EN**：完全按 36 个真实 `.po` 目录名（`zh_CN`、`ar`、`fr_FR`、`ru_RU`…）。
   `default` locale 即英文 fallback（对应 Python `NullTranslations`，`gettext` 查不到时返回 `msgid`）。
2. **plural 规则由 po2mbt 编译**：解析每个 `.po` 的 `Plural-Forms` 表达式，生成 MoonBit `plural(locale, n): Int` 函数；
   运行时按 locale 查表调用（忠实于 gettext 原语义，覆盖 ar=6 / ru=3 / pl=3 / sl=4 / sk=3 / lv=3 / uk=3 等）。
3. **wasm 仅生成库产物**：不新建 demo 页面；只确保 `moon.pkg` 链接 wasm 目标，可 `moon build --target wasm` 产出 `.wasm`/`.js`。

---

## §1 现状核实（事实，非 spec 臆测）

- `moonbit/src/humanize/i18n.mbt`：仅 stub（`Locale` 枚举 + `gettext` 恒返回 `msgid`）。
- 缺失文件：`clock.mbt`、`i18n_data.mbt`、`wasm/`、`scripts/po2mbt`（scripts 仅有 `.sh`，无 po2mbt）。
- 现有可用代码：`number.mbt` / `filesize.mbt` / `time.mbt` / `util.mbt` / `lists.mbt` / `duration.mbt` / `normdate.mbt`，
  英文文案内联（如 `"%d second"`, `"%d second"`, `"%d day"`），无 `extern` 声明（纯逻辑）。
- 测试：已有 `time_test.mbt` 等 golden 测试（`@test.assert_eq`，期望来自 installed python-humanize）。
- Locale 目录：36 个（`zh_CN`、`zh_TW`、`ar`、`fr_FR`、`ru_RU`、`de_DE`、`ja_JP`、`ko_KR`…），无 `en`。
- `Plural-Forms` 多样：ar(6 式)、ru/pl/uk/sk/lv(3 式)、sl(4 式)、其余多 `n != 1`(2 式)。

> 修正 spec 偏差：spec §1.3 引用不存在的 `format.mbt` / 本地化占位符 `_format`/`_p0n` —— 真实接线点是各个 humanizer 内联英文文案。

---

## §2 任务拆分（顺序依赖）

### T1 — Locale 枚举 + 目录映射（`i18n.mbt` 改写）
- 定义 `enum Locale { ZH_CN | ZH_TW | AR | FR_FR | RU_RU | … }`（36 个，命名按 spec §1.1，顺序对齐真实目录）。
- 提供 `to_dirname(Locale) -> String`（`zh_CN` 等）与 `from_dirname(String) -> Locale?`（po2mbt 注册用）。
- 提供 `default_locale()` = `None`（语义：英文 fallback，不进枚举）。
- 删除 stub 的恒等 `gettext`，改为调用 `i18n_data` 的查表（T3 完成后接线）。

### T2 — clock.mbt（`src/humanize/clock.py` 移植）
- 纯函数，无 FFI：`now() -> Int`（依赖 wasm/JS `Date.now`，见 T5 extern）。
- `naturaltime(input, when~, locale~) -> String`：移植 `naturaltime`，内部文案经 i18n 层。
- `naturalday(date, when~, locale~)`、`naturaldate(date, locale~)`。
- 复用 `time.mbt` 的 `TimeInput`/`timedelta` 与 i18n 文案（"yesterday"/"today"/"tomorrow"/"now" 等）。
- 单位文案（"ago"/"from now"）走 `dgettext(locale, msgid)`。

### T3 — i18n_data.mbt（po2mbt 生成，不手写）
- 结构：`_TRANSLATIONS: Map[String, Translation]`，`Translation { table: Map[String, String], plural_fn: (Int) -> Int }`。
- API：`dgettext(locale, msgid) -> String`、`dngettext(locale, msgid, msgid_plural, n) -> String`、`activate(locale)`、`deactivate()`。
- `dngettext` 流程：查 `plural_fn(n)` 得索引 → 取 `msgstr[n]`；缺失则 fallback（单返回 `msgid`，复返回 `n==1?msgid:msgid_plural`）。
- 该文件由 T4 的 po2mbt 生成；提供 `i18n_data.mbt.header` 模板（手写固定头部 + `// ===== GENERATED BELOW =====` 分割线）。

### T4 — po2mbt 生成器（`scripts/po2mbt`）
- 语言：**Python**（与 `scripts/*.sh` + `src/*.py` 同栈，零新增依赖；spec §1.3 的 Go 选项弃用）。
- 输入：遍历 `src/humanize/locale/*/LC_MESSAGES/humanize.po`。
- 解析：`msgid`/`msgstr` 数组（支持 `msgctxt` 单语境；本项目无 `msgctxt`，按无语境处理）、`Plural-Forms`。
- **Plural-Forms 编译器**：将 C 风格表达式（如 `n%100>=3&&n%100<=10?2:...`）转写为 MoonBit 表达式。
  支持语法：`n` 变量、`%` `==` `!=` `>` `<` `>=` `<=` `&&` `||` `?:` 三元、整数常量。输出每个 locale 一个 `fn plural_<dir>(n: Int) -> Int`。
- 输出：写 `moonbit/src/humanize/i18n_data.mbt`（含 T3 头部 + 生成体）。
- 校验：生成后跑 `moon check`；对 ar/ru 抽样打印 `plural` 验证 0/1/2/5/11 等分支正确。
- 幂等：每次重新生成覆盖，保留手写头部。

### T5 — wasm 目标接线（`moonbit/src/humanize/wasm/` + `moon.pkg`）
- `clock.mbt` 的 `now()` 需要时间源：
  - 新增 `wasm/ffi.mbt`：`extern "js" fn js_now() -> Int`（浏览器 `Date.now()`）。
  - `moon.pkg`：wasm 目标 `link ["ffi"]`；native/js 目标用 `sys.sleep`/等价实现（见 T6）。
- 提供 `wasm/exports.mbt`：`pub fn humanize_version() -> String` 等最小导出，确保 build 产出 `.wasm` 可被加载。
- **不写 demo 页面**（决策 3）。

### T6 — 多目标 now() 适配
- native / js / wasm 三个 target 的 `now()` 实现分文件（`@if target` 条件编译或 per-pkg link）。
- 优先用 MoonBit 标准库当前时间 API；无则走 T5 extern。

### T7 — 连接现有 humanizer（i18n 接线）
- `number.mbt`/`filesize.mbt`/`time.mbt` 内联英文文案改为先 `dgettext(current_locale(), msgid)` 再 fallback。
- 引入包级当前 locale（`activate`/`deactivate` 设置），默认 = 英文 fallback。
- 不破坏现有 golden 测试（英文路径输出不变）。

### T8 — 测试与验证
- 扩展 golden 测试：新增 `i18n_test.mbt`（抽样 `dngettext` 对 zh_CN/ru_RU/ar 验证 plural 分支）、`clock_test.mbt`、`naturaltime` 用例。
- 运行 `moon test` 全绿；`moon build --target wasm` 成功产出产物。
- 用 Python `humanize` 生成非英文 golden（如 `naturaltime` 中文）做对等校验。

---

## §3 执行顺序（含依赖）

1. T1（Locale 枚举） → 2. T4（po2mbt 生成器）→ 3. T3（生成 i18n_data）
4. T2（clock）→ 5. T5+T6（wasm/now）→ 6. T7（连接 humanizer）
7. T8（测试）→ 全量 `moon test` + `moon build --target wasm` 验收

> T1 与 T4 可并行起草，但 T3 依赖 T4 产出；T5/T6 可与 T2 并行。

---

## §4 验收标准

- [ ] `moon test` 全绿（含新增 i18n/clock 测试，英文 golden 不回归）。
- [ ] `moon build --target wasm` 成功产出 `moonbit/target/wasm/.../humanize.wasm`（或等价路径）。
- [ ] `dngettext` 对 ar/ru/sl 多形态返回与 Python `humanize` 一致。
- [ ] 去掉 EN 枚举后，`default` 路径英文输出与旧行为位级一致。
- [ ] po2mbt 可重跑且幂等，产物通过 `moon check`。

## §5 风险与缓解

- **Plural-Forms 编译**：表达式语法若遇未覆盖运算符（如 `!`、`()` 嵌套），po2mbt 抛明确错误并列出 locale。
- **多目标 now()**：若 MoonBit 某 target 无时间 API，退化为该 target 下 `now()` 返回固定 epoch（测试标注 skip）。
- **i18n 接线回归**：T7 改动后 english golden 必须不变；用 `git diff` 锁定 `time_test.mbt` 期望。
