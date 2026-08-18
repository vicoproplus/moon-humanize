# Spec: 科学计数法连接符本地化（scientific connector i18n）

- 日期：2026-08-18
- 关联计划：`docs/plans/2026-08-18-moonbit-gap-fill-plan.md`
- 关联前置 Spec：`docs/specs/2026-08-18-moonbit-gap-fill-spec.md` §2.3
- 决策来源：`@command://brainstorming` 确认（用户选择 **A + A**）

## 1. 背景与问题

### 1.1 现状
- `moonbit/src/humanize/number.mbt` 中 `scientific` 当前实现：

```moonbit
let sign = if neg { "-" } else { "" }
// 整串经 gettext；英文/未知语言回退
gettext(sign + mant_str + " x 10" + exp_str)
```

  其中 `sign` / `mant_str`（系数，如 `"5.00"`）/ `exp_str`（上标指数，如 `"²"`）均为**数值或符号**，无对应 `.po` 词条；唯一潜在可译 token 是连接符 `" x 10"`。
  当前把**整串**喂给 `gettext`，因目录里没有组合串词条，永远回退英文，故 `activate("ru")` 后 `scientific` 输出仍是英文。

- `fractional` 当前也是 `gettext(整串)`（如 `"3/10"`）。但 python-humanize 的 `fractional` **本就输出数字形式**（`fractional(0.3) == "3/10"`，非 `"three tenths"`），所有 `.po` 目录中**不存在** `half`/`third`/`quarter` 等单词词条，且 `number_test.mbt:46-49` 断言期望纯数字串。

### 1.2 结论（经自查 python-humanize 源码确认）
- **`fractional` 无需单词映射**：python 本身不用单词，移植已与之对齐，没有"分母单词"可译 → 保持现状，本次**不改动**。
- **唯一真实本地化缺口在 `scientific` 的连接符 `" x 10"`** → 本次只解决它。

## 2. 目标

让 `activate("ru"); scientific(...)` 的连接符进入**可翻译状态**：俄语下渲染为 `" × 10"`（Unicode 乘号，俄文科学计数法惯例），英文/未配置语言保持 `" x 10"` 不变。

### 2.1 非目标
- 不引入"分母/系数单词表"（与 python 行为偏离、破坏既有测试）。
- 不改动 `fractional`（无词可译，数字形式即 python 行为）。
- 不改动 `apnumber` / `ordinal`（已正确本地化，见 gap-fill 实现）。

## 3. 方案（A + A）

### 3.1 代码改动：`scientific` 拆分连接符（`moonbit/src/humanize/number.mbt`）
将连接符 `" x 10"` 作为独立 token 走 `gettext`，数值部分不译：

```moonbit
let sign = if neg { "-" } else { "" }
// 系数/指数均为数值，保持原样；仅连接符走 gettext 以支持本地化。
// 英文（无 " x 10" 词条）回退为 " x 10"，输出与现状一致。
sign + mant_str + gettext(" x 10") + exp_str
```

- `gettext` 在 msgid 缺失时返回 msgid 本身（`lookup_message` 默认分支），故英文下行为**完全不变**。
- 不动 `fractional`（维持 `gettext(整串)`，因无对应词条，回退英文，与 python 一致）。

### 3.2 目录改动：新增 `" x 10"` 词条
在需要本地化的 `.po` 中追加条目。本 Spec 以 `ru_RU` 作示范（其余语言按需，由 `po2mbt --check` 保证 `i18n_data.mbt` 与 `.po` 一致）。

`src/humanize/locale/ru_RU/LC_MESSAGES/humanize.po` 追加：

```
#: src/humanize/number.mbt:scientific
msgid " x 10"
msgstr " × 10"
```

- 英文回退机制：英文无 `.po`（仓库仅含非英文目录），`gettext(" x 10")` 在 `TRANSLATIONS` 缺失时返回 `" x 10"` → 不变。
- 其他语言（如 `fr_FR`、`de_DE` 等）：可选追加；若不追加则保持英文连接符，符合"未翻译即回退"原则。

### 3.3 重新生成并提交 `i18n_data.mbt`
```bash
python3 scripts/po2mbt        # 由 .po 重新生成 moonbit/src/humanize/i18n_data.mbt
```
`ru_RU` 的 `msg_RuRU` 映射将包含 `(" x 10", " × 10")`。该生成文件须随 `.po` 一并提交（CI 中 `scripts/po2mbt --check` 校验其同步性）。

### 3.4 测试预期
新增本地化断言（建议置于 `moonbit/src/humanize/number_test.mbt` 或新建 `i18n_localization_test.mbt`）：

```moonbit
test "scientific_ru" {
  let _ = activate("ru")
  @test.assert_eq(scientific("500"), "5.00 × 10²")
  @test.assert_eq(scientific("-1000"), "-1.00 × 10³")
  deactivate()
}

test "scientific_en_fallback" {
  deactivate()
  @test.assert_eq(scientific("500"), "5.00 x 10²")
}
```

- 既有 `number_test.mbt:53-60` 断言（`"5.00 x 10²"` 等）在 `deactivate()`（英文）下**仍然成立**，无回归。

## 4. 验收标准

| # | 场景 | 期望 |
|---|------|------|
| 1 | `deactivate()` 后 `scientific("500")` | `"5.00 x 10²"`（与现状一致，无回归） |
| 2 | `activate("ru")` 后 `scientific("500")` | `"5.00 × 10²"` |
| 3 | `activate("ru")` 后 `scientific("-1000")` | `"-1.00 × 10³"` |
| 4 | `fractional("0.3")`（`activate("ru")` 或默认） | `"3/10"`（数字形式不变，与 python 一致） |
| 5 | `scripts/po2mbt --check` | 退出码 0（`.po` 与 `i18n_data.mbt` 同步） |
| 6 | `moon build` / `--target wasm-gc` / `--target native` | 三目标编译通过 |
| 7 | CI `moonbit-i18n-sync` 与 `moonbit-build` job | 均绿 |

## 5. 实现步骤清单
1. [ ] 改 `number.mbt` `scientific`：拆分 `gettext(" x 10")`。
2. [ ] `ru_RU.po` 追加 `msgid " x 10"` / `msgstr " × 10"`。
3. [ ] 运行 `python3 scripts/po2mbt` 重新生成 `i18n_data.mbt`，审查 diff 确认新条目。
4. [ ] 新增 ru 本地化测试 + 确认既有测试无回归。
5. [ ] `moon build`（默认/native/wasm-gc）通过；`scripts/po2mbt --check` 通过。
6. [ ] 提交 `.po` 与 `i18n_data.mbt`（连同代码与测试）。

## 6. 风险与备注
- **零回归**：英文路径经 `gettext` 身份回退，输出字节级不变；既有 `number_test` 全绿。
- **`fractional` 不动**：避免偏离 python 行为、避免破坏 `number_test.mbt:46-49`。
- **乘号选择**：ru 示例用 `" × 10"`（U+00D7）。若俄语维护者偏好 `" x 10"` 或 `"·10"`, 仅需改 `ru_RU.po` 一处并重新生成，无需动代码。
- **可扩展性**：后续任何语言只需在其 `.po` 加一条 `msgid " x 10"`，即可获得本地化连接符。
