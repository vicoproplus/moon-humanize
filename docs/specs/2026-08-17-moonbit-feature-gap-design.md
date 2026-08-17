# Spec: MoonBit 功能补全 — 缺失模块补全设计 (moon-humanize)

- 状态: Draft（已通过 brainstorming 共享理解确认门）
- 创建日期: 2026-08-17
- 关联文档: `docs/specs/port-to-moonbit.md`（总体移植规划）
- 本 spec 范围: 闭合 `python-humanize` 相对 MoonBit 移植 **缺失的 11 个能力**（time 5 + filesize 1 + lists 1 + i18n 4）。
- 已移植的 `number` 模块 8 个函数 **不重写**（决策 1）。

## 0. 与总规划的分歧修正（重要）

本 spec 修订 `port-to-moonbit.md` 中的两处假设：

| 原规划条目 | 原内容 | 本 spec 修正 |
|-----------|--------|-------------|
| NG1 / Phase 6 | i18n 暂不做，留作后续 | **纳入本期补全**（决策 2 + 4A + 5A）：time/filesize 的文案经 i18n 内核输出 |
| Phase 2 假设 | "使用 core `time` 模块" | **MoonBit core 无 `time` 模块**（已核实 `C:/Users/Administrator/.moon/lib/core` 列表，无 `core/time`）。当前时间必须走 `extern "js"`（`Date.now()`）或 native 系统时钟，注入式时钟 `now~default_now()` |

## 1. 目标 (Goals)

- G1 功能等价: 11 个缺失能力对相同输入产生与原 Python 版一致（约定容差内）的输出。
- G2 i18n 开箱即用: 英文默认无翻译；`activate(locale)` 后 30+ 语言（36 个 `.po`）生效。
- G3 可测性: 复用 Python 测试断言值作 golden，经 `moon test` 验证；时间函数用注入 `now` 保证确定性。
- G4 WASM 友好: 无文件系统依赖（翻译数据编译期内嵌），WASM/js 目标用 `extern "js"` 取当前时间。

## 2. 非目标 (Non-Goals)

- NG1 重写 `number` 模块（8 函数已可用）。
- NG2 CLI 工具。
- NG3 性能基准强制（以行为正确优先）。

## 3. 已核实的能力事实 (MoonBit core)

来源: `moonbitlang/core` 源码核实（`C:/Users/Administrator/.moon/lib/core`）+ 工具链实测（moon v0.1.20260807）。

| 能力 | MoonBit 对应 | 备注 |
|------|-------------|------|
| 当前时间 | **无 core/time 模块** | 需 `extern "js"` 调 `Date.now()`（js/wasm），native 走系统时钟 |
| `extern "js"` 语法 | `extern "js" fn <name>(<args>) -> <ret> =`（见 `core/builtin` `random_seed` 等） | WASM 取时间范式已确认 |
| 平台分文件 | `options(targets: { "env_js.mbt": ["js"], "env_wasm.mbt": ["wasm","wasm-gc"], "env_native.mbt": ["native","llvm"] })`（见 `core/env/moon.pkg`） | clock 模块优先采用此范式；**待决 F2**：自定义业务包（`humanize`）是否支持同包 `options` + 平台分文件（如 `clock_js.mbt`/`clock_native.mbt`）需实测验证。若不支持，退路：单文件内仅 `extern "js"` 实现 + native 目标用条件编译/单独 wasm/native 构建矩阵 |
| 可变状态 | `Ref[T]` | i18n 当前 locale 状态 |
| 不可变 Map | `@immut/hashmap.HashMap` | 翻译表 |
| 浮点格式化 `%.1f` | 无精度格式符 | 复用 Phase 1 的 `format_fixed`（来自 `util.mbt`） |
| 大整数 | `BigInt` | 无关本期，但 `intword` 已用 |

## 4. 目标架构

```
moonbit/src/humanize/
├── util.mbt          # 已存在: format_fixed / 上标 / 二分 / 连分数
├── number.mbt        # 已存在: 8 函数（不动）
├── time.mbt          # 新增: 5 函数 + Unit 枚举 + Duration 结构 + 内部辅助
├── filesize.mbt      # 新增: naturalsize + suffixes 表
├── lists.mbt         # 新增: natural_list
├── i18n.mbt          # 新增: 4 公共函数 + gettext/ngettext 内核 + 当前 locale 状态
├── i18n_data.mbt     # 生成: 36 语言词条 + plural_index（由脚本生成，提交入库）
├── clock.mbt         # 新增: default_now()，js/native/wasm 分文件
└── wasm.mbt          # 已存在: 导出层
```

### 4.1 时钟设计（决策 3：注入式）

```mbt
pub struct DateTime {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
}

// 默认时钟，可被覆盖（测试/宿主自定义）
pub fn default_now() -> DateTime          // 平台分文件实现
//   env_js.mbt / env_wasm.mbt: extern "js" fn now_ms() -> Int64 = ; 转换 epoch ms -> DateTime
//   env_native.mbt: 走系统时钟
```

> 注：`Duration` 结构仅在第 5.1 节统一定义一次，本节不重复声明（避免同包重复定义编译失败）。

所有依赖"当前时间"的函数以 `now~default_now()` 为默认参数，调用方可在测试时注入固定 `DateTime`。

### 4.2 API 设计原则
- 核心层纯函数、`String/Double/Duration/DateTime -> String`。
- 时间函数全部 `now~default_now()` 注入。
- 所有用户可见文案走 `i18n.gettext` / `i18n.ngettext`，保证多语言可切换。

## 5. 模块设计

### 5.1 time.mbt（5 函数）

内部类型：
```mbt
pub enum Unit {
  Microseconds | Milliseconds | Seconds | Minutes | Hours | Days | Months | Years
} // 声明次序即大小序，承载 ord 比较

pub struct Duration { days~: Int, seconds~: Int, microseconds~: Int }
```

公开签名：
```mbt
pub fn naturaldelta(
  value : Duration,
  ~months : Bool = true,
  ~minimum_unit : String = "seconds",
) -> String

pub fn naturaltime(
  value : DateTime,
  ~future : Bool = false,
  ~months : Bool = true,
  ~minimum_unit : String = "seconds",
  ~now : DateTime = default_now(),
) -> String

pub fn naturalday(
  value : DateTime,
  ~format : String = "%b %d",
  ~now : DateTime = default_now(),
) -> String

pub fn naturaldate(
  value : DateTime,
  ~now : DateTime = default_now(),
) -> String

pub fn precisedelta(
  value : Duration,
  ~minimum_unit : String = "seconds",
  ~suppress : Array[String] = [],
  ~format : String = "%0.2f",
) -> String
```

**行为对齐细则（验收基准）**：
- `naturaldelta`: "a moment" 边界；秒/分/时/天/月/年分级；months 基于 30.5 天近似；年数经 `intcomma` 包裹；`minimum_unit` 仅支持 seconds/milliseconds/microseconds（否则抛错）。
- `naturaltime`: 内部定值时 `a moment -> now`；按 DateTime 自动判时态；`now` 用于定相对时刻。
- `naturalday`: today/tomorrow/yesterday 或 `format` 格式化；`now` 决定"今天"。
- `naturaldate`: 距今 > ~5 个月时附加年份。
- `precisedelta`: `_quotient_and_remainder` 进位链；`suppress` 升档最小单位；`"%d year" -> intcomma` 处理；`minimum_unit` 同 `naturaldelta`。
- 所有输出串经 `i18n.gettext` / `i18n.ngettext`（如 `"%d second"`/`"%d seconds"`）。

### 5.2 filesize.mbt（1 函数）

```mbt
pub fn naturalsize(
  value : Double,
  ~binary : Bool = false,
  ~gnu : Bool = false,
  ~format : String = "%.1f",
) -> String
```

**行为对齐细则**：
- `suffixes` 三套表完整移植：`decimal`(kB…QB 10级) / `binary`(KiB…QiB 10级) / `gnu`("KMGTPEZYRQ")。
- `base`: gnu/binary → 1024；否则 → 1000。
- 单字节特例：`abs==1 且 非 gnu` → `"1 Byte"`；`< base 且 gnu` → `"{int}B"`；`< base` → `"{int} Bytes"`。
- 指数 `exp = floor(log(abs, base))` 截断到后缀长度。
- 进位修正：格式化后若 ≥ base 且仍有更大后缀，则 `exp += 1`（999999 → 修正 "1.0 MB"）。
- gnu 无空格（`"2.9K"`），其余有空格（`"3.0 MB"`）。
- 负数透传负号。
- 文案（`"1 Byte"`/`"1 Bytes"`/suffix）经 i18n 可翻译。

### 5.3 lists.mbt（1 函数）

```mbt
pub fn natural_list(items : Array[String]) -> String
```

**行为对齐**：
- 空 → `""`；单元素 → 该元素；两元素 → `"a and b"`；多元素 → `"a, b and c"`。
- 仅支持 `Array[String]`（与 number 模块统一的 String 化约定；不引入泛型 `str()` 转换）。

### 5.4 i18n.mbt（4 公共函数 + 内核）

```mbt
pub fn activate(locale : String?) -> Unit          // None 或 "en*" → 默认(无翻译)
pub fn deactivate() -> Unit
pub fn thousands_separator() -> String            // 默认 ","
pub fn decimal_separator() -> String              // 默认 "."

// 包内可见内核（供 time/filesize 调用）
fn gettext(msg : String) -> String
fn ngettext(msg : String, plural : String, n : Int) -> String
```

**内核设计**：
- 默认 locale（`None`）→ `IdentityTranslator`：`gettext` 原样返回；`ngettext` 按 `n==1 ? singular : plural` 返回英文原型。
- 非英文 → 从内嵌 `Catalog`（`@immut/hashmap.HashMap[String, String]`）查表；缺失 key 回退 msgid 原串（对齐 gettext）。
- 当前 locale 用 `Ref[String?]` 包内可变状态；测试收尾需 `deactivate()` 复位。
- `thousands_separator`/`decimal_separator` 用 Python 既有 `_THOUSANDS_SEPARATOR`/`_DECIMAL_SEPARATOR` 映射（de_DE/fr_FR/it_IT/pt_BR/hu_HU/lv 等），内嵌为 `HashMap[String?, String]`。

**复数规则（nplurals 差异）**：
- `scripts/po2mbt.py` 从每个 `.po` 的 `Plural-Forms` 头提取 `nplurals` 与 `plural=` 公式。
- 生成 `i18n_data.mbt` 时为每语言产出一个 `plural_index(locale, n) -> Int`（公式编译为 MoonBit 表达式，如俄语 `n%10==1 && n%100!=11 ? 0 : ...`）。
- `ngettext` 调用：`idx = plural_index(current_locale, n)`，`msgstr[idx]`。

**数据来源（决策 4A + 5A：编译期内嵌 + 全量）**：
- `scripts/po2mbt.py` 遍历 `src/humanize/locale/*.po`（36 个），解析 `msgid`/`msgstr[0..n]` 与 `Plural-Forms`，生成 `moonbit/src/humanize/i18n_data.mbt`：
  - `fn catalog_for(locale) -> Catalog`（全量词条）
  - `fn plural_index(locale, n) -> Int`
  - 默认英文由 Python 源码 `_()` 调用字符串直接作 identity 兜底。
- **提交策略**：提交 `i18n_data.mbt`（开箱即用，免构建步）；脚本仅用于后续更新。
- **CI 校验（F3）**：因 `i18n_data.mbt` 为生成文件且入库，需在 CI 中加一步 `python scripts/po2mbt.py --check`：重跑脚本断言产物与已提交文件无 diff，防止 `.po` 更新后生成文件腐烂。

## 6. 验收标准 (Acceptance)

- A1 11 个能力全部函数在 `moon test` 通过对应 Python 断言值（浮点末位差异允许约定容差 R1）。
- A2 英文开箱即用（无 `activate` 时输出等同 Python 英文）；`activate("ru_RU")`、`activate("fr_FR")` 等 30+ 语言生效，复数形态正确。
- A3 `naturaltime`/`naturalday`/`naturaldate` 在注入 `now` 下确定性可测。
- A4 `moon build --target wasm` 成功；JS 封装可调用新函数返回等价字符串。
- A5 i18n 测试用例收尾均调用 `deactivate()`，保证状态隔离。

## 7. 风险与待决

| 风险 | 应对 |
|------|------|
| MoonBit WASM 取当前时间的精度/可用性 | `extern "js"` 调 `Date.now()` 得 epoch ms，转 `DateTime`；native 走系统时钟；clock 平台分文件 |
| `.po` 复数公式编译为 MoonBit 表达式的正确性 | 脚本单测覆盖 ru/fr/zh 等典型 nplurals；python 侧 `ngettext` 值作 golden |
| 包级可变 locale 状态的测试隔离 | `Ref[T]` + 每用例 `deactivate()` 复位 |
| 36 语言内嵌体积对 WASM 的影响 | 约数十 KB，可接受；超阈再转资源加载（本 spec 不采用） |
| `.po` 转义（`\n`/`\"`）还原 | 脚本正确解析转义为 MoonBit 字符串字面量 |
| 自定义业务包平台分文件机制（F2） | 实测 `humanize` 包是否支持 `options(targets:...)`；不支持则改用单文件 `extern "js"` + 构建矩阵 |

## 8. 实施顺序建议

1. `clock.mbt`（default_now + 平台分文件）—— 时间模块前置依赖。
2. `i18n.mbt` + `scripts/po2mbt.py` + 生成 `i18n_data.mbt` —— time/filesize 的文案依赖。
3. `time.mbt`（5 函数）。
4. `filesize.mbt`（1 函数）。
5. `lists.mbt`（1 函数）。
6. 全量 `moon test` + WASM 构建 + JS 封装导出。

## 9. 待后续（非本期）

- 若 WASM 体积超阈，i18n 数据可改资源加载（需宿主注入）。
- `plural_index` 公式的语法覆盖范围需随 `.po` 实测补充。
