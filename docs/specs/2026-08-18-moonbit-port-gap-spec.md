# MoonBit 移植功能缺口补全 Spec

> 日期：2026-08-18
> 目标：补全 python-humanize → MoonBit 移植版中**尚未实现**的模块与函数。
> 范围：本 spec 仅聚焦"移植功能缺口"（即 Python 版有、MoonBit 版还没有的东西），
>       不讨论语言哲学对比，也不重写已实现且测试通过的模块。
>
> 事实依据：本 spec 编写前已逐文件核对 `moonbit/src/humanize/` 与 `src/humanize/` 全部源码。
>       旧 `2026-08-17-*` 的 plan 声称"已执行完成"但实际只修了 3 个局部 bug，
>       其规划的 clock/wasm/i18n_data/po2mbt **全部未落地**，本 spec 以真实现状为准。

---

## 0. 真实现状盘点（已核对，非臆测）

### 0.1 MoonBit 已实现（保留，不动）
| 模块 | 函数 | 来源 |
|------|------|------|
| `filesize` | `naturalsize`(`binary`/`gnu`/`format`)、`decimal` | `filesize.mbt` |
| `number` | `intword`/`intcomma`/`apnumber`/`fractional`/`ordinal`/`scientific` | `number.mbt` |
| `lists` | `natural_list`/`oxford`/`rangelist` | `lists.mbt` |
| `time` | `naturaltime`/`naturalday`/`naturaldate`/`naturaldelta`/`precisedelta` + `TimeInput`/`TimeDelta`/`TimeUnit` | `time.mbt` |
| 内部 | `format.mbt`(`_p0n` 本地化占位符、`_format` 替身) | `format.mbt` |

### 0.2 MoonBit 现状缺口（本 spec 要补）
| 缺口 | 状态 | 影响 |
|------|------|------|
| `i18n` 内核 | **英文 stub 实现**：`i18n.mbt` 已有 `decimal_separator`/`thousands_separator`/`decimal_separator_for`/`thousands_separator_for` 四个函数（均硬编码英语/逗号），但**无** `activate`/`deactivate`/`gettext`/`ngettext`/`plural_index`/`default_locale` 实现，不加载任何 `.po` 数据 | 所有本地化函数输出恒为英语；实现者是在现有 stub 上扩展，而非从零开始 |
| `clock.mbt` | **缺失** | `naturaltime` 默认依赖"当前时间"，但 MoonBit core `Date` 无 `now()`；当前 `naturaltime` 仅靠 `when~` 参数，无默认"现在" |
| `i18n_data.mbt` | **缺失** | 无 36 语言翻译数据内嵌，i18n 内核无数据可查 |
| `wasm.mbt` | **缺失** | 无 JS 导出层，浏览器/JS 侧无法调用 humanize |
| `po2mbt.py` | **缺失** | 无 `src/humanize/locale/*.po` → `i18n_data.mbt` 的自动生成管线 |
| `.po` 资源 | `src/humanize/locale/` 下有 36 语言 `.po`，但 MoonBit 侧未消费 | i18n 数据来源存在，缺消费链 |

### 0.3 关键约束（旧 spec 失败的根因，本 spec 必须规避）
1. **MoonBit 静态强类型**：Python 的 `datetime | timedelta | int | float` 多态入参已用 `TimeInput` enum 建模，i18n 也必须用显式 enum/struct，不能依赖运行时鸭子类型。
2. **无 `gettext`/动态 locale**：Python 用 C 库 `gettext` + 运行时 `.mo` 加载；MoonBit 必须**编译期内嵌**翻译表（`.po` → `.mbt` 常量）。
3. **无运行时 `format` 复数魔法**：Python `ngettext` 依赖复数规则；MoonBit 需显式 `plural_index(locale, n)` + 双形态字符串表。
4. **无动态"当前时间"**：MoonBit core `Date` 无 `now()`，必须由宿主层（JS `Date.now()`）注入 → `clock.mbt` 用 `extern`/FFI 获取。

---

## 1. i18n 内核 Spec（`i18n.mbt` 重写）

**目标**：让所有 humanize 函数能按需切换语言，与 Python `humanize.i18n` 行为对齐。

### 1.1 公共 API（补全 stub）

```moonbit
// 语言标识：与 src/humanize/locale/ 下 .po 目录名一一对应（含地区后缀）
// 真实目录共 36 个，含 zh_CN / zh_HK、pt_BR / pt_PT 等成对变体
pub enum Locale {
  EN AR BG BS CA DA DE EL EO ES EU FA FI FR HE HU ID IT JA KO LV NB NL PL PT_BR
  PT_PT RU SI SK SL SV TLH TR UK UZ VI ZH_CN ZH_HK BN_BD FA_IR ... // 共 36 个
}

// 当前激活语言（模块级可变状态，唯一可变点）
pub fn activate(locale : Locale) -> Unit
pub fn deactivate() -> Unit                 // 回到默认英语
pub fn default_locale() -> Locale           // 当前默认（EN）

// 翻译查询：单/复数
pub fn gettext(msg : String) -> String
pub fn ngettext(singular : String, plural : String, n : Int) -> String

// 复数规则：返回该语言下 n 对应的形态索引
pub fn plural_index(locale : Locale, n : Int) -> Int
```

### 1.2 复数规则表（关键差异补全）
Python 用 `gettext` 的复数公式；MoonBit 需**逐语言实现** `plural_index`：
- EN/ZH_CN/ZH_HK/JA/KO 等：`n == 1 ? 0 : 1`（单/复两态）
- RU/UK：`n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10||n%100>=20) ? 1 : 2`（三态）
- AR：`n==0?0 : n==1?1 : n==2?2 : n%100>=3&&n%100<=10?3 : n%100>=11?4 : 5`（六态）
- 其余 36 语言按 CLDR 规则各实现一态函数，集中放在 `i18n_data.mbt`。

### 1.3 与现有函数的接线
> 先核对真实代码中的硬编码点（已 grep 确认）：
> - `time.mbt`：`_nunit`/`_nyear_days`/`_nyear_months`/`_nunit_big` 等辅助函数硬编码单位词（"a day"/"days"/"a month"）。
> - `number.mbt`：`apnumber` 硬编码 "zero".."nine"；`intword` 硬编码 "thousand"/"million"/"billion" 等单位词；`ordinal`/`fractional` 硬编码序数/分数词。
> - `filesize.mbt`：`naturalsize` 输出含 "B"/"KB"/"KiB"/"GB" 等单位词（Python 部分 locale 下本地化，如 zh_CN 用 "字节"）。

逐模块接线：
- `format.mbt`：本地化占位符辅助函数 → 经 `gettext`/`ngettext` 查表。
- `number.mbt`：
  - `apnumber` 数字词（"one"/"two"）→ `gettext`
  - `intword` 单位词（"million"/"billion"）→ `gettext`
  - `ordinal` 序数词（"first"/"second"）→ `gettext`
  - `fractional` 分数词（"half"/"quarter"）→ `gettext`
- `time.mbt`：`_nunit`/`_nyear_days`/`_nyear_months`/`_nunit_big` 单位名词 → 经 `ngettext`（区分单/复）。
- `filesize.mbt`：`naturalsize` 单位词（"B"/"KB"/"KiB"）→ 经 `gettext`，使中文等 locale 可本地化单位。

### 1.4 msgid 命名规范（内核与生成器共享，避免对不上）
- **msgid = 英语原文模板字符串**（与 Python `humanize` 一致，如 `"a day"` / `"%d days"` / `"million"`）。
- `ngettext` 的 `singular`/`plural` 亦用英语原文（如 `"a day"` / `"%d days"`）。
- `po2mbt.py`（§5）与 `i18n.mbt` 内核**必须共用同一套 msgid 常量**，否则查表 miss 静默回退英语。建议把 msgid 集中为 `i18n.mbt` 内的 `const` 或在生成器中与内核符号名对齐。

### 1.5 验收
- `activate(Locale::ZH_CN); naturalsize(1024)` → `"1.0 KB"`（中文 locale 应有对应，或保留英文单位但本地化连接词——以 `.po` 为准）。
- `deactivate(); naturaltime(...)` 回到英语。
- 单元测试覆盖 EN/ZH_CN/RU/AR 四种复数态。

---

## 2. 时钟注入 Spec（`clock.mbt` 新建）

**目标**：提供"当前时间"来源，使 `naturaltime` 可无 `when~` 参数运行，对齐 Python `naturaltime()` 默认用 `datetime.now()`。

### 2.1 API
```moonbit
// 返回自 epoch 的秒数（Double），精度到秒
pub fn now() -> Double

// 模块级可覆盖的时钟源（测试用）
pub fn set_clock(fn () -> Double) -> Unit
pub fn reset_clock() -> Unit
```

### 2.2 实现
- 默认实现通过 `extern "js"` / `extern "wasm"` 调用宿主 `Date.now()/1000`。
- **未注入时钟时的行为**：`now()` 在未设置任何时钟源时**显式 panic**，并给出清晰错误（如 `"clock not initialized: call clock::set_clock or provide host Date.now()"`），**禁止静默返回编译期常量**——否则 wasm 目标若漏注入会静默产出错误时间，且测试可能因常量漂移而 flaky。
- `time.mbt` 的 `naturaltime`：`when~` 缺省时调用 `clock::now()`（由宿主或测试注入）。

### 2.3 验收
- `naturaltime(TimeInput::from_seconds(0))` 无 `when~` 且有宿主/注入时钟时，输出相对"现在"的描述，不 panic。
- **未注入时钟直接调用 `now()` 必须 panic**（验证错误路径），而非返回错误值。
- 测试用 `set_clock` 注入固定时间，断言确定性输出（消除 flaky test）。

---

## 3. i18n 数据内嵌 Spec（`i18n_data.mbt` 新建）

**目标**：把 `src/humanize/locale/*.po` 的 36 语言翻译编译进二进制。

### 3.1 数据结构
> **不用不可变 `Map` 常量**：MoonBit 的 `Map` 是持久化不可变结构，36 语言 × 数百词条在编译期构造常量时产物体积大、初始化慢。改用生成器直接产出的 `match` 查表函数或 `HashMap`。

```moonbit
// 单语言翻译表：msgid -> 形态数组（按 plural_index 索引）
struct Catalog {
  locale : Locale
  plural_count : Int
  entries : HashMap[String, Array[String]]   // 可变哈希表，运行时 O(1) 查表
}

// 全局目录：Locale -> Catalog（由 po2mbt 生成初始化，非手写）
let catalogs : HashMap[Locale, Catalog] = { ... 由 po2mbt 生成 ... }
```

> 备选（更省体积）：不存 `HashMap`，而是由 `po2mbt.py` 为每个语言生成 `fn lookup_<lang>(msgid : String, form : Int) -> String` 的 `match` 表达式，内核按激活语言分发调用。两种方式二选一，生成器统一处理。

### 3.2 生成式填充
- **不手写** 36 语言翻译表，由 `po2mbt.py` 从 `.po` 生成 `i18n_data.mbt` 的 `catalogs` 初始化代码。
- 生成文件顶部标注 `// AUTO-GENERATED by po2mbt.py — DO NOT EDIT`。

### 3.3 验收
- `i18n_data.mbt` 存在且 `catalogs` 含全部 36 语言 key。
- `gettext` 对已知 msgid 返回非英语译文（ZH 至少覆盖 filesize/number/time 核心词条）。

---

## 4. WASM/JS 导出层 Spec（`wasm.mbt` 新建）

**目标**：暴露 humanize 到 JS，使浏览器/Node 可 `import` 调用，对齐 Python 的"库即导入即用"。

### 4.1 导出函数（extern "wasm" 标记）
```moonbit
pub fn wasm_naturalsize(bytes : Double, binary : Bool) -> String
pub fn wasm_naturaltime(seconds : Double) -> String
pub fn wasm_intcomma(n : Int) -> String
pub fn wasm_natural_list(items : Array[String]) -> String
// ... 覆盖 filesize/number/lists/time 全部 pub 函数 ...
pub fn wasm_activate(locale_code : String) -> Unit  // "zh_CN" / "ru_RU" / "ar" ...
pub fn wasm_deactivate() -> Unit
```

### 4.2 字符串桥接
- MoonBit `String` ↔ JS `string` 由 moonbit wasm 运行时自动 marshall；`wasm_activate` 接收语言码字符串，映射到 `Locale` enum（未知码 fallback EN）。

### 4.3 验收
- `moon build --target wasm` 产出 wasm，JS 侧 `wasm_naturalsize(1024, true)` 返回 `"1.0 KiB"`。
- 提供 `examples/wasm-demo.html` 最小可运行 demo（可选，建议纳入）。

---

## 5. `.po` → `.mbt` 生成器 Spec（`po2mbt.py` 新建）

**目标**：把 Python 侧的 `src/humanize/locale/*.po` 自动转为 `i18n_data.mbt`，建立"翻译更新即重新生成"的管线，避免手工维护 36 语言数据。

### 5.1 行为
- 输入：`src/humanize/locale/<lang>/LC_MESSAGES/*.po`（Python 现有 36 语言）。
- 输出：`moonbit/src/humanize/i18n_data.mbt`。
- 解析 `.po` 的 `msgid`/`msgid_plural`/`msgstr[0..n]` → 生成 `Catalog` 初始化字面量。
- 语言码映射：`.po` 目录名（如 `zh_CN`）→ `Locale::ZH_CN`（在生成器内维护映射表）。
- 无 `.po` 的语言跳过并在 stderr 警告。

### 5.2 验收
- `python po2mbt.py` 跑通，生成 `i18n_data.mbt` 且可被 `moon check` 通过。
- 修改任一 `.po` 重跑生成器，humanize 输出随之变化（端到端验证 i18n 链路）。

---

## 6. 实现顺序与依赖

> **依赖方向修正**：`i18n.mbt` 内核**不依赖** `i18n_data.mbt` —— 内核自带英语 identity fallback，可独立编译运行；`i18n_data.mbt` 是"增强"（提供 36 语言数据）而非"依赖"。因此 `po2mbt.py`/`i18n_data.mbt` 可在内核之后并行推进。

```
i18n.mbt(内核, 含 EN fallback) ──► 接线 format/number/time
        ▲ 可选增强：po2mbt.py ──► i18n_data.mbt
clock.mbt ──► time.mbt(默认 now)
wasm.mbt (依赖上述全部 pub 函数)
```

1. **P0** `clock.mbt` + `time.mbt` 接线（无外部数据，先打通"现在"）。
2. **P0** `i18n.mbt` 内核（activate/gettext/ngettext/plural_index，自带 EN identity fallback，**不依赖** i18n_data）。
3. **P1** `po2mbt.py` + `i18n_data.mbt`（注入 36 语言真实数据，作为内核的可选增强接入）。
4. **P1** 把 `format`/`number`/`time`/`filesize` 的硬编码英语模板改为走 i18n。
5. **P2** `wasm.mbt` + demo。

## 7. 非目标（明确排除，避免 scope creep）
- 不新增 Python 版没有的 humanize 函数。
- 不重写已通过的 filesize/number/lists/time 逻辑，仅"接线 i18n"。
- 不实现运行时动态加载 `.po`/`.mo`（MoonBit 编译期内嵌即可）。
- 不处理 CLDR 以外的自定义复数规则。

## 8. 验收总表
| 项 | 验收命令 |
|----|---------|
| i18n 内核 | `moon test -p humanize` 含 ZH_CN/RU/AR 用例 |
| clock | `naturaltime` 无 `when~` 且有注入时钟时不 panic；未注入时 `now()` 显式 panic |
| po2mbt | `python po2mbt.py && moon check` |
| wasm | `moon build --target wasm` 产出 + demo 可调 |
| 全量 | `moon test` 全绿，旧测试不受影响 |
