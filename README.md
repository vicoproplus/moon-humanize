# humanize

[![PyPI 版本](https://img.shields.io/pypi/v/humanize.svg?logo=pypi&logoColor=FFE873)](https://pypi.org/project/humanize/)
[![支持的 Python 版本](https://img.shields.io/pypi/pyversions/humanize.svg?logo=python&logoColor=FFE873)](https://pypi.org/project/humanize/)
[![文档状态](https://readthedocs.org/projects/python-humanize/badge/?version=latest)](https://humanize.readthedocs.io/en/latest/?badge=latest)
[![PyPI 下载量](https://img.shields.io/pypi/dm/humanize.svg)](https://pypistats.org/packages/humanize)
[![GitHub Actions 状态](https://github.com/python-humanize/humanize/workflows/Test/badge.svg)](https://github.com/python-humanize/humanize/actions)
[![codecov](https://codecov.io/gh/python-humanize/humanize/branch/main/graph/badge.svg)](https://codecov.io/gh/python-humanize/humanize)
[![MIT 许可证](https://img.shields.io/github/license/python-humanize/humanize.svg)](LICENCE)
[![Tidelift](https://tidelift.com/badges/package/pypi/humanize)](https://tidelift.com/subscription/pkg/pypi-humanize?utm_source=pypi-humanize&utm_medium=badge)

这个小巧的库包含各种常用的人文化（humanization）工具函数，例如将数字转换为模糊的人类可读时长（"3 分钟前"），或转换为人类可读的大小、吞吐量。它支持以下语言本地化：

- 阿拉伯语
- 巴斯克语
- 孟加拉语
- 巴西葡萄牙语
- 加泰罗尼亚语
- 丹麦语
- 荷兰语
- 世界语
- 欧洲葡萄牙语
- 芬兰语
- 法语
- 德语
- 希腊语
- 希伯来语
- 印尼语
- 意大利语
- 日语
- 克林贡语
- 韩语
- 拉脱维亚语
- 挪威语
- 波斯语
- 波兰语
- 俄语
- 简体中文
- 僧伽罗语
- 斯洛伐克语
- 斯洛文尼亚语
- 西班牙语
- 瑞典语
- 土耳其语
- 乌克兰语
- 乌兹别克语
- 越南语

## API 参考

[https://humanize.readthedocs.io](https://humanize.readthedocs.io/)

<!-- usage-start -->

## 安装

### 通过 PyPI 安装

```bash
python3 -m pip install --upgrade humanize
```

### 从源码安装

```bash
git clone https://github.com/python-humanize/humanize
cd humanize
python3 -m pip install -e .
```

## 用法

### 整数人文化（Integer humanization）

```pycon
>>> import humanize
>>> humanize.intcomma(12345)
'12,345'
>>> humanize.intword(123455913)
'123.5 million'
>>> humanize.intword(12345591313)
'12.3 billion'
>>> humanize.apnumber(4)
'four'
>>> humanize.apnumber(41)
'41'
```

### 日期与时间人文化（Date & time humanization）

```pycon
>>> import humanize
>>> import datetime as dt
>>> humanize.naturalday(dt.datetime.now())
'today'
>>> humanize.naturaldelta(dt.timedelta(seconds=1001))
'16 minutes'
>>> humanize.naturalday(dt.datetime.now() - dt.timedelta(days=1))
'yesterday'
>>> humanize.naturalday(dt.date(2007, 6, 5))
'Jun 05'
>>> humanize.naturaldate(dt.date(2007, 6, 5))
'Jun 05 2007'
>>> humanize.naturaltime(dt.datetime.now() - dt.timedelta(seconds=1))
'a second ago'
>>> humanize.naturaltime(dt.datetime.now() - dt.timedelta(seconds=3600))
'an hour ago'
```

### 精确时间差（Precise time delta）

```pycon
>>> import humanize
>>> import datetime as dt
>>> delta = dt.timedelta(seconds=3633, days=2, microseconds=123000)
>>> humanize.precisedelta(delta)
'2 days, 1 hour and 33.12 seconds'
>>> humanize.precisedelta(delta, minimum_unit="microseconds")
'2 days, 1 hour, 33 seconds and 123 milliseconds'
>>> humanize.precisedelta(delta, suppress=["days"], format="%0.4f")
'49 hours and 33.1230 seconds'
```

#### 更小的单位（Smaller units）

如果秒级单位太大，可将 `minimum_unit` 设为毫秒或微秒：

```pycon
>>> import humanize
>>> import datetime as dt
>>> humanize.naturaldelta(dt.timedelta(seconds=2))
'2 seconds'
```

```pycon
>>> delta = dt.timedelta(milliseconds=4)
>>> humanize.naturaldelta(delta)
'a moment'
>>> humanize.naturaldelta(delta, minimum_unit="milliseconds")
'4 milliseconds'
>>> humanize.naturaldelta(delta, minimum_unit="microseconds")
'4 milliseconds'
```

```pycon
>>> humanize.naturaltime(delta)
'now'
>>> humanize.naturaltime(delta, minimum_unit="milliseconds")
'4 milliseconds ago'
>>> humanize.naturaltime(delta, minimum_unit="microseconds")
'4 milliseconds ago'
```

### 文件大小人文化（File size humanization）

```pycon
>>> import humanize
>>> humanize.naturalsize(1_000_000)
'1.0 MB'
>>> humanize.naturalsize(1_000_000, binary=True)
'976.6 KiB'
>>> humanize.naturalsize(1_000_000, gnu=True)
'976.6K'
```

### 人类可读的浮点数（Human-readable floating point numbers）

```pycon
>>> import humanize
>>> humanize.fractional(1/3)
'1/3'
>>> humanize.fractional(1.5)
'1 1/2'
>>> humanize.fractional(0.3)
'3/10'
>>> humanize.fractional(0.333)
'333/1000'
>>> humanize.fractional(1)
'1'
```

### 科学计数法（Scientific notation）

```pycon
>>> import humanize
>>> humanize.scientific(0.3)
'3.00 x 10⁻¹'
>>> humanize.scientific(500)
'5.00 x 10²'
>>> humanize.scientific("20000")
'2.00 x 10⁴'
>>> humanize.scientific(1**10)
'1.00 x 10⁰'
>>> humanize.scientific(1**10, precision=1)
'1.0 x 10⁰'
>>> humanize.scientific(1**10, precision=0)
'1 x 10⁰'
```

## 本地化（Localization）

如何在运行时切换语言区域（locale）：

```pycon
>>> import humanize
>>> import datetime as dt
>>> humanize.naturaltime(dt.timedelta(seconds=3))
'3 seconds ago'
>>> _t = humanize.i18n.activate("ru_RU")
>>> humanize.naturaltime(dt.timedelta(seconds=3))
'3 секунды назад'
>>> humanize.i18n.deactivate()
>>> humanize.naturaltime(dt.timedelta(seconds=3))
'3 seconds ago'
```

你可以向 `activate` 传递额外的 `path` 参数，以指定搜索翻译文件的路径。

```pycon
>>> import humanize
>>> humanize.i18n.activate("xx_XX")
<...>
FileNotFoundError: [Errno 2] No translation file found for domain: 'humanize'
>>> humanize.i18n.activate("pt_BR", path="path/to/my/own/translation/")
<gettext.GNUTranslations instance ...>
```

<!-- usage-end -->

如何向已有的语言区域文件添加新短语：

```sh
xgettext --from-code=UTF-8 -o humanize.pot -k'_' -k'N_' -k'P_:1c,2' -k'NS_:1,2' -k'_ngettext:1,2' -l python src/humanize/*.py  # 抽取新短语
msgmerge -U src/humanize/locale/ru_RU/LC_MESSAGES/humanize.po humanize.pot # 将其加入语言区域文件
```

如何新增一种语言区域：

```sh
msginit -i humanize.pot -o humanize/locale/<locale name>/LC_MESSAGES/humanize.po --locale <locale name>
```

其中 `<locale name>` 是语言区域缩写，例如 `en_GB`、`pt_BR`，或简写为 `ru`、`fr`` 等。

请在本 README 顶部列出该语言。

---

# 从 python-humanize 迁移到 MoonBit 库（moon-humanize）

本项目 `moon-humanize` 是 [python-humanize](https://github.com/python-humanize/humanize) 的 **MoonBit** 移植版本。

> MoonBit 包已发布到 [mooncakes.io](https://mooncakes.io)：[`yjdszjoe/moon-humanize`](https://mooncakes.io/#/package/yjdszjoe/moon-humanize)。
>
> 在 MoonBit 项目中添加依赖：
>
> ```bash
> moon add yjdszjoe/moon-humanize
> ```
>
> 引用方式：
>
> ```moonbit
> // 通过根包导入便捷函数
> import "yjdszjoe/moon-humanize"
>
> // 或直接引用内部 humanize 模块
> import "yjdszjoe/moon-humanize/src/humanize"
> ```
原项目是一个 Python 库，提供数字、时间、文件大小等的人文化转换工具；本库用 MoonBit 重新实现了其核心语义，
便于在 MoonBit / WASM 环境中复用相同的人文化能力。

> 仓库地址：<https://github.com/python-humanize/humanize>
> 本移植项目：<https://github.com/...> （如有自有仓库请替换）

## 为什么迁移到 MoonBit

- **跨平台 / WASM 友好**：MoonBit 可编译到 WASM，能在浏览器、边缘计算和嵌入式等无 Python 运行时的环境运行。
- **强类型与高性能**：MoonBit 的静态类型与编译期检查，在保持语义一致的同时提供更小的体积与更快的启动速度。
- **API 对齐**：函数命名与行为尽量对齐 Python 原版，降低迁移心智负担。

## 项目结构

```text
moon-humanize/
├── moonbit/                 # MoonBit 源码（移植核心）
│   ├── moonbit.mbt          # 根包，对外再导出 @humanize 模块
│   └── src/humanize/
│       ├── moon.pkg         # 包依赖声明
│       ├── number.mbt       # 数字人文化：clamp / metric / intcomma / intword / apnumber / fractional / scientific / ordinal
│       └── util.mbt         # 私有辅助函数（上标、定点格式化、幂运算等）
├── src/                     # 原 Python 库（保留以供对照 / 参考）
├── tests/                   # 原 Python 测试
└── docs/                    # 设计文档、移植规格说明
```

MoonBit 包入口（`moonbit/moonbit.mbt`）对外再导出了以下函数：

```moonbit
pub use @humanize.{clamp, metric, intcomma, intword, apnumber, fractional, scientific, ordinal}
```

同时还提供了一个便捷封装：

```moonbit
// 对整数直接添加千分位分隔符
pub fn intcomma_int(n : Int) -> String
```

## 已移植的 API 对照

| Python 函数 | MoonBit 函数 | 说明 |
| --- | --- | --- |
| `humanize.clamp(value, floor, ceil, floor_token, ceil_token, format)` | `clamp(value, ~floor, ~ceil, ~floor_token, ~ceil_token, ~format)` | 将数值钳制到区间；MoonBit 中非有限值返回 `"Inf"`/`"NaN"` 字符串形式（Python 的 `None` 在 MoonBit 中以 `Double?` 可省略表示）。 |
| `humanize.metric(value, unit, precision)` | `metric(value, ~unit, ~precision)` | SI 公制前缀格式化。 |
| `humanize.intcomma(value, ndigits)` | `intcomma(value : String, ~ndigits)` | 添加千分位分隔符；注意 MoonBit 版入参为 **字符串**，需先 `n.to_string()`。 |
| `humanize.intword(value, format)` | `intword(value : String, ~format)` | 大数友好量级表达（如 `"123.5 million"`）；入参同样为字符串。 |
| `humanize.apnumber(value)` | `apnumber(value : String)` | 0–9 转为英文单词，其余保持数字串。 |
| `humanize.fractional(value)` | `fractional(value : String)` | 浮点转为分数 / 带分数。 |
| `humanize.scientific(value, precision)` | `scientific(value : String, ~precision)` | 科学计数法，指数用上标渲染（`10ⁿ`）。 |
| `humanize.ordinal(value)` | `ordinal(value : String)` | 英文序数后缀（`1st` / `2nd` / `3rd` …）。 |

> 注意：MoonBit 版本的函数入参普遍为 **`String`**（而非 Python 的各类数值类型），内部再做解析，
> 这样可以与原 Python 行为对齐、同时避免数值类型重载带来的复杂度。

## 用法对照示例

Python 原版：

```python
import humanize
humanize.intcomma(12345)          # '12,345'
humanize.intword(123455913)       # '123.5 million'
humanize.apnumber(4)              # 'four'
humanize.fractional(1.5)          # '1 1/2'
humanize.scientific(500)          # '5.00 x 10²'
```

MoonBit 等价写法：

```moonbit
// 假设已 import @humanize 或通过根包导入
@humanize.intcomma(12345.to_string())   // "12,345"
@humanize.intword(123455913.to_string())// "123.5 million"
@humanize.apnumber(4.to_string())       // "four"
@humanize.fractional(1.5.to_string())   // "1 1/2"
@humanize.scientific(500.to_string())   // "5.00 x 10²"

// 或使用根包便捷函数
intcomma_int(12345)                    // "12,345"
```

## 与 Python 版本的主要差异（已知移植差距）

1. **入参类型**：Python 接受 `int` / `float` / `str` 等多种类型；MoonBit 统一用 `String`（数字需先转字符串）。
2. **本地化（i18n）**：MoonBit 移植已接入 `gettext` / `ngettext` / `pgettext` 体系，
   `apnumber` / `fractional` / `scientific` / `ordinal` 等用户可见文案已通过 `gettext` 路由，
   可由 `src/humanize/locale/*/LC_MESSAGES/humanize.po` 提供多语言翻译；英文与未配置语言区域自动回退为英文。
   翻译数据由 `scripts/po2mbt` 从 `.po` 文件生成 `moonbit/src/humanize/i18n_data.mbt`
   （CI 中通过 `scripts/po2mbt --check` 确保二者同步）。
3. **时间相关函数**：`naturalday` / `naturaltime` / `naturaldelta` / `precisedelta` / `naturalsize` 等
   依赖 `datetime` 与文件系统翻译数据，目前尚在移植规划中（参见 `docs/time.md`、`docs/filesize.md`、
   `docs/number.md` 等规格说明）。
4. **定点格式化**：MoonBit 的 `Double::to_string` 不支持精度说明符，本项目自实现了 `format_fixed`
   （四舍五入 half-up）以近似 Python 的 `"%.Nf"`（已知差距 R1）。

## 构建与测试

MoonBit 部分使用 MoonBit 工具链构建：

```bash
# 需要已安装 MoonBit 工具链（moon）
cd moonbit
moon build
moon test
```

详细的移植计划与阶段进度见 `docs/specs/port-to-moonbit.md` 及各模块设计文档
（`docs/number.md`、`docs/time.md`、`docs/filesize.md`、`docs/i18n.md`、`docs/lists.md`）。
