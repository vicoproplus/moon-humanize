# Spec: Python → MoonBit 移植规划 (moon-humanize)

- 状态: Draft
- 创建日期: 2026-08-17
- 关联项目: 当前仓库为 `python-humanize` 的镜像（`src/humanize/*.py`）。
- 目标: 将该库的人类可读文本格式化能力移植到 MoonBit，行为等价于原 Python 版。

## 1. 目标 (Goals)

- G1 功能等价: 移植后的 MoonBit 库对相同输入产生与原 Python 版一致（或约定容差内一致）的输出。
- G2 库 + WASM/JS 交付: 除 MoonBit 库外，编译为 WASM 并提供 JS/TS 互操作 API。
- G3 可测性: 复用原 Python 测试断言值作为 golden，通过 `moon test` 验证等价性。

## 2. 非目标 (Non-Goals)

- NG1 国际化(i18n): MVP 不做 gettext / `.po` 多语言。仅实现英文/默认行为。i18n 留作后续阶段(Phase 6)。
- NG2 CLI 工具: 本次不提供命令行可执行（如需要，作为独立阶段追加）。
- NG3 100% 性能对标: 不强制性能基准，以行为正确为优先。

## 3. 已核实的能力事实 (MoonBit core)

来源: `moonbitlang/core` 源码核实 + 工具链实测（2026-06 toolchain v0.1.20260629）。

| 能力 | MoonBit 对应 | 备注 |
|------|-------------|------|
| 大整数(googol, 100位) | `BigInt`(`123N` / `from_string` / `Show::to_string`，任意精度) | `intword` 可用 |
| `math.log10` | `@math.log10(x: Double) -> Double`（调用带 `@` 前缀包名别名） | `intword` 指数计算 |
| `math.floor/ceil/round/trunc` | `@double.floor/@double.ceil` 等，作为方法 `(x).floor()` 或 `@double.floor(x)`（由 `math/round.mbt` 的 `pub using @double` 重导出） | 浮点取整 |
| import 机制 | 包导入写在 `moon.pkg`（`import { "moonbitlang/core/math" }`），不可写在 .mbt | 工程结构 |
| 浮点格式化 `%.1f` | `Double::to_string()` 存在，但无精度格式符 | 需自写 `format_fixed` |
| `Fraction.limit_denominator` | 无 Fraction 类型 | `fractional` 需自实现连分数近似 |
| `bisect` 二分查找 | 数组 `binary_search` 可替代 | `intword` 区间定位 |
| `str.maketrans` 上标映射 | `String` 逐字符替换 | `scientific` 上标 |
| gettext `.po` | 无原生对应 | MVP 不做(NG1) |
| WASM/JS 导出 | `foreign_library` + `#export_name` + `moon build --target wasm` | 交付形态(G2) |

> 环境状态(已实测 2026-08-17): 本机 `moon` 工具链与 core 标准库**均完好可用**。先前"Cannot load core file"系误用旧版 `moon.mod` 格式所致；改用现代 `moon new` 生成工程（含 `moon.pkg`/`moon.mod`）后 `moon check` 正常。验证通过的调用方式：`BigInt` 字面量 `123N`、`@math.log10(x)`、`(x).floor()`，包导入置于 `moon.pkg`。

## 4. 目标架构

```
moon-humanize/
├── moon.mod.json            # 包名 humanize，依赖 @moonbitlang/core
├── src/humanize/
│   ├── number.mbt           # ordinal/intcomma/intword/apnumber/fractional/scientific/clamp/metric
│   ├── time.mbt             # naturaltime/naturalday/naturaldelta/precisedelta
│   ├── filesize.mbt         # naturalsize
│   ├── lists.mbt            # natural_list
│   ├── util.mbt             # 私有辅助: format_fixed / 上标映射 / 二分 / 连分数近似
│   └── wasm.mbt             # 导出层（foreign_library + #export_name）
├── tests/                   # moon test（复用 Python 断言值）
└── js/                      # 加载 WASM 的 JS 封装 + 示例 index.html
```

### 4.1 API 设计原则
- 核心层保持纯函数、`String/String -> String` 风格，便于测试。
- WASM 导出层做"字符串进出"桥接（JS 传 `String`/`Int`，返回 `String`），规避类型鸿沟。
- `naturaltime` 等依赖"当前时间"的函数注入 `now` 参数保持可测。

## 5. 分阶段实施计划

### Phase 0 — 环境修复
- 重装/修复 `moonc` 使 core 可用；`moon new` 建骨架；`moon check` 跑通空包。
- 建立 `moon test` 与 `moon build --target wasm` 验证流水线。

### Phase 1 — 数字模块 (number.mbt)
- `util.mbt`: `format_fixed`(仿 `%.Nf`)、上标字符表、`bisect` 区间定位、连分数有理近似。
- 函数: `intcomma`, `ordinal`, `apnumber`, `intword`(BigInt 转 Double 后用 @math.log10 算指数), `scientific`, `clamp`, `metric`, `fractional`。
- 验收: 对照 Python 测试值 100% 通过。

### Phase 2 — 时间模块 (time.mbt)
- 使用 core `time` 模块。先实现无外部时钟依赖的 `naturaldelta`/`precisedelta`；`naturaltime`/`naturalday` 用注入 `now` 参数。

### Phase 3 — 文件大小 + 列表 (filesize.mbt / lists.mbt)
- `naturalsize` 复用 `intword` 思路；`natural_list` 纯字符串拼接。

### Phase 4 — WASM/JS 互操作层 (wasm.mbt + js/)
- 用 `foreign_library` + `#export_name` 导出核心函数（`moon build --target wasm`）；`js/loader.mjs` 加载并暴露 `humanize.intcomma(...)` 等 TS 风格 API；`index.html` 演示。

### Phase 5 — 测试对齐 & 文档
- 将 Python `tests/*.py` 全部用例翻译为 `moon test`；写 `README`(含 JS 用法)；可选 CI。

### Phase 6 (后续, 暂不做) — i18n
- 设计 `.po` 数据的 MoonBit 字典结构 + 运行时查表；先内置 2-3 语言验证机制。

## 6. 验收标准 (Acceptance)

- A1 Phase 1~3 全部函数在 `moon test` 中通过对应的 Python 断言值（浮点末位差异允许约定容差）。
- A2 `moon build --target wasm` 成功产出 wasm，JS 封装可调用核心函数并返回等价字符串。
- A3 `naturaltime` 等在注入 `now` 下确定性可测。

## 7. 风险与待决

- R1 浮点显示末位差异（如 `scientific` 尾数舍入）→ 约定容差。
- R2 `fractional` 有理近似实现选择（连分数 vs 固定分母表）→ 对齐 Python `Fraction.limit_denominator(1e6)` 算法。
- R3 环境修复需联网/重装 moonc → 需用户授权执行。
